package core

import "../common"
import "core:c"
import "core:strings"
import "vendor:sdl3"

GamepadState :: struct {
	gamepad:      ^sdl3.Gamepad,
	id:           sdl3.JoystickID,
	name:         string,
	buttons:      [sdl3.GamepadButton]bool,
	buttons_down: [sdl3.GamepadButton]bool,
	buttons_up:   [sdl3.GamepadButton]bool,
	axes:         [sdl3.GamepadAxis]f32,
	connected:    bool,
}

MAX_GAMEPADS :: 8
GAMEPAD_DEADZONE :: 0.15
gamepads: [MAX_GAMEPADS]GamepadState

init_gamepad :: proc() {
	if !sdl3.InitSubSystem({.GAMEPAD}) {
		common.print_error("Failed to initialize SDL3")
		return
	}

	joystick_count: c.int
	joystick_ids := sdl3.GetJoysticks(&joystick_count)
	if joystick_ids == nil {
		common.print_error("Error to get joysticks:", sdl3.GetError())
		return
	}
	defer sdl3.free(joystick_ids)

	for i: i32 = 0; i < joystick_count && i < MAX_GAMEPADS; i += 1 {
		if sdl3.IsGamepad(joystick_ids[i]) {
			add_gamepad(joystick_ids[i])
		}
	}
}

add_gamepad :: proc(joystick_id: sdl3.JoystickID) -> bool {
	slot := -1
	for i in 0 ..< MAX_GAMEPADS {
		if !gamepads[i].connected {
			slot = i
			break
		}
	}

	if slot == -1 {
		return false
	}

	if gamepads[slot].name != "" {
		delete(gamepads[slot].name)
	}

	gamepad := sdl3.OpenGamepad(joystick_id)
	if gamepad == nil {
		common.print_error("Failed to run the gamepad:", sdl3.GetError())
		return false
	}

	gamepads[slot].gamepad = gamepad
	gamepads[slot].id = sdl3.GetGamepadID(gamepad)

	name := sdl3.GetGamepadName(gamepad)
	gamepads[slot].name = strings.clone(name != nil ? string(name) : "Unknown")
	gamepads[slot].connected = true

	for axis in sdl3.GamepadAxis {
		gamepads[slot].axes[axis] = 0.0
	}

	return true
}

remove_gamepad :: proc(id: sdl3.JoystickID) {
	for i in 0 ..< MAX_GAMEPADS {
		if gamepads[i].connected && gamepads[i].id == id {
			if gamepads[i].gamepad != nil {
				sdl3.CloseGamepad(gamepads[i].gamepad)
			}
			if gamepads[i].name != "" {
				delete(gamepads[i].name)
			}
			gamepads[i] = {}
			break
		}
	}
}

clear_gamepad_states :: proc() {
	for i in 0 ..< MAX_GAMEPADS {
		if gamepads[i].connected {
			for btn in sdl3.GamepadButton {
				gamepads[i].buttons_down[btn] = false
				gamepads[i].buttons_up[btn] = false
			}
		}
	}
}

handle_gamepad_event :: proc(event: ^sdl3.Event) {
	#partial switch event.type {
	case .GAMEPAD_ADDED:
		add_gamepad(event.gdevice.which)

	case .GAMEPAD_REMOVED:
		remove_gamepad(event.gdevice.which)

	case .GAMEPAD_BUTTON_DOWN:
		for i in 0 ..< MAX_GAMEPADS {
			if gamepads[i].connected && gamepads[i].id == event.gbutton.which {
				btn := sdl3.GamepadButton(event.gbutton.button)
				if !gamepads[i].buttons[btn] {
					gamepads[i].buttons_down[btn] = true
				}
				gamepads[i].buttons[btn] = true
				break
			}
		}

	case .GAMEPAD_BUTTON_UP:
		for i in 0 ..< MAX_GAMEPADS {
			if gamepads[i].connected && gamepads[i].id == event.gbutton.which {
				btn := sdl3.GamepadButton(event.gbutton.button)
				gamepads[i].buttons[btn] = false
				gamepads[i].buttons_up[btn] = true
				break
			}
		}

	case .GAMEPAD_AXIS_MOTION:
		for i in 0 ..< MAX_GAMEPADS {
			if gamepads[i].connected && gamepads[i].id == event.gaxis.which {
				axis := sdl3.GamepadAxis(event.gaxis.axis)
				value := f32(event.gaxis.value) / 32767.0

				if abs(value) < GAMEPAD_DEADZONE {
					value = 0.0
				}

				gamepads[i].axes[axis] = value
				break
			}
		}
	}
}

poll_gamepad_events :: proc() {
	event: sdl3.Event
	for sdl3.PollEvent(&event) {
		handle_gamepad_event(&event)
	}
}

shutdown_gamepad :: proc() {
	for i in 0 ..< MAX_GAMEPADS {
		if gamepads[i].connected && gamepads[i].gamepad != nil {
			sdl3.CloseGamepad(gamepads[i].gamepad)
		}
		if gamepads[i].name != "" {
			delete(gamepads[i].name)
		}
		gamepads[i] = {}
	}
	sdl3.QuitSubSystem({.GAMEPAD})
}

gamepad_get_name :: proc(slot: int) -> string {
	if slot < 0 || slot >= MAX_GAMEPADS || !gamepads[slot].connected {
		return ""
	}
	return gamepads[slot].name
}

Gamepad_Button_Name :: struct {
	name:   string,
	button: sdl3.GamepadButton,
}

Gamepad_Axis_Name :: struct {
	name: string,
	axis: sdl3.GamepadAxis,
}

GAMEPAD_BUTTON_NAMES := [?]Gamepad_Button_Name {
	{"a", .SOUTH},
	{"b", .EAST},
	{"x", .NORTH},
	{"y", .WEST},
	{"back", .BACK},
	{"guide", .GUIDE},
	{"start", .START},
	{"left_stick", .LEFT_STICK},
	{"right_stick", .RIGHT_STICK},
	{"left_shoulder", .LEFT_SHOULDER},
	{"right_shoulder", .RIGHT_SHOULDER},
	{"dpad_up", .DPAD_UP},
	{"dpad_down", .DPAD_DOWN},
	{"dpad_left", .DPAD_LEFT},
	{"dpad_right", .DPAD_RIGHT},
}

GAMEPAD_AXIS_NAMES := [?]Gamepad_Axis_Name {
	{"left_x", .LEFTX},
	{"left_y", .LEFTY},
	{"right_x", .RIGHTX},
	{"right_y", .RIGHTY},
	{"trigger_left", .LEFT_TRIGGER},
	{"trigger_right", .RIGHT_TRIGGER},
}
