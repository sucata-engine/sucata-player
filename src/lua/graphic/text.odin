package graphic

import common "../../common"
import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

TEXT_FUNCTION :: lua_common.LuaFunction {
	name = "draw_text",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_text") do return 0
		if !lua_common.validate_table(L, 1, "draw_text") do return 0

		x: f32 = 0.0
		y: f32 = 0.0
		font_size: f32 = 16.0
		color_rgba: [4]f32 = {1, 1, 1, 1}
		zIndex: f64 = 0.0
		text: string = ""
		text_owned := false
		font: string = ""
		font_owned := false
		scale: f32 = 1.0
		scale_x: f32 = 1.0
		scale_y: f32 = 1.0
		origin: f32 = 0.0
		origin_x: f32 = 0.0
		origin_y: f32 = 0.0
		rotation: f32 = 0.0
		fixed: bool = false
		align: string = "left"
		align_owned := false
		max_width: f32 = 0.0
		opacity: Maybe(f32) = nil
		shader: f64 = 0.0
		shader_args := common.ShaderArgs{}

		lua.pushnil(L)
		for lua.next(L, 1) != 0 {
			if lua.type(L, -2) == lua.Type.STRING {
				switch lua.tostring(L, -2) {
				case "x":
					if lua.isnumber(L, -1) do x = f32(lua.tonumber(L, -1))
				case "y":
					if lua.isnumber(L, -1) do y = f32(lua.tonumber(L, -1))
				case "size":
					if lua.isnumber(L, -1) do font_size = f32(lua.tonumber(L, -1))
				case "color":
					if lua.type(L, -1) == lua.Type.TABLE {
						color_rgba = parse_color_array(L, -1)
					}
				case "z_index":
					if lua.isnumber(L, -1) do zIndex = f64(lua.tonumber(L, -1))
				case "text":
					if lua.isstring(L, -1) {
						text = strings.clone_from_cstring(lua.tostring(L, -1))
						text_owned = true
					}
				case "font":
					if lua.isstring(L, -1) {
						font = strings.clone_from_cstring(lua.tostring(L, -1))
						font_owned = true
					}
				case "scale":
					if lua.isnumber(L, -1) do scale = f32(lua.tonumber(L, -1))
				case "scale_x":
					if lua.isnumber(L, -1) do scale_x = f32(lua.tonumber(L, -1))
				case "scale_y":
					if lua.isnumber(L, -1) do scale_y = f32(lua.tonumber(L, -1))
				case "origin":
					if lua.isnumber(L, -1) do origin = f32(lua.tonumber(L, -1))
				case "origin_x":
					if lua.isnumber(L, -1) do origin_x = f32(lua.tonumber(L, -1))
				case "origin_y":
					if lua.isnumber(L, -1) do origin_y = f32(lua.tonumber(L, -1))
				case "rotation":
					if lua.isnumber(L, -1) do rotation = f32(lua.tonumber(L, -1))
				case "fixed":
					if lua.isboolean(L, -1) do fixed = bool(lua.toboolean(L, -1))
				case "align":
					if lua.isstring(L, -1) {
						align = strings.clone_from_cstring(lua.tostring(L, -1))
						align_owned = true
					}
				case "max_width":
					if lua.isnumber(L, -1) do max_width = f32(lua.tonumber(L, -1))
				case "opacity":
					if lua.isnumber(L, -1) do opacity = f32(lua.tonumber(L, -1))
				case "shader":
					if lua.isnumber(L, -1) do shader = f64(lua.tonumber(L, -1))
				case "shader_args":
					if lua.type(L, -1) == lua.Type.TABLE {
						shader_args = lua_common.parse_shader_args_table(L)
					}
				}
			}
			lua.pop(L, 1)
		}

		if !text_owned do text = strings.clone(text)
		if !font_owned do font = strings.clone(font)
		if !align_owned do align = strings.clone(align)
		defer delete(align)

		if scale != 1.0 && (scale_x == 1.0 && scale_y == 1.0) {
			scale_x = scale
			scale_y = scale
		}

		if origin != 0.0 && (origin_x == 0.0 && origin_y == 0.0) {
			origin_x = origin
			origin_y = origin
		}

		text_align := common.TextAlign.Left
		switch align {
		case "center":
			text_align = .Center
		case "right":
			text_align = .Right
		case "left":
			text_align = .Left
		}

		props := common.TextObjectProps {
			position    = [2]f32{x, y},
			color       = color_rgba,
			zIndex      = i32(zIndex),
			font        = font,
			size        = font_size,
			shader      = u32(shader),
			scale       = [2]f32{scale_x, scale_y},
			origin      = [2]f32{origin_x, origin_y},
			rotation    = rotation,
			opacity     = opacity,
			text        = text,
			fixed       = fixed,
			align       = text_align,
			max_width   = max_width,
			shader_args = shader_args,
		}

		core.add_to_render_queue(props)

		return 0
	},
}
