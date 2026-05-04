package lua_common

import common "../../common"
import "../../core"
import "core:c"
import lua "shared:lua55"

get_behaviours_refs_from_table_index :: proc(L: ^lua.State, table_index2: c.int) -> [dynamic]i64 {
	top := lua.gettop(L)
	table_index := absindex(L, table_index2)

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
				core.add_behaviour(bhv_id, i32(ref))
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
	id := core.get_entity_id()
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

copy_state_table_with_modifications :: proc(L: ^lua.State, table_index: c.int, id: u64) -> i32 {
	lua.getfield(L, table_index, "state")

	if !lua.istable(L, -1) {
		lua.pop(L, 1)
		return i32(lua.REFNIL)
	}

	state_index := lua.gettop(L)

	lua.newtable(L)
	new_table_index := lua.gettop(L)

	lua.pushnil(L)
	for lua.next(L, c.int(state_index)) != 0 {
		lua.pushvalue(L, -2)
		lua.pushvalue(L, -2)
		lua.settable(L, new_table_index)
		lua.pop(L, 1)
	}

	if lua.getmetatable(L, state_index) != 0 {
		lua.setmetatable(L, new_table_index)
	}

	lua.pushnumber(L, lua.Number(id))
	lua.setfield(L, new_table_index, "id")

	lua.remove(L, state_index)

	return i32(lua.L_ref(L, lua.REGISTRYINDEX))
}

get_entity_id :: proc(L: ^lua.State, table_index: c.int) -> u64 {
	if lua.istable(L, table_index) {
		return u64(get_table_number(L, table_index, "id", 0))
	} else if lua.isnumber(L, table_index) {
		return u64(lua.tonumber(L, table_index))
	}
	return 0
}
