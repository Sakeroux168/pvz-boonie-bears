class_name LevelValidator
extends RefCounted
## Minimal schema/reference validation for level + data files (H4A-3).
## Fails loud with a list of problems instead of letting bad config silently
## run into a fake victory or a broken board. No external schema library.

const FIXED_LANES := 5
const MIN_COLUMNS := 1
const MAX_COLUMNS := 20
const LEVEL_DIRECTORY := "res://src/data/levels"
const ATTACKING_BEHAVIORS := {
	"single_ranged": true,
	"double_ranged": true,
	"double_ranged_with_periodic_heavy": true,
	"melee_guard": true,
	"ranged_plus_guard_collaboration": true,
}


static func validate(level: Dictionary, units: Dictionary,
		enemies: Dictionary, recipes: Array) -> Array[String]:
	var problems: Array[String] = []
	_validate_grid(level, problems)
	_validate_resources(level, problems)
	_validate_trees(level, problems)
	_validate_waves(level, enemies, problems)
	_validate_deck(level, units, problems)
	_validate_units(units, problems)
	_validate_enemies(enemies, problems)
	_validate_recipes(units, recipes, problems)
	_validate_enabled_recipe_ids(level, recipes, problems)
	_validate_progression(level, problems)
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


static func _validate_resources(level: Dictionary, problems: Array[String]) -> void:
	if int(level.get("initial_resource", -1)) < 0:
		problems.append("initial_resource must be >= 0 (got %s)" % str(level.get("initial_resource")))


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
		# H4B-0: wave times must be non-negative.
		if at < 0.0:
			problems.append("wave %d time must be >= 0 (got %.2f)" % [index, at])
		if at < last_at:
			problems.append("wave %d time %.2f earlier than previous wave %.2f" % [index, at, last_at])
		last_at = at
		# H4B-0: numeric override sanity. A negative start_column_override
		# spawns the enemy past the finish line, instantly triggering
		# insurance/failure — fail loud here instead. Positive on-board spawns
		# stay legal (may become a legitimate level design later); only
		# negatives are rejected.
		if wave.has("start_column_override") and float(wave["start_column_override"]) < 0.0:
			problems.append("wave %d start_column_override must be >= 0 (got %s)"
					% [index, str(wave["start_column_override"])])
		if wave.has("health_override") and int(wave["health_override"]) <= 0:
			problems.append("wave %d health_override must be > 0 (got %s)"
					% [index, str(wave["health_override"])])
		if wave.has("speed_override") and float(wave["speed_override"]) < 0.0:
			problems.append("wave %d speed_override must be >= 0 (got %s)"
					% [index, str(wave["speed_override"])])
		if wave.has("attack_damage_override") and int(wave["attack_damage_override"]) < 0:
			problems.append("wave %d attack_damage_override must be >= 0 (got %s)"
					% [index, str(wave["attack_damage_override"])])


# H4B-0: numeric sanity for unit/enemy/recipe definitions so a typo'd data
# file fails at load instead of producing unkillable enemies or free deploys.
static func _validate_units(units: Dictionary, problems: Array[String]) -> void:
	for unit_id in units:
		var def: Dictionary = units[unit_id]
		if int(def.get("cost", 0)) < 0:
			problems.append("unit '%s' cost must be >= 0 (got %s)" % [unit_id, str(def.get("cost"))])
		if int(def.get("max_health", 0)) <= 0:
			problems.append("unit '%s' max_health must be > 0 (got %s)" % [unit_id, str(def.get("max_health"))])
		var behavior := String(def.get("behavior", ""))
		if not ATTACKING_BEHAVIORS.has(behavior):
			continue
		if float(def.get("range_cells", -1.0)) < 0.0:
			problems.append("attacking unit '%s' range_cells must be >= 0 (got %s)" % [unit_id, str(def.get("range_cells"))])
		if float(def.get("attack_period", 0.0)) <= 0.0:
			problems.append("attacking unit '%s' attack_period must be > 0 (got %s)" % [unit_id, str(def.get("attack_period"))])
		if int(def.get("damage", -1)) < 0:
			problems.append("attacking unit '%s' damage must be >= 0 (got %s)" % [unit_id, str(def.get("damage"))])
		if int(def.get("burst_count", 0)) < 1:
			problems.append("attacking unit '%s' burst_count must be >= 1 (got %s)" % [unit_id, str(def.get("burst_count"))])
		if behavior == "double_ranged_with_periodic_heavy":
			if int(def.get("heavy_every", 0)) < 1:
				problems.append("unit '%s' heavy_every must be >= 1 (got %s)" % [unit_id, str(def.get("heavy_every"))])
			if int(def.get("heavy_damage", -1)) < 0:
				problems.append("unit '%s' heavy_damage must be >= 0 (got %s)" % [unit_id, str(def.get("heavy_damage"))])
		if behavior == "ranged_plus_guard_collaboration" \
				and int(def.get("guard_damage", -1)) < 0:
			problems.append("unit '%s' guard_damage must be >= 0 (got %s)" % [unit_id, str(def.get("guard_damage"))])


