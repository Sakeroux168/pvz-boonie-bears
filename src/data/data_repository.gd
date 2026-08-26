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
	if units.is_empty() or enemies.is_empty() or recipes.is_empty() or level.is_empty():
		return false
	# H4A-3: fail loud on reference/schema errors instead of running a
	# broken level into a fake victory.
	var problems := LevelValidator.validate(level, units, enemies, recipes)
	if not problems.is_empty():
		for problem in problems:
			push_error("Level validation: %s" % problem)
		return false
	return true

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
