package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

LAYOUT_END_COLUMN_FUNCTION :: lua_common.LuaFunction {
	name = "layout_end_column",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		core.microui_layout_end_column()
		return 0
	},
}
