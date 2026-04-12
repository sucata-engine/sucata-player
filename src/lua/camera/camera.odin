package lua_camera

import "../lua_common"
import "core:c"
import lua "shared:luajit"

CAMERA_NAMESPACE :: lua_common.LuaNamespace {
	name      = "camera",
	functions = []lua_common.LuaFunction {
		GET_CAMERA_POSITION_FUNCTION,
		SET_CAMERA_POSITION_FUNCTION,
		GET_CAMERA_ROTATION_FUNCTION,
		SET_CAMERA_ROTATION_FUNCTION,
		GET_CAMERA_ZOOM_FUNCTION,
		SET_CAMERA_ZOOM_FUNCTION,
	},
}
