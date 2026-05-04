package audio

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "shared:lua55"

UNPAUSE_FUNCTION :: lua_common.LuaFunction {
	name = "unpause",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "unpause") do return 0
		if !lua_common.validate_number(L, 1, "unpause") do return 0

		sound_id := lua.tonumber(L, 1)

		core.unpause_sound(u32(sound_id))

		return 0
	},
}
