package lua_camera

import "../../core"
import "../../graphics"
import "../lua_common"
import "core:c"
import lua "shared:luajit"

GET_CAMERA_ROTATION_FUNCTION :: lua_common.LuaFunction {
	name = "get_camera_rotation",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		lua.pushnumber(L, lua.Number(graphics.camera.rotation))

		return 1
	},
}

SET_CAMERA_ROTATION_FUNCTION :: lua_common.LuaFunction {
	name = "set_camera_rotation",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "set_camera_rotation") do return 0
		if !lua_common.validate_number(L, 1, "set_camera_rotation") do return 0

		rotation := f32(lua.tonumber(L, 1))
		graphics.set_camera_rotation(rotation)

		return 0
	},
}
