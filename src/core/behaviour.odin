package core

import lua "vendor:lua/5.4"

behaviours := map[i64]i32{}

has_behaviour :: proc(id: i64) -> bool {
	_, ok := behaviours[id]
	return ok
}

add_behaviour :: proc(id: i64, table_ref: i32) {
	behaviours[id] = table_ref
}

cleanup_behaviours :: proc() {
	if LUA_GLOBAL_STATE != nil {
		for _, ref in behaviours {
			lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, ref)
		}
	}
	delete(behaviours)
	behaviours = {}
}

call_behaviour :: proc(id: i64, method: string, state: i32) {
	table_ref, ok := behaviours[id]
	if !ok {
		return
	}

	call_lua_method_with_self_ref(LUA_GLOBAL_STATE, table_ref, method, state)
}
