package input

import camera "../../camera"
import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "shared:luajit"

GET_RELATIVE_MOUSE_POSITION_FUNCTION :: lua_common.LuaFunction {
	name = "get_relative_mouse_position",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		mouse_x, mouse_y := core.mouse_position()
		camera_position := camera.camera.position
		camera_zoom := camera.camera.zoom

		x := (mouse_x + camera_position[0]) / camera_zoom
		y := (mouse_y + camera_position[1]) / camera_zoom

		lua.pushnumber(L, lua.Number(x))
		lua.pushnumber(L, lua.Number(y))

		return 2
	},
}
