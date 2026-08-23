class_name BattleState
extends RefCounted

const UNDO_WINDOW_MS := 3000

var board: BoardState
var resource: int
var catalog := UnitCatalog.new()
var recipe_book := RecipeBook.new()
var transition_log: Array[Dictionary] = []
var last_merge_receipt: Dictionary = {}
var level_failed := false


func _init(p_lanes: int = 5, p_columns: int = 9, initial_resource: int = 450) -> void:
	board = BoardState.new(p_lanes, p_columns)
	resource = initial_resource


func deploy(unit_id: String, cell: Vector2i) -> Dictionary:
	var definition := catalog.definition(unit_id)
	if definition.is_empty():
		return _rejected("unknown_unit")
	if not board.is_empty(cell):
		return _rejected("cell_occupied")
	var cost := int(definition["cost"])
	if resource < cost:
		return _rejected("insufficient_resource")
	var before_resource := resource
	var unit_state := catalog.create_runtime_state(unit_id)
	if not board.place_unit(cell, unit_state):
		return _rejected("invalid_cell")
	resource -= cost
	var transition := {
		"ok": true, "kind": "deploy", "cell": cell, "unit_id": unit_id,
		"resource_before": before_resource, "resource_after": resource
	}
	transition_log.append(transition.duplicate(true))
	return transition


func merge_cells(source: Vector2i, target: Vector2i, now_ms: int = -1) -> Dictionary:
	if source == target:
		return _rejected("same_cell")
	var source_state := board.cell_state(source)
	var target_state := board.cell_state(target)
	if source_state.get("kind", "") != "unit" or target_state.get("kind", "") != "unit":
		return _rejected("missing_unit")
	var recipe := recipe_book.find_recipe(source_state["unit_id"], target_state["unit_id"])
	if recipe.is_empty():
		return _rejected("illegal_recipe")
	var merge_cost := int(recipe["resource_cost"])
	if resource < merge_cost:
		return _rejected("insufficient_resource")

	var result_definition := catalog.definition(recipe["result"])
	var source_definition := catalog.definition(source_state["unit_id"])
	var target_definition := catalog.definition(target_state["unit_id"])
	var source_health_ratio := float(source_state["current_health"]) / float(source_definition["max_health"])
	var target_health_ratio := float(target_state["current_health"]) / float(target_definition["max_health"])
	var preserved_health_ratio := minf(source_health_ratio, target_health_ratio)
	var result_state := catalog.create_runtime_state(recipe["result"])
	result_state["current_health"] = maxi(1, int(round(float(result_definition["max_health"]) * preserved_health_ratio)))
	result_state["attack_cooldown_remaining"] = maxf(
		float(source_state["attack_cooldown_remaining"]),
		float(target_state["attack_cooldown_remaining"])
	)
	result_state["shots_fired"] = int(source_state["shots_fired"]) + int(target_state["shots_fired"])

	var before_resource := resource
	board.remove_unit(source)
	board.remove_unit(target)
	board.place_unit(target, result_state)
	resource -= merge_cost
	var effective_now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	last_merge_receipt = {
		"ok": true,
		"kind": recipe["kind"],
		"recipe_id": recipe["id"],
		"source_cell": source,
		"target_cell": target,
		"before_source": source_state,
		"before_target": target_state,
		"after_target": result_state.duplicate(true),
		"resource_before": before_resource,
		"resource_after": resource,
		"undo_deadline_ms": effective_now + UNDO_WINDOW_MS,
		"undo_implemented": false
	}
	transition_log.append(last_merge_receipt.duplicate(true))
	return last_merge_receipt.duplicate(true)


func undo_window_open(now_ms: int = -1) -> bool:
	if last_merge_receipt.is_empty():
		return false
	var effective_now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	return effective_now <= int(last_merge_receipt["undo_deadline_ms"])


func undo_last_merge(_now_ms: int = -1) -> Dictionary:
	return _rejected("undo_not_implemented_in_poc")


func add_protected_tree(target_id: String, cell: Vector2i, health: int = 100) -> bool:
	return board.place_protected_tree(target_id, cell, health)


func tick(delta: float, enemies: Array) -> void:
	_tick_enemies(delta, enemies)
	_tick_units(delta, enemies)


func _tick_enemies(delta: float, enemies: Array) -> void:
	for enemy in enemies:
		if enemy.defeated or enemy.crossed_finish:
			continue
		var attacked := false
		if enemy.prefers_protected_tree:
			for tree_cell in board.protected_positions():
				var tree := board.protected_target_at(tree_cell)
				if tree_cell.y == enemy.lane and tree["alive"] and absf(enemy.progress_column - float(tree_cell.x)) <= 0.55:
					enemy.attack_cooldown_remaining -= delta
					if enemy.attack_cooldown_remaining <= 0.0:
						board.damage_protected_tree_at(tree_cell, enemy.attack_damage)
						enemy.attack_cooldown_remaining = enemy.attack_period
					attacked = true
					break
		if not attacked:
			for unit_cell in board.unit_positions():
				if unit_cell.y != enemy.lane:
					continue
				var distance: float = float(enemy.progress_column) - float(unit_cell.x)
				if distance >= -0.1 and distance <= 0.55:
					var state := board.cell_state(unit_cell)
					enemy.attack_cooldown_remaining -= delta
					if enemy.attack_cooldown_remaining <= 0.0:
						state["current_health"] = maxi(0, int(state["current_health"]) - enemy.attack_damage)
						enemy.attack_cooldown_remaining = enemy.attack_period
						if int(state["current_health"]) == 0:
							board.remove_unit(unit_cell)
						else:
							board.set_cell_state(unit_cell, state)
					attacked = true
					break
		if not attacked:
			enemy.advance(delta)
		if enemy.crossed_finish:
			enemy.insurance_triggered = board.consume_insurance(enemy.lane)
			if enemy.insurance_triggered:
				for lane_enemy in enemies:
					if lane_enemy.lane == enemy.lane:
						lane_enemy.defeated = true
			else:
				level_failed = true


func _tick_units(delta: float, enemies: Array) -> void:
	for unit_cell in board.unit_positions():
		var state := board.cell_state(unit_cell)
		var definition := catalog.definition(state["unit_id"])
		state["attack_cooldown_remaining"] = maxf(0.0, float(state["attack_cooldown_remaining"]) - delta)
		if float(state["attack_cooldown_remaining"]) > 0.0:
			board.set_cell_state(unit_cell, state)
			continue
		var selected_enemy = null
		var nearest_distance := INF
		for enemy in enemies:
			if enemy.defeated or enemy.crossed_finish or enemy.lane != unit_cell.y:
				continue
			var distance: float = float(enemy.progress_column) - float(unit_cell.x)
			if distance >= 0.0 and distance <= float(definition["range_cells"]) and distance < nearest_distance:
				nearest_distance = distance
				selected_enemy = enemy
		if selected_enemy != null:
			var total_damage := int(definition["damage"]) * int(definition["burst_count"])
			if definition["behavior"] == "ranged_plus_guard_collaboration" and nearest_distance <= 1.0:
				total_damage += int(definition["guard_damage"])
			state["shots_fired"] = int(state["shots_fired"]) + 1
			if definition.has("heavy_every") and int(state["shots_fired"]) % int(definition["heavy_every"]) == 0:
				total_damage += 18
			selected_enemy.take_damage(total_damage)
			state["attack_cooldown_remaining"] = float(definition["attack_period"])
		board.set_cell_state(unit_cell, state)


func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
