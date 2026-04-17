package graphics

import "../common"
import shader_quad "../shaders/quad"
import "core:c"
import "core:strings"
import sg "shared:sokol/gfx"

quad_ib: sg.Buffer
quad_buffers_inited: bool
quad_shader: sg.Shader
quad_pipeline: sg.Pipeline
quad_sampler: sg.Sampler
quad_sampler_repeat: sg.Sampler

init_quad_indices :: proc() {
	if quad_buffers_inited {
		return
	}
	quad_shader = shader_quad.load_rect_shader()
	quad_pipeline = sg.make_pipeline(
		{
			shader = quad_shader,
			layout = {
				buffers = {0 = {stride = c.int(size_of(Vertex_Data))}},
				attrs = {
					shader_quad.ATTR_quad_position = {
						format = .FLOAT2,
						buffer_index = 0,
						offset = 0,
					},
					shader_quad.ATTR_quad_color = {format = .FLOAT4, buffer_index = 0, offset = 8},
					shader_quad.ATTR_quad_uv = {format = .FLOAT2, buffer_index = 0, offset = 24},
				},
			},
			index_type = .UINT16,
			colors = {
				0 = {
					blend = {
						enabled = true,
						src_factor_rgb = .SRC_ALPHA,
						dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
						src_factor_alpha = .ONE,
						dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
						op_rgb = .ADD,
						op_alpha = .ADD,
					},
				},
			},
		},
	)
	quad_ib = sg.make_buffer(
		{usage = {index_buffer = true, immutable = true}, data = sg_range(indices)},
	)

	quad_sampler = sg.make_sampler(
		{
			min_filter = .NEAREST,
			mag_filter = .NEAREST,
			wrap_u = .CLAMP_TO_EDGE,
			wrap_v = .CLAMP_TO_EDGE,
		},
	)

	quad_sampler_repeat = sg.make_sampler(
		{min_filter = .NEAREST, mag_filter = .NEAREST, wrap_u = .REPEAT, wrap_v = .REPEAT},
	)

	quad_buffers_inited = true
}

shutdown_quad_buffers :: proc() {
	if quad_buffers_inited {
		sg.destroy_buffer(quad_ib)
		sg.destroy_pipeline(quad_pipeline)
		sg.destroy_sampler(quad_sampler)
		sg.destroy_sampler(quad_sampler_repeat)
		sg.destroy_shader(quad_shader)
		quad_buffers_inited = false
	}
}

quad_group :: proc(props: common.GroupObjectProps) {
	init_quad_indices()

	z_index := props.z_index
	texture := props.texture
	shader_id := props.shader
	fixed := props.fixed
	quads := props.quads

	if len(quads) == 0 {
		return
	}

	custom_shader, has_custom_shader := custom_shaders[shader_id]
	image := load_image(texture)

	mvp := get_mvp(props.fixed)
	batch_vertices := [dynamic]f32{}

	for quad in quads {
		quad_vertex := get_quad_vertex_data(
			quad,
			image,
			props.tiled,
			has_custom_shader,
			custom_shader,
		)
		append(&batch_vertices, ..quad_vertex[:])
	}
	if len(batch_vertices) == 0 {
		return
	}

	vertex_buffer := sg.make_buffer(
		{usage = {vertex_buffer = true, immutable = true}, data = sg_range(batch_vertices[:])},
	)
	state := sg.query_buffer_state(vertex_buffer)

	if has_custom_shader {
		sg.apply_pipeline(custom_shader.pipeline)
	} else {
		sg.apply_pipeline(quad_pipeline)
	}

	sg.apply_uniforms(0, {ptr = &mvp, size = size_of(mvp)})

	bindings := sg.Bindings {
		vertex_buffers = {0 = vertex_buffer},
		index_buffer = quad_ib,
		views = get_views_data(image.view),
		samplers = get_samplers_data(props.tiled),
	}
	sg.apply_bindings(bindings)

	quad_count := len(quads)
	index_count := quad_count * 6
	sg.draw(0, index_count, 1)

	sg.destroy_buffer(vertex_buffer)
	delete(batch_vertices)
}
