package core

import "../graphics"
import "core:hash"
import "core:math"

Hoverable :: struct {
	id:      u64,
	x:       f32,
	y:       f32,
	width:   f32,
	height:  f32,
	z_index: i32,
	fixed:   bool,
}

hoverables: [dynamic]Hoverable
hover: u64 = 0

hover_id :: #force_inline proc(id: string) -> u64 {
	value := hash.fnv64a(transmute([]u8)id)
	return value == 0 ? 1 : value
}

add_hoverable :: proc(id: string, x, y, width, height: f32, z_index: i32, fixed: bool) -> bool {
	key := hover_id(id)
	append(
		&hoverables,
		Hoverable{id = key, x = x, y = y, width = width, height = height, z_index = z_index, fixed = fixed},
	)
	return key == hover
}

process_hoverables :: proc() {
	if len(hoverables) <= 0 {
		hover = 0
		return
	}

	mouse_x, mouse_y := mouse_position()

	if graphics.camera.rotation != 0 {
		cos_r := math.cos(-graphics.camera.rotation)
		sin_r := math.sin(-graphics.camera.rotation)
		rotated_x := mouse_x * cos_r - mouse_y * sin_r
		rotated_y := mouse_x * sin_r + mouse_y * cos_r
		mouse_x = rotated_x
		mouse_y = rotated_y
	}

	world_mouse_x := (mouse_x + graphics.camera.position.x) / graphics.camera.zoom
	world_mouse_y := (mouse_y + graphics.camera.position.y) / graphics.camera.zoom

	best: u64 = 0
	best_z: i32 = min(i32)
	for h in hoverables {
		px := h.fixed ? mouse_x : world_mouse_x
		py := h.fixed ? mouse_y : world_mouse_y
		if px >= h.x && px <= h.x + h.width && py >= h.y && py <= h.y + h.height {
			if best == 0 || h.z_index > best_z {
				best = h.id
				best_z = h.z_index
			}
		}
	}
	hover = best

	clear(&hoverables)
}

clear_hoverables :: proc() {
	clear(&hoverables)
}
