package core

import "../common"
import "../graphics"
import "base:runtime"
import "core:sort"
import "core:strings"
import lua "shared:luajit"
import sapp "shared:sokol/app"

LUA_GLOBAL_STATE: ^lua.State
DEFAULT_CONTEXT: runtime.Context

width: i32 = 800
height: i32 = 600

is_build_mode: bool = false
is_game_started: bool = false
is_draw_step: bool = false

next_entity_id: u64 = 0
scene: [dynamic]^common.Entity = {}
global_scene: [dynamic]^common.Entity = [dynamic]^common.Entity{}
global_scene_map: map[string]^common.Entity = {}
renderQueue: [dynamic]common.GraphicObjectProps = {}
destroyQueue: [dynamic]^common.Entity = {}

VERSION :: "0.2.2"

main :: proc() {
	init_sokol()
}

get_entity_id :: proc() -> u64 {
	next_entity_id += 1
	return next_entity_id
}

load_scene :: proc(entities: [dynamic]^common.Entity) {
	if scene != nil && len(scene) > 0 {
		run_free()
	}

	scene = entities

	if is_game_started {
		run_init()
	}
}

destroy :: proc(entity: ^common.Entity) -> bool {
	if entity == nil {
		return false
	}
	for i := 0; i < len(scene); i += 1 {
		if scene[i] == entity {
			ordered_remove(&scene, i)
			free_obj(entity)
			return true
		}
	}
	return false
}

spawn :: proc(entity: ^common.Entity) -> u64 {
	if entity == nil {
		return 0
	}
	if scene == nil {
		scene = [dynamic]^common.Entity{}
	}

	append(&scene, entity)
	gObj := scene[len(scene) - 1]
	if is_game_started {
		init(gObj)
	}
	return gObj.id
}

load_global :: proc(key: string, entity: ^common.Entity) -> u64 {
	if entity == nil {
		delete(key)
		return 0
	}

	for k, e in global_scene_map {
		if k == key {
			delete_key(&global_scene_map, k)
			delete(k)
			_remove_global_entity(e)
			break
		}
	}

	global_scene_map[key] = entity
	append(&global_scene, entity)
	gObj := global_scene[len(global_scene) - 1]
	if is_game_started {
		init(gObj)
	}
	return gObj.id
}

get_global :: proc(key: string) -> ^common.Entity {
	if e, ok := global_scene_map[key]; ok {
		return e
	}
	return nil
}

unload_global_by_key :: proc(key: string) {
	for k, e in global_scene_map {
		if k == key {
			delete_key(&global_scene_map, k)
			delete(k)
			_remove_global_entity(e)
			break
		}
	}
}

_remove_global_entity :: proc(entity: ^common.Entity) {
	if entity == nil {
		return
	}
	for i := 0; i < len(global_scene); i += 1 {
		if global_scene[i] == entity {
			ordered_remove(&global_scene, i)
			free_obj(entity)
			break
		}
	}
}

unload_global :: proc(entity: ^common.Entity) {
	if entity == nil {
		return
	}
	for k, e in global_scene_map {
		if e == entity {
			delete_key(&global_scene_map, k)
			delete(k)
			break
		}
	}
	_remove_global_entity(entity)
}

run_init :: proc() {
	if scene != nil && len(scene) > 0 {
		for &entity in scene {
			if entity != nil && !entity.destroyed {
				init(entity)
			}
		}
	}
	if len(global_scene) > 0 {
		for &global in global_scene {
			if global != nil && !global.destroyed {
				init(global)
			}
		}
	}
}

init :: proc(entity: ^common.Entity) {
	if entity.initiated {
		return
	}
	run_entity_behaviour(entity, "init")
	entity.initiated = true
}

run_update :: proc() {
	if global_scene != nil && len(global_scene) > 0 {
		for i := len(global_scene) - 1; i >= 0; i -= 1 {
			if i >= len(global_scene) {
				continue
			}
			entity := global_scene[i]
			if entity != nil && !entity.destroyed && entity.initiated {
				update(entity)
			}
		}
	}
	if scene != nil && len(scene) > 0 {
		for i := len(scene) - 1; i >= 0; i -= 1 {
			if i >= len(scene) {
				continue
			}
			entity := scene[i]
			if entity != nil && !entity.destroyed && entity.initiated {
				update(entity)
			}
		}
	}
}

update :: proc(entity: ^common.Entity) {
	run_entity_behaviour(entity, "tick")
}

