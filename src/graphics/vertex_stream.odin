package graphics

import "core:c"
import sg "shared:sokol/gfx"

Vertex_Stream :: struct {
	buffer:   sg.Buffer,
	capacity: int,
	data:     [dynamic]f32,
}

Draw_Command :: struct {
	pipeline:      sg.Pipeline,
	mvp:           matrix[4, 4]f32,
	stream:        ^Vertex_Stream,
	vertex_offset: c.int,
	index_buffer:  sg.Buffer,
	views:         [32]sg.View,
	samplers:      [12]sg.Sampler,
	index_count:   int,
}

draw_commands: [dynamic]Draw_Command

make_transient_vertex_buffer :: proc(size: int) -> sg.Buffer {
	return sg.make_buffer(
		{usage = {vertex_buffer = true, write_transient = true}, size = c.size_t(size)},
	)
}

init_vertex_stream :: proc(stream: ^Vertex_Stream, capacity: int) {
	stream.buffer = make_transient_vertex_buffer(capacity)
	stream.capacity = capacity
	stream.data = {}
}

destroy_vertex_stream :: proc(stream: ^Vertex_Stream) {
	sg.destroy_buffer(stream.buffer)
	delete(stream.data)
	stream^ = {}
}

stream_push :: proc(stream: ^Vertex_Stream, vertices: []f32) -> c.int {
	offset := c.int(len(stream.data) * size_of(f32))
	append(&stream.data, ..vertices)
	return offset
}

stream_flush :: proc(stream: ^Vertex_Stream) {
	size := len(stream.data) * size_of(f32)
	if size == 0 {
		return
	}

	if size > stream.capacity {
		new_capacity := max(size, stream.capacity * 2)
		sg.destroy_buffer(stream.buffer)
		stream.buffer = make_transient_vertex_buffer(new_capacity)
		stream.capacity = new_capacity
	}

	sg.write_buffer_transient(
		{
			src = {data = {ptr = raw_data(stream.data), size = c.size_t(size)}},
			dst = {buffer = stream.buffer},
		},
	)
	clear(&stream.data)
}

flush_draw_commands :: proc() {
	if len(draw_commands) == 0 {
		return
	}

	stream_flush(&quad_stream)
	stream_flush(&text_stream)

	for &command in draw_commands {
		sg.apply_pipeline(command.pipeline)
		sg.apply_uniforms(0, {ptr = &command.mvp, size = size_of(command.mvp)})
		sg.apply_bindings(
			{
				vertex_buffers = {0 = command.stream.buffer},
				vertex_buffer_offsets = {0 = command.vertex_offset},
				index_buffer = command.index_buffer,
				views = command.views,
				samplers = command.samplers,
			},
		)
		sg.draw(0, command.index_count, 1)
	}

	clear(&draw_commands)
}

shutdown_draw_commands :: proc() {
	delete(draw_commands)
	draw_commands = {}
}
