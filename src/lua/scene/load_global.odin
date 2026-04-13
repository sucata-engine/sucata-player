package scene

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "shared:luajit"

LOAD_GLOBAL_FUNCTION :: lua_common.LuaFunction {
	name = "load_global",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 2, "load_global") do return 0
		if !lua_common.validate_string(L, 1, "load_global") do return 0
		if !lua_common.validate_table(L, 2, "load_global") do return 0

		key_cstr := lua.tostring(L, 1)
		key := strings.clone_from_cstring(key_cstr)

		entity := lua_common.create_entity_by_lua(L, 2)
		core.load_global(key, entity)

		entity_id := lua.Number(entity.id)
		lua.pushnumber(L, entity_id)

		return 1
	},
}
