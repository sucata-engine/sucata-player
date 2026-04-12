package core

import common "../common"
import "../filesystem"
import "core:strings"
import sapp "shared:sokol/app"
import stbi "vendor:stb/image"

default_icon_png := #load("../../assets/sucata.png")

load_default_icon :: proc() -> sapp.Icon_Desc {
	width: i32
	height: i32
	channels: i32

	pixels := stbi.load_from_memory(
		&default_icon_png[0],
		i32(len(default_icon_png)),
		&width,
		&height,
		&channels,
		4,
	)

	icon := sapp.Icon_Desc{}

	pixel_count := width * height * 4
	icon.images[0] = {
		width = width,
		height = height,
		pixels = {ptr = pixels, size = uint(pixel_count)},
	}

	return icon
}

load_window_icon :: proc(icon_path: string) -> sapp.Icon_Desc {
	icon_desc := sapp.Icon_Desc{}

	if icon_path == "" {
		return load_default_icon()
	}

	w, h: i32
	pixels: [^]u8

	if asset_data, ok := filesystem.get_asset(icon_path); ok && len(asset_data) > 0 {
		pixels = stbi.load_from_memory(raw_data(asset_data), i32(len(asset_data)), &w, &h, nil, 4)
	}

	if pixels == nil {
		common.print_warning("Failed to load the icon: %s, using default", icon_path)
		icon_desc.sokol_default = true
		return icon_desc
	}

	pixel_count := w * h * 4
	icon_desc.images[0] = sapp.Image_Desc {
		width = w,
		height = h,
		pixels = {ptr = pixels, size = uint(pixel_count)},
	}

	return icon_desc
}

free_icon_desc :: proc(icon_desc: ^sapp.Icon_Desc) {
	if icon_desc.sokol_default {
		return
	}

	for i := 0; i < 8; i += 1 {
		if icon_desc.images[i].pixels.ptr != nil {
			stbi.image_free(icon_desc.images[i].pixels.ptr)
		}
	}
}

set_window_icon :: proc(icon_path: string) {
	if windowConfig.icon != "" {
		delete(windowConfig.icon)
	}
	windowConfig.icon = strings.clone(icon_path)

	if !sapp.isvalid() {
		return
	}

	icon_desc := sapp.Icon_Desc{}

	if icon_path == "" {
		sapp.set_icon(icon_desc)
		return
	}

	w, h: i32
	pixels: [^]u8

	if asset_data, ok := filesystem.get_asset(icon_path); ok && len(asset_data) > 0 {
		pixels = stbi.load_from_memory(raw_data(asset_data), i32(len(asset_data)), &w, &h, nil, 4)
	}

	if pixels == nil {
		common.print_warning("Failed to load the icon: %s, using default", icon_path)
		return
	}

	pixel_count := w * h * 4
	icon_desc.images[0] = sapp.Image_Desc {
		width = w,
		height = h,
		pixels = {ptr = pixels, size = uint(pixel_count)},
	}

	sapp.set_icon(icon_desc)

	stbi.image_free(pixels)
}
