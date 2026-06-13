package filesystem

import "core:os"
import "core:path/filepath"
import "core:strings"

read_file :: proc(file_path: string) -> ([]u8, bool) {
	if asset, asset_ok := get_asset(file_path); asset_ok {
		return asset, true
	}

	return {}, false
}

read_file_as_string :: proc(file_path: string) -> (string, bool) {
	data, ok := read_file(file_path)
	if !ok {
		return "", false
	}

	return strings.clone_from(data), true
}

read_dir :: proc(dir_path: string) -> ([]string, bool) {
	files := find_assets_with_prefix(dir_path)
	defer delete(files)
	if len(files) > 0 {
		return files, true
	}

	dir_path_normalized := get_path(dir_path)
	dir_handle, open_err := os.open(dir_path_normalized, os.O_RDONLY)
	if open_err != os.ERROR_NONE {
		return {}, false
	}
	defer os.close(dir_handle)

	file_infos, read_err := os.read_dir(dir_handle, -1, context.allocator)
	if read_err != os.ERROR_NONE {
		return {}, false
	}
	defer os.file_info_slice_delete(file_infos, context.allocator)

	files_os := [dynamic]string{}
	for info in file_infos {
		full_path, _ := filepath.join({dir_path, info.name}, context.allocator)
		defer delete(full_path)

		clean_path, _ := filepath.clean(full_path, context.allocator)
		append(&files_os, clean_path)
	}

	return files_os[:], true
}

write_file :: proc(file_path: string, data: []u8) -> bool {
	file_path_normalized := get_path(file_path)
	file_handle, create_err := os.open(
		file_path_normalized,
		os.O_CREATE | os.O_WRONLY | os.O_TRUNC,
	)
	if create_err != os.ERROR_NONE {
		return false
	}
	defer os.close(file_handle)

	os.write(file_handle, data)
	return true
}

mkdir :: proc(dir_path: string) {
	dir_path_normalized := get_path(dir_path)
	os.make_directory(dir_path_normalized)
}

rm :: proc(path: string) {
	file_path_normalized := get_path(path)
	os.remove(file_path_normalized)
}

rename :: proc(old_path: string, new_path: string) {
	old_path_normalized := get_path(old_path)
	new_path_normalized := get_path(new_path)
	os.rename(old_path_normalized, new_path_normalized)
}

exists :: proc(path: string) -> bool {
	path_normalized := get_path(path)
	info, stat_err := os.stat(path_normalized, context.allocator)
	if stat_err == os.ERROR_NONE {
		os.file_info_delete(info, context.allocator)
		return true
	}
	return false
}
