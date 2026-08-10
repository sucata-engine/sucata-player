package core

import "core:dynlib"
import "core:strings"

DynlibHandle :: struct {
	library: dynlib.Library,
	path:    string,
}

dynlib_registry: map[i64]DynlibHandle = {}
dynlib_next_id: i64 = 1

load_dynlib :: proc(path: string) -> (i64, bool) {
	library, ok := dynlib.load_library(path)
	if !ok {
		ext := dynlib.LIBRARY_FILE_EXTENSION
		if !strings.has_suffix(path, ext) {
			fallback_path := strings.concatenate({path, ".", ext})
			defer delete(fallback_path)
			library, ok = dynlib.load_library(fallback_path)
		}
	}

	if !ok {
		return 0, false
	}

	id := dynlib_next_id
	dynlib_next_id += 1

	dynlib_registry[id] = DynlibHandle {
		library = library,
		path    = strings.clone(path),
	}

	return id, true
}

get_dynlib :: proc(id: i64) -> (DynlibHandle, bool) {
	handle, ok := dynlib_registry[id]
	return handle, ok
}

dynlib_symbol :: proc(id: i64, name: string) -> (rawptr, bool) {
	handle, ok := get_dynlib(id)
	if !ok {
		return nil, false
	}
	return dynlib.symbol_address(handle.library, name)
}

unload_dynlib :: proc(id: i64) -> bool {
	handle, ok := dynlib_registry[id]
	if !ok {
		return false
	}

	dynlib.unload_library(handle.library)
	delete(handle.path)
	delete_key(&dynlib_registry, id)

	return true
}

dynlib_shutdown :: proc() {
	for _, handle in dynlib_registry {
		dynlib.unload_library(handle.library)
		delete(handle.path)
	}
	delete(dynlib_registry)
	dynlib_registry = {}
}
