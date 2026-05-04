package core

import common "../common"
import "core:hash"
import lua "vendor:lua/5.4"

event_handlers: map[u64][dynamic]common.EventHandler = {}

event_name_to_u64 :: #force_inline proc(event: string) -> u64 {
	return hash.fnv64a(transmute([]u8)event)
}

add_handler :: proc(owner: u64, event: string, function_ref: i32) {
	event_key := event_name_to_u64(event)

	if _, exists := event_handlers[event_key]; !exists {
		event_handlers[event_key] = [dynamic]common.EventHandler{}
	}
	handler := common.EventHandler {
		function = function_ref,
		owner    = owner,
	}
	append(&event_handlers[event_key], handler)
}

remove_handler_owner :: proc(owner: u64) {
	for event in event_handlers {
		handlers := &event_handlers[event]
		for i := len(handlers) - 1; i >= 0; i -= 1 {
			if handlers[i].owner == owner {
				lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, handlers[i].function)
				ordered_remove(&event_handlers[event], i)
			}
		}
	}
	empty_events := make([dynamic]u64, context.temp_allocator)
	for event in event_handlers {
		if len(event_handlers[event]) == 0 {
			append(&empty_events, event)
		}
	}
	for event in empty_events {
		delete(event_handlers[event])
		delete_key(&event_handlers, event)
	}
}

emit_event :: proc(event: string, data: i32) {
	event_key := event_name_to_u64(event)
	if handlers, exists := event_handlers[event_key]; exists {
		for i: int = 0; i < len(handlers); i += 1 {
			handler := handlers[i]
			call_lua_function_with_table_ref(LUA_GLOBAL_STATE, handler.function, data)
		}
	}
}

cleanup_event_handlers :: proc() {
	for event, handlers in event_handlers {
		for handler in handlers {
			lua.L_unref(LUA_GLOBAL_STATE, lua.REGISTRYINDEX, handler.function)
		}
		delete(handlers)
	}
	delete(event_handlers)
	event_handlers = {}
}
