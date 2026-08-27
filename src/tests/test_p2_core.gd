extends GutTest

var repository: GameDataRepository

func before_each() -> void:
	repository = GameDataRepository.new()
	assert_true(repository.load_all())

func test_board_supports_5_lanes_and_variable_columns() -> void:
	assert_eq(BoardState.new(5, 8).columns, 8)
	assert_eq(BoardState.new(5, 9).columns, 9)
	assert_eq(BoardState.new(5, 10).columns, 10)
	assert_eq(BoardState.new(5, 10).lanes, 5)

func test_occupied_cell_rejects_deployment() -> void:
	var battle := BattleSession.new(repository, _empty_level(500))
	assert_true(battle.deploy("unit_a_1", Vector2i(2, 1))["ok"])
	var second := battle.deploy("unit_b_1", Vector2i(2, 1))
	assert_false(second["ok"])
	assert_eq(second["reason"], "cell_occupied")

func test_insufficient_resource_rejects_deployment() -> void:
	var battle := BattleSession.new(repository, _empty_level(10))
	var result := battle.deploy("unit_a_1", Vector2i(1, 0))
	assert_false(result["ok"])
	assert_eq(result["reason"], "insufficient_resource")

func test_enemy_stays_in_lane_and_advances_right_to_left() -> void:
	var definition := repository.enemy_def("enemy_basic")
	var enemy := EnemyState.from_definition(definition, 3, 9.0)
	enemy.advance(2.0)
	assert_eq(enemy.lane, 3)
	assert_lt(enemy.progress_column, 9.0)

func test_lane_insurance_only_consumes_once() -> void:
	var board := BoardState.new(5, 9)
	assert_true(board.consume_insurance(2))
	assert_false(board.consume_insurance(2))
	assert_false(board.insurance_available(2))

func test_a1_plus_a1_becomes_a2() -> void:
	var battle := BattleSession.new(repository, _empty_level(1000))
	battle.deploy("unit_a_1", Vector2i(1, 0))
	battle.deploy("unit_a_1", Vector2i(2, 0))
	var merged := battle.merge_cells(Vector2i(1, 0), Vector2i(2, 0), 1000)
	assert_true(merged["ok"])
	var result: UnitState = battle.board.cell_value(Vector2i(2, 0))
	assert_eq(result.unit_id, "unit_a_2")
	assert_eq(repository.unit_def(result.unit_id)["behavior"], "double_ranged")

func test_a2_plus_a2_becomes_a3() -> void:
	var battle := BattleSession.new(repository, _empty_level(2000))
	for x in [0, 1, 2, 3]:
		battle.deploy("unit_a_1", Vector2i(x, 0))
	battle.merge_cells(Vector2i(0, 0), Vector2i(1, 0), 1000)
	battle.merge_cells(Vector2i(2, 0), Vector2i(3, 0), 1000)
	var merged := battle.merge_cells(Vector2i(1, 0), Vector2i(3, 0), 1000)
	assert_true(merged["ok"])
	var result: UnitState = battle.board.cell_value(Vector2i(3, 0))
	assert_eq(result.unit_id, "unit_a_3")
	assert_eq(repository.unit_def(result.unit_id)["behavior"], "double_ranged_with_periodic_heavy")

func test_invalid_recipe_is_rejected() -> void:
	var battle := BattleSession.new(repository, _empty_level(1000))
	battle.deploy("unit_b_1", Vector2i(1, 0))
	battle.deploy("unit_b_1", Vector2i(2, 0))
	var result := battle.merge_cells(Vector2i(1, 0), Vector2i(2, 0))
	assert_false(result["ok"])
	assert_eq(result["reason"], "illegal_recipe")

func test_a_plus_b_becomes_collaborative_ab_and_loses_coverage() -> void:
	var battle := BattleSession.new(repository, _empty_level(1000))
	battle.deploy("unit_a_1", Vector2i(1, 2))
	battle.deploy("unit_b_1", Vector2i(5, 2))
	assert_eq(battle.board.unit_positions().size(), 2)
	var result := battle.merge_cells(Vector2i(1, 2), Vector2i(5, 2), 1000)
	assert_true(result["ok"])
	assert_eq(battle.board.unit_positions().size(), 1)
	var ab: UnitState = battle.board.cell_value(Vector2i(5, 2))
	assert_eq(ab.unit_id, "unit_ab")
	assert_eq(repository.unit_def(ab.unit_id)["behavior"], "ranged_plus_guard_collaboration")

