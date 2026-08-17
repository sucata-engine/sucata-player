package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

DRAW_POPUP_FUNCTION :: lua_common.LuaFunction {
	name = "draw_popup",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_popup") do return 0
		if !lua_common.validate_table(L, 1, "draw_popup") do return 0

		name := lua_common.get_table_string(L, 1, "name", "")
		defer delete(name)

		open := core.microui_popup_begin(name)
		lua.pushboolean(L, b32(open))
		return 1
	},
}
