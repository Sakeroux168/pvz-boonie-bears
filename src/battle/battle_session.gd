class_name BattleSession
extends RefCounted

const STATE_RUNNING := "running"
const STATE_VICTORY := "victory"
const STATE_FAILURE := "failure"
const STATE_CONFIG_ERROR := "config_error"
# Maximum distance an enemy may travel within one combat substep. The melee
# contact window is 0.65 cells wide, so capping substep movement below that
# guarantees a fast enemy can never tunnel past a blocker in a single frame.
const MAX_SUBSTEP_TRAVEL := 0.5
const UNDO_WINDOW_MS := 3000

var repository: GameDataRepository
var board: BoardState
var resources: ResourcePool
var fusion: FusionService
var tree_rule: ProtectedTreeRule
# Level-scoped recipe gate (GPT review on PR #8): recipes not in this list are
# illegal in this level. Missing/empty field means "no recipes enabled" only if
# the key exists; absent key keeps the legacy allow-all behaviour so the old
# level_playable.json regression fixture still teaches upgrades/fusion.
var enabled_recipe_ids: Dictionary = {}
var recipe_gate_active := false
var enemies: Array[EnemyState] = []
var level: Dictionary = {}
var state := STATE_RUNNING
var elapsed := 0.0
var next_wave_index := 0
var last_merge_receipt: Dictionary = {}

func _init(p_repository: GameDataRepository, level_override: Dictionary = {}) -> void:
	repository = p_repository
	level = level_override.duplicate(true) if not level_override.is_empty() else repository.level.duplicate(true)
	if level.has("enabled_recipe_ids"):
		recipe_gate_active = true
		_configure_recipe_gate(level["enabled_recipe_ids"])
	board = BoardState.new(int(level.get("lanes", 5)), int(level.get("columns", 9)))
	resources = ResourcePool.new(int(level.get("initial_resource", 450)))
	fusion = FusionService.new(repository)
	tree_rule = ProtectedTreeRule.new(int(level.get("minimum_protected_trees", 0)))
	for tree in level.get("protected_trees", []):
		board.place_tree(String(tree.get("id", "")), Vector2i(int(tree.get("column", 0)), int(tree.get("lane", 0))), int(tree.get("health", 100)))

func _configure_recipe_gate(raw_gate: Variant) -> void:
	# GameDataRepository validates shipped files, but BattleSession also has a
	# public level_override path used by tools/tests. Keep this boundary safe
	# without duplicating the full level schema validator.
	if not raw_gate is Array:
		_fail_config("enabled_recipe_ids must be an Array when present")
		return
	var allowed_ids: Array = raw_gate
	for index in allowed_ids.size():
		var raw_id: Variant = allowed_ids[index]
		if not raw_id is String or String(raw_id).strip_edges().is_empty():
			_fail_config("enabled_recipe_ids[%d] must be a non-empty String" % index)
			return
		enabled_recipe_ids[String(raw_id)] = true

func _fail_config(message: String) -> void:
	state = STATE_CONFIG_ERROR
	enabled_recipe_ids.clear()
	push_error("BattleSession config error: %s" % message)

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

