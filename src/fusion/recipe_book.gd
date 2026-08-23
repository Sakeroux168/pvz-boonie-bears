class_name RecipeBook
extends RefCounted
## Fixed fusion/upgrade recipes loaded from the data layer.
## Formal replacement for the P1 PoC `const RECIPES` table. No random results,
## no per-character if/else chains: recipes are looked up by a sorted input key.

var _recipes: Dictionary = {}


func _init(payload: Dictionary = {}) -> void:
	if not payload.is_empty():
		load_recipes(payload)


func load_recipes(payload: Dictionary) -> bool:
	var entries: Array = []
	if payload.has("recipes") and payload["recipes"] is Array:
		entries = payload["recipes"]
	else:
		for key in payload.keys():
			if payload[key] is Dictionary:
				entries.append(payload[key])
	var loaded := 0
	for entry in entries:
		if entry is Dictionary and entry.has("input_a") and entry.has("input_b") and entry.has("result"):
			var key := recipe_key(String(entry["input_a"]), String(entry["input_b"]))
			_recipes[key] = entry.duplicate(true)
			loaded += 1
	return loaded > 0


static func from_json_text(text: String) -> RecipeBook:
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return RecipeBook.new(parsed)
	push_error("RecipeBook: invalid JSON payload")
	return RecipeBook.new()


func recipe_key(input_a: String, input_b: String) -> String:
	var inputs := [input_a, input_b]
	inputs.sort()
	return "%s|%s" % [inputs[0], inputs[1]]


func find_recipe(input_a: String, input_b: String) -> Dictionary:
	var key := recipe_key(input_a, input_b)
	if not _recipes.has(key):
		return {}
	return _recipes[key].duplicate(true)


func is_legal(input_a: String, input_b: String) -> bool:
	return not find_recipe(input_a, input_b).is_empty()


func preview_result(input_a: String, input_b: String) -> String:
	var recipe := find_recipe(input_a, input_b)
	return String(recipe.get("result", ""))
