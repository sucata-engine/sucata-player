package scene

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "shared:lua55"

UNLOAD_GLOBAL_FUNCTION :: lua_common.LuaFunction {
	name = "unload_global",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "unload_global") do return 0
		if !lua_common.validate_string(L, 1, "unload_global") do return 0

		key_cstr := lua.tostring(L, 1)
		key := strings.clone_from_cstring(key_cstr)
		defer delete(key)

		core.unload_global_by_key(key)

		return 0
	},
}
