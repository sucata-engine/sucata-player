package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

DRAW_TEXTBOX_FUNCTION :: lua_common.LuaFunction {
	name = "draw_textbox",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_textbox") do return 0
		if !lua_common.validate_table(L, 1, "draw_textbox") do return 0

		id := lua_common.get_table_string(L, 1, "id", "")
		defer delete(id)
		initial := lua_common.get_table_string(L, 1, "text", "")
		defer delete(initial)

		style := get_style_from_table(L, 1)

		changed, submitted, new_text := core.microui_textbox(id, initial, style)

		new_text_cstr := strings.clone_to_cstring(new_text)
		defer delete_cstring(new_text_cstr)

		lua.pushboolean(L, b32(changed))
		lua.pushboolean(L, b32(submitted))
		lua.pushstring(L, new_text_cstr)
		return 3
	},
}
