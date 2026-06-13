package filesystem

import "../common"
import "core:encoding/json"
import "core:os"
import "core:strings"
import "vendor:compress/lz4"

assets: ^common.Asset_Archive = nil
asset_index: map[string]int = {}

file_cache: map[string][]byte = {}

load_assets :: proc(asset_path: string) -> bool {
	file_data, read_ok := os.read_entire_file_from_path(asset_path, context.allocator)
	if read_ok != nil {
		return false
	}
	defer delete(file_data)

	if len(file_data) < 8 {
		return false
	}

	header_size := (^u64)(raw_data(file_data))^

	if header_size == 0 || int(header_size) > len(file_data) - 8 {
		return false
	}

	json_start := 8
	json_end := json_start + int(header_size)
	json_data := file_data[json_start:json_end]

	entries: []common.Asset_Entry
	unmarshal_err := json.unmarshal(json_data, &entries)
	if unmarshal_err != nil {
		return false
	}

	assets = new(common.Asset_Archive)
	assets.entries = entries
	assets.path = asset_path

	asset_index = make(map[string]int, len(entries))
	for entry, i in assets.entries {
		key := strings.to_lower(entry.path)
		asset_index[key] = i
	}

	return true
}

get_entry :: proc(path: string) -> ^common.Asset_Entry {
	if assets == nil {
		return nil
	}
	lower := strings.to_lower(path)
	defer delete(lower)
	if idx, ok := asset_index[lower]; ok {
		return &assets.entries[idx]
	}
	return nil
}

load_asset :: proc(path: string) -> (data: []byte, ok: bool) {
	if assets == nil {
		return nil, false
	}

	entry := get_entry(path)
	if entry == nil {
		return nil, false
	}

	if entry.cache != nil {
		return entry.cache, true
	}

	file_data, read_ok := os.read_entire_file_from_path(assets.path, context.allocator)
	if read_ok != nil {
		return nil, false
	}
	defer delete(file_data)

	if len(file_data) < 8 {
		return nil, false
	}

	header_size := (^u64)(raw_data(file_data))^

	if header_size == 0 || int(header_size) > len(file_data) - 8 {
		return nil, false
	}

	json_start := 8
	json_end := json_start + int(header_size)
	compressed_data := file_data[json_end:]

	total_uncompressed_size := 0
	if len(assets.entries) > 0 {
		last_entry := assets.entries[len(assets.entries) - 1]
		total_uncompressed_size = last_entry.offset + last_entry.size
	}

	decompressed_buffer := make([]byte, total_uncompressed_size)
	defer delete(decompressed_buffer)
	decompressed_size := lz4.decompress_safe(
		raw_data(compressed_data),
		raw_data(decompressed_buffer),
		cast(i32)len(compressed_data),
		cast(i32)total_uncompressed_size,
	)

	decompressed_data := decompressed_buffer[entry.offset:entry.offset + entry.size]
	entry_data := make([]byte, len(decompressed_data))
	copy(entry_data, decompressed_data)

	entry.cache = entry_data

	return entry_data, true
}

unload_assets :: proc() {
	for key in asset_index {
		delete(key)
	}
	delete(asset_index)
	asset_index = {}

	if assets != nil {
		for &entry in assets.entries {
			if entry.cache != nil {
				delete(entry.cache)
			}
			delete(entry.path)
		}
		delete(assets.path)
		delete(assets.entries)
		free(assets)
		assets = nil
	}
}

get_asset :: proc(file_path: string, from_system: bool = false) -> (data: []byte, ok: bool) {
	if !filesystem.is_bundle || from_system || !strings.has_prefix(file_path, "src://") {
		if cached, hit := file_cache[file_path]; hit {
			return cached, true
		}

		path := get_path(file_path)
		file_data, read_ok := os.read_entire_file_from_path(path, context.allocator)
		if read_ok != nil {
			return nil, false
		}

		file_cache[strings.clone(file_path)] = file_data
		return file_data, true
	}

	if assets == nil {
		return nil, false
	}

	clean_path := file_path
	if strings.has_prefix(file_path, "src://") {
		clean_path = file_path[6:]
	}

	return load_asset(clean_path)
}

unload_file_cache :: proc() {
	for key, data in file_cache {
		delete(data)
		delete(key)
	}
	delete(file_cache)
	file_cache = {}
}

find_assets_with_prefix :: proc(prefix: string) -> []string {
	matching := make([dynamic]string)
	for entry in assets.entries {
		if strings.has_prefix(entry.path, prefix) {
			append(&matching, entry.path)
		}
	}
	return matching[:]
}
