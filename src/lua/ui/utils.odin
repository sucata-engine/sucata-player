package ui

import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "vendor:lua/5.4"
import mu "vendor:microui"

get_table_color :: proc(L: ^lua.State, table_index: c.int, field: cstring) -> Maybe(mu.Color) {
	lua.pushstring(L, field)
	lua.gettable(L, table_index)
	defer lua.pop(L, 1)

	if lua.type(L, -1) != lua.Type.TABLE {
		return nil
	}

	rgba := [4]f32{0, 0, 0, 1}
	for i in 1 ..= 4 {
		lua.rawgeti(L, -1, lua.Integer(i))
		if lua.isnumber(L, -1) do rgba[i - 1] = f32(lua.tonumber(L, -1))
		lua.pop(L, 1)
	}

	return mu.Color {
		u8(clamp(rgba[0], 0, 1) * 255),
		u8(clamp(rgba[1], 0, 1) * 255),
		u8(clamp(rgba[2], 0, 1) * 255),
		u8(clamp(rgba[3], 0, 1) * 255),
	}
}

get_style_from_table :: proc(L: ^lua.State, table_index: c.int) -> core.Mu_Style {
	style: core.Mu_Style
	style.x = lua_common.get_table_number_nil(L, table_index, "x")
	style.y = lua_common.get_table_number_nil(L, table_index, "y")
	style.width = lua_common.get_table_number_nil(L, table_index, "width")
	style.height = lua_common.get_table_number_nil(L, table_index, "height")
	style.text_size = lua_common.get_table_number_nil(L, table_index, "text_size")
	style.color = get_table_color(L, table_index, "color")
	style.background_color = get_table_color(L, table_index, "background_color")
	style.border_color = get_table_color(L, table_index, "border_color")
	return style
}
