package scene

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "shared:luajit"

ON_INIT_FUNCTION :: lua_common.LuaFunction {
	name = "init",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "scene.init") do return 0

		if !lua.isfunction(L, 1) {
			lua.pushstring(L, "scene.init: expected a function as argument")
			lua.error(L)
			return 0
		}

		lua.pushvalue(L, 1)
		function_ref := i32(lua.L_ref(L, lua.REGISTRYINDEX))

		if core.is_game_started {
			core.call_lua_function(L, function_ref)
			lua.L_unref(L, lua.REGISTRYINDEX, c.int(function_ref))
		} else {
			core.add_to_init_queue(function_ref)
		}

		return 0
	},
}
