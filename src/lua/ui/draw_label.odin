package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

DRAW_LABEL_FUNCTION :: lua_common.LuaFunction {
	name = "draw_label",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_label") do return 0
		if !lua_common.validate_table(L, 1, "draw_label") do return 0

		text := lua_common.get_table_string(L, 1, "text", "")
		defer delete(text)

		style := get_style_from_table(L, 1)

		core.microui_label(text, style)
		return 0
	},
}
