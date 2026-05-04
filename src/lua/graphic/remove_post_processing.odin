package graphic

import core "../../core"
import "../../graphics"
import lua_common "../lua_common"
import "core:c"
import "core:crypto"
import "core:encoding/uuid"
import "core:strings"
import lua "shared:lua55"

REMOVE_POST_PROCESSING_FUNCTION :: lua_common.LuaFunction {
	name = "remove_post_processing",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "remove_post_processing") do return 0
		if !lua_common.validate_number(L, 1, "remove_post_processing") do return 0

		shader_id := lua.tonumber(L, 1)

		graphics.remove_post_processing(u32(shader_id))

		return 0
	},
}
