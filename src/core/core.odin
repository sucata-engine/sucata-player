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
	texture: string,
	z_index: i32,
	shader:  u32,
	fixed:   bool,
	tiled:   bool,
}
render_group_index: map[RenderGroupKey]int = {}

group_quads_pool: [dynamic]^[dynamic]common.ObjectProp = {}

acquire_group_quads :: proc() -> ^[dynamic]common.ObjectProp {
	if len(group_quads_pool) > 0 {
		return pop(&group_quads_pool)
	}
	return new([dynamic]common.ObjectProp)
}

release_group_quads :: proc(quads: ^[dynamic]common.ObjectProp) {
	clear(quads)
	append(&group_quads_pool, quads)
}

cleanup_group_quads_pool :: proc() {
	for quads in group_quads_pool {
		delete(quads^)
		free(quads)
	}
	delete(group_quads_pool)
	group_quads_pool = {}
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
	if !is_draw_step {
		common.print_error("Trying to render outside draw() function")
		return
	}

	lookup_key := RenderGroupKey {
		texture = texture,
		z_index = z_index,
		shader  = shader,
		fixed   = fixed,
		tiled   = tiled,
	}
	if index, ok := render_group_index[lookup_key]; ok {
		group := renderQueue[index].(common.GroupObjectProps)
		append(group.quads, prop)
		return
	}

	quads := acquire_group_quads()
	append(quads, prop)
	owned_texture := strings.clone(texture)
	group_quads := common.GroupObjectProps {
		texture = owned_texture,
		z_index = z_index,
		shader  = shader,
		fixed   = fixed,
		tiled   = tiled,
		quads   = quads,
	}
	append(&renderQueue, group_quads)
	render_group_index[RenderGroupKey{texture = owned_texture, z_index = z_index, shader = shader, fixed = fixed, tiled = tiled}] =
		len(renderQueue) - 1
}

clear_render_queue :: proc() {
	for v in renderQueue {
		switch obj in v {
		case common.GroupObjectProps:
			delete(obj.texture)

			if obj.quads != nil {
				for quad in obj.quads^ {
					for key, shader in quad.shader_args {
						#partial switch v in shader {
						case string:
							delete(v)
						}
						delete(key)
					}
					shader_args := quad.shader_args
					delete(shader_args)
				}

				release_group_quads(obj.quads)
			}
		case common.TextObjectProps:
			delete(obj.font)
			delete(obj.text)
			for key, shader in obj.shader_args {
				#partial switch v in shader {
				case string:
					delete(v)
				}
				delete(key)
			}
			shader_args := obj.shader_args
			delete(shader_args)
		}
	}
	clear(&renderQueue)
	clear(&render_group_index)
}

draw_render_queue :: proc() {
	for v in renderQueue {
		switch obj in v {
		case common.TextObjectProps:
			graphics.queue_text(obj)
		case common.GroupObjectProps:
			graphics.queue_quad_group(obj)
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
