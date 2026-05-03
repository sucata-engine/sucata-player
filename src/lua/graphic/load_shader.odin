package graphic

import core "../../core"
import "../../graphics"
import lua_common "../lua_common"
import "core:c"
import "core:crypto"
import "core:encoding/uuid"
import "core:strings"
import lua "shared:luajit"

LOAD_SHADER_FUNCTION :: lua_common.LuaFunction {
	name = "load_shader",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "load_shader") do return 0
		if !lua_common.validate_string(L, 1, "load_shader") do return 0

		shader_path := strings.clone_from_cstring(lua.tostring(L, 1))

		shader_id := graphics.shader_name_to_32(shader_path)

		if !core.is_game_started {
			core.add_post_command(core.PostLoadShader{shader_path = shader_path})
			lua.pushnumber(L, lua.Number(shader_id))
			return 1
		}

		_, ok := graphics.init_shader(shader_path)

		if ok {
			lua.pushnumber(L, lua.Number(shader_id))
		} else {
			lua.pushnil(L)
		}

		return 1
	},
}