func test_merge_preserves_worse_health_ratio_and_cooldown() -> void:
	var battle := BattleSession.new(repository, _empty_level(1000))
	battle.deploy("unit_a_1", Vector2i(1, 0))
	battle.deploy("unit_a_1", Vector2i(2, 0))
	var first: UnitState = battle.board.cell_value(Vector2i(1, 0))
	first.health = 40
	first.attack_cooldown = 0.7
	var result := battle.merge_cells(Vector2i(1, 0), Vector2i(2, 0), 1000)
	assert_true(result["ok"])
	var merged: UnitState = battle.board.cell_value(Vector2i(2, 0))
	assert_lt(merged.health, merged.max_health)
	assert_gte(merged.attack_cooldown, 0.7)

func test_protected_tree_blocks_deployment_and_controls_objective() -> void:
	var level := _empty_level(500)
	level["minimum_protected_trees"] = 1
	level["protected_trees"] = [{"id":"tree","lane":2,"column":4,"health":20}]
	var battle := BattleSession.new(repository, level)
	var blocked := battle.deploy("unit_a_1", Vector2i(4, 2))
	assert_false(blocked["ok"])
	assert_true(battle.tree_rule.is_met(battle.board))
	battle.board.damage_tree(Vector2i(4, 2), 20)
	assert_false(battle.tree_rule.is_met(battle.board))

func test_complete_battle_reaches_victory() -> void:
	var level := _empty_level(500)
	level["waves"] = [{"at":0.0,"enemy":"enemy_basic","lane":0,"health_override":1,"speed_override":0.05,"start_column_override":3.0}]
	var battle := BattleSession.new(repository, level)
	assert_true(battle.deploy("unit_a_1", Vector2i(0, 0))["ok"])
	for _i in range(40):
		battle.tick(0.1)
		if battle.state != BattleSession.STATE_RUNNING:
			break
	assert_eq(battle.state, BattleSession.STATE_VICTORY)

func test_complete_battle_reaches_failure_after_insurance_is_spent() -> void:
	var level := _empty_level(500)
	level["waves"] = [{"at":0.0,"enemy":"enemy_basic","lane":0,"speed_override":10.0,"start_column_override":0.05},{"at":0.3,"enemy":"enemy_basic","lane":0,"speed_override":10.0,"start_column_override":0.05}]
	var battle := BattleSession.new(repository, level)
	for _i in range(20):
		battle.tick(0.1)
		if battle.state != BattleSession.STATE_RUNNING:
			break
	assert_eq(battle.state, BattleSession.STATE_FAILURE)

func test_pointer_router_accepts_mouse_and_touch() -> void:
	var router := PointerRouter.new()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(10, 20)
	assert_eq(router.decode(mouse)["type"], "down")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(30, 40)
	assert_eq(router.decode(touch)["type"], "down")

func _empty_level(initial_resource: int) -> Dictionary:
	return {"id":"test","lanes":5,"columns":9,"initial_resource":initial_resource,"minimum_protected_trees":0,"protected_trees":[],"waves":[]}

# --- Codex review round 2 regression tests ---

func _battle_with_unit(unit_id: String, cell: Vector2i, resource: int = 1000) -> BattleSession:
	var battle := BattleSession.new(repository, _empty_level(resource))
	assert_true(battle.deploy(unit_id, cell)["ok"])
	return battle

func _wave(enemy: String, lane: int, at: float = 0.0, speed: float = 0.1, column: float = 8.0, health: int = 1000) -> Dictionary:
	return {"at":at,"enemy":enemy,"lane":lane,"speed_override":speed,"start_column_override":column,"health_override":health}

func test_fast_enemy_cannot_tunnel_past_blocking_unit() -> void:
	# Regression: a high move_speed * delta once jumped the 0.65-cell contact
	# window in one advance(), letting enemies bypass blockers entirely.
	var battle := _battle_with_unit("unit_b_1", Vector2i(4, 0))
	var enemy := EnemyState.from_definition({"id":"e","move_speed":60.0,"max_health":100000,"attack_damage":1,"attack_period":0.5}, 0, 8.0)
	battle.enemies.append(enemy)
	for _i in range(10):
		battle.tick(0.5)
		if battle.state != BattleSession.STATE_RUNNING:
			break
	assert_true(is_instance_valid(enemy))
	assert_false(enemy.crossed_finish, "fast enemy must stop at the blocker, not tunnel past")
	assert_true(battle.board.cell_value(Vector2i(4, 0)) is UnitState, "blocker still on board")
	assert_lt(enemy.progress_column, 4.6, "enemy held inside contact window of blocker")

