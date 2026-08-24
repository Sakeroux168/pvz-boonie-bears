class_name BattleSession
extends RefCounted

const STATE_RUNNING := "running"
const STATE_VICTORY := "victory"
const STATE_FAILURE := "failure"
const UNDO_WINDOW_MS := 3000

var repository: GameDataRepository
var board: BoardState
var resources: ResourcePool
var fusion: FusionService
var tree_rule: ProtectedTreeRule
var enemies: Array[EnemyState] = []
var level: Dictionary = {}
var state := STATE_RUNNING
var elapsed := 0.0
var next_wave_index := 0
var last_merge_receipt: Dictionary = {}

func _init(p_repository: GameDataRepository, level_override: Dictionary = {}) -> void:
	repository = p_repository
	level = level_override.duplicate(true) if not level_override.is_empty() else repository.level.duplicate(true)
	board = BoardState.new(int(level.get("lanes", 5)), int(level.get("columns", 9)))
	resources = ResourcePool.new(int(level.get("initial_resource", 450)))
	fusion = FusionService.new(repository)
	tree_rule = ProtectedTreeRule.new(int(level.get("minimum_protected_trees", 0)))
	for tree in level.get("protected_trees", []):
		board.place_tree(String(tree.get("id", "")), Vector2i(int(tree.get("column", 0)), int(tree.get("lane", 0))), int(tree.get("health", 100)))

func deploy(unit_id: String, cell: Vector2i) -> Dictionary:
	if state != STATE_RUNNING:
		return _reject("battle_not_running")
	var definition := repository.unit_def(unit_id)
	if definition.is_empty():
		return _reject("unknown_unit")
	if not board.is_inside(cell):
		return _reject("invalid_cell")
	if not board.is_empty(cell):
		return _reject("cell_occupied")
	var cost := int(definition.get("cost", 0))
	if not resources.can_spend(cost):
		return _reject("insufficient_resource")
	var unit := UnitState.from_definition(definition)
	if not board.place_unit(cell, unit):
		return _reject("invalid_cell")
	resources.spend(cost)
	return {"ok": true, "kind": "deploy", "unit_id": unit_id, "cell": cell}

func merge_cells(source: Vector2i, target: Vector2i, now_ms: int = -1) -> Dictionary:
	if state != STATE_RUNNING:
		return _reject("battle_not_running")
	if source == target:
		return _reject("same_cell")
	var source_unit = board.cell_value(source)
	var target_unit = board.cell_value(target)
	if source_unit is not UnitState or target_unit is not UnitState:
		return _reject("missing_unit")
	var recipe := fusion.preview(source_unit.unit_id, target_unit.unit_id)
	if recipe.is_empty():
		return _reject("illegal_recipe")
	var cost := int(recipe.get("resource_cost", 0))
	if not resources.can_spend(cost):
		return _reject("insufficient_resource")
	var result_def := repository.unit_def(String(recipe.get("result", "")))
	if result_def.is_empty():
		return _reject("unknown_result")
	var result := UnitState.from_definition(result_def)
	var preserved_ratio := minf(source_unit.health_ratio(), target_unit.health_ratio())
	result.health = maxi(1, int(round(float(result.max_health) * preserved_ratio)))
	result.attack_cooldown = maxf(source_unit.attack_cooldown, target_unit.attack_cooldown)
	result.shots_fired = source_unit.shots_fired + target_unit.shots_fired
	var before_resource := resources.amount
	board.remove_unit(source)
	board.remove_unit(target)
	board.place_unit(target, result)
	resources.spend(cost)
	var effective_now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	last_merge_receipt = {"ok": true,"recipe_id": recipe.get("id", ""),"kind": recipe.get("kind", ""),"result": result.unit_id,"source_cell": source,"target_cell": target,"resource_before": before_resource,"resource_after": resources.amount,"undo_deadline_ms": effective_now + UNDO_WINDOW_MS,"undo_implemented": false}
	return last_merge_receipt.duplicate(true)

func tick(delta: float) -> void:
	if state != STATE_RUNNING:
		return
	elapsed += delta
	_spawn_due_waves()
	_tick_enemies(delta)
	if state != STATE_RUNNING:
		_cleanup_enemies()
		return
	_tick_units(delta)
	_cleanup_enemies()
	if not tree_rule.is_met(board):
		state = STATE_FAILURE
		return
	var waves: Array = level.get("waves", [])
	if next_wave_index >= waves.size() and enemies.is_empty():
		state = STATE_VICTORY

