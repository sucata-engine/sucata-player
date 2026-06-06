package graphics

import "../common"
import shader_text "../shaders/text"
import "core:c"
import "core:unicode/utf8"
import sg "shared:sokol/gfx"

text_ib: sg.Buffer
text_shader: sg.Shader
text_buffers_inited: bool
text_pipeline: sg.Pipeline
text_sampler: sg.Sampler

init_text_indices :: proc() {
	if text_buffers_inited {
		return
	}
	text_shader = shader_text.load_text_shader()
	text_pipeline = sg.make_pipeline(
		{
			shader = text_shader,
			layout = {
				buffers = {0 = {stride = c.int(size_of(Vertex_Data))}},
				attrs = {
					shader_text.ATTR_text_position = {
						format = .FLOAT2,
						buffer_index = 0,
						offset = 0,
					},
					shader_text.ATTR_text_color = {format = .FLOAT4, buffer_index = 0, offset = 8},
					shader_text.ATTR_text_uv = {format = .FLOAT2, buffer_index = 0, offset = 24},
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
	text_ib = sg.make_buffer(
		{usage = {index_buffer = true, immutable = true}, data = sg_range(indices)},
	)

	text_sampler = sg.make_sampler(
		{
			min_filter = .NEAREST,
			mag_filter = .NEAREST,
			wrap_u = .CLAMP_TO_EDGE,
			wrap_v = .CLAMP_TO_EDGE,
		},
	)

	text_buffers_inited = true
}

shutdown_text_buffers :: proc() {
	if text_buffers_inited {
		sg.destroy_buffer(text_ib)
		sg.destroy_pipeline(text_pipeline)
		sg.destroy_sampler(text_sampler)
		sg.destroy_shader(text_shader)
		text_buffers_inited = false
	}
}

text :: proc(props: common.TextObjectProps) {
	init_text_indices()
	font := load_font(props.font, props.size)

	if font == nil {
		return
	}

	mvp := get_mvp(props.fixed)

	custom_shader, has_custom_shader := custom_shaders[props.shader]
	if has_custom_shader {
		sg.apply_pipeline(custom_shader.pipeline)
	} else {
		sg.apply_pipeline(text_pipeline)
	}

	clear(&vertex_scratch)
	get_text_vertex_data(&vertex_scratch, props, props.text, font, has_custom_shader, custom_shader)

	if len(vertex_scratch) == 0 {
		return
	}

	vertex_buffers := sg.make_buffer(
		{usage = {vertex_buffer = true, immutable = true}, data = sg_range(vertex_scratch[:])},
	)
	sg.apply_uniforms(0, {ptr = &mvp, size = size_of(mvp)})

	bindings := sg.Bindings {
		vertex_buffers = vertex_buffers,
		index_buffer = text_ib,
		views = get_views_data(font.image),
		samplers = {0 = text_sampler},
	}
	sg.apply_bindings(bindings)

	quad_count := len(props.text)
	index_count := quad_count * 6
	sg.draw(0, index_count, 1)

	sg.destroy_buffer(vertex_buffers)
}
