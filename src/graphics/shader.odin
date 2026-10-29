package graphics

import "../common"
import "../filesystem"
import "core:c"
import "core:fmt"
import "core:hash"
import "core:strings"
import sg "shared:sokol/gfx"

CustomShader :: struct {
	ib:              sg.Buffer,
	shader:          sg.Shader,
	pipeline:        sg.Pipeline,
	attributes:      [16]ShaderAttribute,
	attributes_size: int,
	views:           [32]ShaderView,
	samplers:        [12]ShaderSampler,
}

custom_shaders := map[u32]CustomShader{}

shader_name_to_32 :: #force_inline proc(shader_name: string) -> u32 {
	return hash.fnv32(transmute([]u8)shader_name)
}

get_shader_from_path :: proc(shader_path: string) -> ([]byte, bool, bool) {
	if asset_data, ok := filesystem.get_asset(shader_path); ok && len(asset_data) > 0 {
		return asset_data, true, true
	}

	return {}, false, false
}

get_shader_attributes_to_sokol_format :: proc(
	attributes: [16]ShaderAttribute,
) -> [16]sg.Vertex_Attr_State {
	formats: [16]sg.Vertex_Attr_State
	for attr, i in attributes {
		if attr.size == 0 do break
		formats[i] = sg.Vertex_Attr_State {
			format       = attr.type,
			buffer_index = 0,
			offset       = c.int(attr.offset),
		}
	}
	return formats
}

get_shader_vertex_size :: proc(attributes: [16]ShaderAttribute) -> int {
	size := 0
	for attr in attributes {
		size += attr.size
	}
	return size / 4
}

create_shader_from_schd :: proc(
	schd_data: []byte,
) -> (
	sg.Shader,
	[16]ShaderAttribute,
	[32]ShaderView,
	[12]ShaderSampler,
	bool,
) {
	backend := sg.query_backend()
	desc, attributes, views, samplers, ok := create_shader_desc_from_schd(backend, schd_data)
	if !ok {
		return {}, attributes, views, samplers, false
	}
	return sg.make_shader(desc), attributes, views, samplers, true
}

SHADER_BUILD_DIR :: ".sucata/shaders/"

resolve_shader_path :: proc(shader_path: string) -> string {
	if !strings.has_suffix(shader_path, ".glsl") {
		return strings.clone(shader_path)
	}

	relative := strings.trim_prefix(shader_path, "src://")
	relative = strings.trim_suffix(relative, ".glsl")
	return fmt.aprintf("src://%s%s.schd", SHADER_BUILD_DIR, relative)
}

init_shader :: proc(shader_path: string) -> (u32, bool) {
	shader_id := shader_name_to_32(shader_path)

	if _, exists := custom_shaders[shader_id]; exists {
		return shader_id, true
	}

	schd_path := resolve_shader_path(shader_path)
	defer delete(schd_path)

	schd_data, ok, is_asset := get_shader_from_path(schd_path)
	defer {
		if !is_asset {
			delete(schd_data)
		}
	}
	if !ok {
		common.print_warning(
			"Failed to read built shader %s for %s, run the game with sucata run or sucata build so the shader is compiled",
			schd_path,
			shader_path,
		)
		return 0, false
	}

	shader, attributes, views, samplers, shader_ok := create_shader_from_schd(schd_data)
	if !shader_ok {
		common.print_warning(
			"Shader %s has no program for the %v backend, build it again with sucata run or sucata build",
			shader_path,
			sg.query_backend(),
		)
		return 0, false
	}

	pipeline := sg.make_pipeline(
		{
			shader = shader,
			layout = {
				buffers = {0 = {stride = c.int(get_shader_vertex_size(attributes) * 4)}},
				attrs = get_shader_attributes_to_sokol_format(attributes),
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

	indices := []u16{0, 1, 2, 0, 2, 3}
	ib := sg.make_buffer(
		{usage = {index_buffer = true}, data = sg_range(indices)},
	)

	custom_shaders[shader_id] = CustomShader {
		shader          = shader,
		pipeline        = pipeline,
		ib              = ib,
		attributes      = attributes,
		attributes_size = get_shader_vertex_size(attributes),
		views           = views,
		samplers        = samplers,
	}

	return shader_id, true
}

destroy_shaders :: proc() {
	for key, shader in custom_shaders {
		for attr in shader.attributes {
			if len(attr.name) > 0 {
				delete(attr.name)
			}
		}
		for view in shader.views {
			delete(view.name)
		}
		for sampler in shader.samplers {
			delete(sampler.name)
		}
		sg.destroy_pipeline(shader.pipeline)
		sg.destroy_shader(shader.shader)
		sg.destroy_buffer(shader.ib)
	}
	clear(&custom_shaders)
	delete(custom_shaders)
}
