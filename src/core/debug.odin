package core

import "core:fmt"
import sg "shared:sokol/gfx"
import lua "vendor:lua/5.4"

draw_debug_info :: proc() {
	if !windowConfig.draw_debug_info {
		return
	}

	context.temp_allocator = temp_allocator

	frame_stats := sg.query_stats()
	frame_time_ms := delta_time * 1000.0
	lua_memory_kb := f64(lua.gc(LUA_GLOBAL_STATE, lua.GCCOUNT, 0))
	lua_bmemory_kb := f64(lua.gc(LUA_GLOBAL_STATE, lua.GCCOUNTB, 0))
	draw_calls := frame_stats.prev_frame.num_draw
	alives :=
		frame_stats.total.buffers.alive +
		frame_stats.total.images.alive +
		frame_stats.total.pipelines.alive +
		frame_stats.total.samplers.alive +
		frame_stats.total.views.alive +
		frame_stats.total.shaders.alive

	if microui_window_begin("Debug Info", 10, 10, 260, 190) {
		microui_label(fmt.tprintf("FPS: %d", fps))
		microui_label(fmt.tprintf("Entities: %d", get_scene_count()))
		microui_label(fmt.tprintf("Draw Calls: %d", draw_calls))
		microui_label(fmt.tprintf("Frame Time: %.2f ms", frame_time_ms))
		microui_label(fmt.tprintf("Lua Memory: %.2f/%.2f KB", lua_memory_kb, lua_bmemory_kb))
		microui_label(fmt.tprintf("Sokol Obj Alives: %d", alives))
		microui_window_end()
	}
}
