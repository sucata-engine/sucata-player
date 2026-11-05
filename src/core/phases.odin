package core

import lua "../luajit"

Phase :: enum {
	Init,
	Tick,
	Draw,
	Late,
	Free,
}

PHASE_NAMES := [Phase]cstring {
	.Init = "init",
	.Tick = "tick",
	.Draw = "draw",
	.Late = "late",
	.Free = "free",
}

phase_refs: [Phase]i32

set_phases :: proc(L: ^lua.State, table_index: i32) {
	cleanup_phases()
	for phase in Phase {
		lua.getfield(L, table_index, PHASE_NAMES[phase])
		if lua.isfunction(L, -1) {
			phase_refs[phase] = i32(lua.L_ref(L, lua.REGISTRYINDEX))
		} else {
			lua.pop(L, 1)
		}
	}
}

run_phase :: proc(phase: Phase) {
	if phase_refs[phase] <= 0 || LUA_GLOBAL_STATE == nil {
		return
	}
	call_lua_function(LUA_GLOBAL_STATE, phase_refs[phase])
}

cleanup_phases :: proc() {
	for phase in Phase {
		if phase_refs[phase] > 0 && LUA_GLOBAL_STATE != nil {
			lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, phase_refs[phase])
		}
		phase_refs[phase] = 0
	}
}
