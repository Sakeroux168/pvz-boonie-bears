class_name UnitCatalog
extends RefCounted
## Loads unit definitions from the data layer (JSON), decoupled from code.
## Formal replacement for the P1 PoC `const UNIT_DEFINITIONS` table.

var _definitions: Dictionary = {}


func _init(definitions: Dictionary = {}) -> void:
	if not definitions.is_empty():
		load_definitions(definitions)


## Accepts {"unit_a1": {...}, ...} or {"units": [...]} style payloads.
func load_definitions(payload: Dictionary) -> bool:
	var entries: Array = []
	if payload.has("units") and payload["units"] is Array:
		entries = payload["units"]
	else:
		for key in payload.keys():
			if payload[key] is Dictionary:
				entries.append(payload[key])
	var loaded := 0
	for entry in entries:
		if entry is Dictionary and entry.has("id"):
			_definitions[String(entry["id"])] = entry.duplicate(true)
			loaded += 1
	return loaded > 0


static func from_json_text(text: String) -> UnitCatalog:
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return UnitCatalog.new(parsed)
	push_error("UnitCatalog: invalid JSON payload")
	return UnitCatalog.new()


func has_unit(unit_id: String) -> bool:
	return _definitions.has(unit_id)


func definition(unit_id: String) -> Dictionary:
	if not has_unit(unit_id):
		return {}
	return _definitions[unit_id].duplicate(true)


func create_runtime_state(unit_id: String) -> Dictionary:
	var data := definition(unit_id)
	if data.is_empty():
		return {}
	return {
		"kind": "unit",
		"unit_id": unit_id,
		"current_health": int(data["max_health"]),
		"attack_cooldown_remaining": 0.0,
		"shots_fired": 0,
		"status": {},
	}
