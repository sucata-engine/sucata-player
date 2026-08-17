package filesystem

import "base:runtime"
import "core:c"
import "core:strings"
import "core:sync"
import "core:time"
import "vendor:sdl3"

Dialog_Result :: struct {
	paths:    [dynamic]string,
	canceled: bool,
	failed:   bool,
	wg:       sync.Wait_Group,
}

dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	result := cast(^Dialog_Result)userdata

	switch {
	case filelist == nil:
		result.failed = true
	case filelist[0] == nil:
		result.canceled = true
	case:
		for i := 0; filelist[i] != nil; i += 1 {
			append(&result.paths, strings.clone_from_cstring(filelist[i]))
		}
	}

	sync.wait_group_done(&result.wg)
}

// Blocks the calling thread until the user closes the native file/folder
// picker. SDL's dialog callback can fire on a different thread than the one
// that opened the dialog, so a wait group is used to make this synchronous.
// On Linux the portal/DBus-backed dialogs are driven by SDL's own event
// pump, which our sokol_app-based main loop never calls into, so we pump it
// ourselves while waiting or the dialog result never arrives.
open_dialog :: proc(
	folder: bool,
	multiple: bool,
	extensions: []string,
) -> (
	paths: []string,
	ok: bool,
) {
	result: Dialog_Result
	sync.wait_group_add(&result.wg, 1)

	c_filter: sdl3.DialogFileFilter
	filters_ptr: [^]sdl3.DialogFileFilter
	nfilters: c.int

	if len(extensions) > 0 {
		pattern := strings.join(extensions, ";")
		c_filter = sdl3.DialogFileFilter {
			name    = "Allowed files",
			pattern = strings.clone_to_cstring(pattern),
		}
		delete(pattern)
		filters_ptr = &c_filter
		nfilters = 1
	}
	defer if nfilters > 0 do delete(c_filter.pattern)

	if folder {
		sdl3.ShowOpenFolderDialog(dialog_callback, &result, nil, nil, multiple)
	} else {
		sdl3.ShowOpenFileDialog(dialog_callback, &result, nil, filters_ptr, nfilters, nil, multiple)
	}

	for !sync.wait_group_wait_with_timeout(&result.wg, 10 * time.Millisecond) {
		sdl3.PumpEvents()
	}

	if result.failed || result.canceled || len(result.paths) == 0 {
		delete(result.paths)
		return nil, false
	}

	return result.paths[:], true
}
