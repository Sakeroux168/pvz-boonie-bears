class_name UnitState
extends RefCounted

var unit_id := ""
var family := ""
var tier := 1
var max_health := 1
var health := 1
var attack_cooldown := 0.0
var shots_fired := 0
var status: Dictionary = {}

static func from_definition(definition: Dictionary) -> UnitState:
	var unit := UnitState.new()
	unit.unit_id = String(definition.get("id", ""))
	unit.family = String(definition.get("family", ""))
	unit.tier = int(definition.get("tier", 1))
	unit.max_health = int(definition.get("max_health", 1))
	unit.health = unit.max_health
	return unit

func health_ratio() -> float:
	return float(health) / float(maxi(1, max_health))
