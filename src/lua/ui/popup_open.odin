package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

POPUP_OPEN_FUNCTION :: lua_common.LuaFunction {
	name = "popup_open",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "popup_open") do return 0
		if !lua_common.validate_table(L, 1, "popup_open") do return 0

		name := lua_common.get_table_string(L, 1, "name", "")
		defer delete(name)

		core.microui_popup_open(name)
		return 0
	},
}
