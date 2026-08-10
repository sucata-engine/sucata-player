package graphic

import common "../../common"
import core "../../core"
import lua_common "../lua_common"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

RECT_FUNCTION :: lua_common.LuaFunction {
	name = "draw_rect",
	func_ptr = proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT

		if !lua_common.validate_arg_count(L, 1, "draw_rect") do return 0
		if !lua_common.validate_table(L, 1, "draw_rect") do return 0

		x: f32 = 0.0
		y: f32 = 0.0
		width: f32 = 50.0
		height: f32 = 50.0
		color: string = "#ffffff"
		color_owned := false
		zIndex: f64 = 0.0
		texture_path: string = ""
		texture_owned := false
		scale: f32 = 1.0
		scale_x: f32 = 1.0
		scale_y: f32 = 1.0
		origin: f32 = 0.0
		origin_x: f32 = 0.0
		origin_y: f32 = 0.0
		rotation: f32 = 0.0
		opacity: Maybe(f32) = nil
		fixed: bool = false
		tiled: bool = false
		shader: f64 = 0.0
		shader_args := common.ShaderArgs{}
		atlas_width: f32 = 0.0
		atlas_height: f32 = 0.0
		atlas_size: f32 = 0.0
		atlas_spacing: f32 = 0.0
		atlas_margin: f32 = 0.0
		atlas_x: f32 = 0.0
		atlas_y: f32 = 0.0
		tile_width: f32 = 0.0
		tile_height: f32 = 0.0
		tile_size: f32 = 0.0

		lua.pushnil(L)
		for lua.next(L, 1) != 0 {
			if lua.type(L, -2) == lua.Type.STRING {
				switch lua.tostring(L, -2) {
				case "x":
					if lua.isnumber(L, -1) do x = f32(lua.tonumber(L, -1))
				case "y":
					if lua.isnumber(L, -1) do y = f32(lua.tonumber(L, -1))
				case "width":
					if lua.isnumber(L, -1) do width = f32(lua.tonumber(L, -1))
				case "height":
					if lua.isnumber(L, -1) do height = f32(lua.tonumber(L, -1))
				case "color":
					if lua.isstring(L, -1) {
						color = strings.clone_from_cstring(lua.tostring(L, -1))
						color_owned = true
					}
				case "z_index":
					if lua.isnumber(L, -1) do zIndex = f64(lua.tonumber(L, -1))
				case "texture":
					if lua.isstring(L, -1) {
						texture_path = strings.clone_from_cstring(lua.tostring(L, -1))
						texture_owned = true
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
				case "opacity":
					if lua.isnumber(L, -1) do opacity = f32(lua.tonumber(L, -1))
				case "fixed":
					if lua.isboolean(L, -1) do fixed = bool(lua.toboolean(L, -1))
				case "tiled":
					if lua.isboolean(L, -1) do tiled = bool(lua.toboolean(L, -1))
				case "shader":
					if lua.isnumber(L, -1) do shader = f64(lua.tonumber(L, -1))
				case "shader_args":
					if lua.type(L, -1) == lua.Type.TABLE {
						shader_args = lua_common.parse_shader_args_table(L)
					}
				case "atlas_width":
					if lua.isnumber(L, -1) do atlas_width = f32(lua.tonumber(L, -1))
				case "atlas_height":
					if lua.isnumber(L, -1) do atlas_height = f32(lua.tonumber(L, -1))
				case "atlas_size":
					if lua.isnumber(L, -1) do atlas_size = f32(lua.tonumber(L, -1))
				case "atlas_spacing":
					if lua.isnumber(L, -1) do atlas_spacing = f32(lua.tonumber(L, -1))
				case "atlas_margin":
					if lua.isnumber(L, -1) do atlas_margin = f32(lua.tonumber(L, -1))
				case "atlas_x":
					if lua.isnumber(L, -1) do atlas_x = f32(lua.tonumber(L, -1))
				case "atlas_y":
					if lua.isnumber(L, -1) do atlas_y = f32(lua.tonumber(L, -1))
				case "tile_width":
					if lua.isnumber(L, -1) do tile_width = f32(lua.tonumber(L, -1))
				case "tile_height":
					if lua.isnumber(L, -1) do tile_height = f32(lua.tonumber(L, -1))
				case "tile_size":
					if lua.isnumber(L, -1) do tile_size = f32(lua.tonumber(L, -1))
				}
			}
			lua.pop(L, 1)
		}

		if !color_owned do color = strings.clone(color)
		defer delete(color)

		if !texture_owned do texture_path = strings.clone(texture_path)
		defer delete(texture_path)

		if scale != 1.0 && (scale_x == 1.0 && scale_y == 1.0) {
			scale_x = scale
			scale_y = scale
		}

		if origin != 0.0 && (origin_x == 0.0 && origin_y == 0.0) {
			origin_x = origin
			origin_y = origin
		}

		if atlas_size != 0.0 && (atlas_width == 0.0 && atlas_height == 0.0) {
			atlas_width = atlas_size
			atlas_height = atlas_size
		}

		if tile_size != 0.0 && (tile_width == 0.0 && tile_height == 0.0) {
			tile_width = tile_size
			tile_height = tile_size
		}

		color_rgba := hex_to_rgba(color)

		props := common.ObjectProp {
			position = [2]f32{x, y},
			size = [2]f32{width, height},
			color = color_rgba,
			scale = [2]f32{scale_x, scale_y},
			origin = [2]f32{origin_x, origin_y},
			rotation = rotation,
			opacity = opacity,
			atlas = common.AtlasProps {
				width = atlas_width,
				height = atlas_height,
				spacing = atlas_spacing,
				margin = atlas_margin,
				x = atlas_x,
				y = atlas_y,
			},
			tile_size = [2]f32{tile_width, tile_height},
			shader_args = shader_args,
		}

		core.add_group_to_render_queue(i32(zIndex), texture_path, u32(shader), fixed, tiled, props)

		return 0
	},
}
