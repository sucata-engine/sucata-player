package core

import "core:c"
import lua "shared:luajit"

init_queue: [dynamic]i32 = {}

add_to_init_queue :: proc(function_ref: i32) {
	append(&init_queue, function_ref)
}

flush_init_queue :: proc() {
	count := len(init_queue)

	for ref in init_queue {
		call_lua_function(LUA_GLOBAL_STATE, ref)
		lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, c.int(ref))
	}

	delete(init_queue)
	init_queue = {}
}
