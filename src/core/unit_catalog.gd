class_name UnitCatalog
extends RefCounted

const UNIT_DEFINITIONS := {
	"unit_a_1": {
		"id": "unit_a_1", "family": "unit_a", "tier": 1, "cost": 50,
		"max_health": 80, "range_cells": 5.0, "attack_period": 1.0,
		"damage": 10, "burst_count": 1, "behavior": "single_ranged"
	},
	"unit_a_2": {
		"id": "unit_a_2", "family": "unit_a", "tier": 2, "cost": 0,
		"max_health": 105, "range_cells": 5.5, "attack_period": 0.95,
		"damage": 7, "burst_count": 2, "behavior": "double_ranged"
	},
	"unit_a_3": {
		"id": "unit_a_3", "family": "unit_a", "tier": 3, "cost": 0,
		"max_health": 130, "range_cells": 6.0, "attack_period": 0.9,
		"damage": 9, "burst_count": 2, "heavy_every": 3,
		"behavior": "double_ranged_with_periodic_heavy"
	},
	"unit_b_1": {
		"id": "unit_b_1", "family": "unit_b", "tier": 1, "cost": 75,
		"max_health": 180, "range_cells": 1.0, "attack_period": 0.8,
		"damage": 14, "burst_count": 1, "behavior": "melee_guard"
	},
	"unit_ab": {
		"id": "unit_ab", "family": "unit_ab", "tier": 1, "cost": 0,
		"max_health": 190, "range_cells": 5.0, "attack_period": 1.1,
		"damage": 9, "burst_count": 1, "guard_damage": 16,
		"behavior": "ranged_plus_guard_collaboration"
	}
}


func has_unit(unit_id: String) -> bool:
	return UNIT_DEFINITIONS.has(unit_id)


func definition(unit_id: String) -> Dictionary:
	if not has_unit(unit_id):
		return {}
	return UNIT_DEFINITIONS[unit_id].duplicate(true)


func create_runtime_state(unit_id: String) -> Dictionary:
	var data := definition(unit_id)
	if data.is_empty():
		return {}
	return {
		"kind": "unit",
		"unit_id": unit_id,
		"current_health": data["max_health"],
		"attack_cooldown_remaining": 0.0,
		"shots_fired": 0,
		"status": {}
	}