func test_fast_tree_targeter_cannot_tunnel_past_protected_tree() -> void:
	var level := _empty_level(500)
	level["protected_trees"] = [{"id":"tree","lane":2,"column":5,"health":100000}]
	var battle := BattleSession.new(repository, level)
	var enemy := EnemyState.from_definition({"id":"e","move_speed":60.0,"max_health":100000,"attack_damage":1,"attack_period":0.5,"prefers_tree":true}, 2, 8.0)
	battle.enemies.append(enemy)
	for _i in range(10):
		battle.tick(0.5)
		if battle.state != BattleSession.STATE_RUNNING:
			break
	assert_false(enemy.crossed_finish, "fast tree-targeter must stop at the tree, not tunnel past")
	assert_true(battle.tree_rule.is_met(battle.board), "tree still alive")

func test_unknown_enemy_wave_enters_config_error_instead_of_fake_victory() -> void:
	# Regression: unknown enemy used to be skipped while next_wave_index still
	# advanced, producing a false victory once the board emptied.
	var level := _empty_level(500)
	level["waves"] = [_wave("enemy_basic", 0), _wave("enemy_does_not_exist", 1, 1.0)]
	var battle := BattleSession.new(repository, level)
	for _i in range(60):
		battle.tick(0.1)
		if battle.state != BattleSession.STATE_RUNNING:
			break
	assert_eq(battle.state, BattleSession.STATE_CONFIG_ERROR)
	assert_ne(battle.state, BattleSession.STATE_VICTORY)

func test_a2_double_ranged_deals_burst_damage() -> void:
	# H3 behavior check: unit_a_2 fires burst_count=2 shots of damage=8.
	var battle := _battle_with_unit("unit_a_2", Vector2i(0, 0))
	var enemy := EnemyState.from_definition({"id":"e","move_speed":0.0,"max_health":100,"attack_damage":0}, 0, 2.0)
	battle.enemies.append(enemy)
	battle.tick(0.1)
	assert_eq(enemy.health, 84, "one volley deals 8 x 2 burst damage")
	battle.tick(0.1)
	assert_eq(enemy.health, 84, "no second volley before attack_period elapses")
	battle.tick(0.8)
	assert_eq(enemy.health, 68, "second volley after attack_period")

func test_a3_heavy_strike_every_third_shot() -> void:
	# H3 behavior check: unit_a_3 deals 10x2, and every 3rd volley adds +18.
	var battle := _battle_with_unit("unit_a_3", Vector2i(0, 0))
	var enemy := EnemyState.from_definition({"id":"e","move_speed":0.0,"max_health":1000,"attack_damage":0}, 0, 2.0)
	battle.enemies.append(enemy)
	battle.tick(0.1)
	assert_eq(enemy.health, 980, "volley 1: 10 x 2")
	battle.tick(0.9)
	assert_eq(enemy.health, 960, "volley 2: 10 x 2")
	battle.tick(0.9)
	assert_eq(enemy.health, 922, "volley 3: 10 x 2 + 18 heavy")
	battle.tick(0.9)
	assert_eq(enemy.health, 902, "volley 4: heavy counter resets, 10 x 2")

func test_ab_guard_bonus_applies_only_in_close_range() -> void:
	# H3 behavior check: unit_ab adds guard_damage when target within 1.0.
	var battle := _battle_with_unit("unit_ab", Vector2i(0, 0))
	var close := EnemyState.from_definition({"id":"c","move_speed":0.0,"max_health":100,"attack_damage":0}, 0, 0.9)
	var far := EnemyState.from_definition({"id":"f","move_speed":0.0,"max_health":100,"attack_damage":0}, 0, 3.0)
	battle.enemies.append(close)
	battle.enemies.append(far)
	battle.tick(0.1)
	assert_eq(close.health, 72, "close target takes 10 + 18 guard damage (100-28)")
	assert_eq(far.health, 100, "ranged part only reaches nearest; far target untouched this volley")

func test_substep_advance_distance_is_exact_across_speeds_and_deltas() -> void:
	# Regression (GPT review round 3): the substep budget once mixed time and
	# distance units, making real speed depend on move_speed and frame rate.
	# With no blocker on the board, one tick must move exactly
	# move_speed * delta cells, for slow, mid and fast enemies and for
	# common frame deltas.
	var battle := BattleSession.new(repository, _empty_level(500))
	var cases := [[0.34, 1.0/30.0], [0.42, 1.0/60.0], [2.0, 1.0/60.0], [60.0, 1.0/60.0], [2.0, 1.0/120.0], [0.42, 0.5]]
	for case in cases:
		var speed: float = case[0]
		var delta: float = case[1]
		var enemy := EnemyState.from_definition({"id":"e","move_speed":speed,"max_health":10,"attack_damage":0}, 0, 9.0)
		battle.enemies.append(enemy)
		battle._substep_advance(enemy, delta)
		var expected: float = 9.0 - speed * delta
		assert_almost_eq(enemy.progress_column, expected, 0.0001, "speed=%s delta=%s must advance exactly speed*delta" % [speed, delta])
		assert_false(enemy.crossed_finish)
		battle.enemies.clear()

