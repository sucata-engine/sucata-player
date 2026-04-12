package common

import lua "shared:luajit"

LuaNamespace :: struct {
	name:      cstring,
	functions: []LuaFunction,
}

LuaFunction :: struct {
	name:     cstring,
	func_ptr: lua.CFunction,
}
