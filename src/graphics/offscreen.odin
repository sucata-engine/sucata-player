package graphics

import sg "shared:sokol/gfx"

Offscreen :: struct {
	color_img:      sg.Image,
	depth_img:      sg.Image,
	color_att_view: sg.View,
	depth_att_view: sg.View,
	color_tex_view: sg.View,
	width:          i32,
	height:         i32,
}

create_offscreen :: proc(width, height: i32) -> Offscreen {
	color_img := sg.make_image(
		{usage = {color_attachment = true}, width = width, height = height, sample_count = 1},
	)

	depth_img := sg.make_image(
		{
			usage = {depth_stencil_attachment = true},
			width = width,
			height = height,
			sample_count = 1,
		},
	)

	color_att_view := sg.make_view({color_attachment = {image = color_img}})

	depth_att_view := sg.make_view({depth_stencil_attachment = {image = depth_img}})

	color_tex_view := sg.make_view({texture = {image = color_img}})

	return Offscreen {
		color_img = color_img,
		color_att_view = color_att_view,
		color_tex_view = color_tex_view,
		depth_att_view = depth_att_view,
		depth_img = depth_img,
		width = width,
		height = height,
	}
}

shutdown_offscreen :: proc(offscreen: ^Offscreen) {
	sg.destroy_view(offscreen.color_att_view)
	sg.destroy_view(offscreen.depth_att_view)
	sg.destroy_view(offscreen.color_tex_view)
	sg.destroy_image(offscreen.color_img)
	sg.destroy_image(offscreen.depth_img)
}
