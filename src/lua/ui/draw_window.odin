package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"

DRAW_WINDOW_FUNCTION :: lua_common.LuaFunction {
	name = "draw_window",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_window") do return 0
		if !lua_common.validate_table(L, 1, "draw_window") do return 0

		title := lua_common.get_table_string(L, 1, "title", "Window")
		defer delete(title)

		x := f32(lua_common.get_table_number(L, 1, "x", 40))
		y := f32(lua_common.get_table_number(L, 1, "y", 40))
		width := f32(lua_common.get_table_number(L, 1, "width", 200))
		height := f32(lua_common.get_table_number(L, 1, "height", 150))
		transparent := lua_common.get_table_boolean(L, 1, "transparent", false)
		movable := lua_common.get_table_boolean(L, 1, "movable", true)
		resizable := lua_common.get_table_boolean(L, 1, "resizable", true)

		color := get_table_color(L, 1, "color")
		background_color := get_table_color(L, 1, "background_color")
		border_color := get_table_color(L, 1, "border_color")

		open := core.microui_window_begin(
			title,
			x,
			y,
			width,
			height,
			transparent,
			movable,
			resizable,
			color,
			background_color,
			border_color,
		)
		lua.pushboolean(L, b32(open))
		return 1
	},
}
