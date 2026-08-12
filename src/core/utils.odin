package core

import "../common"
import "core:c"
import lua "vendor:lua/5.4"

@(private = "file")
push_error_handler :: proc(L: ^lua.State) -> c.int {
	if LUA_TRACEBACK_REF <= 0 {
		return 0
	}
	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(LUA_TRACEBACK_REF))
	return lua.gettop(L)
}

@(private = "file")
get_entity_debug_id :: proc(L: ^lua.State, self_ref: i32) -> (id: f64, ok: bool) {
	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(self_ref))
	defer lua.pop(L, 1)

	if !lua.istable(L, -1) {
		return 0, false
	}

	lua.getfield(L, -1, "id")
	defer lua.pop(L, 1)

	if !lua.isnumber(L, -1) {
		return 0, false
	}
	return f64(lua.tonumber(L, -1)), true
}

call_lua_function :: proc(L: ^lua.State, function_ref: i32) -> bool {
	top := lua.gettop(L)
	if function_ref <= 0 {
		return false
	}

	msgh := push_error_handler(L)

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(function_ref))

	if !lua.isfunction(L, -1) {
		lua.settop(L, top)
		return false
	}

	result := lua.pcall(L, 0, 0, msgh)
	if result != 0 {
		msg := lua.tostring(L, -1)
		common.print_error("%s", msg)
		lua.pop(L, 1)

		lua.gc(L, lua.GCCOLLECT, 0)
	}

	lua.settop(L, top)

	return result == 0
}

call_lua_function_with_table_ref :: proc(
	L: ^lua.State,
	function_ref: i32,
	table_ref: i32,
) -> bool {
	top := lua.gettop(L)
	if function_ref <= 0 || table_ref <= 0 {
		common.print_error("Invalid function or table reference")
		return false
	}

	msgh := push_error_handler(L)

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(function_ref))
	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(table_ref))

	if !lua.isfunction(L, -2) {
		lua.settop(L, top)
		return false
	}
	if !lua.istable(L, -1) {
		lua.settop(L, top)
		return false
	}

	result := lua.pcall(L, 1, 0, msgh)
	if result != 0 {
		msg := lua.tostring(L, -1)
		common.print_error("%s", msg)
		lua.pop(L, 1)
	}

	lua.settop(L, top)

	return result == 0
}

call_lua_method_with_self_ref :: proc(
	L: ^lua.State,
	table_ref: i32,
	field_name: cstring,
	self_ref: i32,
) -> bool {
	top := lua.gettop(L)

	if table_ref <= 0 || self_ref <= 0 {
		common.print_error("Invalid table or self reference")
		return false
	}

	msgh := push_error_handler(L)

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(table_ref))

	if !lua.istable(L, -1) {
		lua.settop(L, top)
		return false
	}

	lua.getfield(L, -1, field_name)

	if !lua.isfunction(L, -1) {
		lua.settop(L, top)
		return false
	}

	lua.remove(L, -2)

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(self_ref))

	result := lua.pcall(L, 1, 0, msgh)

	if result != 0 {
		msg := lua.tostring(L, -1)
		if id, ok := get_entity_debug_id(L, self_ref); ok {
			common.print_error("[entity #%.0f][%s] %s", id, field_name, msg)
		} else {
			common.print_error("[%s] %s", field_name, msg)
		}
		lua.pop(L, 1)
	}

	lua.settop(L, top)

	return result == 0
}
