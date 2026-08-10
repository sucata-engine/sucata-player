package dynlib_lua

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

CALL_FUNCTION :: lua_common.LuaFunction {
	name = "call",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 2, "dynlib.call") do return 0
		if !lua_common.validate_number(L, 1, "dynlib.call") do return 0
		if !lua_common.validate_string(L, 2, "dynlib.call") do return 0

		handle_id := i64(lua.tonumber(L, 1))
		func_name := strings.clone_from_cstring(lua.tostring(L, 2))
		defer delete(func_name)

		symbol, found := core.dynlib_symbol(handle_id, func_name)
		if !found {
			lua_common.push_lua_error_msg(
				L,
				"dynlib.call: symbol not found or invalid dynlib handle",
			)
			return 0
		}

		func := (lua.CFunction)(symbol)

		lua.remove(L, 2)
		lua.remove(L, 1)

		return func(L)
	},
}
