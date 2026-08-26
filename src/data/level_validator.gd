class_name LevelValidator
extends RefCounted
## Minimal schema/reference validation for level + data files (H4A-3).
## Fails loud with a list of problems instead of letting bad config silently
## run into a fake victory or a broken board. No external schema library.

const FIXED_LANES := 5
const MIN_COLUMNS := 1
const MAX_COLUMNS := 20


static func validate(level: Dictionary, units: Dictionary,
		enemies: Dictionary, recipes: Array) -> Array[String]:
	var problems: Array[String] = []
	_validate_grid(level, problems)
	_validate_trees(level, problems)
	_validate_waves(level, enemies, problems)
	_validate_deck(level, units, problems)
	_validate_recipes(units, recipes, problems)
	return problems

static func is_valid(level: Dictionary, units: Dictionary,
		enemies: Dictionary, recipes: Array) -> bool:
	return validate(level, units, enemies, recipes).is_empty()


static func _validate_grid(level: Dictionary, problems: Array[String]) -> void:
	if int(level.get("lanes", -1)) != FIXED_LANES:
		problems.append("lanes must be %d (got %s)" % [FIXED_LANES, str(level.get("lanes"))])
	var columns := int(level.get("columns", -1))
	if columns < MIN_COLUMNS or columns > MAX_COLUMNS:
		problems.append("columns must be between %d and %d (got %d)" % [MIN_COLUMNS, MAX_COLUMNS, columns])


static func _validate_trees(level: Dictionary, problems: Array[String]) -> void:
	var seen_ids := {}
	var seen_cells := {}
	for tree in level.get("protected_trees", []):
		var tree_id := String(tree.get("id", ""))
		if tree_id.is_empty():
			problems.append("protected_tree entry missing id")
			continue
		if seen_ids.has(tree_id):
			problems.append("protected_tree id '%s' duplicated" % tree_id)
		seen_ids[tree_id] = true
		var cell := Vector2i(int(tree.get("column", 0)), int(tree.get("lane", 0)))
		if seen_cells.has(cell):
			problems.append("protected_tree '%s' shares cell %s with '%s'"
					% [tree_id, str(cell), String(seen_cells[cell])])
		else:
			seen_cells[cell] = tree_id
		if cell.x < 0 or cell.x >= int(level.get("columns", 0)) \
				or cell.y < 0 or cell.y >= int(level.get("lanes", 0)):
			problems.append("protected_tree '%s' at %s is outside the board" % [tree_id, str(cell)])
		if int(tree.get("health", 0)) <= 0:
			problems.append("protected_tree '%s' has non-positive health" % tree_id)
	if int(level.get("minimum_protected_trees", 0)) > seen_cells.size():
		problems.append("minimum_protected_trees exceeds the number of distinct tree cells (%d)" % seen_cells.size())


static func _validate_waves(level: Dictionary, enemies: Dictionary,
		problems: Array[String]) -> void:
	var lanes := int(level.get("lanes", 0))
	var last_at := -INF
	for index in (level.get("waves", []) as Array).size():
		var wave: Dictionary = level["waves"][index]
		var enemy_id := String(wave.get("enemy", ""))
		if not enemies.has(enemy_id):
			problems.append("wave %d references unknown enemy '%s'" % [index, enemy_id])
		var lane := int(wave.get("lane", -1))
		if lane < 0 or lane >= lanes:
			problems.append("wave %d lane %d out of range (0..%d)" % [index, lane, lanes - 1])
		var at := float(wave.get("at", 0.0))
		if at < last_at:
			problems.append("wave %d time %.2f earlier than previous wave %.2f" % [index, at, last_at])
		last_at = at


static func _validate_deck(level: Dictionary, units: Dictionary,
		problems: Array[String]) -> void:
	for entry in level.get("deck", []):
		var unit_id := String(entry)
		if not units.has(unit_id):
			problems.append("deck references unknown unit '%s'" % unit_id)


static func _validate_recipes(units: Dictionary, recipes: Array,
		problems: Array[String]) -> void:
	for index in recipes.size():
		var recipe: Dictionary = recipes[index]
		for key in ["input_a", "input_b", "result"]:
			var unit_id := String(recipe.get(key, ""))
			if not units.has(unit_id):
				problems.append("recipe %d ('%s') %s references unknown unit '%s'"
						% [index, String(recipe.get("id", "")), key, unit_id])
