package core

import "../common"
import "../filesystem"
import "../graphics"
import audio "./audio"
import "base:runtime"
import "core:c"
import "core:strings"
import "core:time"
import sapp "shared:sokol/app"
import sg "shared:sokol/gfx"
import sglue "shared:sokol/glue"
import shelpers "shared:sokol/helpers"
import st "shared:sokol/time"
import lua "vendor:lua/5.4"

BACKGROUND_FPS :: 15
MINIMIZED_FPS :: 5

is_window_focused: bool = true
is_window_minimized: bool = false

delta_time: f64 = 0.016
time_scale: f64 = 1.0
fps: u64 = 0.0

clear_color := sg.Color {
	r = 0.0,
	g = 0.0,
	b = 0.0,
	a = 1.0,
}
last_frame_time: u64
first_frame: bool = true

GC_STEP_KB_MIN :: 5
last_gc_kb: c.int = 0

calc_time :: proc() {
	current_time := st.now()

	if first_frame {
		last_frame_time = current_time
		first_frame = false
		delta_time = 0.016
		return
	}

	delta_ticks := current_time - last_frame_time
	delta_seconds := st.sec(delta_ticks)

	if delta_seconds < 0.001 {
		delta_time = 0.001
	} else if delta_seconds > 0.1 {
		delta_time = 0.1
	} else {
		delta_time = delta_seconds
	}

	last_frame_time = current_time

	if delta_time > 0.0 {
		fps = u64(1.0 / delta_time)
	}
}

init_sokol :: proc() {
	window_title := strings.clone_to_cstring(windowConfig.title)
	defer delete(window_title)

	icon_desc := load_window_icon(windowConfig.icon)
	defer free_icon_desc(&icon_desc)

	sapp.run(
		{
			width = windowConfig.width,
			height = windowConfig.height,
			window_title = window_title,
			allocator = sapp.Allocator(shelpers.allocator(&DEFAULT_CONTEXT)),
			logger = sapp.Logger(shelpers.logger(&DEFAULT_CONTEXT)),
			swap_interval = windowConfig.vsync,
			fullscreen = windowConfig.fullscreen,
			icon = icon_desc,
			init_cb = init_callback,
			frame_cb = frame_callback,
			cleanup_cb = cleanup_callback,
			event_cb = event_callback,
		},
	)
}

init_callback :: proc "c" () {
	context = DEFAULT_CONTEXT

	st.setup()
	sg.setup(
		{
			environment = sglue.environment(),
			allocator = sg.Allocator(shelpers.allocator(&DEFAULT_CONTEXT)),
			logger = sg.Logger(shelpers.logger(&DEFAULT_CONTEXT)),
		},
	)
	graphics.set_game_dimensions(windowConfig.width, windowConfig.height)
	graphics.init_graphics()
	common.print_info("Sokol initialized with %s", sg.query_backend())

	if audio.init() {
		common.print_info("Audio engine initialized")
	} else {
		common.print_error("Failed to initialize audio engine")
	}

	init_gamepad()

	is_game_started = true
	process_post_commands()

	run_init()

	flush_init_queue()
}

cleanup_callback :: proc "c" () {
	context = DEFAULT_CONTEXT

	if exit_callback_ref > 0 && LUA_GLOBAL_STATE != nil {
		call_lua_function(LUA_GLOBAL_STATE, exit_callback_ref)
		lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, exit_callback_ref)
		exit_callback_ref = 0
	}

	run_free()
	cleanup_group_quads_pool()
	cleanup_event_handlers()
	cleanup_behaviours()
	cleanup_tags()
	cleanup_timers()
	cleanup_entities()
	shutdown_gamepad()
	audio.shutdown()
	dynlib_shutdown()
	graphics.shutdown_graphics()

	sg.shutdown()
	filesystem.unload_assets()
	filesystem.unload_file_cache()

	if LUA_GLOBAL_STATE != nil {
		lua.close(LUA_GLOBAL_STATE)
		LUA_GLOBAL_STATE = nil
	}
	cleanup_temp_arena()
	filesystem.uninit_paths()
}

