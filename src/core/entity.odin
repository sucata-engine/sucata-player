package core

import "../common"

run_entity_behaviour :: proc(entity: ^common.Entity, method: cstring) {
	for behaviour_id in entity.behaviours {
		call_behaviour(behaviour_id, method, entity.state)
	}
}
