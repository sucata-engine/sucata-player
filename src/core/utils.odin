package core

import "../common"
import "core:strings"
import lua "shared:luajit"

call_lua_function :: proc(L: ^lua.State, function_ref: i32) -> bool {
	top := lua.gettop(L)
	if function_ref <= 0 {
		return false
	}

	if !lua.checkstack(L, 1) {
		common.print_error("Lua stack overflow")
		return false
	}

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(function_ref))

	if !lua.isfunction(L, -1) {
		lua.pop(L, 1)
		return false
	}

	result := lua.pcall(L, 0, 0, 0)
	if result != .OK {
		msg := lua.tostring(L, -1)
		common.print_error("%s", msg)
		lua.pop(L, 1)

		lua.gc(L, lua.GCCOLLECT, 0)
	}

	lua.settop(L, top)

	return result == .OK
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

	if !lua.checkstack(L, 3) {
		common.print_error("Lua stack overflow")
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
	if result != .OK {
		msg := lua.tostring(L, -1)
		common.print_error("%s", msg)
		lua.pop(L, 1)
	}

	lua.settop(L, top)

	return result == .OK
}

call_lua_method_with_self_ref :: proc(
	L: ^lua.State,
	table_ref: i32,
	field_name: string,
	self_ref: i32,
) -> bool {
	top := lua.gettop(L)

	if table_ref <= 0 || self_ref <= 0 {
		common.print_error("Invalid table or self reference")
		return false
	}

	if !lua.checkstack(L, 4) {
		common.print_error("Lua stack overflow")
		return false
	}

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(table_ref))

	if !lua.istable(L, -1) {
		lua.pop(L, 1)
		return false
	}

	field_cstring := strings.clone_to_cstring(field_name)
	defer delete_cstring(field_cstring)

	lua.getfield(L, -1, field_cstring)

	if !lua.isfunction(L, -1) {
		lua.pop(L, 2)
		return false
	}

	lua.remove(L, -2)

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(self_ref))

	result := lua.pcall(L, 1, 0, 0)

	if result != .OK {
		msg := lua.tostring(L, -1)
		common.print_error("%s", msg)
		lua.pop(L, 1)
	}

	lua.settop(L, top)

	return result == .OK
}
