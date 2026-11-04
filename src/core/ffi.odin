package core

import "../common"
import "../graphics"
import "core:strings"
import "vendor:sdl3"

Ffi_Time :: struct {
	delta:      f64,
	raw_delta:  f64,
	time_scale: f64,
	fps:        f64,
}

Ffi_Screen :: struct {
	width:  f64,
	height: f64,
}

Ffi_Quad :: struct {
	tex:        u32,
	z:          i32,
	x, y, w, h: f32,
	rotation:   f32,
	scale_x:    f32,
	scale_y:    f32,
	origin_x:   f32,
	origin_y:   f32,
	fixed:      i32,
	tiled:      i32,
	shader:     u32,
	tile_w:     f32,
	tile_h:     f32,
}

Sprite :: struct {
	image: u32,
	color: [4]f32,
	atlas: common.AtlasProps,
}

Ffi_Text :: struct {
	font:      u32,
	z:         i32,
	x, y:      f32,
	size:      f32,
	rotation:  f32,
	scale_x:   f32,
	scale_y:   f32,
	origin_x:  f32,
	origin_y:  f32,
	color:     [4]f32,
	opacity:   f32,
	fixed:     i32,
	align:     i32,
	max_width: f32,
	shader:    u32,
}

FFI_GAMEPAD_BUTTONS :: 32
FFI_GAMEPAD_AXES :: 8

Ffi_Gamepad :: struct {
	connected: i32,
	held:      [FFI_GAMEPAD_BUTTONS]bool,
	pressed:   [FFI_GAMEPAD_BUTTONS]bool,
	released:  [FFI_GAMEPAD_BUTTONS]bool,
	axes:      [FFI_GAMEPAD_AXES]f32,
}

Ffi_Mouse :: struct {
	x, y: f32,
}

Ffi_Is_Hover :: #type proc "c" (id: [^]u8, len: uint, x, y, w, h: f32, z: i32, fixed: i32) -> i32

Ffi_Rect :: #type proc "c" (tex: u32, x, y, w, h: f32, z: i32)
Ffi_Rect_Ex :: #type proc "c" (quad: ^Ffi_Quad)
Ffi_Draw_Text :: #type proc "c" (str: [^]u8, len: uint, x, y, size: f32, z: i32)
Ffi_Draw_Text_Ex :: #type proc "c" (str: [^]u8, len: uint, text: ^Ffi_Text)

Ffi_Api :: struct {
	time:      ^Ffi_Time,
	input:     ^InputState,
	screen:    ^Ffi_Screen,
	rect:    Ffi_Rect,
	rect_ex: Ffi_Rect_Ex,
	text:    Ffi_Draw_Text,
	text_ex: Ffi_Draw_Text_Ex,
	mouse:    ^Ffi_Mouse,
	camera:   ^graphics.Camera,
	gamepads: ^[MAX_GAMEPADS]Ffi_Gamepad,
	is_hover: Ffi_Is_Hover,
}

FFI_INPUT_KEYS :: len(InputState{}.keys_down)

ffi_time := Ffi_Time {
	delta      = 0.016,
	raw_delta  = 0.016,
	time_scale = 1.0,
}
ffi_screen := Ffi_Screen{}
ffi_api := Ffi_Api{}
ffi_mouse := Ffi_Mouse{}
ffi_gamepads: [MAX_GAMEPADS]Ffi_Gamepad

textures: [dynamic]string = {}
texture_handles: map[string]u32 = {}
sprites: [dynamic]Sprite = {}
sprite_handles: map[Sprite]u32 = {}

NO_SPRITE :: Sprite {
	color = {1, 1, 1, 1},
}

get_ffi_api :: proc() -> ^Ffi_Api {
	ffi_api = Ffi_Api {
		time      = &ffi_time,
		input     = &input_state,
		screen    = &ffi_screen,
		rect      = ffi_rect,
		rect_ex   = ffi_rect_ex,
		text      = ffi_text,
		text_ex   = ffi_text_ex,
		mouse     = &ffi_mouse,
		camera    = &graphics.camera,
		gamepads  = &ffi_gamepads,
		is_hover  = ffi_is_hover,
	}
	return &ffi_api
}

sync_ffi_frame :: proc() {
	ffi_time.raw_delta = delta_time
	ffi_time.delta = delta_time * ffi_time.time_scale
	ffi_time.fps = f64(fps)
	ffi_screen.width = f64(graphics.game_width)
	ffi_screen.height = f64(graphics.game_height)
}

