package graphic

import "../../common"
import core "../../core"
import "../../graphics"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "shared:luajit"

SET_POST_PROCESSING_ARGS_FUNCTION :: lua_common.LuaFunction {
	name = "set_post_processing_args",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 3, "set_post_processing_args") do return 0
		if !lua_common.validate_number(L, 1, "set_post_processing_args") do return 0
		if !lua_common.validate_string(L, 2, "set_post_processing_args") do return 0

		shader_id := u64(lua.tonumber(L, 1))
		field := strings.clone_from_cstring(lua.tostring(L, 2))
		defer delete(field)

		value: common.ShaderArgumentValue
		value_type := lua.type(L, 3)
		#partial switch value_type {
		case .NUMBER:
			value = f32(lua.tonumber(L, 3))
		case .STRING:
			value = strings.clone_from_cstring(lua.tostring(L, 3))
		case .TABLE:
			count := 0
			result := [4]f32{}

			lua.pushnil(L)
			for lua.next(L, 3) != false {
				if lua.type(L, -1) == lua.Type.NUMBER && count < 4 {
					result[count] = f32(lua.tonumber(L, -1))
					count += 1
				}
				lua.pop(L, 1)
			}

			if count == 2 {
				value = [2]f32{result[0], result[1]}
			} else if count == 3 {
				value = [3]f32{result[0], result[1], result[2]}
			} else if count == 4 {
				value = [4]f32{result[0], result[1], result[2], result[3]}
			}
		}

		graphics.set_post_processing_args(shader_id, field, value)

		return 0
	},
}
