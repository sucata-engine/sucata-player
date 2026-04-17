package graphics

import "core:encoding/json"
import "core:fmt"
import "core:strings"
import sg "shared:sokol/gfx"

get_shader_attr_type :: proc(type: string, base_type: string) -> sg.Vertex_Format {
	switch type {
	case "float":
		return .FLOAT
	case "int":
		return .INT
	case "vec2":
		return base_type == "Int" ? .INT2 : .FLOAT2
	case "vec3":
		return base_type == "Int" ? .INT3 : .FLOAT3
	case "vec4":
		return base_type == "Int" ? .INT4 : .FLOAT4
	}
	return .INVALID
}

get_shader_attr_type_size :: proc(attr_type: sg.Vertex_Format) -> int {
	#partial switch attr_type {
	case .FLOAT, .INT:
		return 4
	case .FLOAT2, .INT2:
		return 8
	case .FLOAT3, .INT3:
		return 12
	case .FLOAT4, .INT4:
		return 16
	}
	return 0
}

get_shader_base_attr_type :: proc(attr_type: string) -> sg.Shader_Attr_Base_Type {
	return attr_type == "Int" ? .SINT : .FLOAT
}

get_shader_stage :: proc(stage: string) -> sg.Shader_Stage {
	switch stage {
	case "compute":
		return .COMPUTE
	case "vertex":
		return .VERTEX
	case "fragment":
		return .FRAGMENT
	}
	return .NONE
}

get_uniform_type :: proc(uniform_type: string) -> sg.Uniform_Type {
	switch uniform_type {
	case "float":
		return .FLOAT
	case "int":
		return .INT
	case "mat4":
		return .MAT4
	case "vec2":
		return .FLOAT2
	case "vec3":
		return .FLOAT3
	case "vec4":
		return .FLOAT4
	}
	return .INVALID
}

get_image_type :: proc(image_type: string) -> sg.Image_Type {
	switch image_type {
	case "2d":
		return ._2D
	case "3d":
		return ._3D
	case "cube":
		return .CUBE
	case "array":
		return .ARRAY
	}
	return .DEFAULT
}

get_image_sample_type :: proc(sample_type: string) -> sg.Image_Sample_Type {
	switch sample_type {
	case "float":
		return .FLOAT
	case "sint":
		return .SINT
	case "uint":
		return .UINT
	case "depth":
		return .DEPTH
	}
	return .DEFAULT
}

get_sampler_type :: proc(sampler_type: string) -> sg.Sampler_Type {
	switch sampler_type {
	case "filtering":
		return .FILTERING
	case "comparison":
		return .COMPARISON
	case "nonfiltering":
		return .NONFILTERING
	}
	return .DEFAULT
}

json_num :: #force_inline proc(v: json.Value) -> f64 {
	if v == nil do return 0
	#partial switch n in v {
	case json.Integer:
		return f64(n)
	case json.Float:
		return n
	case json.Boolean:
		return n ? 1 : 0
	}
	return 0
}

json_str :: #force_inline proc(v: json.Value) -> string {
	s, _ := v.(json.String)
	return s
}

json_bool :: #force_inline proc(v: json.Value) -> bool {
	b, _ := v.(json.Boolean)
	return b
}

json_array_to_cstring :: proc(arr: json.Array) -> string {
	bytes := make([]u8, len(arr))
	defer delete(bytes)
	for v, i in arr {
		bytes[i] = u8(v.(json.Float))
	}
	return strings.clone_from_bytes(bytes)
}

find_program_in_schd :: proc(schd_data: json.Value, slang: string) -> json.Object {
	shaders, ok := schd_data.(json.Object)["shaders"].(json.Array)
	if !ok do return nil
	for shader in shaders {
		obj := shader.(json.Object)
		if json_str(obj["slang"]) == slang {
			return obj["programs"].(json.Array)[0].(json.Object)
		}
	}
	return nil
}

create_shader_attributes :: proc(json_data: json.Value) -> [16]ShaderAttribute {
	program := find_program_in_schd(json_data, "glsl430")
	attributes: [16]ShaderAttribute
	offset, i := 0, 0

	attrs_val, ok := program["attrs"].(json.Array)
	if !ok do return attributes

	for attr in attrs_val {
		obj := attr.(json.Object)
		name := strings.clone(json_str(obj["glsl_name"]))
		type_str := json_str(obj["type"])
		base_type := json_str(obj["base_type"])
		slot := json_num(obj["slot"])

		fmt_type := get_shader_attr_type(type_str, base_type)
		size := get_shader_attr_type_size(fmt_type)

		attributes[i] = ShaderAttribute {
			name   = name,
			type   = fmt_type,
			slot   = int(slot),
			size   = size,
			offset = offset,
		}
		i += 1
		offset += size
	}
	return attributes
}

