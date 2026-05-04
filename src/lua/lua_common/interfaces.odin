package lua_common

import lua "shared:lua55"

LuaNamespace :: struct {
	name:      cstring,
	functions: []LuaFunction,
}

LuaFunction :: struct {
	name:     cstring,
	func_ptr: lua.CFunction,
}

LuaTable :: map[string]any
