package core

import "../common"
import "core:c"
import lua "../luajit"

@(private = "file")
push_error_handler :: proc(L: ^lua.State) -> c.int {
	if LUA_TRACEBACK_REF <= 0 {
		return 0
	}
	lua.rawgeti(L, lua.REGISTRYINDEX, c.int(LUA_TRACEBACK_REF))
	return lua.gettop(L)
}

call_lua_function :: proc(L: ^lua.State, function_ref: i32) -> bool {
	top := lua.gettop(L)
	if function_ref <= 0 {
		return false
	}

	msgh := push_error_handler(L)

	lua.rawgeti(L, lua.REGISTRYINDEX, c.int(function_ref))

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
