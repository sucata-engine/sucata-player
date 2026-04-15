package filesystem

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

init_run_paths :: proc(file: string, default_file: string = "main.lua") {
	file_absolute, ok_file_absolute := filepath.abs(file, context.allocator)

	if os.is_file(file) {
		filesystem.file = file_absolute
	} else {
		defer delete(file_absolute)
		filesystem.file, _ = filepath.join({file_absolute, default_file}, context.allocator)
	}

	filesystem.is_bundle = false
	filesystem.src = filepath.dir(filesystem.file)
	filesystem.build = strings.clone(filesystem.src)
	filesystem.name = filepath.base(filesystem.src)

	when ODIN_OS == .Windows {
		filesystem.data = get_config_dir("windows")
		filesystem.system = "windows"
	} else when ODIN_OS == .Darwin {
		filesystem.data = get_config_dir("darwin")
		filesystem.system = "darwin"
	} else when ODIN_OS == .Linux {
		filesystem.data = get_config_dir("linux")
		filesystem.system = "linux"
	}
}

uninit_paths :: proc() {
	delete(filesystem.build)
	delete(filesystem.data)
	delete(filesystem.file)
	delete(filesystem.src)
}

init_build_paths :: proc(assets_file: string) {
	filesystem.file = strings.clone("main.lua")
	filesystem.src = filepath.dir(assets_file)
	filesystem.build = strings.clone(filesystem.src)
	filesystem.name = filepath.base(filesystem.src)
	filesystem.is_bundle = true

	when ODIN_OS == .Windows {
		filesystem.data = get_config_dir("windows")
		filesystem.system = "windows"
	} else when ODIN_OS == .Darwin {
		filesystem.data = get_config_dir("darwin")
		filesystem.system = "darwin"
	} else when ODIN_OS == .Linux {
		filesystem.data = get_config_dir("linux")
		filesystem.system = "linux"
	}
}

get_config_dir :: proc(system: string) -> string {
	if system == "windows" {
		appdata := os.get_env_alloc("APPDATA", context.allocator)
		if appdata != "" {
			return appdata
		}
	}

	if system == "linux" {
		home := os.get_env_alloc("HOME", context.allocator)
		defer delete(home)
		if home != "" {
			result, _ := filepath.join({home, ".local", "share"}, context.allocator)
			return result
		}
	}

	if system == "darwin" {
		home := os.get_env_alloc("HOME", context.allocator)
		defer delete(home)
		if home != "" {
			result, _ := filepath.join({home, "Library", "Application Support"}, context.allocator)
			return result
		}
	}

	return "."
}

get_sucata_folder :: proc() -> string {
	arg0 := os.args[0]

	if filepath.is_abs(arg0) {
		return filepath.dir(arg0)
	}

	executable_path, ok := os.get_executable_path(context.allocator)
	defer delete(executable_path)
	if ok == nil && os.exists(executable_path) {
		return filepath.dir(executable_path)
	}

	return strings.clone("")
}

get_executable :: proc(name: string) -> string {
	when ODIN_OS == .Windows {
		return fmt.aprintf("%s.exe", name)
	}
	return strings.clone(name)
}

get_sucata_path :: proc() -> string {
	sucata_folder := get_sucata_folder()
	sucata_executable := get_executable("sucata")
	defer delete(sucata_folder)
	defer delete(sucata_executable)

	result, _ := filepath.join({sucata_folder, sucata_executable}, context.allocator)
	return result
}

get_sucata_player_path :: proc() -> string {
	sucata_folder := get_sucata_folder()
	sucata_executable := get_executable("sucata-player")
	defer delete(sucata_folder)
	defer delete(sucata_executable)

	result, _ := filepath.join({sucata_folder, sucata_executable}, context.allocator)
	return result
}
