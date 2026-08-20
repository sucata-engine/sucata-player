package system

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:os"
import "core:strings"
import lua "vendor:lua/5.4"

EXECUTE_FUNCTION :: lua_common.LuaFunction {
	name = "execute",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "execute") do return 0
		if !lua_common.validate_string(L, 1, "execute") do return 0

		command := strings.clone_from_cstring(lua.tostring(L, 1))
		defer delete(command)

		shell_command: []string
		when ODIN_OS == .Windows {
			shell_command = {"cmd", "/C", command}
		} else {
			shell_command = {"sh", "-c", command}
		}

		state, stdout, stderr, err := os.process_exec(
			os.Process_Desc{command = shell_command},
			context.allocator,
		)
		defer delete(stdout)
		defer delete(stderr)

		if err != nil {
			lua.pushnumber(L, lua.Number(-1))
			lua.pushstring(L, "")
			push_lua_bytes(L, transmute([]u8)os.error_string(err))
			return 3
		}

		lua.pushnumber(L, lua.Number(state.exit_code))
		push_lua_bytes(L, stdout)
		push_lua_bytes(L, stderr)
		return 3
	},
}

push_lua_bytes :: proc(L: ^lua.State, bytes: []u8) {
	if len(bytes) == 0 {
		lua.pushstring(L, "")
		return
	}
	lua.pushlstring(L, cstring(raw_data(bytes)), c.size_t(len(bytes)))
}