get_target_fps :: proc() -> i32 {
	if is_window_minimized {
		return MINIMIZED_FPS
	}
	if !is_window_focused {
		return BACKGROUND_FPS
	}
	return windowConfig.max_fps
}

elapsed_time := 0.0
frame_callback :: proc "c" () {
	context = DEFAULT_CONTEXT
	context.temp_allocator = temp_allocator
	defer reset_temp_arena()

	frame_start_time := st.now()

	if init_callback_ref > 0 && LUA_GLOBAL_STATE != nil {
		call_lua_function(LUA_GLOBAL_STATE, init_callback_ref)
		lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, init_callback_ref)
		init_callback_ref = 0
	}

	sapp.show_mouse(windowConfig.visible_mouse)
	sapp.lock_mouse(windowConfig.lock_mouse)

	calc_time()
	update_timers(delta_time)
	audio.update()

	poll_gamepad_events()

	process_pending_scene()
	run_update()
	process_hoverables()

	elapsed_time += delta_time

	pass_action := sg.Pass_Action{}
	pass_action.colors[0] = {
		load_action = .CLEAR,
		clear_value = clear_color,
	}
	sg.begin_pass(
		{
			action = pass_action,
			attachments = {
				colors = {0 = graphics.offscreen.color_att_view},
				depth_stencil = graphics.offscreen.depth_att_view,
			},
		},
	)

	is_draw_step = true
	run_draw()
	is_draw_step = false
	sg.end_pass()

	graphics.preprocess_postfx(&graphics.offscreen)

	swapchain_action := sg.Pass_Action{}
	swapchain_action.colors[0] = {
		load_action = .CLEAR,
		clear_value = clear_color,
	}
	sg.begin_pass({swapchain = sglue.swapchain(), action = swapchain_action})

	if windowConfig.keep_aspect > 0 {
		screen_width := sapp.width()
		screen_height := sapp.height()
		x, y, w, h: i32

		if windowConfig.keep_aspect == 2 {
			x, y, w, h = get_game_screen_crop(screen_width, screen_height)
		} else {
			x, y, w, h = get_game_screen(screen_width, screen_height)
		}

		sg.apply_viewport(x, y, w, h, true)
		sg.apply_scissor_rect(x, y, w, h, true)
	}
	graphics.draw_postfx()
	sg.end_pass()

	sg.commit()
	elapsed_time = 0.0

	clear_input()
	clear_gamepad_states()
	process_destroy_queue()

	if LUA_GLOBAL_STATE != nil {
		current_kb := lua.gc(LUA_GLOBAL_STATE, lua.GCCOUNT)
		delta_kb := current_kb - last_gc_kb
		step_kb := delta_kb > GC_STEP_KB_MIN ? delta_kb : GC_STEP_KB_MIN
		lua.gc(LUA_GLOBAL_STATE, lua.GCSTEP, step_kb)
		last_gc_kb = lua.gc(LUA_GLOBAL_STATE, lua.GCCOUNT)
	}

	target_fps := get_target_fps()
	if target_fps > 0 {
		target_frame_seconds := 1.0 / f64(target_fps)
		elapsed_seconds := st.sec(st.since(frame_start_time))
		if elapsed_seconds < target_frame_seconds {
			time.sleep(time.Duration((target_frame_seconds - elapsed_seconds) * f64(time.Second)))
		}
	}
}

event_callback :: proc "c" (event: ^sapp.Event) {
	context = DEFAULT_CONTEXT

	if event.type == .RESIZED {
		handle_window_resize(event.window_width, event.window_height)
	}

	#partial switch event.type {
	case .FOCUSED:
		is_window_focused = true
	case .UNFOCUSED:
		is_window_focused = false
	case .ICONIFIED:
		is_window_minimized = true
	case .RESTORED:
		is_window_minimized = false
	}

	handle_input_event(event)
}

handle_window_resize :: proc(width, height: i32) {
	if windowConfig.keep_aspect > 0 {
		graphics.set_game_dimensions(windowConfig.width, windowConfig.height)
		graphics.resize_postfx(windowConfig.width, windowConfig.height)
	} else {
		graphics.set_game_dimensions(width, height)
		graphics.resize_postfx(width, height)
	}
}
