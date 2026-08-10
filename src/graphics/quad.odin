package graphics

import "../common"
import shader_quad "../shaders/quad"
import "core:c"
import sg "shared:sokol/gfx"

quad_ib: sg.Buffer
quad_vb: sg.Buffer
quad_buffers_inited: bool
quad_shader: sg.Shader
quad_pipeline: sg.Pipeline
quad_sampler: sg.Sampler
quad_sampler_repeat: sg.Sampler

QUAD_STREAM_CAPACITY :: MAX_QUADS * 4

init_quad_indices :: proc() {
	if quad_buffers_inited {
		return
	}
	reserve(&vertex_scratch, 32 * 4096)
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
	quad_vb = sg.make_buffer(
		{
			usage = {vertex_buffer = true, stream_update = true},
			size = QUAD_STREAM_CAPACITY * size_of(Vertex_Data) * 4,
		},
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
		sg.destroy_buffer(quad_vb)
		sg.destroy_pipeline(quad_pipeline)
		sg.destroy_sampler(quad_sampler)
		sg.destroy_sampler(quad_sampler_repeat)
		sg.destroy_shader(quad_shader)
		delete(vertex_scratch)
		vertex_scratch = {}
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
	clear(&vertex_scratch)

	for quad in quads {
		get_quad_vertex_data(
			&vertex_scratch,
			quad,
			image,
			props.tiled,
			has_custom_shader,
			custom_shader,
		)
	}
	if len(vertex_scratch) == 0 {
		return
	}

	data := sg_range(vertex_scratch[:])
	if sg.query_buffer_will_overflow(quad_vb, data.size) {
		common.print_error("quad vertex stream buffer overflow, dropping draw")
		return
	}
	vertex_offset := sg.append_buffer(quad_vb, data)

	if has_custom_shader {
		sg.apply_pipeline(custom_shader.pipeline)
	} else {
		sg.apply_pipeline(quad_pipeline)
	}

	sg.apply_uniforms(0, {ptr = &mvp, size = size_of(mvp)})

	bindings := sg.Bindings {
		vertex_buffers = {0 = quad_vb},
		vertex_buffer_offsets = {0 = vertex_offset},
		index_buffer = quad_ib,
		views = get_views_data(image.view),
		samplers = get_samplers_data(props.tiled),
	}
	sg.apply_bindings(bindings)

	quad_count := len(quads)
	index_count := quad_count * 6
	sg.draw(0, index_count, 1)
}
