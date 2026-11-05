package lua

import "../common"
import "../core"
import "../filesystem"
import "../graphics"
import "./audio"
import cam "./camera"
import "./file_system"
import "./system"
import "./window"
import "core:c"
import "core:fmt"
import "core:strings"
import "graphic"
import lua_common "lua_common"
import "ui"
import lua "../luajit"

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

Runtime_Module :: struct {
	name:   cstring,
	chunk:  cstring,
	source: string,
}

PRELUDE_SOURCE :: #load("runtime/prelude.lua", string)

RUNTIME_MODULES := [?]Runtime_Module {
	{"sucata.scene", "=sucata/scene", #load("runtime/scene.lua", string)},
	{"sucata.events", "=sucata/events", #load("runtime/events.lua", string)},
	{"sucata.time", "=sucata/time", #load("runtime/time.lua", string)},
	{"sucata.math", "=sucata/math", #load("runtime/math.lua", string)},
	{"sucata.input", "=sucata/input", #load("runtime/input.lua", string)},
	{"sucata.gamepad", "=sucata/gamepad", #load("runtime/gamepad.lua", string)},
}

lua_namespaces :: []lua_common.LuaNamespace {
	audio.AUDIO_NAMESPACE,
	cam.CAMERA_NAMESPACE,
	file_system.FILE_SYSTEM_NAMESPACE,
	graphic.GRAPHIC_NAMESPACE,
	window.WINDOW_NAMESPACE,
	ui.UI_NAMESPACE,
	system.SYSTEM_NAMESPACE,
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
			chunk_name := strings.clone_to_cstring(fmt.tprintf("@%s", pattern))
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
		core.LUA_TRACEBACK_REF = 0
	}
}

load_path :: proc() {
	L := core.LUA_GLOBAL_STATE

	lua.getglobal(L, "package")

	lua.getfield(L, -1, "loaders")
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

report_lua_error :: proc(L: ^lua.State, prefix: string) {
	err := lua.tostring(L, -1)
	common.print_error("%s: %s", prefix, err)
	lua.pop(L, 1)
}

run_embedded :: proc(L: ^lua.State, source: string, chunk: cstring) -> bool {
	if lua.L_loadbuffer(L, raw_data(source), c.size_t(len(source)), chunk) != .OK {
		report_lua_error(L, "Failed to load Sucata runtime")
		return false
	}
	if lua.pcall(L, 0, 0, 0) != 0 {
		report_lua_error(L, "Failed to run Sucata runtime")
		return false
	}
	return true
}

register_runtime_modules :: proc(L: ^lua.State) {
	lua.getglobal(L, "package")
	lua.getfield(L, -1, "preload")
	for module in RUNTIME_MODULES {
		if lua.L_loadbuffer(L, raw_data(module.source), c.size_t(len(module.source)), module.chunk) != .OK {
			report_lua_error(L, "Failed to load Sucata runtime module")
			continue
		}
		lua.setfield(L, -2, module.name)
	}
	lua.pop(L, 2)
}

boot_runtime :: proc(L: ^lua.State, has_root: bool) {
	lua.getglobal(L, "sucata")
	lua.getfield(L, -1, "_boot")
	lua.remove(L, -2)
	if !lua.isfunction(L, -1) {
		lua.pop(L, 1)
		common.print_error("Sucata runtime is missing sucata._boot")
		return
	}

	if has_root {
		lua.rawgeti(L, lua.REGISTRYINDEX, ROOT_REF)
	} else {
		lua.pushnil(L)
	}

	if lua.pcall(L, 1, 1, 0) != 0 {
		report_lua_error(L, "Failed to boot Sucata runtime")
		return
	}

	if lua.istable(L, -1) {
		core.set_phases(L, lua.gettop(L))
	}
	lua.pop(L, 1)
}

ROOT_REF: i32 = 0

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

	lua.getglobal(L, "debug")
	lua.getfield(L, -1, "traceback")
	if lua.isfunction(L, -1) {
		core.LUA_TRACEBACK_REF = i32(lua.L_ref(L, lua.REGISTRYINDEX))
	} else {
		lua.pop(L, 1)
	}
	lua.pop(L, 1)

	create_namespaces(L)
	load_path()
	register_runtime_modules(L)

	defer setup_garbage_collector(L, default_gc_config)

	if !run_embedded(L, PRELUDE_SOURCE, "=sucata/prelude") {
		return
	}

	asset_data, found := filesystem.get_asset(path)
	if !found || len(asset_data) == 0 {
		common.print_error("Failed to find Lua asset: %s", path)
		boot_runtime(L, false)
		return
	}

	chunk_name := strings.clone_to_cstring(fmt.tprintf("@%s", path))
	defer delete_cstring(chunk_name)

	if lua.L_loadbuffer(L, raw_data(asset_data), c.size_t(len(asset_data)), chunk_name) != .OK {
		report_lua_error(L, "Failed to load Lua buffer")
		boot_runtime(L, false)
		return
	}

	if lua.pcall(L, 0, lua.MULTRET, 0) != 0 {
		report_lua_error(L, "Failed to execute Lua buffer")
	}

	has_root := false
	if lua.gettop(L) > 0 && lua.istable(L, 1) {
		lua.pushvalue(L, 1)
		ROOT_REF = i32(lua.L_ref(L, lua.REGISTRYINDEX))
		has_root = true
	} else if lua.gettop(L) > 0 && lua.isstring(L, -1) {
		msg := lua.tostring(L, -1)
		fmt.print(msg)
	}

	lua.settop(L, 0)

	boot_runtime(L, has_root)

	if has_root {
		lua.L_unref(L, lua.REGISTRYINDEX, ROOT_REF)
		ROOT_REF = 0
	}
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

create_runtime_data :: proc(L: ^lua.State) {
	lua.pushlightuserdata(L, core.get_ffi_api())
	lua.setfield(L, -2, "_ffi")

	lua.createtable(L, 0, c.int(len(core.KEY_NAMES) + len(core.MOUSE_NAMES)))
	for entry in core.KEY_NAMES {
		name := strings.clone_to_cstring(entry.name, context.temp_allocator)
		lua.pushinteger(L, lua.Integer(entry.code))
		lua.setfield(L, -2, name)
	}
	for entry in core.MOUSE_NAMES {
		name := strings.clone_to_cstring(entry.name, context.temp_allocator)
		lua.pushinteger(L, lua.Integer(core.FFI_INPUT_KEYS + int(entry.button)))
		lua.setfield(L, -2, name)
	}
	lua.setfield(L, -2, "_keys")

	lua.pushinteger(L, lua.Integer(core.FFI_INPUT_KEYS))
	lua.setfield(L, -2, "_mouse_offset")

	lua.createtable(L, 0, c.int(len(core.GAMEPAD_BUTTON_NAMES)))
	for entry in core.GAMEPAD_BUTTON_NAMES {
		name := strings.clone_to_cstring(entry.name, context.temp_allocator)
		lua.pushinteger(L, lua.Integer(entry.button))
		lua.setfield(L, -2, name)
	}
	lua.setfield(L, -2, "_gamepad_buttons")

	lua.createtable(L, 0, c.int(len(core.GAMEPAD_AXIS_NAMES)))
	for entry in core.GAMEPAD_AXIS_NAMES {
		name := strings.clone_to_cstring(entry.name, context.temp_allocator)
		lua.pushinteger(L, lua.Integer(entry.axis))
		lua.setfield(L, -2, name)
	}
	lua.setfield(L, -2, "_gamepad_axes")

	lua.pushinteger(L, lua.Integer(core.MAX_GAMEPADS))
	lua.setfield(L, -2, "_max_gamepads")

	lua.pushcfunction(L, runtime_gamepad_name)
	lua.setfield(L, -2, "_gamepad_name")

	lua.pushboolean(L, b32(!core.is_build_mode))
	lua.setfield(L, -2, "debug")

	lua.createtable(L, 0, 9)
	lua.pushinteger(L, lua.Integer(size_of(core.Ffi_Time)))
	lua.setfield(L, -2, "time")
	lua.pushinteger(L, lua.Integer(size_of(core.Ffi_Screen)))
	lua.setfield(L, -2, "screen")
	lua.pushinteger(L, lua.Integer(size_of(core.InputState)))
	lua.setfield(L, -2, "input")
	lua.pushinteger(L, lua.Integer(size_of(core.Ffi_Api)))
	lua.setfield(L, -2, "api")
	lua.pushinteger(L, lua.Integer(size_of(core.Ffi_Quad)))
	lua.setfield(L, -2, "quad")
	lua.pushinteger(L, lua.Integer(size_of(core.Ffi_Text)))
	lua.setfield(L, -2, "text")
	lua.pushinteger(L, lua.Integer(size_of(core.Ffi_Gamepad)))
	lua.setfield(L, -2, "gamepad")
	lua.pushinteger(L, lua.Integer(size_of(core.Ffi_Mouse)))
	lua.setfield(L, -2, "mouse")
	lua.pushinteger(L, lua.Integer(size_of(graphics.Camera)))
	lua.setfield(L, -2, "camera")
	lua.setfield(L, -2, "_sizes")

	lua.pushcfunction(L, runtime_error)
	lua.setfield(L, -2, "_error")

	lua.pushcfunction(L, runtime_resolve_path)
	lua.setfield(L, -2, "_resolve_path")
}

runtime_gamepad_name :: proc "c" (L: ^lua.State) -> c.int {
	context = core.DEFAULT_CONTEXT
	if !lua_common.validate_number(L, 1, "get_info") do return 0
	name := core.gamepad_get_name(int(lua.tonumber(L, 1)))
	lua.pushlstring(L, cstring(raw_data(name)), c.size_t(len(name)))
	return 1
}

runtime_resolve_path :: proc "c" (L: ^lua.State) -> c.int {
	context = core.DEFAULT_CONTEXT
	if !lua_common.validate_string(L, 1, "_resolve_path") do return 0
	path := filesystem.get_path(string(lua.tostring(L, 1)))
	lua.pushlstring(L, cstring(raw_data(path)), c.size_t(len(path)))
	return 1
}

runtime_error :: proc "c" (L: ^lua.State) -> c.int {
	context = core.DEFAULT_CONTEXT
	msg := lua.tostring(L, 1)
	if msg != nil {
		common.print_error("%s", msg)
	}
	return 0
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
	create_runtime_data(L)

	lua.setglobal(L, "sucata")
}

setup_garbage_collector :: proc(L: ^lua.State, config: GC_Config) {
	if !config.auto_gc {
		lua.gc(L, lua.GCSTOP, 0)
	} else {
		lua.gc(L, lua.GCRESTART, 0)
	}

	lua.gc(L, lua.GCSETPAUSE, config.pause)
	lua.gc(L, lua.GCSETSTEPMUL, config.step_mul)

	common.print_info(
		"Lua Garbage collector initialized - Pause: %d%%, StepMul: %d%%, Auto: %t",
		config.pause,
		config.step_mul,
		config.auto_gc,
	)
}