# --- H4A-4: tiny-speed epsilon regression ---

func test_substep_advance_tiny_speed_still_moves_each_frame() -> void:
	# Regression (H4A-4): the old `remaining_distance > 0.0001` floor
	# permanently swallowed the ~0.0000167 cells/frame that a move_speed of
	# 0.001 produces at 60 fps, freezing slow enemies forever.
	var battle := BattleSession.new(repository, _empty_level(500))
	var enemy := EnemyState.from_definition({"id":"slow","move_speed":0.001,"max_health":10,"attack_damage":0}, 0, 9.0)
	battle.enemies.append(enemy)
	battle._substep_advance(enemy, 1.0 / 60.0)
	assert_almost_eq(enemy.progress_column, 9.0 - 0.001 / 60.0, 0.0000001,
			"move_speed=0.001 must advance its full speed*delta in one 60fps frame")

func test_substep_advance_tiny_speed_accumulates_over_frames() -> void:
	var battle := BattleSession.new(repository, _empty_level(500))
	var enemy := EnemyState.from_definition({"id":"slow","move_speed":0.001,"max_health":10,"attack_damage":0}, 0, 9.0)
	battle.enemies.append(enemy)
	for _frame in range(600):
		battle._substep_advance(enemy, 1.0 / 60.0)
	assert_almost_eq(enemy.progress_column, 9.0 - 0.01, 0.000001,
			"600 frames at 0.001 cells/s must accumulate exactly 0.01 cells")

func test_substep_advance_zero_speed_is_safe() -> void:
	# move_speed <= 0 must not divide by zero or loop forever.
	var battle := BattleSession.new(repository, _empty_level(500))
	var enemy := EnemyState.from_definition({"id":"statue","move_speed":0.0,"max_health":10,"attack_damage":0}, 0, 9.0)
	battle.enemies.append(enemy)
	battle._substep_advance(enemy, 1.0 / 60.0)
	assert_eq(enemy.progress_column, 9.0, "zero speed must not move")
	assert_false(enemy.crossed_finish)

func test_normal_and_fast_speeds_do_not_regress() -> void:
	# Guard against over-correcting: exact displacement for normal speeds and
	# tunnel protection for fast ones must both keep working.
	var battle := BattleSession.new(repository, _empty_level(500))
	for speed in [0.34, 0.42, 2.0]:
		var enemy := EnemyState.from_definition({"id":"e","move_speed":speed,"max_health":10,"attack_damage":0}, 0, 5.34)
		battle.enemies.append(enemy)
		battle._substep_advance(enemy, 1.0)
		assert_almost_eq(enemy.progress_column, 5.34 - speed, 0.0001,
				"speed %s must advance exactly speed*1.0" % str(speed))
		battle.enemies.clear()

func test_fast_enemy_with_tiny_delta_still_blocked_by_unit() -> void:
	# High speed + small frames: contact re-check must still stop the enemy
	# at the blocker instead of tunnelling through it.
	var battle := _battle_with_unit("unit_b_1", Vector2i(4, 0))
	var enemy := EnemyState.from_definition({"id":"fast","move_speed":60.0,"max_health":100000,"attack_damage":1,"attack_period":100.0}, 0, 8.0)
	battle.enemies.append(enemy)
	for _frame in range(120):
		battle.tick(1.0 / 60.0)
	assert_lt(enemy.progress_column, 4.6, "fast enemy held inside the contact window")
	assert_true(battle.board.cell_value(Vector2i(4, 0)) is UnitState, "blocker survived")

func test_fast_tree_targeter_with_small_frames_cannot_tunnel_past_tree() -> void:
	var level := _empty_level(500)
	level["protected_trees"] = [{"id":"tree","lane":2,"column":5,"health":100000}]
	var battle := BattleSession.new(repository, level)
	var enemy := EnemyState.from_definition({"id":"fast","move_speed":60.0,"max_health":100000,"attack_damage":1,"attack_period":100.0,"prefers_tree":true}, 2, 8.0)
	battle.enemies.append(enemy)
	for _frame in range(120):
		battle.tick(1.0 / 60.0)
	assert_lt(enemy.progress_column, 5.6, "tree targeter held inside tree contact window")
	assert_true(battle.tree_rule.is_met(battle.board), "tree still alive")

