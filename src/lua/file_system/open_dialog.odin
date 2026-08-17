package file_system

import core "../../core"
import "../../filesystem"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

OPEN_DIALOG_FUNCTION :: lua_common.LuaFunction {
	name = "open_dialog",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "open_dialog") do return 0
		if !lua_common.validate_table(L, 1, "open_dialog") do return 0

		folder := lua_common.get_table_boolean(L, 1, "folder", false)
		multiple := lua_common.get_table_boolean(L, 1, "multiple", false)

		extensions := [dynamic]string{}
		defer {
			for extension in extensions do delete(extension)
			delete(extensions)
		}

		lua.pushstring(L, "filters")
		lua.gettable(L, 1)
		if lua.istable(L, -1) {
			filters_count := c.int(lua.rawlen(L, -1))
			filters_table := lua.gettop(L)

			for i in 1 ..= filters_count {
				lua.rawgeti(L, filters_table, lua.Integer(i))
				if lua.isstring(L, -1) {
					append(&extensions, strings.clone_from_cstring(lua.tostring(L, -1)))
				}
				lua.pop(L, 1)
			}
		}
		lua.pop(L, 1)

		paths, ok := filesystem.open_dialog(folder, multiple, extensions[:])
		defer {
			for path in paths do delete(path)
			delete(paths)
		}

		if !ok {
			lua.pushnil(L)
			return 1
		}

		if multiple {
			lua.newtable(L)
			result_table := lua.gettop(L)
			for path, i in paths {
				cpath := strings.clone_to_cstring(path)
				defer delete(cpath)
				lua.pushstring(L, cpath)
				lua.rawseti(L, result_table, lua.Integer(i + 1))
			}
		} else {
			cpath := strings.clone_to_cstring(paths[0])
			defer delete(cpath)
			lua.pushstring(L, cpath)
		}

		return 1
	},
}
