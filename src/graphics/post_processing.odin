package graphics

import "../common"
import shader "../shaders/post_processing"
import "core:c"
import "core:fmt"
import sg "shared:sokol/gfx"

Postfx_Vertex :: struct {
	position: Vec2,
	uv:       Vec2,
}

Postfx_Effect :: struct {
	id:      u64,
	enabled: bool,
	args:    common.ShaderArgs,
}
effects := [dynamic]Postfx_Effect{}

offscreen: Offscreen

postfx_targets: [2]Offscreen
postfx_vb: sg.Buffer
postfx_ib: sg.Buffer
postfx_inited: bool

postfx_passthrough_pipeline: sg.Pipeline
postfx_passthrough_shader: sg.Shader
postfx_passthrough_inited: bool

init_passthrough :: proc() {
	postfx_passthrough_shader = shader.load_post_processing_shader()
	postfx_passthrough_pipeline = sg.make_pipeline(
		{
			shader = postfx_passthrough_shader,
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
			color_count = 1,
			label = "postfx-passthrough-pipeline",
		},
	)
	postfx_passthrough_inited = true
}

resize_postfx :: proc(width, height: i32) {
	if !postfx_inited {
		return
	}
	shutdown_offscreen(&postfx_targets[0])
	shutdown_offscreen(&postfx_targets[1])
	shutdown_offscreen(&offscreen)
	postfx_targets[0] = create_offscreen(width, height)
	postfx_targets[1] = create_offscreen(width, height)
	offscreen = create_offscreen(width, height)
}

init_postfx :: proc(width, height: i32) {
	if !postfx_passthrough_inited {
		init_passthrough()
	}
	if postfx_inited {
		return
	}
	postfx_targets[0] = create_offscreen(width, height)
	postfx_targets[1] = create_offscreen(width, height)
	offscreen = create_offscreen(width, height)

	vertices := [4]Postfx_Vertex {
		{position = {-1.0, 1.0}, uv = {0.0, 0.0}},
		{position = {1.0, 1.0}, uv = {1.0, 0.0}},
		{position = {1.0, -1.0}, uv = {1.0, 1.0}},
		{position = {-1.0, -1.0}, uv = {0.0, 1.0}},
	}
	postfx_vb = sg.make_buffer(
		{usage = {vertex_buffer = true, immutable = true}, data = sg_range(vertices[:])},
	)

	indices := []u16{0, 1, 2, 0, 2, 3}
	postfx_ib = sg.make_buffer(
		{usage = {index_buffer = true, immutable = true}, data = sg_range(indices)},
	)

	effects = make([dynamic]Postfx_Effect)
	postfx_inited = true
}

shutdown_postfx :: proc() {
	if postfx_passthrough_inited {
		sg.destroy_pipeline(postfx_passthrough_pipeline)
		sg.destroy_shader(postfx_passthrough_shader)
	}
	if postfx_inited {
		delete(effects)
		sg.destroy_buffer(postfx_vb)
		sg.destroy_buffer(postfx_ib)
		shutdown_offscreen(&postfx_targets[0])
		shutdown_offscreen(&postfx_targets[1])
		postfx_inited = false
	}
}

draw_postfx :: proc(offscreen: ^Offscreen) {
	if !postfx_inited || len(effects) == 0 {
		draw_fullscreen_quad(offscreen.color_tex_view)
		return
	}

	current_src := offscreen
	ping: int = 0
	pong: int = 1

	for effect, i in effects {
		if !effect.enabled do continue

		shader, ok := custom_shaders[effect.id]
		if !ok do continue

		is_last := i == len(effects) - 1

		if is_last {
			sg.apply_pipeline(shader.pipeline)
			sg.apply_bindings(
				{
					vertex_buffers = {0 = postfx_vb},
					index_buffer = postfx_ib,
					views = get_views_data(current_src.color_tex_view),
					samplers = get_samplers_data(false),
				},
			)
			sg.draw(0, 6, 1)
		} else {
			pass_action := sg.Pass_Action{}
			pass_action.colors[0] = {
				load_action = .DONTCARE,
			}

			sg.begin_pass(
				{
					action = pass_action,
					attachments = {
						colors = {0 = postfx_targets[pong].color_att_view},
						depth_stencil = postfx_targets[pong].depth_att_view,
					},
				},
			)
			sg.apply_pipeline(shader.pipeline)
			sg.apply_bindings(
				{
					vertex_buffers = {0 = postfx_vb},
					index_buffer = postfx_ib,
					views = get_views_data(current_src.color_tex_view),
					samplers = get_samplers_data(false),
				},
			)
			sg.draw(0, 6, 1)
			sg.end_pass()

			current_src = &postfx_targets[pong]
			ping, pong = pong, ping
		}
	}
}

draw_fullscreen_quad :: proc(tex_view: sg.View) {
	sg.apply_pipeline(postfx_passthrough_pipeline)
	sg.apply_bindings(
		{
			vertex_buffers = {0 = postfx_vb},
			index_buffer = postfx_ib,
			views = get_views_data(tex_view),
			samplers = get_samplers_data(false),
		},
	)
	sg.draw(0, 6, 1)
}

add_post_processing :: proc(shader_id: u64) {
	append(&effects, Postfx_Effect{enabled = true, id = shader_id})
}
