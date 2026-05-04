package scene

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

FIND_BY_ID_FUNCTION :: lua_common.LuaFunction {
	name = "find_by_id",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "find_by_id") do return 0
		if !lua_common.validate_number(L, 1, "find_by_id") do return 0

		entity_id := u64(lua.tonumber(L, 1))
		entity := core.find_by_id(entity_id)

		if entity == nil {
			lua.pushnil(L)
		} else {
			lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(entity.state))
		}

		return 1
	},
}
