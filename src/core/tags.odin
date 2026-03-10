package core

import "core:hash"
import "core:strings"

tags: map[u64][dynamic]string = {}

tag_to_u64 :: #force_inline proc(tag: string) -> u64 {
	return hash.fnv64a(transmute([]u8)tag)
}

has_tag :: proc(entity_id: string, tag: string) -> bool {
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

add_tag :: proc(entity_id: string, tag: string) {
	tag_key := tag_to_u64(tag)

	if has_tag(entity_id, tag) {
		return
	}
	entity_id_clone := strings.clone(entity_id)

	if _, exists := tags[tag_key]; !exists {
		tags[tag_key] = [dynamic]string{}
	}
	append(&tags[tag_key], entity_id_clone)
}

remove_tag :: proc(entity_id: string, tag: string) {
	tag_key := tag_to_u64(tag)
	if tag_list, exists := tags[tag_key]; exists {
		for i: int = 0; i < len(tag_list); i += 1 {
			if tag_list[i] == entity_id {
				delete(tags[tag_key][i])
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

get_entities :: proc(tag: string) -> ^[dynamic]string {
	tag_key := tag_to_u64(tag)
	if tag_list, exists := tags[tag_key]; exists {
		return &tags[tag_key]
	}
	return nil
}

remove_entity_tags :: proc(entity_id: string) {
	for tag_key, &tag_list in tags {
		for i := len(tag_list) - 1; i >= 0; i -= 1 {
			if tag_list[i] == entity_id {
				delete(tag_list[i])
				ordered_remove(&tags[tag_key], i)
			}
		}
	}
}

cleanup_tags :: proc() {
	for _, tag_list in tags {
		for entity_id in tag_list {
			delete(entity_id)
		}
		delete(tag_list)
	}
	delete(tags)
	tags = {}
}