create_shader_views :: proc(json_data: json.Value) -> [32]ShaderView {
	views: [32]ShaderView

	program := find_program_in_schd(json_data, "glsl430")

	views_val, ok := program["views"].(json.Array)
	if !ok do return views

	for view, i in views_val {
		obj := view.(json.Object)
		texture := obj["texture"].(json.Object)
		view_name := strings.clone(json_str(texture["name"]))
		views[i] = ShaderView {
			name = view_name,
		}
	}

	return views
}

create_shader_sampler :: proc(json_data: json.Value) -> [12]ShaderSampler {
	samplers: [12]ShaderSampler

	program := find_program_in_schd(json_data, "glsl430")

	samplers_val, ok := program["samplers"].(json.Array)
	if !ok do return samplers

	for sampler, i in samplers_val {
		obj := sampler.(json.Object)
		sampler_name := strings.clone(json_str(obj["name"]))
		samplers[i] = ShaderSampler {
			name = sampler_name,
		}
	}

	return samplers
}

fill_shader_funcs :: proc(desc: ^sg.Shader_Desc, program: json.Object) {
	vs_src := json_array_to_cstring(program["vertex_func"].(json.Object)["data"].(json.Array))
	fs_src := json_array_to_cstring(program["fragment_func"].(json.Object)["data"].(json.Array))
	defer delete(vs_src)
	defer delete(fs_src)

	desc.label = strings.clone_to_cstring(
		json_str(program["name"]),
		allocator = context.temp_allocator,
	)
	desc.vertex_func.source = strings.clone_to_cstring(vs_src, allocator = context.temp_allocator)
	desc.vertex_func.entry = strings.clone_to_cstring(
		json_str(program["vertex_func"].(json.Object)["entry_point"]),
		allocator = context.temp_allocator,
	)
	desc.fragment_func.source = strings.clone_to_cstring(
		fs_src,
		allocator = context.temp_allocator,
	)
	desc.fragment_func.entry = strings.clone_to_cstring(
		json_str(program["fragment_func"].(json.Object)["entry_point"]),
		allocator = context.temp_allocator,
	)
}

fill_uniform_blocks :: proc(desc: ^sg.Shader_Desc, program: json.Object, fill_glsl: bool = false) {
	blocks, ok := program["uniform_blocks"].(json.Array)
	if !ok do return

	for block, i in blocks {
		obj := block.(json.Object)
		desc.uniform_blocks[i].stage = get_shader_stage(json_str(obj["stage"]))
		desc.uniform_blocks[i].layout = .STD140
		desc.uniform_blocks[i].size = u32(json_num(obj["size"]))

		if fill_glsl {
			if glsl_uniforms, ok2 := obj["glsl_uniforms"].(json.Array); ok2 {
				for u, j in glsl_uniforms {
					uo := u.(json.Object)
					desc.uniform_blocks[i].glsl_uniforms[j].type = get_uniform_type(
						json_str(uo["type"]),
					)
					desc.uniform_blocks[i].glsl_uniforms[j].array_count = u16(
						json_num(uo["array_count"]),
					)
					if name := uo["glsl_name"]; name != nil {
						desc.uniform_blocks[i].glsl_uniforms[j].glsl_name =
							strings.clone_to_cstring(
								json_str(name),
								allocator = context.temp_allocator,
							)
					}
				}
			}
		}

		if v, ok := obj["hlsl_register_b_n"];
		   ok {desc.uniform_blocks[i].hlsl_register_b_n = u8(json_num(v))}
		if v, ok := obj["msl_buffer_n"]; ok {desc.uniform_blocks[i].msl_buffer_n = u8(json_num(v))}
		if v, ok := obj["wgsl_group0_binding_n"];
		   ok {desc.uniform_blocks[i].wgsl_group0_binding_n = u8(json_num(v))}
	}
}

fill_views :: proc(desc: ^sg.Shader_Desc, program: json.Object) {
	views, ok := program["views"].(json.Array)
	if !ok do return

	for view, i in views {
		obj := view.(json.Object)["texture"].(json.Object)
		desc.views[i].texture.stage = get_shader_stage(json_str(obj["stage"]))
		desc.views[i].texture.image_type = get_image_type(json_str(obj["type"]))
		desc.views[i].texture.sample_type = get_image_sample_type(json_str(obj["sample_type"]))
		desc.views[i].texture.multisampled = json_bool(obj["multisampled"])

		if v, ok := obj["hlsl_register_t_n"];
		   ok {desc.views[i].texture.hlsl_register_t_n = u8(json_num(v))}
		if v, ok := obj["msl_texture_n"];
		   ok {desc.views[i].texture.msl_texture_n = u8(json_num(v))}
		if v, ok := obj["wgsl_group1_binding_n"];
		   ok {desc.views[i].texture.wgsl_group1_binding_n = u8(json_num(v))}
		if v, ok := obj["spirv_set1_binding_n"];
		   ok {desc.views[i].texture.spirv_set1_binding_n = u8(json_num(v))}
	}
}

