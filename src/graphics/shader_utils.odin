package graphics

import "../common"
import "core:strings"
import "core:unicode/utf8"
import sg "shared:sokol/gfx"

get_quad_vertex_data :: proc(
	object: common.ObjectProp,
	image: Image,
	tiled: bool,
	has_custom_shader: bool,
	custom_shader: CustomShader,
) -> [dynamic]f32 {
	position := object.position
	size := object.size
	color := object.color
	scale := object.scale
	origin := object.origin
	rotation := object.rotation
	atlas := object.atlas
	shader_args := object.shader_args
	opacity := object.opacity.(f32) or_else color[3]

	points := to_world_space_2d(position, size, scale, origin, rotation)
	quad_color := Vec4{color[0], color[1], color[2], opacity}

	uv_pos: [4][2]f32
	if tiled {
		uv_pos = calculate_atlas_uv_tiled(atlas, f32(image.width), f32(image.height), size)
	} else {
		uv_pos = calculate_atlas_uv(atlas, f32(image.width), f32(image.height))
	}
	if has_custom_shader {
		vertex_data := [dynamic]f32{}
		shader_params := custom_shader.attributes

		for i in 0 ..< 4 {
			for attr in shader_params {
				if strings.equal_fold(attr.name, "position") {
					append(&vertex_data, ..points[i][:])
				} else if strings.equal_fold(attr.name, "col") {
					append(&vertex_data, ..quad_color[:])
				} else if strings.equal_fold(attr.name, "uv") {
					append(&vertex_data, ..uv_pos[i][:])
				} else {
					if value, ok := shader_args[attr.name]; ok {
						#partial switch v in value {
						case f32:
							append(&vertex_data, v)
							break
						case [2]f32:
							v2 := v
							append(&vertex_data, ..v2[:])
							break
						case [3]f32:
							v3 := v
							append(&vertex_data, ..v3[:])
							break
						case [4]f32:
							v4 := v
							append(&vertex_data, ..v4[:])
							break
						}
					}
				}
			}
		}
		return vertex_data
	}

	vertex_data := [dynamic]f32{}
	for i in 0 ..< 4 {
		append(&vertex_data, ..points[i][:])
		append(&vertex_data, ..quad_color[:])
		append(&vertex_data, ..uv_pos[i][:])
	}
	return vertex_data
}

get_text_vertex_data :: proc(
	props: common.TextObjectProps,
	text: string,
	font: ^Font,
	has_custom_shader: bool,
	custom_shader: CustomShader,
) -> [dynamic]f32 {
	vertex_data := [dynamic]f32{}
	lines := wrap_text(text, font, props.scale, props.max_width)
	defer delete(lines)

	line_height := props.size * props.scale[1]
	current_y := props.position[1]

	opacity := props.opacity.(f32) or_else props.color[3]
	text_color := Vec4{props.color[0], props.color[1], props.color[2], opacity}

	for line in lines {
		if len(line) == 0 {
			current_y += line_height
			continue
		}

		line_width := calculate_text_width(line, font, props.scale)
		alignment_offset := calculate_alignment_offset(line_width, props.max_width, props.align)

		cursor_pos := [2]f32{props.position[0] + alignment_offset, current_y}

		i := 0
		for i < len(line) {
			r, size := utf8.decode_rune(line[i:])
			i += size

			if r < 32 || r > 255 {
				continue
			}

			char_index := int(r) - 32
			if char_index < 0 || char_index >= len(font.char_data) {
				continue
			}

			baked_char := font.char_data[char_index]

			char_width := f32(baked_char.x1 - baked_char.x0)
			char_height := f32(baked_char.y1 - baked_char.y0)
			char_size := [2]f32{char_width, char_height}

			char_pos := [2]f32 {
				cursor_pos[0] + f32(baked_char.xoff),
				cursor_pos[1] + f32(baked_char.yoff),
			}

			points := to_world_space_2d(
				char_pos,
				char_size,
				props.scale,
				props.origin,
				props.rotation,
			)

			half_px_u := 0.5 / f32(font.bitmap_width)
			half_px_v := 0.5 / f32(font.bitmap_height)
			uv_pos := to_uv_space_2d(
				f32(baked_char.x0) + half_px_u,
				f32(baked_char.y0) + half_px_v,
				f32(baked_char.x1) - half_px_u,
				f32(baked_char.y1) - half_px_v,
				f32(font.bitmap_width),
				f32(font.bitmap_height),
			)

			for j in 0 ..< 4 {
				if has_custom_shader {
					shader_params := custom_shader.attributes
					for attr in shader_params {
						if strings.equal_fold(attr.name, "position") {
							append(&vertex_data, ..points[j][:])
						} else if strings.equal_fold(attr.name, "col") {
							append(&vertex_data, ..text_color[:])
						} else if strings.equal_fold(attr.name, "uv") {
							append(&vertex_data, ..uv_pos[j][:])
						} else {
							if value, ok := props.shader_args[attr.name]; ok {
								#partial switch v in value {
								case f32:
									append(&vertex_data, v)
									break
								case [2]f32:
									v2 := v
									append(&vertex_data, ..v2[:])
									break
								case [3]f32:
									v3 := v
									append(&vertex_data, ..v3[:])
									break
								case [4]f32:
									v4 := v
									append(&vertex_data, ..v4[:])
									break
								}
							}
						}
					}
				} else {
					append(&vertex_data, ..points[j][:])
					append(&vertex_data, ..text_color[:])
					append(&vertex_data, ..uv_pos[j][:])
				}
			}

			cursor_pos[0] += f32(baked_char.xadvance) * props.scale[0]
		}
		current_y += line_height
	}
	return vertex_data
}

get_views_data :: proc(image: sg.View) -> [32]sg.View {
	return {0 = image}
}

get_samplers_data :: proc(tiled: bool) -> [12]sg.Sampler {
	if tiled {
		return {0 = quad_sampler_repeat}
	}
	return {0 = quad_sampler}
}
