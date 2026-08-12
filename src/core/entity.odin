package core

import "../common"

run_entity_behaviour :: proc(entity: ^common.Entity, method: Behaviour_Method) {
	for behaviour_index in entity.behaviours {
		call_behaviour(behaviour_index, method, entity.state)
	}
}
