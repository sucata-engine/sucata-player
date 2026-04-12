package build

import "../common"
import "../core"
import "../filesystem"
import "../lua"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

run :: proc(assets_hash: string) {
	file_path, _ := filepath.abs(os.args[0])
	defer delete(file_path)
	dir_path := filepath.dir(file_path)
	defer delete(dir_path)
	assets_path := filepath.join({dir_path, DEFAULT_ASSETS_PATH})

	actual_assets_hash := get_assets_hash(assets_path)
	defer delete(actual_assets_hash)

	if !strings.equal_fold(assets_hash, actual_assets_hash) {
		fmt.panicf(
			"Build assets hash mismatch! Expected: ",
			assets_hash,
			" Got: ",
			actual_assets_hash,
		)
	}

	filesystem.init_build_paths(assets_path)
	filesystem.load_assets(assets_path)
	common.print_info("Running Sucata script: %s", filesystem.filesystem.file)

	lua.init_lua(filesystem.filesystem.file)
	core.main()
}
