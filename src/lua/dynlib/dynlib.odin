package dynlib_lua

import lua_common "../lua_common"

DYNLIB_NAMESPACE :: lua_common.LuaNamespace {
	name      = "dynlib",
	functions = []lua_common.LuaFunction{LOAD_FUNCTION, CALL_FUNCTION, UNLOAD_FUNCTION},
}
