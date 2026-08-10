package dynlib_lua

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

UNLOAD_FUNCTION :: lua_common.LuaFunction {
	name = "unload",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "dynlib.unload") do return 0
		if !lua_common.validate_number(L, 1, "dynlib.unload") do return 0

		handle_id := i64(lua.tonumber(L, 1))
		ok := core.unload_dynlib(handle_id)
		lua.pushboolean(L, b32(ok))

		return 1
	},
}
