package build

import "core:crypto/hash"
import "core:encoding/hex"
import "core:os"

DEFAULT_ASSETS_PATH :: "assets.scta"
BUILD_HEADER :: "SUCATA_BUILD_"


get_assets_hash :: proc(assets_path: string) -> string {
	file_data, read_ok := os.read_entire_file(assets_path)
	defer delete(file_data)

	hash_bytes: [32]byte
	hash.hash(hash.Algorithm.SHA256, file_data, hash_bytes[:])

	hash_string := hex.encode(hash_bytes[:])
	hash_bytes = {}

	return string(hash_string)
}
