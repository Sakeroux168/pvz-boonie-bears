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

