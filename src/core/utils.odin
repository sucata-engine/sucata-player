package core

import "../common"
import lua "vendor:lua/5.4"

call_lua_function :: proc(L: ^lua.State, function_ref: i32) -> bool {
	top := lua.gettop(L)
	if function_ref <= 0 {
		return false
	}

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(function_ref))

	if !lua.isfunction(L, -1) {
		lua.pop(L, 1)
		return false
	}

	result := lua.pcall(L, 0, 0, 0)
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

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(function_ref))
	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(table_ref))

	if !lua.isfunction(L, -2) {
		lua.pop(L, 2)
		return false
	}
	if !lua.istable(L, -1) {
		lua.pop(L, 2)
		return false
	}

	result := lua.pcall(L, 1, 0, 0)
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

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(table_ref))

	if !lua.istable(L, -1) {
		lua.pop(L, 1)
		return false
	}

	lua.getfield(L, -1, field_name)

	if !lua.isfunction(L, -1) {
		lua.pop(L, 2)
		return false
	}

	lua.remove(L, -2)

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(self_ref))

	result := lua.pcall(L, 1, 0, 0)

	if result != 0 {
		msg := lua.tostring(L, -1)
		common.print_error("%s", msg)
		lua.pop(L, 1)
	}

	lua.settop(L, top)

	return result == 0
}
