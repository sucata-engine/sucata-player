package graphic

import "core:c"
import lua "vendor:lua/5.4"

parse_color_array :: proc(L: ^lua.State, table_index: c.int) -> [4]f32 {
	color := [4]f32{0, 0, 0, 1}

	for i in 1 ..= 4 {
		lua.rawgeti(L, table_index, lua.Integer(i))
		if lua.isnumber(L, -1) {
			color[i - 1] = f32(lua.tonumber(L, -1))
		}
		lua.pop(L, 1)
	}

	return color
}
