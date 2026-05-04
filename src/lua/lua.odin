package lua

import "../common"
import "../core"
import "../filesystem"
import "./audio"
import cam "./camera"
import "./file_system"
import mathns "./math"
import "./scene"
import "./window"
import "core:c"
import "core:fmt"
import "core:strings"
import "events"
import "gamepad"
import "graphic"
import "input"
import lua_common "lua_common"
import timens "time"
import lua "vendor:lua/5.4"

GC_Config :: struct {
	pause:    c.int,
	step_mul: c.int,
	auto_gc:  bool,
}

default_gc_config := GC_Config {
	pause    = 150,
	step_mul = 150,
	auto_gc  = true,
}

lua_namespaces :: []lua_common.LuaNamespace {
	audio.AUDIO_NAMESPACE,
	cam.CAMERA_NAMESPACE,
	file_system.FILE_SYSTEM_NAMESPACE,
	gamepad.GAMEPAD_NAMESPACE,
	graphic.GRAPHIC_NAMESPACE,
	scene.SCENE_NAMESPACE,
	timens.TIME_NAMESPACE,
	events.EVENTS_NAMESPACE,
	input.INPUT_NAMESPACE,
	mathns.MATH_NAMESPACE,
	window.WINDOW_NAMESPACE,
}

custom_loader :: proc "c" (L: ^lua.State) -> c.int {
	context = core.DEFAULT_CONTEXT

	module_name := lua.tostring(L, 1)
	if module_name == nil {
		lua.pushstring(L, "module not found")
		return 1
	}

	module_str := strings.clone_from_cstring(module_name)
	module_path, ok := strings.replace_all(module_str, ".", "/")
	defer {
		if module_str != module_path {
			delete(module_str)
		}
		delete(module_path)
	}

	asset_patterns := []string {
		fmt.aprintf("src://%s.lua", module_path),
		fmt.aprintf("src://%s/init.lua", module_path),
		fmt.aprintf("%s.lua", module_path),
		fmt.aprintf("%s/init.lua", module_path),
	}
	defer {
		for p in asset_patterns {
			delete(p)
		}
	}

	for pattern in asset_patterns {
		if asset_data, ok := filesystem.get_asset(pattern); ok && len(asset_data) > 0 {
			chunk_name := strings.clone_to_cstring(pattern)
			defer delete_cstring(chunk_name)

			result := lua.L_loadbuffer(
				L,
				raw_data(asset_data),
				c.size_t(len(asset_data)),
				chunk_name,
			)

			if result == .OK {
				return 1
			} else {
				lua.pop(L, 1)
			}
		}
	}

	fs_patterns := []string {
		fmt.aprintf("%s.lua", module_path),
		fmt.aprintf("%s/init.lua", module_path),
	}
	defer {
		for p in fs_patterns {
			delete(p)
		}
	}

	lua.pushnil(L)
	return 1
}

close_lua :: proc() {
	if core.LUA_GLOBAL_STATE != nil {
		lua.close(core.LUA_GLOBAL_STATE)
		core.LUA_GLOBAL_STATE = nil
	}
}

load_path :: proc() {
	L := core.LUA_GLOBAL_STATE

	lua.getglobal(L, "package")

	lua.getfield(L, -1, "searchers")
	lua.pushcfunction(L, custom_loader)
	lua.rawseti(L, -2, 2)
	lua.pop(L, 1)

	lua.getfield(L, -1, "path")
	old_path := lua.tostring(L, -1)
	lua.pop(L, 1)

	script_dir := filesystem.filesystem.src

	new_path := fmt.tprintf(
		"%s;%s/?.lua;%s/?/init.lua;%s/?/?.lua",
		old_path,
		script_dir,
		script_dir,
		script_dir,
	)
	cstring_new_path := strings.clone_to_cstring(new_path)
	defer delete_cstring(cstring_new_path)

	lua.pushstring(L, cstring_new_path)
	lua.setfield(L, -2, "path")

	lua.pop(L, 1)
}

init_lua :: proc(path: string, entity_file: string = "") {
	close_lua()

	L := lua.L_newstate()
	core.LUA_GLOBAL_STATE = L

	lua.atpanic(L, proc "c" (L: ^lua.State) -> c.int {
		context = core.DEFAULT_CONTEXT
		msg := lua.tostring(L, 1)
		if msg != nil {
			common.print_error("Lua panic: %s", msg)
		}
		return 0
	})

	lua.L_openlibs(L)

	create_namespaces(L)
	load_path()

	asset_data, found := filesystem.get_asset(path)
	if !found || len(asset_data) == 0 {
		common.print_error("Failed to find Lua asset: %s", path)
		return
	}

	chunk_name := strings.clone_to_cstring(path)
	defer delete_cstring(chunk_name)

	if lua.L_loadbuffer(L, raw_data(asset_data), c.size_t(len(asset_data)), chunk_name) != .OK {
		err := lua.tostring(L, -1)
		common.print_error("Failed to load Lua buffer: %s", err)
		lua.pop(L, 1)
		setup_garbage_collector(L, default_gc_config)
		return
	}

	if lua.pcall(L, 0, lua.MULTRET, 0) != 0 {
		err := lua.tostring(L, -1)
		common.print_error("Failed to execute Lua buffer: %s", err)
		lua.pop(L, 1)
	}

	if lua.gettop(L) > 0 && lua.isstring(L, -1) {
		msg := lua.tostring(L, -1)
		fmt.print(msg)
	}

	setup_garbage_collector(L, default_gc_config)
}

create_meta :: proc(L: ^lua.State) {
	lua.newtable(L)

	os_cstr := strings.clone_to_cstring(filesystem.filesystem.system)
	defer delete_cstring(os_cstr)
	lua.pushstring(L, os_cstr)
	lua.setfield(L, -2, "OS")

	version_cstr := strings.clone_to_cstring(core.VERSION)
	defer delete_cstring(version_cstr)
	lua.pushstring(L, version_cstr)
	lua.setfield(L, -2, "VERSION")

	lua.setfield(L, -2, "meta")
}

create_namespaces :: proc(L: ^lua.State) {
	lua.newtable(L)
	for namespace in lua_namespaces {
		lua.newtable(L)

		for func in namespace.functions {
			lua.pushcfunction(L, func.func_ptr)
			lua.setfield(L, -2, func.name)
		}

		lua.setfield(L, -2, namespace.name)
	}
	create_meta(L)

	lua.setglobal(L, "sucata")
}

setup_garbage_collector :: proc(L: ^lua.State, config: GC_Config) {
	if !config.auto_gc {
		lua.gc(L, lua.GCSTOP, 0)
	} else {
		lua.gc(L, lua.GCRESTART, 0)
	}

	lua.gc(L, lua.GCINC, config.pause, config.step_mul, 0)

	common.print_info(
		"Lua Garbage collector initialized - Pause: %d%%, StepMul: %d%%, Auto: %t",
		config.pause,
		config.step_mul,
		config.auto_gc,
	)
}