# --- H4A-1: deck-driven cards ---

func test_level_deck_configures_available_cards() -> void:
	# Deck ids come from level config; cost shown/spent comes from unit data.
	var level := _empty_level(500)
	level["deck"] = ["unit_a_1", "unit_b_1"]
	assert_eq(level["deck"].size(), 2)
	for unit_id in level["deck"]:
		assert_false(repository.unit_def(String(unit_id)).is_empty(),
				"deck unit '%s' must exist in units.json" % String(unit_id))

func test_card_cost_matches_unit_definition_single_source() -> void:
	# UI display cost must equal the definition cost that deploy() spends:
	# change JSON cost and both sides follow without touching UI code.
	for unit_id in ["unit_a_1", "unit_b_1"]:
		var def := repository.unit_def(unit_id)
		var card_cost := int(def.get("cost", 0))
		var battle := BattleSession.new(repository, _empty_level(card_cost))
		assert_true(battle.deploy(unit_id, Vector2i(0, 0))["ok"],
				"deploy succeeds with exactly the definition cost")
		assert_eq(battle.resources.amount, 0, "wallet drained by exactly cost")

func test_deck_referencing_unknown_unit_is_caught_by_validator() -> void:
	var level := _empty_level(500)
	level["deck"] = ["unit_does_not_exist"]
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("deck")),
			"validator must flag unknown deck units")

# --- H4A-2: fusion plan boundary ---

func test_fusion_service_build_plan_for_upgrade() -> void:
	var fusion := FusionService.new(repository)
	var source := UnitState.from_definition(repository.unit_def("unit_a_1"))
	var target := UnitState.from_definition(repository.unit_def("unit_a_1"))
	source.health = 40
	source.attack_cooldown = 0.7
	target.shots_fired = 3
	var plan := fusion.build_plan(source, target)
	assert_true(plan["ok"])
	assert_eq(String(plan["result_unit"]), "unit_a_2")
	assert_eq(int(plan["resource_cost"]), 30)
	assert_eq(String(plan["recipe_id"]), "upgrade_a_1_to_2")
	var unit: UnitState = plan["unit"]
	# Inheritance lives in the Fusion layer: worse health ratio, longer cooldown,
	# summed shots.
	assert_eq(int(unit.health), int(round(float(unit.max_health) * (40.0 / 80.0))))
	assert_gte(unit.attack_cooldown, 0.7)
	assert_eq(int(unit.shots_fired), 3)

func test_fusion_service_build_plan_rejects_illegal_pair() -> void:
	var fusion := FusionService.new(repository)
	var b1 := UnitState.from_definition(repository.unit_def("unit_b_1"))
	var b2 := UnitState.from_definition(repository.unit_def("unit_b_1"))
	assert_true(fusion.build_plan(b1, b2).is_empty(), "B+B has no recipe: empty plan")
	assert_true(fusion.can_fuse("unit_a_1", "unit_a_1"))
	assert_false(fusion.can_fuse("unit_b_1", "unit_b_1"))

func test_session_merge_still_works_through_plan_boundary() -> void:
	# Behaviour compatibility: session-level results identical after the
	# FusionService refactor.
	var battle := BattleSession.new(repository, _empty_level(1000))
	battle.deploy("unit_a_1", Vector2i(1, 0))
	battle.deploy("unit_b_1", Vector2i(3, 0))
	var result := battle.merge_cells(Vector2i(1, 0), Vector2i(3, 0), 1000)
	assert_true(result["ok"])
	assert_eq(String(result["result"]), "unit_ab")
	assert_eq(String(result["kind"]), "fixed_cross_unit_fusion")
	assert_eq(battle.board.unit_positions().size(), 1)

# --- H4A-3: level/data reference validation ---

func test_validator_accepts_current_shipped_data() -> void:
	assert_true(LevelValidator.is_valid(repository.level, repository.units,
			repository.enemies, repository.recipes),
			"shipped level_playable.json + data files must validate clean")

func test_validator_flags_bad_lanes_and_columns() -> void:
	var level := _empty_level(500)
	level["lanes"] = 6
	level["columns"] = 0
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_gt(problems.size(), 0)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("lanes")))
	assert_true(problems.any(func(p: String) -> bool: return p.contains("columns")))

func test_validator_flags_unknown_wave_enemy() -> void:
	var level := _empty_level(500)
	level["waves"] = [_wave("enemy_basic", 0), _wave("ghost_enemy", 1)]
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("unknown enemy 'ghost_enemy'")))

func test_validator_flags_out_of_range_wave_lane() -> void:
	var level := _empty_level(500)
	level["waves"] = [_wave("enemy_basic", 9)]
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("lane 9 out of range")))

