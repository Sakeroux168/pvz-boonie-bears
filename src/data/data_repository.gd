class_name GameDataRepository
extends RefCounted

var units: Dictionary = {}
var enemies: Dictionary = {}
var recipes: Array = []
var level: Dictionary = {}

func load_all(level_path: String = "res://src/data/level_playable.json") -> bool:
	units = _load_json("res://src/data/units.json")
	enemies = _load_json("res://src/data/enemies.json")
	var recipe_doc := _load_json("res://src/data/recipes.json")
	recipes = recipe_doc.get("recipes", [])
	level = _load_json(level_path)
	return not units.is_empty() and not enemies.is_empty() and not level.is_empty()

func unit_def(unit_id: String) -> Dictionary:
	return units.get(unit_id, {}).duplicate(true)

func enemy_def(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {}).duplicate(true)

func recipe_for(input_a: String, input_b: String) -> Dictionary:
	var pair := [input_a, input_b]
	pair.sort()
	for recipe in recipes:
		var recipe_pair := [String(recipe.get("input_a", "")), String(recipe.get("input_b", ""))]
		recipe_pair.sort()
		if pair == recipe_pair:
			return recipe.duplicate(true)
	return {}

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open data file: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Expected dictionary JSON at %s" % path)
	return {}
