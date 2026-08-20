package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

LAYOUT_ROW_FUNCTION :: lua_common.LuaFunction {
	name = "layout_row",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "layout_row") do return 0
		if !lua_common.validate_table(L, 1, "layout_row") do return 0

		widths := get_table_number_array(L, 1, "widths")
		defer delete(widths)
		height := i32(lua_common.get_table_number(L, 1, "height", 0))

		core.microui_layout_row(widths, height)
		return 0
	},
}