func test_validator_flags_tree_outside_board() -> void:
	var level := _empty_level(500)
	level["protected_trees"] = [{"id":"t","lane":2,"column":50,"health":100}]
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("outside the board")))

func test_validator_flags_recipe_with_unknown_result() -> void:
	var recipes := repository.recipes.duplicate(true)
	recipes.append({"id":"bad","input_a":"unit_a_1","input_b":"unit_a_1","result":"unit_ghost","resource_cost":10})
	var problems := LevelValidator.validate(_empty_level(500), repository.units, repository.enemies, recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("unit_ghost")))

func test_validator_flags_two_trees_sharing_one_cell() -> void:
	# Regression (GPT review on PR #7): two different tree ids occupying the
	# same (lane, column) passed validation, but BoardState.place_tree()
	# silently drops the second one — the level would run with fewer trees
	# than configured and minimum_protected_trees could become unmeetable.
	var level := _empty_level(500)
	level["minimum_protected_trees"] = 2
	level["protected_trees"] = [
		{"id":"tree_a","lane":2,"column":4,"health":100},
		{"id":"tree_b","lane":2,"column":4,"health":100},
	]
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("shares cell")),
			"duplicate tree cell must be flagged")
	assert_true(problems.any(func(p: String) -> bool: return p.contains("minimum_protected_trees")),
			"min trees must also be reported as unmeetable")

func test_repository_load_all_fails_loud_on_duplicate_tree_cell() -> void:
	# End-to-end: the duplicate-cell config must fail at load_all() time.
	var bad_repo := GameDataRepository.new()
	var tmp_path := "res://reports/test_dup_tree_level.json"
	if not DirAccess.dir_exists_absolute("res://reports"):
		DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"id":"dup_tree","lanes":5,"columns":9,"initial_resource":500,"minimum_protected_trees":1,"protected_trees":[{"id":"t1","lane":1,"column":4,"health":100},{"id":"t2","lane":1,"column":4,"health":100}],"waves":[]}))
	file.close()
	GutUtils.get_error_tracker().disabled = true
	assert_false(bad_repo.load_all(tmp_path), "duplicate tree cell must fail loud")
	GutUtils.get_error_tracker().disabled = false
	DirAccess.remove_absolute(tmp_path)

func test_repository_load_all_fails_loud_on_invalid_level_file() -> void:
	var bad_repo := GameDataRepository.new()
	# A level file with an unknown wave enemy must make load_all() fail
	# instead of booting a broken battle.
	var tmp_path := "res://reports/test_bad_level.json"
	if not DirAccess.dir_exists_absolute("res://reports"):
		DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"id":"bad","lanes":5,"columns":9,"initial_resource":500,"minimum_protected_trees":0,"protected_trees":[],"waves":[{"at":1.0,"enemy":"no_such_enemy","lane":0}]}))
	file.close()
	# The push_error inside load_all is the EXPECTED fail-loud behaviour this
	# test asserts on; silence GUT's error tracker for the call so the
	# intentional push_error is not double-counted as an unexpected failure.
	GutUtils.get_error_tracker().disabled = true
	assert_false(bad_repo.load_all(tmp_path), "invalid level must fail loud")
	GutUtils.get_error_tracker().disabled = false
	DirAccess.remove_absolute(tmp_path)

# --- H4B-0: numeric sanity validation ---

func test_validator_flags_negative_start_column_override() -> void:
	var level := _empty_level(500)
	level["waves"] = [{"at": 1.0, "enemy": "enemy_basic", "lane": 0, "start_column_override": -1.5}]
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("start_column_override")),
			"negative start_column_override must fail loud")

func test_validator_allows_positive_onboard_start_column() -> void:
	# Positive on-board spawns stay legal: only negatives are rejected.
	var level := _empty_level(500)
	level["waves"] = [{"at": 1.0, "enemy": "enemy_basic", "lane": 0, "start_column_override": 3.0}]
	assert_true(LevelValidator.is_valid(level, repository.units, repository.enemies, repository.recipes),
			"positive in-board spawn override is legal config")

func test_validator_flags_bad_wave_time_and_overrides() -> void:
	var level := _empty_level(500)
	level["waves"] = [
		{"at": -2.0, "enemy": "enemy_basic", "lane": 0},
		{"at": 5.0, "enemy": "enemy_basic", "lane": 0, "health_override": 0, "speed_override": -1.0, "attack_damage_override": -3},
	]
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("time must be >= 0")))
	assert_true(problems.any(func(p: String) -> bool: return p.contains("health_override must be > 0")))
	assert_true(problems.any(func(p: String) -> bool: return p.contains("speed_override must be >= 0")))
	assert_true(problems.any(func(p: String) -> bool: return p.contains("attack_damage_override must be >= 0")))

