package graphics

import "../common"
import "core:strings"
import sg "shared:sokol/gfx"

ShaderCalcProps :: struct {
	image:             Image,
	tiled:             bool,
	custom_shader:     CustomShader,
	has_custom_shader: bool,
	position:          [2]f32,
	size:              [2]f32,
	color:             [4]f32,
	scale:             [2]f32,
	origin:            [2]f32,
	rotation:          f32,
	opacity:           Maybe(f32),
	atlas:             common.AtlasProps,
	shader_args:       common.ShaderArgs,
}

get_quad_vertex_data :: proc(
	object: common.ObjectProp,
	image: Image,
	tiled: bool,
	has_custom_shader: bool,
	custom_shader: CustomShader,
) -> [dynamic]f32 {
	return get_vertex_data(
		{
			image = image,
			tiled = tiled,
			custom_shader = custom_shader,
			has_custom_shader = has_custom_shader,
			position = object.position,
			size = object.size,
			color = object.color,
			scale = object.scale,
			origin = object.origin,
			rotation = object.rotation,
			opacity = object.opacity,
			atlas = object.atlas,
			shader_args = object.shader_args,
		},
	)
}

get_vertex_data :: proc(shader_calc: ShaderCalcProps) -> [dynamic]f32 {
	position := shader_calc.position
	size := shader_calc.size
	color := shader_calc.color
	scale := shader_calc.scale
	origin := shader_calc.origin
	rotation := shader_calc.rotation
	atlas := shader_calc.atlas
	shader_args := shader_calc.shader_args
	opacity := shader_calc.opacity.(f32) or_else color[3]

	points := to_world_space_2d(position, size, scale, origin, rotation)
	quad_color := Vec4{color[0], color[1], color[2], opacity}

	uv_pos: [4][2]f32
	if shader_calc.tiled {
		uv_pos = calculate_atlas_uv_tiled(
			atlas,
			f32(shader_calc.image.width),
			f32(shader_calc.image.height),
			size,
		)
	} else {
		uv_pos = calculate_atlas_uv(
			atlas,
			f32(shader_calc.image.width),
			f32(shader_calc.image.height),
		)
	}
	if shader_calc.has_custom_shader {
		vertex_data := [dynamic]f32{}
		shader_args := shader_calc.shader_args
		shader_params := shader_calc.custom_shader.attributes

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

get_views_data :: proc(image: sg.View) -> [32]sg.View {
	return {0 = image}
}

get_samplers_data :: proc(tiled: bool) -> [12]sg.Sampler {
	if tiled {
		return {0 = quad_sampler_repeat}
	}
	return {0 = quad_sampler}
}
