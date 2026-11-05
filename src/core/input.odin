package core

import "core:strings"
import sapp "shared:sokol/app"

InputState :: struct {
	keys_down:     [512]bool,
	keys_pressed:  [512]bool,
	keys_released: [512]bool,
	mods:          u32,
	mouse_pos:     [2]f32,
	mouse_delta:   [2]f32,
	scroll:        [2]f32,
	btn_down:      [3]bool,
	btn_pressed:   [3]bool,
	btn_released:  [3]bool,
	last_char:     u32,
}

input_state := InputState{}

mouse_btn_index :: proc(b: sapp.Mousebutton) -> int {
	when int(sapp.Mousebutton.LEFT) == 0 {
		return int(b)
	}
	if b == .LEFT do return 0
	if b == .RIGHT do return 1
	if b == .MIDDLE do return 2
	return 0
}

clear_input :: proc() {
	input_state.mouse_delta = [2]f32{0, 0}
	input_state.scroll = [2]f32{0, 0}
	input_state.last_char = 0
	for i in 0 ..< len(input_state.keys_pressed) do input_state.keys_pressed[i] = false
	for i in 0 ..< len(input_state.keys_released) do input_state.keys_released[i] = false
	for i in 0 ..< len(input_state.btn_pressed) do input_state.btn_pressed[i] = false
	for i in 0 ..< len(input_state.btn_released) do input_state.btn_released[i] = false
}

handle_input_event :: proc(event: ^sapp.Event) {
	input_state.mods = event.modifiers

	#partial switch event.type {
	case .MOUSE_MOVE:
		new_pos := [2]f32{event.mouse_x, event.mouse_y}
		input_state.mouse_delta = [2]f32 {
			new_pos[0] - input_state.mouse_pos[0],
			new_pos[1] - input_state.mouse_pos[1],
		}
		input_state.mouse_pos = new_pos

	case .MOUSE_DOWN:
		idx := mouse_btn_index(event.mouse_button)
		if 0 <= idx && idx < 3 {
			if !input_state.btn_down[idx] {
				input_state.btn_pressed[idx] = true
			}
			input_state.btn_down[idx] = true
		}

	case .MOUSE_UP:
		idx := mouse_btn_index(event.mouse_button)
		if 0 <= idx && idx < 3 {
			input_state.btn_down[idx] = false
			input_state.btn_released[idx] = true
		}

	case .MOUSE_SCROLL:
		input_state.scroll = [2]f32{event.scroll_x, event.scroll_y}

	case .KEY_DOWN:
		code := int(event.key_code)
		if 0 <= code && code < len(input_state.keys_down) {
			if !input_state.keys_down[code] {
				input_state.keys_pressed[code] = true
			}
			input_state.keys_down[code] = true
		}
		#partial switch event.key_code {
		case .BACKSPACE:
			input_state.last_char = 8
		case .SPACE:
			input_state.last_char = 32
		case .ENTER:
			input_state.last_char = 13
		case .TAB:
			input_state.last_char = 9
		case .ESCAPE:
			input_state.last_char = 27
		case .UP:
			input_state.last_char = 0xF700
		case .DOWN:
			input_state.last_char = 0xF701
		case .LEFT:
			input_state.last_char = 0xF702
		case .RIGHT:
			input_state.last_char = 0xF703
		case .DELETE:
			input_state.last_char = 127
		}

	case .KEY_UP:
		code := int(event.key_code)
		if 0 <= code && code < len(input_state.keys_down) {
			input_state.keys_down[code] = false
			input_state.keys_released[code] = true
		}

	case .CHAR:
		if event.char_code != 127 {
			input_state.last_char = event.char_code
		}
	}
}


mouse_position :: proc() -> (f32, f32) {
	mx := input_state.mouse_pos[0]
	my := input_state.mouse_pos[1]

	if windowConfig.keep_aspect > 0 {
		screen_width := sapp.width()
		screen_height := sapp.height()
		offset_x, offset_y, viewport_width, viewport_height: i32

		if windowConfig.keep_aspect == 2 {
			offset_x, offset_y, viewport_width, viewport_height = get_game_screen_crop(
				screen_width,
				screen_height,
			)
		} else {
			offset_x, offset_y, viewport_width, viewport_height = get_game_screen(
				screen_width,
				screen_height,
			)
		}

		game_x := (mx - f32(offset_x)) * (f32(windowConfig.width) / f32(viewport_width))
		game_y := (my - f32(offset_y)) * (f32(windowConfig.height) / f32(viewport_height))

		return game_x, game_y
	}

	scale := sapp.dpi_scale()
	return mx / scale, my / scale
}

Key_Name :: struct {
	name: string,
	code: sapp.Keycode,
}

Mouse_Name :: struct {
	name: string,
	button: sapp.Mousebutton,
}

KEY_NAMES := [?]Key_Name {
	{"a", .A},
	{"b", .B},
	{"c", .C},
	{"d", .D},
	{"e", .E},
	{"f", .F},
	{"g", .G},
	{"h", .H},
	{"i", .I},
	{"j", .J},
	{"k", .K},
	{"l", .L},
	{"m", .M},
	{"n", .N},
	{"o", .O},
	{"p", .P},
	{"q", .Q},
	{"r", .R},
	{"s", .S},
	{"t", .T},
	{"u", .U},
	{"v", .V},
	{"w", .W},
	{"x", .X},
	{"y", .Y},
	{"z", .Z},
	{"space", .SPACE},
	{" ", .SPACE},
	{"escape", .ESCAPE},
	{"esc", .ESCAPE},
	{"enter", .ENTER},
	{"return", .ENTER},
	{"shift", .LEFT_SHIFT},
	{"ctrl", .LEFT_CONTROL},
	{"control", .LEFT_CONTROL},
	{"alt", .LEFT_ALT},
	{"apostrophe", .APOSTROPHE},
	{"tab", .TAB},
	{"up", .UP},
	{"down", .DOWN},
	{"left", .LEFT},
	{"right", .RIGHT},
}

MOUSE_NAMES := [?]Mouse_Name {
	{"mouse_left", .LEFT},
	{"mouse_right", .RIGHT},
	{"mouse_middle", .MIDDLE},
}
