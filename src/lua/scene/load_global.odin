package scene

import common "../../common"
import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "shared:luajit"

LOAD_GLOBAL_FUNCTION :: lua_common.LuaFunction {
	name = "load_global",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "load_global") do return 0
		if !lua_common.validate_table(L, 1, "load_global") do return 0

		entity := lua_common.create_entity_by_lua(L, 1)
		core.load_global(entity)

		entity_id := lua.Number(entity.id)
		lua.pushnumber(L, entity_id)

		return 1
	},
}
