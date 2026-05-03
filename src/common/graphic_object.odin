package common

TextAlign :: enum {
	Left,
	Center,
	Right,
}

AtlasProps :: struct {
	width:   f32,
	height:  f32,
	spacing: f32,
	margin:  f32,
	x:       f32,
	y:       f32,
}

ShaderArgumentValue :: union {
	f32,
	[2]f32,
	[3]f32,
	[4]f32,
	string,
}

ShaderArgs :: map[string]ShaderArgumentValue

ObjectProp :: struct {
	position:    [2]f32,
	size:        [2]f32,
	color:       [4]f32,
	scale:       [2]f32,
	origin:      [2]f32,
	rotation:    f32,
	opacity:     Maybe(f32),
	atlas:       AtlasProps,
	shader_args: ShaderArgs,
}

GroupObjectProps :: struct {
	z_index: i32,
	texture: string,
	shader:  u32,
	fixed:   bool,
	tiled:   bool,
	quads:   ^[dynamic]ObjectProp,
}

TextObjectProps :: struct {
	text:        string,
	zIndex:      i32,
	position:    [2]f32,
	font:        string,
	shader:      u32,
	size:        f32,
	color:       [4]f32,
	scale:       [2]f32,
	origin:      [2]f32,
	fixed:       bool,
	rotation:    f32,
	opacity:     Maybe(f32),
	align:       TextAlign,
	max_width:   f32,
	shader_args: ShaderArgs,
}

GraphicObjectProps :: union {
	TextObjectProps,
	GroupObjectProps,
}
