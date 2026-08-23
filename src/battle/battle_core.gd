class_name BattleCore
extends RefCounted
## Formal battle core for the Playable Prototype (H2+H3).
## Headless-testable: no scene/UI dependencies. UI only calls these APIs.
##
## Win condition: all waves spawned and every enemy defeated, and the
## protected-tree objective met.
## Lose condition: any enemy crosses a lane finish line without insurance,
## or protected trees fall below the required minimum.

signal state_changed

var board: BoardState
var wallet: ResourceWallet
var catalog: UnitCatalog
var recipe_book: RecipeBook
var waves: WaveSystem
var enemy_definitions: Dictionary = {}

var minimum_protected_trees := 0
var outcome := "ongoing"  # ongoing | victory | defeat


func _init(level: Dictionary) -> void:
	var columns := int(level.get("columns", 9))
	board = BoardState.new(columns)
	wallet = ResourceWallet.new(int(level.get("initial_resource", 450)))
	catalog = UnitCatalog.new()
	recipe_book = RecipeBook.new()
	waves = WaveSystem.new()
	minimum_protected_trees = int(level.get("minimum_protected_trees", 0))
	for tree in level.get("protected_trees", []):
		board.place_protected_tree(
				String(tree["id"]), Vector2i(int(tree["column"]), int(tree["lane"])),
				int(tree.get("health", 100)))


func load_data(units_json: Dictionary, recipes_json: Dictionary,
		enemies_json: Dictionary) -> void:
	catalog.load_definitions(units_json)
	recipe_book.load_recipes(recipes_json)
	for entry in enemies_json.get("enemies", []):
		if entry is Dictionary and entry.has("id"):
			enemy_definitions[String(entry["id"])] = entry.duplicate(true)


func start(waves_array: Array) -> void:
	waves.setup(waves_array)


# --- Deployment -------------------------------------------------------------

func deploy(unit_id: String, cell: Vector2i) -> Dictionary:
	if outcome != "ongoing":
		return _rejected("battle_over")
	var def := catalog.definition(unit_id)
	if def.is_empty():
		return _rejected("unknown_unit")
	if not board.is_inside(cell):
		return _rejected("invalid_cell")
	if not board.is_empty(cell):
		return _rejected("cell_occupied")
	if not wallet.can_afford(int(def["cost"])):
		return _rejected("insufficient_resource")
	var unit_state := catalog.create_runtime_state(unit_id)
	board.place_unit(cell, unit_state)
	wallet.spend(int(def["cost"]))
	state_changed.emit()
	return {"ok": true, "kind": "deploy", "cell": cell, "unit_id": unit_id}


# --- Fusion / upgrade -------------------------------------------------------

func merge_cells(source: Vector2i, target: Vector2i) -> Dictionary:
	if outcome != "ongoing":
		return _rejected("battle_over")
	if source == target:
		return _rejected("same_cell")
	var source_state := board.cell_state(source)
	var target_state := board.cell_state(target)
	if String(source_state.get("kind", "")) != "unit" or String(target_state.get("kind", "")) != "unit":
		return _rejected("missing_unit")
	var recipe := recipe_book.find_recipe(String(source_state["unit_id"]), String(target_state["unit_id"]))
	if recipe.is_empty():
		return _rejected("illegal_recipe")
	var merge_cost := int(recipe["resource_cost"])
	if not wallet.can_afford(merge_cost):
		return _rejected("insufficient_resource")

	var result_def := catalog.definition(String(recipe["result"]))
	var source_def := catalog.definition(String(source_state["unit_id"]))
	var target_def := catalog.definition(String(target_state["unit_id"]))
	# State inheritance: keep the WORSE health ratio and LONGER cooldown so a
	# fusion never grants free healing or skill refreshes.
	var source_ratio := float(source_state["current_health"]) / float(source_def["max_health"])
	var target_ratio := float(target_state["current_health"]) / float(target_def["max_health"])
	var result_state := catalog.create_runtime_state(String(recipe["result"]))
	result_state["current_health"] = maxi(1,
			int(round(float(result_def["max_health"]) * minf(source_ratio, target_ratio))))
	result_state["attack_cooldown_remaining"] = maxf(
			float(source_state["attack_cooldown_remaining"]),
			float(target_state["attack_cooldown_remaining"]))
	result_state["shots_fired"] = int(source_state["shots_fired"]) + int(target_state["shots_fired"])

	board.remove_unit(source)
	board.remove_unit(target)
	board.place_unit(target, result_state)  # two cells collapse into one
	wallet.spend(merge_cost)
	state_changed.emit()
	return {
		"ok": true, "kind": String(recipe["kind"]), "recipe_id": String(recipe["id"]),
		"source_cell": source, "target_cell": target,
		"result_unit": String(recipe["result"]),
	}


func preview_merge(source: Vector2i, target: Vector2i) -> Dictionary:
	"""UI helper: legality + result id without mutating state."""
	if source == target:
		return {"legal": false, "reason": "same_cell"}
	var source_state := board.cell_state(source)
	var target_state := board.cell_state(target)
	if String(source_state.get("kind", "")) != "unit" or String(target_state.get("kind", "")) != "unit":
		return {"legal": false, "reason": "missing_unit"}
	var recipe := recipe_book.find_recipe(String(source_state["unit_id"]), String(target_state["unit_id"]))
	if recipe.is_empty():
		return {"legal": false, "reason": "illegal_recipe"}
	return {"legal": true, "result": String(recipe["result"]),
			"cost": int(recipe["resource_cost"])}


