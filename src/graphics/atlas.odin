package graphics

import "../common"

calculate_atlas_uv :: proc(atlas: common.AtlasProps, width: f32, height: f32) -> [4][2]f32 {
	atlas_width := atlas.width
	atlas_height := atlas.height
	atlas_spacing := atlas.spacing
	atlas_margin := atlas.margin
	atlas_x := atlas.x
	atlas_y := atlas.y

	if atlas_height == 0.0 || atlas_width == 0.0 {
		return [4][2]f32{{0.0, 0.0}, {0.0, 1.0}, {1.0, 1.0}, {1.0, 0.0}}
	}

	u0 := (atlas_margin + (atlas_x * (atlas_width + atlas_spacing))) / width
	v0 := (atlas_margin + (atlas_y * (atlas_height + atlas_spacing))) / height
	u1 := (atlas_margin + (atlas_x * (atlas_width + atlas_spacing)) + atlas_width) / width
	v1 := (atlas_margin + (atlas_y * (atlas_height + atlas_spacing)) + atlas_height) / height

	return [4][2]f32{{u0, v0}, {u0, v1}, {u1, v1}, {u1, v0}}
}

calculate_atlas_uv_tiled :: proc(
	atlas: common.AtlasProps,
	img_width: f32,
	img_height: f32,
	quad_size: [2]f32,
) -> [4][2]f32 {
	atlas_width := atlas.width
	atlas_height := atlas.height
	atlas_spacing := atlas.spacing
	atlas_margin := atlas.margin
	atlas_x := atlas.x
	atlas_y := atlas.y

	if atlas_height == 0.0 || atlas_width == 0.0 {
		repeat_x := quad_size[0] / img_width
		repeat_y := quad_size[1] / img_height
		return [4][2]f32{{0.0, 0.0}, {0.0, repeat_y}, {repeat_x, repeat_y}, {repeat_x, 0.0}}
	}

	u0 := (atlas_margin + (atlas_x * (atlas_width + atlas_spacing))) / img_width
	v0 := (atlas_margin + (atlas_y * (atlas_height + atlas_spacing))) / img_height
	u1 := (atlas_margin + (atlas_x * (atlas_width + atlas_spacing)) + atlas_width) / img_width
	v1 := (atlas_margin + (atlas_y * (atlas_height + atlas_spacing)) + atlas_height) / img_height

	tile_u := u1 - u0
	tile_v := v1 - v0
	repeat_x := quad_size[0] / atlas_width
	repeat_y := quad_size[1] / atlas_height

	return [4][2]f32 {
		{u0, v0},
		{u0, v0 + tile_v * repeat_y},
		{u0 + tile_u * repeat_x, v0 + tile_v * repeat_y},
		{u0 + tile_u * repeat_x, v0},
	}
}
