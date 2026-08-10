package graphics

import "../common"
import "../filesystem"
import "core:fmt"
import "core:os"
import "core:strings"
import sg "shared:sokol/gfx"
import stbt "vendor:stb/truetype"

Font :: struct {
	char_data:     []stbt.bakedchar,
	image:         sg.View,
	bitmap_width:  i32,
	bitmap_height: i32,
	ascent:        f32,
	descent:       f32,
	line_gap:      f32,
}

get_default_system_font :: proc() -> string {
	when ODIN_OS == .Windows {
		return "C:/Windows/Fonts/arial.ttf"
	} else when ODIN_OS == .Darwin {
		macos_fonts := []string {
			"/System/Library/Fonts/Supplemental/Arial.ttf",
			"/System/Library/Fonts/Supplemental/Courier New.ttf",
			"/System/Library/Fonts/Supplemental/Times New Roman.ttf",
			"/Library/Fonts/Arial.ttf",
			"/System/Library/Fonts/Helvetica.ttc",
		}
		for font_path in macos_fonts {
			if os.exists(font_path) {
				return font_path
			}
		}
		return "/System/Library/Fonts/Supplemental/Arial.ttf"
	} else when ODIN_OS == .Linux {
		linux_fonts := []string {
			"/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
			"/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
			"/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
			"/usr/share/fonts/truetype/freefont/FreeSans.ttf",
			"/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
			"/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf",
			"/usr/share/fonts/TTF/DejaVuSans.ttf",
			"/usr/share/fonts/noto/NotoSans-Regular.ttf",
			"/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
			"/usr/share/fonts/dejavu/DejaVuSans.ttf",
			"/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf",
			"/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf",
			"/usr/share/fonts/liberation/LiberationSans-Regular.ttf",
			"/usr/share/fonts/google-noto/NotoSans-Regular.ttf",
			"/usr/share/fonts/truetype/DejaVuSans.ttf",
		}
		for font_path in linux_fonts {
			if os.exists(font_path) {
				return font_path
			}
		}

		search_dirs := []string{"/usr/share/fonts", "/usr/local/share/fonts"}
		for dir in search_dirs {
			if found, ok := find_first_font_in_dir(dir, 4); ok {
				return found
			}
		}
		return ""
	} else {
		return ""
	}
}

@(private)
find_first_font_in_dir :: proc(dir: string, max_depth: int) -> (string, bool) {
	if max_depth < 0 do return "", false
	if !os.is_dir(dir) do return "", false

	handle, open_err := os.open(dir, os.O_RDONLY)
	if open_err != os.ERROR_NONE do return "", false
	defer os.close(handle)

	entries, read_err := os.read_dir(handle, -1, context.allocator)
	if read_err != os.ERROR_NONE do return "", false
	defer os.file_info_slice_delete(entries, context.allocator)

	is_font_file :: proc(name: string) -> bool {
		return(
			strings.has_suffix(name, ".ttf") ||
			strings.has_suffix(name, ".TTF") ||
			strings.has_suffix(name, ".otf") ||
			strings.has_suffix(name, ".OTF") ||
			strings.has_suffix(name, ".ttc") ||
			strings.has_suffix(name, ".TTC") \
		)
	}

	for entry in entries {
		if os.is_dir(entry.fullpath) do continue
		if is_font_file(entry.name) {
			return strings.clone(entry.fullpath), true
		}
	}
	for entry in entries {
		if !os.is_dir(entry.fullpath) do continue
		if found, ok := find_first_font_in_dir(entry.fullpath, max_depth - 1); ok {
			return found, true
		}
	}
	return "", false
}

FontKey :: struct {
	path: string,
	size: f32,
}

loaded_fonts := map[FontKey]^Font{}

load_font :: proc(file_path: string, font_size: f32) -> ^Font {
	font_path := file_path
	from_system := false
	if font_path == "" {
		font_path = get_default_system_font()
		from_system = true
	}

	if font, exists := loaded_fonts[FontKey{path = font_path, size = font_size}]; exists {
		return font
	}

	ttf_data: []byte
	read_ok: bool

	if asset_data, ok := filesystem.get_asset(font_path, from_system); ok && len(asset_data) > 0 {
		ttf_data = make([]byte, len(asset_data))
		copy(ttf_data, asset_data)
		read_ok = true
	}

	if !read_ok {
		if from_system && font_path == "" {
			common.print_error(
				"No system font found. Install a font package (e.g. fonts-dejavu-core, fonts-liberation, fonts-noto) or pass a font file path explicitly.",
			)
		} else {
			common.print_error("Font '%s' not found", font_path)
		}
		return nil
	}
	defer delete(ttf_data)

	font_info: stbt.fontinfo
	if !stbt.InitFont(&font_info, raw_data(ttf_data), 0) {
		return nil
	}

	bitmap_width: i32 = 2048
	bitmap_height: i32 = 2048
	bitmap := make([^]byte, bitmap_width * bitmap_height)

	first_char: i32 = 32
	char_count: i32 = 255 - first_char + 1
	char_data := make([]stbt.bakedchar, char_count)
	result := stbt.BakeFontBitmap(
		raw_data(ttf_data),
		0,
		font_size,
		bitmap,
		bitmap_width,
		bitmap_height,
		first_char,
		char_count,
		raw_data(char_data),
	)

	if result <= 0 {
		free(bitmap)
		delete(char_data)
		return nil
	}

	ascent_i, descent_i, line_gap_i: i32
	stbt.GetFontVMetrics(&font_info, &ascent_i, &descent_i, &line_gap_i)
	v_scale := stbt.ScaleForPixelHeight(&font_info, font_size)

	image := sg.make_image(
		sg.Image_Desc {
			width = bitmap_width,
			height = bitmap_height,
			pixel_format = .R8,
			data = {mip_levels = {0 = {ptr = bitmap, size = uint(bitmap_width * bitmap_height)}}},
		},
	)
	free(bitmap)

	label_cstr := fmt.ctprintf("%s_%f", font_path, font_size)

	view := sg.make_view({texture = {image = image}, label = label_cstr})

	font := new(Font)
	font.char_data = char_data
	font.bitmap_width = bitmap_width
	font.bitmap_height = bitmap_height
	font.image = view
	font.ascent = f32(ascent_i) * v_scale
	font.descent = f32(descent_i) * v_scale
	font.line_gap = f32(line_gap_i) * v_scale

	loaded_fonts[FontKey{path = strings.clone(font_path), size = font_size}] = font

	return font
}

unload_fonts :: proc() {
	for font_key, font in loaded_fonts {
		sg.destroy_image(sg.query_view_image(font.image))
		sg.destroy_view(font.image)
		delete(font.char_data)
		free(font)
		delete_key(&loaded_fonts, font_key)
		delete(font_key.path)
	}
	delete(loaded_fonts)
	loaded_fonts = {}
}