func _spawn_due_waves() -> void:
	var waves: Array = level.get("waves", [])
	while next_wave_index < waves.size():
		var wave: Dictionary = waves[next_wave_index]
		if float(wave.get("at", 0.0)) > elapsed:
			break
		_spawn_enemy_from_wave(wave)
		next_wave_index += 1

func _spawn_enemy_from_wave(wave: Dictionary) -> void:
	var definition := repository.enemy_def(String(wave.get("enemy", "")))
	if definition.is_empty():
		push_error("Unknown enemy in wave: %s" % wave.get("enemy", ""))
		return
	if wave.has("health_override"):
		definition["max_health"] = int(wave["health_override"])
	if wave.has("speed_override"):
		definition["move_speed"] = float(wave["speed_override"])
	if wave.has("attack_damage_override"):
		definition["attack_damage"] = int(wave["attack_damage_override"])
	var start_column := float(wave.get("start_column_override", float(board.columns) + 0.35))
	enemies.append(EnemyState.from_definition(definition, int(wave.get("lane", 0)), start_column))

func _tick_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy.defeated or enemy.crossed_finish:
			continue
		var attacked := false
		if enemy.prefers_tree:
			for tree_cell in board.tree_positions():
				var tree := board.tree_at(tree_cell)
				if tree_cell.y == enemy.lane and bool(tree.get("alive", false)) and absf(enemy.progress_column - float(tree_cell.x)) <= 0.55:
					enemy.attack_cooldown -= delta
					if enemy.attack_cooldown <= 0.0:
						board.damage_tree(tree_cell, enemy.attack_damage)
						enemy.attack_cooldown = enemy.attack_period
					attacked = true
					break
		if not attacked:
			for unit_cell in board.unit_positions():
				if unit_cell.y != enemy.lane:
					continue
				var distance := enemy.progress_column - float(unit_cell.x)
				if distance >= -0.1 and distance <= 0.55:
					var unit: UnitState = board.cell_value(unit_cell)
					enemy.attack_cooldown -= delta
					if enemy.attack_cooldown <= 0.0:
						unit.health = maxi(0, unit.health - enemy.attack_damage)
						enemy.attack_cooldown = enemy.attack_period
						if unit.health == 0:
							board.remove_unit(unit_cell)
					attacked = true
					break
		if not attacked:
			enemy.advance(delta)
		if enemy.crossed_finish:
			if board.consume_insurance(enemy.lane):
				for lane_enemy in enemies:
					if lane_enemy.lane == enemy.lane:
						lane_enemy.defeated = true
			else:
				state = STATE_FAILURE
				return

func _tick_units(delta: float) -> void:
	for unit_cell in board.unit_positions():
		var unit: UnitState = board.cell_value(unit_cell)
		var definition := repository.unit_def(unit.unit_id)
		unit.attack_cooldown = maxf(0.0, unit.attack_cooldown - delta)
		if unit.attack_cooldown > 0.0:
			continue
		var selected: EnemyState = null
		var nearest := INF
		for enemy in enemies:
			if enemy.defeated or enemy.crossed_finish or enemy.lane != unit_cell.y:
				continue
			var distance := enemy.progress_column - float(unit_cell.x)
			if distance >= 0.0 and distance <= float(definition.get("range_cells", 1.0)) and distance < nearest:
				nearest = distance
				selected = enemy
		if selected == null:
			continue
		var damage := int(definition.get("damage", 0)) * int(definition.get("burst_count", 1))
		if String(definition.get("behavior", "")) == "ranged_plus_guard_collaboration" and nearest <= 1.0:
			damage += int(definition.get("guard_damage", 0))
		unit.shots_fired += 1
		var heavy_every := int(definition.get("heavy_every", 0))
		if heavy_every > 0 and unit.shots_fired % heavy_every == 0:
			damage += int(definition.get("heavy_damage", 0))
		selected.take_damage(damage)
		unit.attack_cooldown = float(definition.get("attack_period", 1.0))

func _cleanup_enemies() -> void:
	enemies = enemies.filter(func(enemy): return not enemy.defeated and not enemy.crossed_finish)

func fusion_preview(source: Vector2i, target: Vector2i) -> Dictionary:
	var a = board.cell_value(source)
	var b = board.cell_value(target)
	if a is not UnitState or b is not UnitState:
		return {}
	return fusion.preview(a.unit_id, b.unit_id)

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
