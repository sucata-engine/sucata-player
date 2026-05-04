package scene

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "shared:lua55"

DESTROYS_FUNCTION :: lua_common.LuaFunction {
	name = "destroys",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "destroys") do return 0
		if !lua_common.validate_table(L, 1, "destroys") do return 0

		table_length := c.int(lua.rawlen(L, 1))

		lua.newtable(L)
		undestroyed_ids_table := lua.gettop(L)

		for i in 1 ..= table_length {
			lua.rawgeti(L, 1, lua.Integer(i))
			if lua.istable(L, -1) {
				entity_id := lua_common.get_entity_id(L, c.int(lua.gettop(L)))
				entity := core.find_by_id(entity_id)

				if entity != nil {
					core.add_to_destroy_queue(entity)
				} else {
					lua.pushnumber(L, lua.Number(entity_id))
					lua.rawseti(L, undestroyed_ids_table, lua.Integer(i))
				}
			}
			lua.pop(L, 1)
		}
		return 1
	},
}
