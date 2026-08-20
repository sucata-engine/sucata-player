package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

END_TREENODE_FUNCTION :: lua_common.LuaFunction {
	name = "end_treenode",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		core.microui_treenode_end()
		return 0
	},
}
