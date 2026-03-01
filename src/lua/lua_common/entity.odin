package lua_common

import common "../../common"
import "../../core"
import "core:c"
import "core:crypto"
import "core:encoding/uuid"
import "core:strings"
import lua "vendor:lua/5.4"

get_behaviours_refs_from_table_index :: proc(L: ^lua.State, table_index2: c.int) -> [dynamic]i64 {
	top := lua.gettop(L)
	table_index := lua.absindex(L, table_index2)

	if !lua.istable(L, table_index) {
		return nil
	}

	lua.getfield(L, table_index, "behaviours")

	if !lua.istable(L, -1) {
		lua.pop(L, 1)
		return nil
	}

	behaviours_index := lua.gettop(L)
	length := lua.rawlen(L, behaviours_index)

	refs := [dynamic]i64{}

	for i: lua.Integer = 1; i <= lua.Integer(length); i += 1 {
		lua.rawgeti(L, behaviours_index, i)

		if !lua.isnil(L, -1) {
			pointer := lua.topointer(L, -1)
			bhv_id := i64(uintptr(pointer))

			if !core.has_behaviour(bhv_id) {
				ref := lua.L_ref(L, lua.REGISTRYINDEX)
				core.add_behaviour(bhv_id, ref)
			} else {
				lua.pop(L, 1)
			}

			append(&refs, bhv_id)
		} else {
			lua.pop(L, 1)
		}
	}

	lua.settop(L, top)

	return refs
}

lua_table_to_entity :: proc(L: ^lua.State, table_index: c.int) -> ^common.Entity {
	context.random_generator = crypto.random_generator()
	id := uuid.to_string(uuid.generate_v4())
	state := get_table_ref(L, table_index, "state")
	behaviours := get_behaviours_refs_from_table_index(L, table_index)

	game_obj := new(common.Entity)
	game_obj^ = common.Entity {
		id         = id,
		behaviours = behaviours,
	}

	return game_obj
}

create_entity_by_lua :: proc(L: ^lua.State, table_index: c.int) -> ^common.Entity {
	entity := lua_table_to_entity(L, table_index)
	entity.state = copy_state_table_with_modifications(L, table_index, entity.id)
	core.save_entity_id(entity)
	return entity
}

copy_state_table_with_modifications :: proc(L: ^lua.State, table_index: c.int, id: string) -> i32 {
	lua.getfield(L, table_index, "state")

	if !lua.istable(L, -1) {
		lua.pop(L, 1)
		return lua.REFNIL
	}

	state_index := lua.gettop(L)

	lua.newtable(L)
	new_table_index := lua.gettop(L)

	lua.pushnil(L)
	for lua.next(L, state_index) != 0 {
		lua.pushvalue(L, -2)
		lua.pushvalue(L, -2)
		lua.settable(L, new_table_index)
		lua.pop(L, 1)
	}

	if lua.getmetatable(L, state_index) != 0 {
		lua.setmetatable(L, new_table_index)
	}

	id_cstring := strings.clone_to_cstring(id)
	defer delete_cstring(id_cstring)
	lua.pushstring(L, id_cstring)
	lua.setfield(L, new_table_index, "id")

	lua.remove(L, state_index)

	return lua.L_ref(L, lua.REGISTRYINDEX)
}

get_entity_id :: proc(L: ^lua.State, table_index: c.int) -> string {
	if lua.istable(L, table_index) {
		return get_table_string(L, table_index, "id", "")
	} else if lua.isstring(L, table_index) {
		return strings.clone_from_cstring(lua.tostring(L, table_index))
	}
	return ""
}
