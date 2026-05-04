package scene

import common "../../common"
import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "shared:lua55"

SPAWNS_FUNCTION :: lua_common.LuaFunction {
	name = "spawns",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "spawns") do return 0
		if !lua_common.validate_table(L, 1, "spawns") do return 0

		table_length := c.int(lua.rawlen(L, 1))

		lua.newtable(L)
		spawned_ids_table := lua.gettop(L)

		for i in 1 ..= table_length {
			lua.rawgeti(L, 1, lua.Integer(i))
			if lua.istable(L, -1) {
				entity := lua_common.create_entity_by_lua(L, c.int(lua.gettop(L)))
				spawned_id := core.spawn(entity)

				if spawned_id != 0 {
					lua.pushnumber(L, lua.Number(spawned_id))
					lua.rawseti(L, spawned_ids_table, lua.Integer(i))
				}
			}
			lua.pop(L, 1)
		}

		return 1
	},
}