func test_validator_flags_negative_initial_resource() -> void:
	var level := _empty_level(-10)
	var problems := LevelValidator.validate(level, repository.units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("initial_resource")))

func test_validator_flags_bad_unit_numbers() -> void:
	var units := repository.units.duplicate(true)
	units["unit_a_1"]["cost"] = -5
	units["unit_b_1"]["max_health"] = 0
	var problems := LevelValidator.validate(_empty_level(500), units, repository.enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("'unit_a_1' cost must be >= 0")))
	assert_true(problems.any(func(p: String) -> bool: return p.contains("'unit_b_1' max_health must be > 0")))

func test_validator_flags_bad_enemy_numbers() -> void:
	var enemies := repository.enemies.duplicate(true)
	enemies["enemy_basic"]["max_health"] = -1
	enemies["enemy_basic"]["move_speed"] = -0.5
	enemies["enemy_basic"]["attack_damage"] = -2
	enemies["enemy_tree_targeter"]["attack_period"] = 0.0
	var problems := LevelValidator.validate(_empty_level(500), repository.units, enemies, repository.recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("'enemy_basic' max_health must be > 0")))
	assert_true(problems.any(func(p: String) -> bool: return p.contains("'enemy_basic' move_speed must be >= 0")))
	assert_true(problems.any(func(p: String) -> bool: return p.contains("'enemy_basic' attack_damage must be >= 0")))
	assert_true(problems.any(func(p: String) -> bool: return p.contains("'enemy_tree_targeter' attack_period must be > 0")))

func test_validator_flags_negative_recipe_cost() -> void:
	var recipes := repository.recipes.duplicate(true)
	recipes[0]["resource_cost"] = -30
	var problems := LevelValidator.validate(_empty_level(500), repository.units, repository.enemies, recipes)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("resource_cost must be >= 0")))

# --- H4B: formal World 01 level 1-1 ---

const WORLD01_01_PATH := "res://src/data/levels/world01_01.json"

func _load_world01_repo() -> GameDataRepository:
	var repo := GameDataRepository.new()
	assert_true(repo.load_all(WORLD01_01_PATH))
	return repo

func test_world01_01_passes_validator_and_loads() -> void:
	var repo := _load_world01_repo()
	assert_eq(String(repo.level.get("id")), "world01_01")
	assert_eq(String(repo.level.get("title")), "1-1 有人来砍树！")

func test_world01_01_deck_only_has_xiong_da_1() -> void:
	var repo := _load_world01_repo()
	var deck: Array = repo.level.get("deck", [])
	assert_eq(deck.size(), 1, "level 1-1 teaches only 熊大 I")
	assert_eq(String(deck[0]), "unit_a_1")

func test_world01_01_waves_only_use_basic_enemy() -> void:
	var repo := _load_world01_repo()
	for wave in repo.level.get("waves", []):
		assert_eq(String(wave.get("enemy")), "enemy_basic",
				"1-1 must only use 木料小推车 (enemy_basic)")

func test_world01_01_no_protected_tree_objective() -> void:
	var repo := _load_world01_repo()
	assert_eq(int(repo.level.get("minimum_protected_trees")), 0,
			"1-1 does not teach the tree objective yet")
	assert_eq((repo.level.get("protected_trees", []) as Array).size(), 0)

func test_world01_01_formal_display_names_exist() -> void:
	var repo := _load_world01_repo()
	assert_eq(String(repo.unit_def("unit_a_1").get("display_name")), "熊大 I")
	assert_eq(String(repo.unit_def("unit_a_1").get("character_key")), "xiong_da")
	assert_eq(String(repo.enemy_def("enemy_basic").get("display_name")), "木料小推车")

