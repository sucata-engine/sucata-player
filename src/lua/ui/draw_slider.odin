package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

DRAW_SLIDER_FUNCTION :: lua_common.LuaFunction {
	name = "draw_slider",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_slider") do return 0
		if !lua_common.validate_table(L, 1, "draw_slider") do return 0

		id := lua_common.get_table_string(L, 1, "id", "")
		defer delete(id)

		value := f32(lua_common.get_table_number(L, 1, "value", 0))
		low := f32(lua_common.get_table_number(L, 1, "low", 0))
		high := f32(lua_common.get_table_number(L, 1, "high", 100))
		step := f32(lua_common.get_table_number(L, 1, "step", 0))

		style := get_style_from_table(L, 1)

		changed, new_value := core.microui_slider(id, value, low, high, step, style)
		lua.pushboolean(L, b32(changed))
		lua.pushnumber(L, lua.Number(new_value))
		return 2
	},
}
