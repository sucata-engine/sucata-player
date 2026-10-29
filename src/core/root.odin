package core

import lua "vendor:lua/5.4"

root_entry: Behaviour_Entry = {}

set_root :: proc(L: ^lua.State, table_ref: i32) {
	cleanup_root()
	root_entry = make_behaviour_entry(L, table_ref)
}

run_root :: proc(method: Behaviour_Method) {
	if root_entry.table_ref <= 0 || LUA_GLOBAL_STATE == nil {
		return
	}

	field_name, ok := behaviour_method_name(root_entry, method)
	if !ok {
		return
	}

	call_lua_method(LUA_GLOBAL_STATE, root_entry.table_ref, field_name)
}

cleanup_root :: proc() {
	if root_entry.table_ref > 0 && LUA_GLOBAL_STATE != nil {
		lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, root_entry.table_ref)
	}
	root_entry = {}
}
