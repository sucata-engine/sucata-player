package graphic

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "../../luajit"

LOAD_TEXTURE_FUNCTION :: lua_common.LuaFunction {
	name = "load_texture",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "load_texture") do return 0
		if !lua_common.validate_string(L, 1, "load_texture") do return 0

		handle := core.register_texture(string(lua.tostring(L, 1)))
		lua.pushinteger(L, lua.Integer(handle))

		return 1
	},
}

LOAD_FONT_FUNCTION :: lua_common.LuaFunction {
	name = "load_font",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "load_font") do return 0
		if !lua_common.validate_string(L, 1, "load_font") do return 0

		handle := core.register_texture(string(lua.tostring(L, 1)))
		lua.pushinteger(L, lua.Integer(handle))

		return 1
	},
}
