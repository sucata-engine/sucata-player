package gamepad

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "shared:luajit"

GET_INFO_FUNCTION :: lua_common.LuaFunction {
	name = "get_info",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "get_info") do return 0
		if !lua_common.validate_number(L, 1, "get_info") do return 0

		device := lua.tonumber(L, 1)
		lua.pushstring(L, strings.clone_to_cstring(core.gamepad_get_name(int(device))))

		return 1
	},
}
