package graphics

game_width: i32 = 800
game_height: i32 = 600

indices: []u16
MAX_QUADS :: 4096

set_game_dimensions :: proc(width, height: i32) {
	game_width = width
	game_height = height
}

calc_indices :: proc() {
	indices = make([]u16, MAX_QUADS * 6)
	for i in 0 ..< MAX_QUADS {
		base_v := u16(i * 4)
		base_i := i * 6

		indices[base_i + 0] = base_v + 0
		indices[base_i + 1] = base_v + 1
		indices[base_i + 2] = base_v + 2
		indices[base_i + 3] = base_v + 0
		indices[base_i + 4] = base_v + 2
		indices[base_i + 5] = base_v + 3
	}
}

init_graphics :: proc() {
	load_default_image()
	calc_indices()
	init_postfx(game_width, game_height)
}

shutdown_graphics :: proc() {
	shutdown_quad_buffers()
	shutdown_text_buffers()
	shutdown_postfx()
	unload_fonts()
	destroy_images()
	destroy_shaders()
	delete(indices)
}