static func _validate_enemies(enemies: Dictionary, problems: Array[String]) -> void:
	for enemy_id in enemies:
		var def: Dictionary = enemies[enemy_id]
		if int(def.get("max_health", 0)) <= 0:
			problems.append("enemy '%s' max_health must be > 0 (got %s)" % [enemy_id, str(def.get("max_health"))])
		if float(def.get("move_speed", 0)) < 0.0:
			problems.append("enemy '%s' move_speed must be >= 0 (got %s)" % [enemy_id, str(def.get("move_speed"))])
		if int(def.get("attack_damage", 0)) < 0:
			problems.append("enemy '%s' attack_damage must be >= 0 (got %s)" % [enemy_id, str(def.get("attack_damage"))])
		if float(def.get("attack_period", 0)) <= 0.0:
			problems.append("enemy '%s' attack_period must be > 0 (got %s)" % [enemy_id, str(def.get("attack_period"))])


static func _validate_deck(level: Dictionary, units: Dictionary,
		problems: Array[String]) -> void:
	for entry in level.get("deck", []):
		var unit_id := String(entry)
		if not units.has(unit_id):
			problems.append("deck references unknown unit '%s'" % unit_id)


static func _validate_recipes(units: Dictionary, recipes: Array,
		problems: Array[String]) -> void:
	var seen_ids := {}
	for index in recipes.size():
		var recipe: Dictionary = recipes[index]
		var recipe_id := ""
		if recipe.get("id") is String:
			recipe_id = String(recipe["id"])
		if recipe_id.strip_edges().is_empty():
			problems.append("recipe %d id must be a non-empty String" % index)
		elif seen_ids.has(recipe_id):
			problems.append("recipe id '%s' duplicated" % recipe_id)
		else:
			seen_ids[recipe_id] = true
		for key in ["input_a", "input_b", "result"]:
			var unit_id := String(recipe.get(key, ""))
			if not units.has(unit_id):
				problems.append("recipe %d ('%s') %s references unknown unit '%s'"
						% [index, recipe_id, key, unit_id])
		if int(recipe.get("resource_cost", 0)) < 0:
			problems.append("recipe %d ('%s') resource_cost must be >= 0 (got %s)"
					% [index, recipe_id, str(recipe.get("resource_cost"))])


static func _validate_enabled_recipe_ids(level: Dictionary, recipes: Array,
		problems: Array[String]) -> void:
	# Missing is the compatibility contract: old levels allow every recipe.
	if not level.has("enabled_recipe_ids"):
		return
	var raw_ids: Variant = level["enabled_recipe_ids"]
	if not raw_ids is Array:
		problems.append("enabled_recipe_ids must be an Array when present")
		return
	var known_ids := {}
	for recipe in recipes:
		var raw_recipe_id: Variant = recipe.get("id")
		if raw_recipe_id is String and not String(raw_recipe_id).is_empty():
			known_ids[String(raw_recipe_id)] = true
	var seen_ids := {}
	for index in raw_ids.size():
		var raw_id: Variant = raw_ids[index]
		if not raw_id is String or String(raw_id).strip_edges().is_empty():
			problems.append("enabled_recipe_ids[%d] must be a non-empty String" % index)
			continue
		var recipe_id := String(raw_id)
		if seen_ids.has(recipe_id):
			problems.append("enabled_recipe_ids contains duplicate '%s'" % recipe_id)
		else:
			seen_ids[recipe_id] = true
		if not known_ids.has(recipe_id):
			problems.append("enabled_recipe_ids references unknown recipe '%s'" % recipe_id)


static func _validate_progression(level: Dictionary, problems: Array[String]) -> void:
	if not level.has("next_level_id"):
		return
	var raw_id: Variant = level["next_level_id"]
	if not raw_id is String or String(raw_id).is_empty():
		problems.append("next_level_id must be a non-empty String when present")
		return
	var next_level_id := String(raw_id)
	if next_level_id.contains("/") or next_level_id.contains("\\") or next_level_id.contains(".."):
		problems.append("next_level_id must be a plain level id (got '%s')" % next_level_id)
		return
	var next_path := "%s/%s.json" % [LEVEL_DIRECTORY, next_level_id]
	if not FileAccess.file_exists(next_path):
		problems.append("next_level_id references missing level '%s'" % next_level_id)