run_draw :: proc() {
	draw_debug_info()
	if global_scene != nil {
		for &entity in global_scene {
			if entity != nil && !entity.destroyed && entity.initiated {
				draw(entity)
			}
		}
	}
	if scene != nil {
		for &entity in scene {
			if entity != nil && !entity.destroyed && entity.initiated {
				draw(entity)
			}
		}
	}
	order_render_queue()
	draw_render_queue()
	clear_render_queue()
	graphics.destroy_unused_images()
}

draw :: proc(entity: ^common.Entity) {
	run_entity_behaviour(entity, "draw")
}

run_free :: proc() {
	if LUA_GLOBAL_STATE == nil {
		return
	}
	if scene == nil {
		return
	}
	for &entity in scene {
		free_obj(entity)
	}
	delete(scene)
	scene = {}

	delete(renderQueue)
	renderQueue = {}

	delete(destroyQueue)
	destroyQueue = {}
}

cleanup_scene :: proc() {
	if scene != nil && len(scene) > 0 {
		run_free()
	}
}

get_scene_count :: proc() -> int {
	if scene == nil {
		return 0
	}
	return len(scene)
}

free_obj :: proc(entity: ^common.Entity) {
	if entity == nil {
		return
	}

	run_entity_behaviour(entity, "free")
	if entity.state > 0 {
		lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, entity.state)
	}

	remove_handler_owner(entity.id)
	remove_entity_tags(entity.id)
	delete_entity_id(entity)
	delete(entity.behaviours)
	free(entity)
}

get_scene :: proc() -> [dynamic]^common.Entity {
	return scene
}

clear_scene :: proc() {
	if scene != nil && len(scene) > 0 {
		run_free()
	}
	scene = {}
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
	shader: string,
	fixed: bool,
	tiled: bool,
	prop: common.ObjectProp,
) {
	if !is_draw_step {
		common.print_error("Trying to render outside draw() function")
		return
	}
	for i in 0 ..< len(renderQueue) {
		#partial switch v in renderQueue[i] {
		case common.GroupObjectProps:
			if v.texture == texture &&
			   v.z_index == z_index &&
			   v.shader == shader &&
			   v.fixed == fixed &&
			   v.tiled == tiled {

				append(renderQueue[i].(common.GroupObjectProps).quads, prop)
				return
			}
		}
	}
	quads := new([dynamic]common.ObjectProp)
	append(quads, prop)
	group_quads := common.GroupObjectProps {
		texture = strings.clone(texture),
		z_index = z_index,
		shader  = strings.clone(shader),
		fixed   = fixed,
		tiled   = tiled,
		quads   = quads,
	}
	append(&renderQueue, group_quads)
}

add_to_destroy_queue :: proc(entity: ^common.Entity) {
	entity.destroyed = true
	append(&destroyQueue, entity)
}

process_destroy_queue :: proc() {
	for &entity in destroyQueue {
		if !destroy(entity) {
			unload_global(entity)
		}
	}
	clear(&destroyQueue)
}

clear_render_queue :: proc() {
	for v in renderQueue {
		switch obj in v {
		case common.QuadObjectProps:
			delete(obj.shader)
			delete(obj.texture)
			for _, shader in obj.shader_args {
				#partial switch v in shader {
				case string:
					delete(v)
				}
			}
		case common.GroupObjectProps:
			delete(obj.shader)
			delete(obj.texture)

			if obj.quads != nil {
				for quad in obj.quads^ {
					for _, shader in quad.shader_args {
						#partial switch v in shader {
						case string:
							delete(v)
						}
					}
				}

				delete(obj.quads^)
				free(obj.quads)
			}
		case common.TextObjectProps:
			delete(obj.font)
			delete(obj.shader)
			delete(obj.text)
			for _, shader in obj.shader_args {
				#partial switch v in shader {
				case string:
					delete(v)
				}
			}
		}
	}
	clear(&renderQueue)
}

draw_render_queue :: proc() {
	for v in renderQueue {
		switch obj in v {
		case common.QuadObjectProps:
			graphics.quad(obj)
		case common.TextObjectProps:
			graphics.text(obj)
		case common.GroupObjectProps:
			graphics.quad_group(obj)
		}
	}
}

order_render_queue :: proc() {
	sort.quick_sort_proc(
		renderQueue[:],
		proc(a: common.GraphicObjectProps, b: common.GraphicObjectProps) -> int {
			a_z_index: i32
			b_z_index: i32

			switch v in a {
			case common.QuadObjectProps:
				a_z_index = v.zIndex
			case common.TextObjectProps:
				a_z_index = v.zIndex
			case common.GroupObjectProps:
				a_z_index = v.z_index
			}

			switch v in b {
			case common.QuadObjectProps:
				b_z_index = v.zIndex
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
