package core

import lua "vendor:lua/5.4"

Behaviour_Method :: enum {
	Init,
	Tick,
	Draw,
	Free,
}

Behaviour_Entry :: struct {
	table_ref: i32,
	has_init:  bool,
	has_tick:  bool,
	has_draw:  bool,
	has_free:  bool,
}

behaviour_entries: [dynamic]Behaviour_Entry = {}

behaviour_index_by_ptr := map[i64]i64{}

has_behaviour :: proc(ptr_id: i64) -> bool {
	_, ok := behaviour_index_by_ptr[ptr_id]
	return ok
}

get_behaviour_index :: proc(ptr_id: i64) -> i64 {
	return behaviour_index_by_ptr[ptr_id]
}

add_behaviour :: proc(L: ^lua.State, ptr_id: i64, table_ref: i32) -> i64 {
	entry := Behaviour_Entry {
		table_ref = table_ref,
	}

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(table_ref))
	if lua.istable(L, -1) {
		entry.has_init = behaviour_table_has_method(L, "init")
		entry.has_tick = behaviour_table_has_method(L, "tick")
		entry.has_draw = behaviour_table_has_method(L, "draw")
		entry.has_free = behaviour_table_has_method(L, "free")
	}
	lua.pop(L, 1)

	append(&behaviour_entries, entry)
	index := i64(len(behaviour_entries) - 1)
	behaviour_index_by_ptr[ptr_id] = index
	return index
}

@(private = "file")
behaviour_table_has_method :: proc(L: ^lua.State, field: cstring) -> bool {
	lua.getfield(L, -1, field)
	is_func := bool(lua.isfunction(L, -1))
	lua.pop(L, 1)
	return is_func
}

cleanup_behaviours :: proc() {
	if LUA_GLOBAL_STATE != nil {
		for entry in behaviour_entries {
			lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, entry.table_ref)
		}
	}
	delete(behaviour_entries)
	behaviour_entries = {}
	delete(behaviour_index_by_ptr)
	behaviour_index_by_ptr = {}
}

call_behaviour :: proc(index: i64, method: Behaviour_Method, state: i32) {
	if index < 0 || int(index) >= len(behaviour_entries) {
		return
	}
	entry := behaviour_entries[index]

	field_name: cstring
	switch method {
	case .Init:
		if !entry.has_init {return}
		field_name = "init"
	case .Tick:
		if !entry.has_tick {return}
		field_name = "tick"
	case .Draw:
		if !entry.has_draw {return}
		field_name = "draw"
	case .Free:
		if !entry.has_free {return}
		field_name = "free"
	}

	call_lua_method_with_self_ref(LUA_GLOBAL_STATE, entry.table_ref, field_name, state)
}
