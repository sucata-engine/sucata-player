package graphic

import core "../../core"
import "../../graphics"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

GET_HOT_TEXTURE_THRESHOLD_FUNCTION :: lua_common.LuaFunction {
	name = "get_hot_texture_threshold",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		lua.pushnumber(L, lua.Number(graphics.hot_texture_use_threshold))

		return 1
	},
}

SET_HOT_TEXTURE_THRESHOLD_FUNCTION :: lua_common.LuaFunction {
	name = "set_hot_texture_threshold",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "set_hot_texture_threshold") do return 0
		if !lua_common.validate_number(L, 1, "set_hot_texture_threshold") do return 0

		graphics.hot_texture_use_threshold = max(0, int(lua.tonumber(L, 1)))

		return 0
	},
}
