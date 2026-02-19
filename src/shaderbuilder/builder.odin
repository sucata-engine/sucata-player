package shader_builder

import "core:fmt"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"

build_shader :: proc(input_file: string) -> (string, bool) {
	ok, temp_path := build_sokol_shader(input_file)

	shader_name_dots := strings.split(filepath.base(input_file), ".")
	shader_name := shader_name_dots[0]
	input_dir := filepath.dir(input_file)
	output_file_name := fmt.aprintf("%s.schd", shader_name)
	defer delete(input_dir)
	defer delete(output_file_name)

	output_path := filepath.join({input_dir, output_file_name})

	if ok {
		generate_json(temp_path, output_path)
		remove_temp_folder(filepath.dir(temp_path))
	}

	return output_path, ok
}

remove_temp_folder :: proc(temp_path: string) {
	if os2.exists(temp_path) {
		os2.remove_all(temp_path)
	}
}
