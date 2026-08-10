package dynlib_lua

import core "../../core"
import "../../filesystem"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

LOAD_FUNCTION :: lua_common.LuaFunction {
	name = "load",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "dynlib.load") do return 0
		if !lua_common.validate_string(L, 1, "dynlib.load") do return 0

		raw_path := strings.clone_from_cstring(lua.tostring(L, 1))
		defer delete(raw_path)

		resolved_path := filesystem.get_path(raw_path)

		id, ok := core.load_dynlib(resolved_path)
		if !ok {
			lua.pushnil(L)
			lua.pushstring(L, "dynlib.load: failed to load library")
			return 2
		}

		lua.pushnumber(L, lua.Number(id))
		return 1
	},
}
