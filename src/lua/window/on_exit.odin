package window

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

ON_EXIT_FUNCTION :: lua_common.LuaFunction {
	name = "on_exit",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua.isfunction(L, 1) {
			lua.pushstring(L, "on_exit expects a function")
			lua.error(L)
			return 0
		}

		func_ref := lua.L_ref(L, lua.REGISTRYINDEX)
		core.set_exit_callback(i32(func_ref))

		return 0
	},
}
