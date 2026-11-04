package graphics

import "../common"
import shader_quad "../shaders/quad"
import "core:c"
import sg "shared:sokol/gfx"

quad_ib: sg.Buffer
quad_stream: Vertex_Stream
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
		{usage = {index_buffer = true}, data = sg_range(indices)},
	)
	init_vertex_stream(&quad_stream, QUAD_STREAM_CAPACITY * size_of(Vertex_Data) * 4)

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
		destroy_vertex_stream(&quad_stream)
		shutdown_draw_commands()
		sg.destroy_pipeline(quad_pipeline)
		sg.destroy_sampler(quad_sampler)
		sg.destroy_sampler(quad_sampler_repeat)
		sg.destroy_shader(quad_shader)
		delete(vertex_scratch)
		vertex_scratch = {}
		quad_buffers_inited = false
	}
}

queue_quad_group :: proc(props: common.GroupObjectProps, texture: string) {
	init_quad_indices()

	quads := props.quads^
	if len(quads) == 0 {
		return
	}

	custom_shader, has_custom_shader := custom_shaders[props.shader]
	image := load_image(texture)
	mvp := get_mvp(props.fixed)

	vertex_offset: c.int
	floats_per_quad: int

	if has_custom_shader {
		clear(&vertex_scratch)
		args := props.args != nil ? props.args^ : nil
		for quad, i in quads {
			quad_args: common.ShaderArgs
			if i < len(args) {
				quad_args = args[i]
			}
			append_custom_quad_vertices(&vertex_scratch, quad, quad_args, image, props.tiled, custom_shader)
		}
		if len(vertex_scratch) == 0 {
			return
		}
		floats_per_quad = len(vertex_scratch) / len(quads)
		vertex_offset = stream_push(&quad_stream, vertex_scratch[:])
	} else {
		floats_per_quad = QUAD_FLOATS
		start := len(quad_stream.data)
		resize(&quad_stream.data, start + len(quads) * QUAD_FLOATS)
		dst := quad_stream.data[start:]
		for quad, i in quads {
			write_quad_vertices(dst[i * QUAD_FLOATS:], quad, image, props.tiled)
		}
		vertex_offset = c.int(start * size_of(f32))
	}

	pipeline := has_custom_shader ? custom_shader.pipeline : quad_pipeline
	views := get_views_data(image.view)
	samplers := get_samplers_data(props.tiled)
	bytes_per_quad := c.int(floats_per_quad * size_of(f32))

	for first := 0; first < len(quads); first += MAX_QUADS {
		count := min(MAX_QUADS, len(quads) - first)
		append(
			&draw_commands,
			Draw_Command {
				pipeline = pipeline,
				mvp = mvp,
				stream = &quad_stream,
				vertex_offset = vertex_offset + c.int(first) * bytes_per_quad,
				index_buffer = quad_ib,
				views = views,
				samplers = samplers,
				index_count = count * 6,
			},
		)
	}
}
