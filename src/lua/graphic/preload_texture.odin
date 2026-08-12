package graphic

import core "../../core"
import "../../graphics"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

PRELOAD_TEXTURE_FUNCTION :: lua_common.LuaFunction {
	name = "preload_texture",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "preload_texture") do return 0
		if !lua_common.validate_string(L, 1, "preload_texture") do return 0

		texture_path := strings.clone_from_cstring(lua.tostring(L, 1))

		if !core.is_game_started {
			core.add_post_command(core.PostPreloadTexture{texture_path = texture_path})
			return 0
		}

		defer delete(texture_path)
		graphics.preload_image(texture_path)

		return 0
	},
}
