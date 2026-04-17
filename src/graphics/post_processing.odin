package graphics

import shader "../shaders/post_processing"
import "core:c"
import sg "shared:sokol/gfx"

Postfx_Vertex :: struct {
	position: Vec2,
	uv:       Vec2,
}

postfx_pipeline: sg.Pipeline
postfx_shader: sg.Shader
postfx_vb: sg.Buffer
postfx_sampler: sg.Sampler
postfx_inited: bool


init_postfx :: proc() {
	if postfx_inited {
		return
	}

	postfx_shader = shader.load_post_processing_shader()

	postfx_pipeline = sg.make_pipeline(
		{
			shader = postfx_shader,
			layout = {
				buffers = {0 = {stride = c.int(size_of(Postfx_Vertex))}},
				attrs = {
					shader.ATTR_shader_post_processing_position = {
						format = .FLOAT2,
						buffer_index = 0,
						offset = 0,
					},
					shader.ATTR_shader_post_processing_uv = {
						format = .FLOAT2,
						buffer_index = 0,
						offset = 8,
					},
				},
			},
			index_type = .UINT16,
			label = "postfx-pipeline",
		},
	)

	vertices := [4]Postfx_Vertex {
		{position = {-1.0, 1.0}, uv = {0.0, 0.0}},
		{position = {1.0, 1.0}, uv = {1.0, 0.0}},
		{position = {1.0, -1.0}, uv = {1.0, 1.0}},
		{position = {-1.0, -1.0}, uv = {0.0, 1.0}},
	}
	postfx_vb = sg.make_buffer(
		{
			usage = {vertex_buffer = true, immutable = true},
			data = sg_range(vertices[:]),
			label = "postfx-vb",
		},
	)

	postfx_sampler = sg.make_sampler(
		{
			min_filter = .LINEAR,
			mag_filter = .LINEAR,
			wrap_u = .CLAMP_TO_EDGE,
			wrap_v = .CLAMP_TO_EDGE,
			label = "postfx-sampler",
		},
	)

	postfx_inited = true
}

shutdown_postfx :: proc() {
	if postfx_inited {
		sg.destroy_pipeline(postfx_pipeline)
		sg.destroy_shader(postfx_shader)
		sg.destroy_buffer(postfx_vb)
		sg.destroy_sampler(postfx_sampler)
		postfx_inited = false
	}
}

draw_offscreen :: proc() {
	init_postfx()

	indices := []u16{0, 1, 2, 0, 2, 3}
	ib := sg.make_buffer(
		{usage = {index_buffer = true, immutable = true}, data = sg_range(indices)},
	)
	defer sg.destroy_buffer(ib)

	sg.apply_pipeline(postfx_pipeline)
	sg.apply_bindings(
		{
			vertex_buffers = {0 = postfx_vb},
			index_buffer = ib,
			views = {shader.VIEW_screen_tex = offscreen.color_tex_view},
			samplers = {shader.SMP_screen_smp = postfx_sampler},
		},
	)
	sg.draw(0, 6, 1)
}