sync_ffi_input :: proc() {
	ffi_mouse.x, ffi_mouse.y = mouse_position()
	for i in 0 ..< MAX_GAMEPADS {
		state := &gamepads[i]
		pad := &ffi_gamepads[i]
		pad.connected = state.connected ? 1 : 0
		for button in sdl3.GamepadButton {
			index := int(button)
			if index < 0 || index >= FFI_GAMEPAD_BUTTONS {
				continue
			}
			pad.held[index] = state.buttons[button]
			pad.pressed[index] = state.buttons_down[button]
			pad.released[index] = state.buttons_up[button]
		}
		for axis in sdl3.GamepadAxis {
			index := int(axis)
			if index < 0 || index >= FFI_GAMEPAD_AXES {
				continue
			}
			pad.axes[index] = state.axes[axis]
		}
	}
}

ffi_is_hover :: proc "c" (id: [^]u8, len: uint, x, y, w, h: f32, z: i32, fixed: i32) -> i32 {
	context = DEFAULT_CONTEXT
	return add_hoverable(string(id[:len]), x, y, w, h, z, fixed != 0) ? 1 : 0
}

register_texture :: proc(path: string) -> u32 {
	if handle, ok := texture_handles[path]; ok {
		return handle
	}
	owned := strings.clone(path)
	append(&textures, owned)
	handle := u32(len(textures))
	texture_handles[owned] = handle
	return handle
}

register_sprite :: proc(sprite: Sprite) -> u32 {
	if handle, ok := sprite_handles[sprite]; ok {
		return handle
	}
	append(&sprites, sprite)
	handle := u32(len(sprites))
	sprite_handles[sprite] = handle
	return handle
}

get_sprite :: #force_inline proc(handle: u32) -> Sprite {
	if handle == 0 || int(handle) > len(sprites) {
		return NO_SPRITE
	}
	return sprites[handle - 1]
}

texture_path :: #force_inline proc(handle: u32) -> string {
	if handle == 0 || int(handle) > len(textures) {
		return ""
	}
	return textures[handle - 1]
}

cleanup_textures :: proc() {
	for path in textures {
		delete(path)
	}
	delete(textures)
	textures = {}
	delete(texture_handles)
	texture_handles = {}
	delete(sprites)
	sprites = {}
	delete(sprite_handles)
	sprite_handles = {}
}

ffi_opacity :: #force_inline proc "contextless" (value: f32) -> Maybe(f32) {
	if value < 0 {
		return nil
	}
	return value
}

ffi_rect :: proc "c" (tex: u32, x, y, w, h: f32, z: i32) {
	context = DEFAULT_CONTEXT
	sprite := get_sprite(tex)
	add_quad_to_render_queue(
		z,
		sprite.image,
		0,
		false,
		false,
		common.QuadProp {
			position = {x, y},
			size = {w, h},
			color = sprite.color,
			scale = {1, 1},
			atlas = sprite.atlas,
		},
	)
}

ffi_rect_ex :: proc "c" (q: ^Ffi_Quad) {
	context = DEFAULT_CONTEXT
	sprite := get_sprite(q.tex)
	add_quad_to_render_queue(
		q.z,
		sprite.image,
		q.shader,
		q.fixed != 0,
		q.tiled != 0,
		common.QuadProp {
			position = {q.x, q.y},
			size = {q.w, q.h},
			color = sprite.color,
			scale = {q.scale_x, q.scale_y},
			origin = {q.origin_x, q.origin_y},
			rotation = q.rotation,
			atlas = sprite.atlas,
			tile_size = {q.tile_w, q.tile_h},
		},
	)
}

ffi_text :: proc "c" (str: [^]u8, len: uint, x, y, size: f32, z: i32) {
	context = DEFAULT_CONTEXT
	add_to_render_queue(
		common.TextObjectProps {
			text = strings.clone(string(str[:len]), temp_allocator),
			position = {x, y},
			size = size,
			zIndex = z,
			color = {1, 1, 1, 1},
			scale = {1, 1},
		},
	)
}

ffi_text_ex :: proc "c" (str: [^]u8, len: uint, t: ^Ffi_Text) {
	context = DEFAULT_CONTEXT
	align := common.TextAlign.Left
	switch t.align {
	case 1:
		align = .Center
	case 2:
		align = .Right
	}
	add_to_render_queue(
		common.TextObjectProps {
			text = strings.clone(string(str[:len]), temp_allocator),
			font = texture_path(t.font),
			position = {t.x, t.y},
			size = t.size,
			zIndex = t.z,
			shader = t.shader,
			color = t.color,
			scale = {t.scale_x, t.scale_y},
			origin = {t.origin_x, t.origin_y},
			rotation = t.rotation,
			opacity = ffi_opacity(t.opacity),
			fixed = t.fixed != 0,
			align = align,
			max_width = t.max_width,
		},
	)
}