# --- Simulation tick --------------------------------------------------------

func tick(delta: float) -> void:
	if outcome != "ongoing":
		return
	waves.tick(delta, float(board.columns), enemy_definitions)

	# Enemies act first.
	for enemy in waves.active_enemies:
		if enemy.defeated or enemy.crossed_finish:
			continue
		if not _enemy_attack(enemy, delta):
			enemy.advance(delta)
		if enemy.crossed_finish:
			enemy.insurance_triggered = board.consume_insurance(enemy.lane)
			if enemy.insurance_triggered:
				for lane_enemy in waves.active_enemies:
					if lane_enemy.lane == enemy.lane:
						lane_enemy.defeated = true
				enemy.defeated = true

	units_tick(delta)

	# Outcome evaluation.
	var trees_met := board.protected_objective_met(minimum_protected_trees)
	if not trees_met or board.alive_protected_count() < minimum_protected_trees:
		outcome = "defeat"
	elif waves.active_enemies.any(func(e: EnemyState) -> bool: return e.crossed_finish and not e.insurance_triggered):
		outcome = "defeat"
	elif waves.is_finished() and waves.alive_count() == 0:
		outcome = "victory"
	if outcome != "ongoing":
		state_changed.emit()


func _enemy_attack(enemy: EnemyState, delta: float) -> bool:
	var acted := false
	if enemy.prefers_protected_tree:
		for tree_cell in board.protected_positions():
			var tree := board.protected_target_at(tree_cell)
			if tree_cell.y == enemy.lane and bool(tree.get("alive", false)) \
					and absf(enemy.progress_column - float(tree_cell.x)) <= 0.55:
				_enemy_swing(enemy, delta, func() -> void:
					board.damage_protected_tree_at(tree_cell, enemy.attack_damage))
				acted = true
				break
	if acted:
		return true
	for unit_cell in board.unit_positions():
		if unit_cell.y != enemy.lane:
			continue
		var distance := enemy.progress_column - float(unit_cell.x)
		if distance >= -0.1 and distance <= 0.55:
			_enemy_swing(enemy, delta, func() -> void:
				var state := board.cell_state(unit_cell)
				state["current_health"] = maxi(0, int(state["current_health"]) - enemy.attack_damage)
				if int(state["current_health"]) == 0:
					board.remove_unit(unit_cell)
				else:
					board.set_cell_state(unit_cell, state))
			return true
	return false


func _enemy_swing(enemy: EnemyState, delta: float, on_hit: Callable) -> void:
	enemy.attack_cooldown_remaining -= delta
	if enemy.attack_cooldown_remaining <= 0.0:
		on_hit.call()
		enemy.attack_cooldown_remaining = enemy.attack_period


func units_tick(delta: float) -> void:
	for unit_cell in board.unit_positions():
		var state := board.cell_state(unit_cell)
		var def := catalog.definition(String(state["unit_id"]))
		state["attack_cooldown_remaining"] = maxf(0.0, float(state["attack_cooldown_remaining"]) - delta)
		if float(state["attack_cooldown_remaining"]) > 0.0:
			board.set_cell_state(unit_cell, state)
			continue
		var selected_enemy: EnemyState = null
		var nearest := INF
		for enemy in waves.active_enemies:
			if enemy.defeated or enemy.crossed_finish or enemy.lane != unit_cell.y:
				continue
			var distance := float(enemy.progress_column) - float(unit_cell.x)
			if distance >= 0.0 and distance <= float(def["range_cells"]) and distance < nearest:
				nearest = distance
				selected_enemy = enemy
		if selected_enemy != null:
			selected_enemy.take_damage(_unit_attack_damage(def, state, nearest))
			state["shots_fired"] = int(state["shots_fired"]) + 1
			state["attack_cooldown_remaining"] = float(def["attack_period"])
		board.set_cell_state(unit_cell, state)


func _unit_attack_damage(def: Dictionary, state: Dictionary, nearest_distance: float) -> int:
	var behavior := String(def.get("behavior", ""))
	match behavior:
		"single_ranged":
			return int(def["damage"])
		"double_ranged":
			# Two quick shots per attack cycle.
			return int(def["damage"]) * int(def.get("burst_count", 1))
		"double_ranged_with_periodic_heavy":
			var total := int(def["damage"]) * int(def.get("burst_count", 1))
			if int(state["shots_fired"]) % int(def.get("heavy_every", 3)) == 0:
				total += int(def.get("heavy_damage", 18))
			return total
		"melee_guard":
			return int(def["damage"])
		"ranged_plus_guard_collaboration":
			# AB collaboration: ranged poke plus a melee guard strike when an
			# enemy is adjacent — not a plain numeric sum of A + B.
			var total := int(def["damage"])
			if nearest_distance <= 1.0:
				total += int(def.get("guard_damage", 16))
			return total
	return int(def["damage"])


func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