func play_card(unit_id: String, target: Vector2i, now_ms: int = -1) -> Dictionary:
	if state != STATE_RUNNING:
		return _reject("battle_not_running")
	var definition := repository.unit_def(unit_id)
	if definition.is_empty():
		return _reject("unknown_unit")
	if not board.is_inside(target):
		return _reject("invalid_cell")
	var target_value = board.cell_value(target)
	if target_value == null:
		return deploy(unit_id, target)
	if target_value is not UnitState:
		return _reject("cell_occupied")

	# A card played onto an existing unit is one atomic purchase + fusion.
	# FusionService remains the single owner of recipe legality and inherited
	# runtime state; the card input starts as a newly purchased full-state unit.
	var card_unit := UnitState.from_definition(definition)
	var plan := fusion.build_plan(card_unit, target_value)
	if plan.is_empty():
		return _reject("illegal_recipe")
	if recipe_gate_active and not enabled_recipe_ids.has(String(plan.get("recipe_id", ""))):
		return _reject("recipe_disabled_in_level")
	var card_cost := int(definition.get("cost", 0))
	var recipe_cost := int(plan.get("resource_cost", 0))
	var total_cost := card_cost + recipe_cost
	if not resources.can_spend(total_cost):
		return _reject("insufficient_resource")

	# Every rejection above leaves both resources and board untouched. The
	# target is known to contain a UnitState, so replacement cannot require a
	# temporary second board cell.
	var result: UnitState = plan["unit"]
	var before_resource := resources.amount
	board.remove_unit(target)
	board.place_unit(target, result)
	resources.spend(total_cost)
	var effective_now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	last_merge_receipt = {
		"ok": true,
		"recipe_id": plan.get("recipe_id", ""),
		"kind": "card_fusion",
		"fusion_kind": plan.get("kind", ""),
		"result": String(plan.get("result_unit", "")),
		"target_cell": target,
		"card_cost": card_cost,
		"recipe_cost": recipe_cost,
		"resource_before": before_resource,
		"resource_after": resources.amount,
		"undo_deadline_ms": effective_now + UNDO_WINDOW_MS,
		"undo_implemented": false,
	}
	return last_merge_receipt.duplicate(true)

func merge_cells(source: Vector2i, target: Vector2i, now_ms: int = -1) -> Dictionary:
	if state != STATE_RUNNING:
		return _reject("battle_not_running")
	if source == target:
		return _reject("same_cell")
	var source_unit = board.cell_value(source)
	var target_unit = board.cell_value(target)
	if source_unit is not UnitState or target_unit is not UnitState:
		return _reject("missing_unit")
	# Fusion layer owns legality + plan construction (incl. state inheritance);
	# the session only executes the battle transaction.
	var plan := fusion.build_plan(source_unit, target_unit)
	if plan.is_empty():
		return _reject("illegal_recipe")
	# Level-scoped recipe gate (GPT review on PR #8): a level with
	# enabled_recipe_ids only allows the listed recipes, so tutorial levels can
	# keep upgrades/fusion locked until their teaching level.
	if recipe_gate_active and not enabled_recipe_ids.has(String(plan.get("recipe_id", ""))):
		return _reject("recipe_disabled_in_level")
	var cost := int(plan.get("resource_cost", 0))
	if not resources.can_spend(cost):
		return _reject("insufficient_resource")
	var result: UnitState = plan["unit"]
	var before_resource := resources.amount
	board.remove_unit(source)
	board.remove_unit(target)
	board.place_unit(target, result)
	resources.spend(cost)
	var effective_now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	last_merge_receipt = {"ok": true,"recipe_id": plan.get("recipe_id", ""),"kind": plan.get("kind", ""),"result": String(plan.get("result_unit", "")),"source_cell": source,"target_cell": target,"resource_before": before_resource,"resource_after": resources.amount,"undo_deadline_ms": effective_now + UNDO_WINDOW_MS,"undo_implemented": false}
	return last_merge_receipt.duplicate(true)

func tick(delta: float) -> void:
	if state != STATE_RUNNING:
		return
	elapsed += delta
	_spawn_due_waves()
	if state != STATE_RUNNING:
		return
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
		if not _spawn_enemy_from_wave(wave):
			# A wave referencing an unknown enemy is a data error: halt the
			# battle instead of counting the wave as done (fake victory).
			state = STATE_CONFIG_ERROR
			printerr("Wave %d references unknown enemy, halting battle." % next_wave_index)
			return
		next_wave_index += 1

func _spawn_enemy_from_wave(wave: Dictionary) -> bool:
	var definition := repository.enemy_def(String(wave.get("enemy", "")))
	if definition.is_empty():
		return false
	if wave.has("health_override"):
		definition["max_health"] = int(wave["health_override"])
	if wave.has("speed_override"):
		definition["move_speed"] = float(wave["speed_override"])
	if wave.has("attack_damage_override"):
		definition["attack_damage"] = int(wave["attack_damage_override"])
	var start_column := float(wave.get("start_column_override", float(board.columns) + 0.35))
	enemies.append(EnemyState.from_definition(definition, int(wave.get("lane", 0)), start_column))
	return true

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
			_substep_advance(enemy, delta)
		if enemy.crossed_finish:
			if board.consume_insurance(enemy.lane):
				for lane_enemy in enemies:
					if lane_enemy.lane == enemy.lane:
						lane_enemy.defeated = true
			else:
				state = STATE_FAILURE
				return

