package scene

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

GET_GLOBAL_FUNCTION :: lua_common.LuaFunction {
	name = "get_global",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "get_global") do return 0
		if !lua_common.validate_string(L, 1, "get_global") do return 0

		key_cstr := lua.tostring(L, 1)
		key := strings.clone_from_cstring(key_cstr)
		defer delete(key)

		entity := core.get_global(key)

		if entity != nil && entity.state > 0 {
			lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(entity.state))
		} else {
			lua.pushnil(L)
		}

		return 1
	},
}
