package shader_post_processing

import sg "shared:sokol/gfx"

load_post_processing_shader :: proc() -> sg.Shader {
	return sg.make_shader(shader_post_processing_shader_desc(sg.query_backend()))
}
