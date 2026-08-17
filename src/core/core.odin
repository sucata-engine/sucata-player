package core

import "../common"
import "../graphics"
import "base:runtime"
import "core:sort"
import "core:strings"
import sapp "shared:sokol/app"
import lua "vendor:lua/5.4"

LUA_GLOBAL_STATE: ^lua.State
DEFAULT_CONTEXT: runtime.Context

LUA_TRACEBACK_REF: i32 = 0

width: i32 = 800
height: i32 = 600

is_build_mode: bool = false
is_game_started: bool = false
is_draw_step: bool = false

next_entity_id: u64 = 0
scene: [dynamic]^common.Entity = {}
scene_index: map[u64]int = {}
global_scene: [dynamic]^common.Entity = [dynamic]^common.Entity{}
global_scene_map: map[string]^common.Entity = {}
renderQueue: [dynamic]common.GraphicObjectProps = {}
destroyQueue: [dynamic]^common.Entity = {}

has_pending_scene: bool = false
pending_scene_is_clear: bool = false
pending_scene: [dynamic]^common.Entity = {}

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

VERSION :: "1.1.0"

exit_callback_ref: i32 = 0
init_callback_ref: i32 = 0

set_exit_callback :: proc(func_ref: i32) {
	if exit_callback_ref > 0 && LUA_GLOBAL_STATE != nil {
		lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, exit_callback_ref)
	}
	exit_callback_ref = func_ref
}

set_init_callback :: proc(func_ref: i32) {
	if init_callback_ref > 0 && LUA_GLOBAL_STATE != nil {
		lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, init_callback_ref)
	}
	init_callback_ref = func_ref
}

main :: proc() {
	init_sokol()
}

get_entity_id :: proc() -> u64 {
	next_entity_id += 1
	return next_entity_id
}

rebuild_scene_index :: proc() {
	clear(&scene_index)
	for entity, i in scene {
		if entity != nil {
			scene_index[entity.id] = i
		}
	}
}

load_scene :: proc(entities: [dynamic]^common.Entity) {
	if !is_game_started {
		if scene != nil && len(scene) > 0 {
			run_free()
		}
		scene = entities
		rebuild_scene_index()
		return
	}

	pending_scene = entities
	pending_scene_is_clear = false
	has_pending_scene = true
}

destroy :: proc(entity: ^common.Entity) -> bool {
	if entity == nil {
		return false
	}
	idx, ok := scene_index[entity.id]
	if !ok || idx >= len(scene) || scene[idx] != entity {
		return false
	}

	last_idx := len(scene) - 1
	moved_entity := scene[last_idx]

	unordered_remove(&scene, idx)
	delete_key(&scene_index, entity.id)
	if idx != last_idx {
		scene_index[moved_entity.id] = idx
	}

	free_obj(entity)
	return true
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
	scene_index[gObj.id] = len(scene) - 1
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
	run_entity_behaviour(entity, .Init)
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
	run_entity_behaviour(entity, .Tick)
}

run_draw :: proc() {
	graphics.invalidate_mvp_cache()
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
	run_entity_behaviour(entity, .Draw)
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

	delete(scene_index)
	scene_index = {}

	delete(renderQueue)
	renderQueue = {}

	delete(render_group_index)
	render_group_index = {}

	delete(destroyQueue)
	destroyQueue = {}
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

	run_entity_behaviour(entity, .Free)
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
	if !is_game_started {
		if scene != nil && len(scene) > 0 {
			run_free()
		}
		scene = {}
		return
	}

	pending_scene = nil
	pending_scene_is_clear = true
	has_pending_scene = true
}

process_pending_scene :: proc() {
	if !has_pending_scene {
		return
	}
	has_pending_scene = false

	if scene != nil && len(scene) > 0 {
		run_free()
	}

	if pending_scene_is_clear {
		pending_scene_is_clear = false
		scene = {}
		return
	}

	scene = pending_scene
	pending_scene = nil
	rebuild_scene_index()
	run_init()
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
