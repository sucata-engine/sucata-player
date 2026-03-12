package core

import "core:hash"

tags: map[u64][dynamic]u64 = {}

tag_to_u64 :: #force_inline proc(tag: string) -> u64 {
	return hash.fnv64a(transmute([]u8)tag)
}

has_tag :: proc(entity_id: u64, tag: string) -> bool {
	tag_key := tag_to_u64(tag)
	if tag, exists := tags[tag_key]; exists {
		for id in tag {
			if id == entity_id {
				return true
			}
		}
	}
	return false
}

add_tag :: proc(entity_id: u64, tag: string) {
	tag_key := tag_to_u64(tag)

	if has_tag(entity_id, tag) {
		return
	}

	if _, exists := tags[tag_key]; !exists {
		tags[tag_key] = [dynamic]u64{}
	}
	append(&tags[tag_key], entity_id)
}

remove_tag :: proc(entity_id: u64, tag: string) {
	tag_key := tag_to_u64(tag)
	if tag_list, exists := tags[tag_key]; exists {
		for i: int = 0; i < len(tag_list); i += 1 {
			if tag_list[i] == entity_id {
				ordered_remove(&tags[tag_key], i)
				if len(tags[tag_key]) == 0 {
					delete(tags[tag_key])
					delete_key(&tags, tag_key)
				}
				break
			}
		}
	}
}

get_entities :: proc(tag: string) -> ^[dynamic]u64 {
	tag_key := tag_to_u64(tag)
	if tag_list, exists := tags[tag_key]; exists {
		return &tags[tag_key]
	}
	return nil
}

remove_entity_tags :: proc(entity_id: u64) {
	for tag_key, &tag_list in tags {
		for i := len(tag_list) - 1; i >= 0; i -= 1 {
			if tag_list[i] == entity_id {
				ordered_remove(&tags[tag_key], i)
			}
		}
	}
}

cleanup_tags :: proc() {
	for _, tag_list in tags {
		delete(tag_list)
	}
	delete(tags)
	tags = {}
}
