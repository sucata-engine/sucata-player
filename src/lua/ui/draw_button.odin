package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

DRAW_BUTTON_FUNCTION :: lua_common.LuaFunction {
	name = "draw_button",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_button") do return 0
		if !lua_common.validate_table(L, 1, "draw_button") do return 0

		text := lua_common.get_table_string(L, 1, "text", "")
		defer delete(text)

		style := get_style_from_table(L, 1)

		clicked := core.microui_button(text, style)
		lua.pushboolean(L, b32(clicked))
		return 1
	},
}