func test_world01_01_simulates_to_victory_with_redeployed_xiong_da() -> void:
	# Tutorial tuning claim: 3~5 熊大 I win. This drives the real runtime
	# path — full BattleSession ticks. 350 starting resource funds the whole
	# plan up front (7 x cost 50): open with 3 on the early lanes, then
	# reinforce lanes 1/3 from the remaining pool before their waves arrive.
	# (BattleSession has no kill/wave income yet — no income is claimed here.)
	var repo := _load_world01_repo()
	var battle := BattleSession.new(repo)
	battle.deploy("unit_a_1", Vector2i(3, 2))
	battle.deploy("unit_a_1", Vector2i(3, 0))
	battle.deploy("unit_a_1", Vector2i(3, 4))
	var reinforced := {1: false, 3: false}
	for _i in range(5000):
		battle.tick(0.05)
		if battle.state != BattleSession.STATE_RUNNING:
			break
		if battle.state == BattleSession.STATE_RUNNING:
			if not reinforced[1] and battle.elapsed >= 20.0 and battle.resources.amount >= 50:
				assert_true(battle.deploy("unit_a_1", Vector2i(3, 1))["ok"])
				reinforced[1] = true
			elif not reinforced[3] and battle.elapsed >= 30.0 and battle.resources.amount >= 50:
				assert_true(battle.deploy("unit_a_1", Vector2i(3, 3))["ok"])
				reinforced[3] = true
	assert_eq(battle.state, BattleSession.STATE_VICTORY,
			"open 3 lanes then reinforce with wave income should clear 1-1")

func test_world01_01_abandoning_lanes_reaches_failure() -> void:
	# Ignore two of the attacked lanes entirely: skipping defenses must be
	# able to lose (tutorial states that ignoring routes fails).
	var repo := _load_world01_repo()
	var battle := BattleSession.new(repo)
	for _i in range(4000):
		battle.tick(0.05)
		if battle.state != BattleSession.STATE_RUNNING:
			break
	assert_eq(battle.state, BattleSession.STATE_FAILURE,
			"a completely undefended board must lose 1-1")

# --- GPT review on PR #8: level recipe gate ---

func test_world01_01_rejects_upgrade_merge() -> void:
	# P1 blocker: 1-1 teaches only base tower defense; A1+A1->A2 must be
	# rejected at runtime and both units plus resources must be untouched.
	var repo := _load_world01_repo()
	var battle := BattleSession.new(repo)
	assert_true(battle.deploy("unit_a_1", Vector2i(1, 0))["ok"])
	assert_true(battle.deploy("unit_a_1", Vector2i(3, 0))["ok"])
	var before_resource := battle.resources.amount
	var result := battle.merge_cells(Vector2i(1, 0), Vector2i(3, 0), 1000)
	assert_false(result["ok"], "1-1 must reject upgrade fusion")
	assert_eq(String(result["reason"]), "recipe_disabled_in_level")
	assert_true(battle.board.cell_value(Vector2i(1, 0)) is UnitState, "source unit still on board")
	assert_true(battle.board.cell_value(Vector2i(3, 0)) is UnitState, "target unit still on board")
	assert_eq(battle.resources.amount, before_resource, "no resource charged on rejected merge")

func test_world01_01_fusion_preview_respects_gate() -> void:
	var repo := _load_world01_repo()
	var battle := BattleSession.new(repo)
	battle.deploy("unit_a_1", Vector2i(1, 0))
	battle.deploy("unit_a_1", Vector2i(3, 0))
	assert_true(battle.fusion_preview(Vector2i(1, 0), Vector2i(3, 0)).is_empty(),
			"drag preview must not advertise a disabled recipe")

func test_recipe_gate_absent_key_keeps_allow_all_behaviour() -> void:
	# Legacy fixture (level_playable.json / _empty_level) has no
	# enabled_recipe_ids: upgrades/fusion keep working there.
	var battle := BattleSession.new(repository, _empty_level(1000))
	battle.deploy("unit_a_1", Vector2i(1, 0))
	battle.deploy("unit_a_1", Vector2i(3, 0))
	var result := battle.merge_cells(Vector2i(1, 0), Vector2i(3, 0), 1000)
	assert_true(result["ok"], "levels without the gate keep legacy behaviour")

func test_level_with_enabled_recipes_allows_listed_only() -> void:
	# Gate semantics: listed recipes work; unlisted ones are rejected even
	# though they exist globally.
	var level := _empty_level(2000)
	level["enabled_recipe_ids"] = ["upgrade_a_1_to_2"]
	var battle := BattleSession.new(repository, level)
	battle.deploy("unit_a_1", Vector2i(1, 2))
	battle.deploy("unit_b_1", Vector2i(5, 2))
	var blocked := battle.merge_cells(Vector2i(1, 2), Vector2i(5, 2))
	assert_false(blocked["ok"], "unlisted cross-fusion must be blocked when gate lists only upgrades")
	assert_eq(String(blocked["reason"]), "recipe_disabled_in_level")
	battle.deploy("unit_a_1", Vector2i(1, 4))
	battle.deploy("unit_a_1", Vector2i(3, 4))
	var allowed := battle.merge_cells(Vector2i(1, 4), Vector2i(3, 4))
	assert_true(allowed["ok"], "listed upgrade recipe stays legal")

