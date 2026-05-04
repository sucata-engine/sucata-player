package lua_camera

import "../../core"
import "../../graphics"
import "../lua_common"
import "core:c"
import lua "shared:lua55"

GET_CAMERA_POSITION_FUNCTION :: lua_common.LuaFunction {
	name = "get_camera_position",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		lua.pushnumber(L, lua.Number(graphics.camera.position.x))
		lua.pushnumber(L, lua.Number(graphics.camera.position.y))

		return 2
	},
}

SET_CAMERA_POSITION_FUNCTION :: lua_common.LuaFunction {
	name = "set_camera_position",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		arg_count := lua.gettop(L)

		if !lua_common.validate_arg_count(L, 2, "set_camera_position") do return 0
		if !lua_common.validate_number(L, 1, "set_camera_position") do return 0
		if !lua_common.validate_number(L, 2, "set_camera_position") do return 0

		x := f32(lua.tonumber(L, 1))
		y := f32(lua.tonumber(L, 2))
		graphics.set_camera_position(x, y)

		return 0
	},
}
