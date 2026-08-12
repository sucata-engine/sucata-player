package core

import "../graphics"

PostLoadShader :: struct {
	shader_path: string,
}

PostPreloadTexture :: struct {
	texture_path: string,
}

PostCommand :: union {
	PostLoadShader,
	PostPreloadTexture,
}

post_commands := [dynamic]PostCommand{}

add_post_command :: proc(data: PostCommand) {
	if is_game_started {
		process_post_command(data)
		return
	}
	append(&post_commands, data)
}

process_post_commands :: proc() {
	for command in post_commands {
		process_post_command(command)
	}
	clear(&post_commands)
}

process_post_command :: proc(data: PostCommand) {
	switch v in data {
	case PostLoadShader:
		graphics.init_shader(v.shader_path)
		delete(v.shader_path)
	case PostPreloadTexture:
		graphics.preload_image(v.texture_path)
		delete(v.texture_path)
	}
}