# Moves an enemy in bounded substeps, re-checking contact after each substep
# so a high move_speed (or a long frame) cannot tunnel past a unit or tree.
# Budget is kept in DISTANCE cells: step_distance <= MAX_SUBSTEP_TRAVEL,
# converted to seconds for advance() as step_distance / move_speed.
#
# H4A-4: the loop condition is on the raw remaining distance with a strict
# float compare — no epsilon floor. The old `> 0.0001` check permanently
# swallowed tiny per-frame movements (e.g. move_speed 0.001 at 60 fps gives
# ~0.0000167 cells/frame), freezing slow enemies forever. move_speed <= 0
# exits immediately: no division by zero, no infinite loop.
func _substep_advance(enemy: EnemyState, delta: float) -> void:
	if delta <= 0.0 or enemy.move_speed <= 0.0:
		return
	var remaining_distance := enemy.move_speed * delta
	while remaining_distance > 0.0 and not enemy.crossed_finish:
		var step_distance := minf(remaining_distance, MAX_SUBSTEP_TRAVEL)
		remaining_distance -= step_distance
		enemy.advance(step_distance / enemy.move_speed)
		if enemy.defeated:
			return
		if _enemy_has_contact(enemy):
			return

func _enemy_has_contact(enemy: EnemyState) -> bool:
	if enemy.prefers_tree:
		for tree_cell in board.tree_positions():
			var tree := board.tree_at(tree_cell)
			if tree_cell.y == enemy.lane and bool(tree.get("alive", false)) and absf(enemy.progress_column - float(tree_cell.x)) <= 0.55:
				return true
	for unit_cell in board.unit_positions():
		if unit_cell.y != enemy.lane:
			continue
		var distance := enemy.progress_column - float(unit_cell.x)
		if distance >= -0.1 and distance <= 0.55:
			return true
	return false

func _tick_units(delta: float) -> void:
	for unit_cell in board.unit_positions():
		var unit: UnitState = board.cell_value(unit_cell)
		var definition := repository.unit_def(unit.unit_id)
		if String(definition.get("behavior", "")) == "resource_producer":
			_tick_resource_producer(unit, definition, delta)
			continue
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

func _tick_resource_producer(unit: UnitState, definition: Dictionary, delta: float) -> void:
	var period := float(definition["production_period"])
	var amount := int(definition["production_amount"])
	unit.production_cooldown -= delta
	while unit.production_cooldown <= 0.0:
		resources.add(amount)
		unit.production_cooldown += period

func _cleanup_enemies() -> void:
	enemies = enemies.filter(func(enemy): return not enemy.defeated and not enemy.crossed_finish)

func fusion_preview(source: Vector2i, target: Vector2i) -> Dictionary:
	var a = board.cell_value(source)
	var b = board.cell_value(target)
	if a is not UnitState or b is not UnitState:
		return {}
	var recipe := fusion.preview(a.unit_id, b.unit_id)
	if recipe.is_empty():
		return {}
	# Respect the level recipe gate so the drag-preview highlight matches what
	# merge_cells would actually allow.
	if recipe_gate_active and not enabled_recipe_ids.has(String(recipe.get("id", ""))):
		return {}
	return recipe

func card_fusion_preview(unit_id: String, target: Vector2i) -> Dictionary:
	if state != STATE_RUNNING or not board.is_inside(target):
		return {}
	var definition := repository.unit_def(unit_id)
	var target_unit = board.cell_value(target)
	if definition.is_empty() or target_unit is not UnitState:
		return {}
	var recipe := fusion.preview(unit_id, target_unit.unit_id)
	if recipe.is_empty():
		return {}
	if recipe_gate_active and not enabled_recipe_ids.has(String(recipe.get("id", ""))):
		return {}
	return recipe

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
