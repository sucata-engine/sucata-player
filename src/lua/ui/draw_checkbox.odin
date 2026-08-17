package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

DRAW_CHECKBOX_FUNCTION :: lua_common.LuaFunction {
	name = "draw_checkbox",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_checkbox") do return 0
		if !lua_common.validate_table(L, 1, "draw_checkbox") do return 0

		id := lua_common.get_table_string(L, 1, "id", "")
		defer delete(id)
		text := lua_common.get_table_string(L, 1, "text", "")
		defer delete(text)

		style := get_style_from_table(L, 1)

		changed, checked := core.microui_checkbox(id, text, style)
		lua.pushboolean(L, b32(changed))
		lua.pushboolean(L, b32(checked))
		return 2
	},
}
