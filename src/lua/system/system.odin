package system

import lua_common "../lua_common"

SYSTEM_NAMESPACE :: lua_common.LuaNamespace {
	name      = "system",
	functions = []lua_common.LuaFunction{EXECUTE_FUNCTION},
}
