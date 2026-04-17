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

offscreen: Offscreen
offscreen_inited: bool

init_offscreen :: proc(width, height: i32) {
	shutdown_offscreen()

	color_img := sg.make_image(
		{
			usage = {color_attachment = true},
			width = width,
			height = height,
			sample_count = 1,
			label = "offscreen-color",
		},
	)

	depth_img := sg.make_image(
		{
			usage = {depth_stencil_attachment = true},
			width = width,
			height = height,
			sample_count = 1,
			label = "offscreen-depth",
		},
	)

	color_att_view := sg.make_view(
		{color_attachment = {image = color_img}, label = "offscreen-color-att-view"},
	)

	depth_att_view := sg.make_view(
		{depth_stencil_attachment = {image = depth_img}, label = "offscreen-depth-att-view"},
	)

	color_tex_view := sg.make_view(
		{texture = {image = color_img}, label = "offscreen-color-tex-view"},
	)

	offscreen = Offscreen {
		color_img      = color_img,
		color_att_view = color_att_view,
		color_tex_view = color_tex_view,
		depth_att_view = depth_att_view,
		depth_img      = depth_img,
		width          = width,
		height         = height,
	}
	offscreen_inited = true
}

shutdown_offscreen :: proc() {
	if offscreen_inited {
		sg.destroy_view(offscreen.color_att_view)
		sg.destroy_view(offscreen.depth_att_view)
		sg.destroy_view(offscreen.color_tex_view)
		sg.destroy_image(offscreen.color_img)
		sg.destroy_image(offscreen.depth_img)
		offscreen_inited = false
	}
}