fill_samplers :: proc(desc: ^sg.Shader_Desc, program: json.Object) {
	samplers, ok := program["samplers"].(json.Array)
	if !ok do return

	for smp, i in samplers {
		obj := smp.(json.Object)
		desc.samplers[i].stage = get_shader_stage(json_str(obj["stage"]))
		desc.samplers[i].sampler_type = get_sampler_type(json_str(obj["sampler_type"]))

		if v, ok := obj["hlsl_register_s_n"];
		   ok {desc.samplers[i].hlsl_register_s_n = u8(json_num(v))}
		if v, ok := obj["msl_sampler_n"]; ok {desc.samplers[i].msl_sampler_n = u8(json_num(v))}
		if v, ok := obj["wgsl_group1_binding_n"];
		   ok {desc.samplers[i].wgsl_group1_binding_n = u8(json_num(v))}
		if v, ok := obj["spirv_set1_binding_n"];
		   ok {desc.samplers[i].spirv_set1_binding_n = u8(json_num(v))}
	}
}

fill_texture_sampler_pairs :: proc(
	desc: ^sg.Shader_Desc,
	program: json.Object,
	use_glsl_name: bool = false,
) {
	pairs, ok := program["texture_sampler_pairs"].(json.Array)
	if !ok do return

	for pair, i in pairs {
		obj := pair.(json.Object)
		desc.texture_sampler_pairs[i].stage = get_shader_stage(json_str(obj["stage"]))
		desc.texture_sampler_pairs[i].view_slot = u8(json_num(obj["view_slot"]))
		desc.texture_sampler_pairs[i].sampler_slot = u8(json_num(obj["sampler_slot"]))

		if use_glsl_name {
			desc.texture_sampler_pairs[i].glsl_name = strings.clone_to_cstring(
				fmt.tprintf("%s_%s", json_str(obj["view_name"]), json_str(obj["sampler_name"])),
				allocator = context.temp_allocator,
			)
		}
	}
}

create_shader_desc_from_schd :: proc(
	backend: sg.Backend,
	schd_data: []byte,
) -> (
	sg.Shader_Desc,
	[16]ShaderAttribute,
	[32]ShaderView,
	[12]ShaderSampler,
) {
	json_data, json_ok := json.parse(schd_data)
	if json_ok != .None do panic("shader .schd JSON invalid")
	defer json.destroy_value(json_data)

	slang_name := ""
	#partial switch backend {
	case .GLCORE:
		slang_name = "glsl430"
	case .D3D11:
		slang_name = "hlsl5"
	case .METAL_MACOS:
		slang_name = "metal_macos"
	case .WGPU:
		slang_name = "wgsl"
	}
	program := find_program_in_schd(json_data, slang_name)
	attributes := create_shader_attributes(json_data)
	views := create_shader_views(json_data)
	samplers := create_shader_sampler(json_data)

	desc: sg.Shader_Desc
	fill_shader_funcs(&desc, program)
	fill_uniform_blocks(&desc, program, fill_glsl = backend == .GLCORE)
	fill_views(&desc, program)
	fill_samplers(&desc, program)
	fill_texture_sampler_pairs(&desc, program, use_glsl_name = backend == .GLCORE)

	if attrs_val, ok := program["attrs"].(json.Array); ok {
		for attr, i in attrs_val {
			obj := attr.(json.Object)
			desc.attrs[i].base_type = get_shader_base_attr_type(json_str(obj["type"]))
			#partial switch backend {
			case .GLCORE:
				desc.attrs[i].glsl_name = strings.clone_to_cstring(
					json_str(obj["glsl_name"]),
					allocator = context.temp_allocator,
				)
			case .D3D11:
				desc.attrs[i].hlsl_sem_name = strings.clone_to_cstring(
					json_str(obj["hlsl_sem_name"]),
					allocator = context.temp_allocator,
				)
				desc.attrs[i].hlsl_sem_index = u8(json_num(obj["hlsl_sem_index"]))
			}
		}
	}

	if backend == .D3D11 {
		desc.vertex_func.d3d11_target = strings.clone_to_cstring(
			json_str(program["vertex_func"].(json.Object)["d3d11_target"]),
			allocator = context.temp_allocator,
		)
		desc.fragment_func.d3d11_target = strings.clone_to_cstring(
			json_str(program["fragment_func"].(json.Object)["d3d11_target"]),
			allocator = context.temp_allocator,
		)
	}

	return desc, attributes, views, samplers
}
