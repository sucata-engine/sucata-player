package src

import "./src/build"
import "./src/common"
import "./src/core"
import "./src/filesystem"
import "./src/lua"
import "core:fmt"
import "core:log"
import "core:os"

main :: proc() {
	context.logger = log.create_console_logger()
	core.DEFAULT_CONTEXT = context
	core.init_temp_arena()

	build_hash, is_build := build.get_build()
	defer delete(build_hash)
	core.is_build_mode = is_build

	if core.is_build_mode {
		build.run(build_hash)
		return
	}

	args := os.args
	if len(args) < 2 {
		common.print_error("You need to pass at least one argument to run it.")
		return
	}

	if args[1] == "--version" {
		fmt.printfln(core.VERSION)
		return
	}

	run(args[1:])
}

run :: proc(args: []string) {
	file_path := args[0]

	filesystem.init_run_paths(file_path)
	common.print("Running Sucata project: %s", filesystem.location.file)

	lua.init_lua(filesystem.location.file)
	core.main()
}
