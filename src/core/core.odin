package core

import "../common"
import "../graphics"
import "base:runtime"
import "core:sort"
import "core:strings"
import sapp "shared:sokol/app"
import lua "../luajit"

LUA_GLOBAL_STATE: ^lua.State
DEFAULT_CONTEXT: runtime.Context

LUA_TRACEBACK_REF: i32 = 0

width: i32 = 800
height: i32 = 600

is_build_mode: bool = false
is_game_started: bool = false
is_draw_step: bool = false

renderQueue: [dynamic]common.GraphicObjectProps = {}

RenderGroupKey :: struct {
	texture: u32,
	z_index: i32,
	shader:  u32,
	fixed:   bool,
	tiled:   bool,
}
render_group_index: map[RenderGroupKey]int = {}

last_group_key: RenderGroupKey
last_group_index := -1

group_quads_pool: [dynamic]^[dynamic]common.QuadProp = {}
group_args_pool: [dynamic]^[dynamic]common.ShaderArgs = {}

acquire_group_quads :: proc() -> ^[dynamic]common.QuadProp {
	if len(group_quads_pool) > 0 {
		return pop(&group_quads_pool)
	}
	return new([dynamic]common.QuadProp)
}

release_group_quads :: proc(quads: ^[dynamic]common.QuadProp) {
	clear(quads)
	append(&group_quads_pool, quads)
}

acquire_group_args :: proc() -> ^[dynamic]common.ShaderArgs {
	if len(group_args_pool) > 0 {
		return pop(&group_args_pool)
	}
	return new([dynamic]common.ShaderArgs)
}

release_group_args :: proc(args: ^[dynamic]common.ShaderArgs) {
	clear(args)
	append(&group_args_pool, args)
}

cleanup_group_quads_pool :: proc() {
	for quads in group_quads_pool {
		delete(quads^)
		free(quads)
	}
	delete(group_quads_pool)
	group_quads_pool = {}
	for args in group_args_pool {
		delete(args^)
		free(args)
	}
	delete(group_args_pool)
	group_args_pool = {}
}

delete_shader_args :: proc(args: common.ShaderArgs) {
	for key, value in args {
		#partial switch v in value {
		case string:
			delete(v)
		}
		delete(key)
	}
	args := args
	delete(args)
}

VERSION :: "2.0.0"

init_callback_ref: i32 = 0

set_init_callback :: proc(func_ref: i32) {
	if init_callback_ref > 0 && LUA_GLOBAL_STATE != nil {
		lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, init_callback_ref)
	}
	init_callback_ref = func_ref
}

main :: proc() {
	init_sokol()
}

run_draw :: proc() {
	graphics.invalidate_mvp_cache()
	draw_debug_info()
	run_phase(.Draw)
	order_render_queue()
	draw_render_queue()
	clear_render_queue()
	graphics.destroy_unused_images()
}

cleanup_render_queue :: proc() {
	clear_render_queue()
	delete(renderQueue)
	renderQueue = {}
	delete(render_group_index)
	render_group_index = {}
}

quit :: proc() {
	sapp.quit()
}

add_to_render_queue :: proc(props: common.GraphicObjectProps) {
	if !is_draw_step {
		common.print_error("Trying to render outside draw() function")
		return
	}
	append(&renderQueue, props)
}

add_group_to_render_queue :: proc(
	z_index: i32,
	texture: string,
	shader: u32,
	fixed: bool,
	tiled: bool,
	prop: common.ObjectProp,
) {
	color := prop.color
	if opacity, ok := prop.opacity.?; ok {
		color[3] = opacity
	}
	handle := texture == "" ? 0 : register_texture(texture)
	add_quad_to_render_queue(
		z_index,
		handle,
		shader,
		fixed,
		tiled,
		common.QuadProp {
			position = prop.position,
			size = prop.size,
			scale = prop.scale,
			origin = prop.origin,
			color = color,
			rotation = prop.rotation,
			atlas = prop.atlas,
			tile_size = prop.tile_size,
		},
		prop.shader_args,
	)
}

add_quad_to_render_queue :: proc(
	z_index: i32,
	texture: u32,
	shader: u32,
	fixed: bool,
	tiled: bool,
	quad: common.QuadProp,
	shader_args: common.ShaderArgs = nil,
) {
	if !is_draw_step {
		common.print_error("Trying to render outside draw() function")
		if shader_args != nil {
			delete_shader_args(shader_args)
		}
		return
	}

	key := RenderGroupKey {
		texture = texture,
		z_index = z_index,
		shader  = shader,
		fixed   = fixed,
		tiled   = tiled,
	}

	index := last_group_index
	if index < 0 || last_group_key != key {
		found: bool
		index, found = render_group_index[key]
		if !found {
			append(
				&renderQueue,
				common.GroupObjectProps {
					texture = texture,
					z_index = z_index,
					shader = shader,
					fixed = fixed,
					tiled = tiled,
					quads = acquire_group_quads(),
				},
			)
			index = len(renderQueue) - 1
			render_group_index[key] = index
		}
		last_group_key = key
		last_group_index = index
	}

	group := &renderQueue[index].(common.GroupObjectProps)
	append(group.quads, quad)

	if shader_args != nil {
		if group.args == nil {
			group.args = acquire_group_args()
		}
		resize(group.args, len(group.quads) - 1)
		append(group.args, shader_args)
	}
}

clear_render_queue :: proc() {
	for v in renderQueue {
		switch obj in v {
		case common.GroupObjectProps:
			if obj.args != nil {
				for args in obj.args^ {
					if args != nil {
						delete_shader_args(args)
					}
				}
				release_group_args(obj.args)
			}
			if obj.quads != nil {
				release_group_quads(obj.quads)
			}
		case common.TextObjectProps:
			if obj.shader_args != nil {
				delete_shader_args(obj.shader_args)
			}
		}
	}
	clear(&renderQueue)
	clear(&render_group_index)
	last_group_index = -1
}

draw_render_queue :: proc() {
	for v in renderQueue {
		switch obj in v {
		case common.TextObjectProps:
			graphics.queue_text(obj)
		case common.GroupObjectProps:
			graphics.queue_quad_group(obj, texture_path(obj.texture))
		}
	}
	graphics.flush_draw_commands()
}

order_render_queue :: proc() {
	sort.quick_sort_proc(
		renderQueue[:],
		proc(a: common.GraphicObjectProps, b: common.GraphicObjectProps) -> int {
			a_z_index: i32
			b_z_index: i32

			switch v in a {
			case common.TextObjectProps:
				a_z_index = v.zIndex
			case common.GroupObjectProps:
				a_z_index = v.z_index
			}

			switch v in b {
			case common.TextObjectProps:
				b_z_index = v.zIndex
			case common.GroupObjectProps:
				b_z_index = v.z_index
			}

			if a_z_index < b_z_index {return -1}
			if a_z_index > b_z_index {return 1}
			return 0
		},
	)
}
