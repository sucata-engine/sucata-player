package graphic

import common "../../common"
import core "../../core"
import lua_common "../lua_common"
import "core:c"
import lua "../../luajit"

LOAD_TEXTURE_FUNCTION :: lua_common.LuaFunction {
	name = "_sprite",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		number :: proc(L: ^lua.State, index: c.int, fallback: f32) -> f32 {
			return lua.isnumber(L, index) ? f32(lua.tonumber(L, index)) : fallback
		}

		image: u32 = 0
		if lua.isstring(L, 1) {
			path := string(lua.tostring(L, 1))
			if path != "" do image = core.register_texture(path)
		}

		sprite := core.Sprite {
			image = image,
			color = {number(L, 2, 1), number(L, 3, 1), number(L, 4, 1), number(L, 5, 1)},
		}

		cell_w := number(L, 6, 0)
		if cell_w > 0 {
			sprite.atlas = common.AtlasProps {
				width   = cell_w,
				height  = number(L, 7, cell_w),
				spacing = number(L, 8, 0),
				margin  = number(L, 9, 0),
				x       = number(L, 10, 0),
				linear  = true,
			}
		}

		lua.pushinteger(L, lua.Integer(core.register_sprite(sprite)))
		return 1
	},
}

LOAD_FONT_FUNCTION :: lua_common.LuaFunction {
	name = "load_font",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "load_font") do return 0
		if !lua_common.validate_string(L, 1, "load_font") do return 0

		handle := core.register_texture(string(lua.tostring(L, 1)))
		lua.pushinteger(L, lua.Integer(handle))

		return 1
	},
}
