extends GutTest

const WORLD01_03_PATH := "res://src/data/levels/world01_03.json"
const WORLD01_04_PATH := "res://src/data/levels/world01_04.json"

var repository: GameDataRepository

func before_each() -> void:
	repository = GameDataRepository.new()
	assert_true(repository.load_all())

func _load_world01_04_repo() -> GameDataRepository:
	var repo := GameDataRepository.new()
	assert_true(repo.load_all(WORLD01_04_PATH))
	return repo

func _running_level(initial_resource: int = 1000) -> Dictionary:
	return {
		"id": "world01_04_runtime_test",
		"lanes": 5,
		"columns": 9,
		"initial_resource": initial_resource,
		"minimum_protected_trees": 0,
		"protected_trees": [],
		"waves": [{"at": 999.0, "enemy": "enemy_basic", "lane": 4}],
	}

func test_enemy_armor_missing_defaults_to_zero_and_keeps_old_damage() -> void:
	var enemy := EnemyState.from_definition({
		"id": "legacy",
		"max_health": 50,
		"move_speed": 0.0,
		"attack_damage": 0,
		"attack_period": 1.0,
	}, 0, 3.0)
	assert_eq(enemy.armor, 0)
	enemy.take_damage(12)
	assert_eq(enemy.health, 38)

func test_enemy_armor_reduces_damage_at_single_entry_point() -> void:
	var enemy := EnemyState.from_definition({
		"id": "armored",
		"max_health": 50,
		"move_speed": 0.0,
		"attack_damage": 0,
		"attack_period": 1.0,
		"armor": 7,
	}, 0, 3.0)
	enemy.take_damage(12)
	assert_eq(enemy.health, 45)

func test_armor_above_incoming_damage_deals_zero_and_never_heals() -> void:
	var enemy := EnemyState.from_definition({
		"id": "armored",
		"max_health": 50,
		"move_speed": 0.0,
		"attack_damage": 0,
		"attack_period": 1.0,
		"armor": 20,
	}, 0, 3.0)
	enemy.health = 40
	enemy.take_damage(12)
	assert_eq(enemy.health, 40)
	enemy.take_damage(-10)
	assert_eq(enemy.health, 40)

func test_validator_rejects_negative_enemy_armor() -> void:
	var enemies := repository.enemies.duplicate(true)
	enemies["enemy_basic"]["armor"] = -1
	var problems := LevelValidator.validate(
		_running_level(), repository.units, enemies, repository.recipes
	)
	assert_true(problems.any(func(problem: String) -> bool:
		return problem.contains("armor must be >= 0")))

func test_world01_04_formal_data_and_armored_enemy_pass_validator() -> void:
	var repo := _load_world01_04_repo()
	assert_eq(String(repo.level.get("id")), "world01_04")
	assert_eq(String(repo.level.get("title")), "1-4 \u4e00\u4e2a\u718a\u5927\u8fd8\u4e0d\u591f")
	var armored := repo.enemy_def("enemy_armored")
	assert_eq(String(armored.get("display_name")), "\u94c1\u76ae\u4f10\u6728\u8f66")
	assert_almost_eq(float(armored.get("move_speed")), 0.30, 0.0001)
	assert_eq(int(armored.get("max_health")), 110)
	assert_eq(int(armored.get("attack_damage")), 12)
	assert_almost_eq(float(armored.get("attack_period")), 1.0, 0.0001)
	assert_eq(int(armored.get("armor")), 7)
	assert_false(bool(armored.get("prefers_tree")))

func test_world01_04_has_exact_tutorial_scope() -> void:
	var repo := _load_world01_04_repo()
	assert_eq(int(repo.level.get("lanes")), 5)
	assert_eq(int(repo.level.get("columns")), 9)
	assert_eq(int(repo.level.get("initial_resource")), 250)
	assert_eq(repo.level.get("deck", []), ["unit_a_1", "unit_b_1", "unit_c_1"])
	assert_eq(repo.level.get("enabled_recipe_ids", []), ["upgrade_a_1_to_2"])
	assert_eq(int(repo.level.get("minimum_protected_trees")), 0)
	assert_eq(repo.level.get("protected_trees", []), [])
	assert_false(repo.level.has("next_level_id"))
	var waves: Array = repo.level.get("waves", [])
	assert_between(waves.size(), 10, 12)
	assert_between(float(waves[-1].get("at")), 100.0, 130.0)
	for index in waves.size():
		var enemy_id := String(waves[index].get("enemy"))
		assert_true(enemy_id in ["enemy_basic", "enemy_armored"])
		if index < 3:
			assert_eq(enemy_id, "enemy_basic")

func test_world01_03_points_to_world01_04() -> void:
	var repo := GameDataRepository.new()
	assert_true(repo.load_all(WORLD01_03_PATH))
	assert_eq(String(repo.level.get("next_level_id")), "world01_04")

func _kill_time(unit_id: String, enemy_id: String) -> float:
	var battle := BattleSession.new(repository, _running_level())
	assert_true(battle.deploy(unit_id, Vector2i(0, 0))["ok"])
	var definition := repository.enemy_def(enemy_id).duplicate(true)
	definition["move_speed"] = 0.0
	definition["attack_damage"] = 0
	var enemy := EnemyState.from_definition(definition, 0, 3.0)
	battle.enemies.append(enemy)
	for _step in range(2000):
		battle.tick(0.05)
		if enemy.defeated:
			return battle.elapsed
	return INF

func test_xiong_da_one_kills_armored_enemy_clearly_slower_than_basic() -> void:
	var basic_time := _kill_time("unit_a_1", "enemy_basic")
	var armored_time := _kill_time("unit_a_1", "enemy_armored")
	assert_lt(basic_time, INF)
	assert_lt(armored_time, INF, "armor must slow damage, not make the enemy invulnerable")
	assert_gt(armored_time, basic_time * 2.0,
		"the armored enemy must take clearly longer for Xiong Da I")

func test_xiong_da_two_has_higher_effective_output_against_armor() -> void:
	var a1_time := _kill_time("unit_a_1", "enemy_armored")
	var a2_time := _kill_time("unit_a_2", "enemy_armored")
	assert_lt(a2_time, a1_time)
	var a1_battle := BattleSession.new(repository, _running_level())
	var a2_battle := BattleSession.new(repository, _running_level())
	assert_true(a1_battle.deploy("unit_a_1", Vector2i(0, 0))["ok"])
	assert_true(a2_battle.deploy("unit_a_2", Vector2i(0, 0))["ok"])
	var a1_enemy := EnemyState.from_definition(repository.enemy_def("enemy_armored"), 0, 3.0)
	var a2_enemy := EnemyState.from_definition(repository.enemy_def("enemy_armored"), 0, 3.0)
	a1_battle.enemies.append(a1_enemy)
	a2_battle.enemies.append(a2_enemy)
	a1_battle.tick(0.05)
	a2_battle.tick(0.05)
	assert_eq(110 - a1_enemy.health, 5)
	assert_eq(110 - a2_enemy.health, 9,
		"A2 keeps its existing combined burst semantics before one armor calculation")

func test_world01_04_allows_only_a1_upgrade_and_spends_recipe_cost() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	assert_true(battle.deploy("unit_a_1", Vector2i(0, 0))["ok"])
	assert_true(battle.deploy("unit_a_1", Vector2i(1, 0))["ok"])
	assert_false(battle.fusion_preview(Vector2i(0, 0), Vector2i(1, 0)).is_empty())
	var before := battle.resources.amount
	var result := battle.merge_cells(Vector2i(0, 0), Vector2i(1, 0))
	assert_true(result.get("ok", false), str(result))
	assert_eq(String(result.get("recipe_id")), "upgrade_a_1_to_2")
	assert_eq(int(result["resource_before"]) - int(result["resource_after"]), 30)
	assert_eq(battle.resources.amount, before - 30)
	assert_eq((battle.board.cell_value(Vector2i(1, 0)) as UnitState).unit_id, "unit_a_2")

func test_card_play_to_empty_cell_keeps_deploy_cost_semantics() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	var before := battle.resources.amount
	var result := battle.play_card("unit_a_1", Vector2i(0, 0))
	assert_true(result.get("ok", false), str(result))
	assert_eq(String(result.get("kind")), "deploy")
	assert_eq(battle.resources.amount, before - 50)
	assert_eq((battle.board.cell_value(Vector2i(0, 0)) as UnitState).unit_id, "unit_a_1")

func test_card_a1_onto_existing_a1_atomically_buys_and_upgrades_for_80() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	var target := Vector2i(2, 0)
	assert_true(battle.deploy("unit_a_1", target)["ok"])
	var before := battle.resources.amount
	var result := battle.play_card("unit_a_1", target)
	assert_true(result.get("ok", false), str(result))
	assert_eq(String(result.get("kind")), "card_fusion")
	assert_eq(String(result.get("recipe_id")), "upgrade_a_1_to_2")
	assert_eq(int(result.get("card_cost")), 50)
	assert_eq(int(result.get("recipe_cost")), 30)
	assert_eq(int(result.get("resource_before")) - int(result.get("resource_after")), 80)
	assert_eq(battle.resources.amount, before - 80)
	assert_eq(battle.board.unit_positions(), [target],
		"card fusion replaces the target without creating a temporary second unit")
	assert_eq((battle.board.cell_value(target) as UnitState).unit_id, "unit_a_2")

func test_card_fusion_with_only_79_is_rejected_without_pollution() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	var target := Vector2i(2, 0)
	assert_true(battle.deploy("unit_a_1", target)["ok"])
	var original: UnitState = battle.board.cell_value(target)
	battle.resources.amount = 79
	var result := battle.play_card("unit_a_1", target)
	assert_eq(String(result.get("reason")), "insufficient_resource")
	assert_eq(battle.resources.amount, 79)
	assert_same(battle.board.cell_value(target), original)
	assert_eq(battle.board.unit_positions(), [target])

func test_card_fusion_gate_and_missing_recipe_fail_without_pollution() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	var b_cell := Vector2i(1, 1)
	var c_cell := Vector2i(2, 1)
	assert_true(battle.deploy("unit_b_1", b_cell)["ok"])
	assert_true(battle.deploy("unit_c_1", c_cell)["ok"])
	var b_original: UnitState = battle.board.cell_value(b_cell)
	var c_original: UnitState = battle.board.cell_value(c_cell)
	var before := battle.resources.amount
	var gated := battle.play_card("unit_a_1", b_cell)
	var missing := battle.play_card("unit_a_1", c_cell)
	assert_eq(String(gated.get("reason")), "recipe_disabled_in_level")
	assert_eq(String(missing.get("reason")), "illegal_recipe")
	assert_eq(battle.resources.amount, before)
	assert_same(battle.board.cell_value(b_cell), b_original)
	assert_same(battle.board.cell_value(c_cell), c_original)

func test_card_fusion_keeps_worse_health_ratio_without_free_heal() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	var target := Vector2i(2, 0)
	assert_true(battle.deploy("unit_a_1", target)["ok"])
	var wounded: UnitState = battle.board.cell_value(target)
	wounded.health = wounded.max_health / 2
	wounded.attack_cooldown = 2.5
	var result := battle.play_card("unit_a_1", target)
	assert_true(result.get("ok", false), str(result))
	var upgraded: UnitState = battle.board.cell_value(target)
	assert_eq(upgraded.health, int(round(float(upgraded.max_health) * 0.5)))
	assert_eq(upgraded.attack_cooldown, 2.5)
	assert_lt(upgraded.health, upgraded.max_health)

func test_card_play_invalid_target_and_stopped_battle_are_atomic() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	var before := battle.resources.amount
	var invalid := battle.play_card("unit_a_1", Vector2i(-1, 0))
	assert_eq(String(invalid.get("reason")), "invalid_cell")
	assert_eq(battle.resources.amount, before)
	assert_true(battle.board.unit_positions().is_empty())
	battle.state = BattleSession.STATE_FAILURE
	var stopped := battle.play_card("unit_a_1", Vector2i(0, 0))
	assert_eq(String(stopped.get("reason")), "battle_not_running")
	assert_eq(battle.resources.amount, before)
	assert_true(battle.board.unit_positions().is_empty())

func test_world01_04_fusions_ui_lists_only_the_enabled_upgrade() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_04"))
	var visible: Array = screen._visible_recipes()
	assert_eq(visible.size(), 1)
	assert_eq(String(visible[0].get("id")), "upgrade_a_1_to_2")
	assert_eq(String(visible[0].get("result")), "unit_a_2")
	assert_eq(screen.status_text, "Drag cards to deploy or onto compatible units to merge.")
	screen.free()

func _mouse_input(screen, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	screen._unhandled_input(event)

func _drag_card_to_cell(screen, card_index: int, cell: Vector2i) -> void:
	var card_rect: Rect2 = screen.deck_cards[card_index]["rect"]
	_mouse_input(screen, card_rect.get_center(), true)
	_mouse_input(screen, screen._cell_rect(cell).get_center(), false)

func test_battle_screen_card_drag_deploys_then_fuses_with_formal_name() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_04"))
	var target := Vector2i(2, 0)
	_drag_card_to_cell(screen, 0, target)
	assert_eq(screen.session.resources.amount, 200)
	_drag_card_to_cell(screen, 0, target)
	assert_eq(screen.session.resources.amount, 120)
	assert_eq((screen.session.board.cell_value(target) as UnitState).unit_id, "unit_a_2")
	assert_eq(screen.session.board.unit_positions(), [target])
	assert_eq(screen.status_text, "Merged -> \u718a\u5927 II")
	assert_false(screen.status_text.contains("unit_a_2"))
	screen.free()

func test_card_hover_preview_respects_gate_and_uses_formal_result_name() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_04"))
	var a_cell := Vector2i(2, 0)
	var b_cell := Vector2i(2, 1)
	assert_true(screen.session.deploy("unit_a_1", a_cell)["ok"])
	assert_true(screen.session.deploy("unit_b_1", b_cell)["ok"])
	var allowed: Dictionary = screen.session.card_fusion_preview("unit_a_1", a_cell)
	assert_eq(String(allowed.get("id")), "upgrade_a_1_to_2")
	assert_eq(screen._display_name_for_unit(String(allowed.get("result"))), "\u718a\u5927 II")
	assert_true(screen.session.card_fusion_preview("unit_a_1", b_cell).is_empty(),
		"the locked A1+B1 recipe must not appear in card hover preview")
	screen.free()

func test_battle_screen_does_not_start_or_execute_field_unit_drag_merge() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_04"))
	var source := Vector2i(1, 0)
	var target := Vector2i(2, 0)
	assert_true(screen.session.deploy("unit_a_1", source)["ok"])
	assert_true(screen.session.deploy("unit_a_1", target)["ok"])
	var source_unit: UnitState = screen.session.board.cell_value(source)
	var target_unit: UnitState = screen.session.board.cell_value(target)
	var before: int = screen.session.resources.amount
	_mouse_input(screen, screen._cell_rect(source).get_center(), true)
	assert_true(screen.drag_payload.is_empty())
	_mouse_input(screen, screen._cell_rect(target).get_center(), false)
	assert_same(screen.session.board.cell_value(source), source_unit)
	assert_same(screen.session.board.cell_value(target), target_unit)
	assert_eq(screen.session.resources.amount, before)
	screen.free()

func _make_a2(battle: BattleSession, source: Vector2i, target: Vector2i) -> void:
	assert_true(battle.deploy("unit_a_1", source)["ok"])
	assert_true(battle.deploy("unit_a_1", target)["ok"])
	assert_true(battle.merge_cells(source, target).get("ok", false))

func test_world01_04_blocks_a2_to_a3_without_state_pollution() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	battle.resources.add(1000)
	_make_a2(battle, Vector2i(0, 0), Vector2i(1, 0))
	_make_a2(battle, Vector2i(2, 0), Vector2i(3, 0))
	var left: UnitState = battle.board.cell_value(Vector2i(1, 0))
	var right: UnitState = battle.board.cell_value(Vector2i(3, 0))
	var before := battle.resources.amount
	assert_true(battle.fusion_preview(Vector2i(1, 0), Vector2i(3, 0)).is_empty())
	var result := battle.merge_cells(Vector2i(1, 0), Vector2i(3, 0))
	assert_eq(String(result.get("reason")), "recipe_disabled_in_level")
	assert_same(battle.board.cell_value(Vector2i(1, 0)), left)
	assert_same(battle.board.cell_value(Vector2i(3, 0)), right)
	assert_eq(battle.resources.amount, before)

func test_world01_04_blocks_a1_plus_b1_without_state_pollution() -> void:
	var battle := BattleSession.new(_load_world01_04_repo())
	assert_true(battle.deploy("unit_a_1", Vector2i(0, 1))["ok"])
	assert_true(battle.deploy("unit_b_1", Vector2i(1, 1))["ok"])
	var left: UnitState = battle.board.cell_value(Vector2i(0, 1))
	var right: UnitState = battle.board.cell_value(Vector2i(1, 1))
	var before := battle.resources.amount
	assert_true(battle.fusion_preview(Vector2i(0, 1), Vector2i(1, 1)).is_empty())
	var result := battle.merge_cells(Vector2i(0, 1), Vector2i(1, 1))
	assert_eq(String(result.get("reason")), "recipe_disabled_in_level")
	assert_same(battle.board.cell_value(Vector2i(0, 1)), left)
	assert_same(battle.board.cell_value(Vector2i(1, 1)), right)
	assert_eq(battle.resources.amount, before)

func test_restart_rebuilds_current_world01_04() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_04"))
	assert_true(screen.session.deploy("unit_c_1", Vector2i(0, 0))["ok"])
	screen.session.tick(9.0)
	screen.session.board.consume_insurance(2)
	screen._restart_level()
	assert_eq(String(screen.repository.level.get("id")), "world01_04")
	assert_eq(screen.session.resources.amount, 250)
	assert_eq(screen.session.elapsed, 0.0)
	assert_eq(screen.session.next_wave_index, 0)
	assert_eq(screen.session.board.unit_positions().size(), 0)
	assert_true(screen.session.board.insurance_available(2))
	assert_eq(screen.session.enabled_recipe_ids.keys(), ["upgrade_a_1_to_2"])
	screen.free()

func test_dev_infinite_refunds_real_upgrade_and_keeps_producer_income() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_04"))
	screen.dev_tools_enabled = true
	if not screen._dev_tools_available():
		pending("debug-only DEV contract requires a debug build")
		screen.free()
		return
	screen.dev_infinite_resources = true
	assert_true(screen.session.deploy("unit_c_1", Vector2i(0, 4))["ok"])
	assert_true(screen.session.deploy("unit_a_1", Vector2i(0, 0))["ok"])
	var before_merge: int = screen.session.resources.amount
	screen.drag_payload = {"kind": "card", "unit_id": "unit_a_1"}
	screen._finish_drag(screen._cell_rect(Vector2i(0, 0)).get_center())
	assert_eq(screen.session.resources.amount, before_merge,
		"DEV infinite must refund the full 50 card + 30 recipe cost")
	assert_eq((screen.session.board.cell_value(Vector2i(0, 0)) as UnitState).unit_id, "unit_a_2")
	assert_eq(screen.session.board.unit_positions().size(), 2,
		"only the producer and upgraded target should exist")
	assert_eq(screen.status_text, "Merged -> \u718a\u5927 II")
	assert_false(screen.status_text.contains("unit_a_2"))
	screen.session.tick(8.0)
	assert_eq(screen.session.resources.amount, before_merge + 25,
		"producer income continues above the refunded balance")
	screen.free()

func _remaining_insurance(battle: BattleSession) -> int:
	var count := 0
	for lane in range(battle.board.lanes):
		if battle.board.insurance_available(lane):
			count += 1
	return count

func _run_world01_04_strategy(use_upgrade: bool) -> Dictionary:
	var battle := BattleSession.new(_load_world01_04_repo())
	var results: Array[Dictionary] = []
	results.append(battle.deploy("unit_c_1", Vector2i(0, 0)))
	results.append(battle.deploy("unit_c_1", Vector2i(0, 4)))
	results.append(battle.deploy("unit_a_1", Vector2i(2, 2)))
	if use_upgrade:
		results.append(battle.play_card("unit_a_1", Vector2i(2, 2)))
	var base_schedule: Array[Dictionary] = [
		{"at": 8.0, "unit_id": "unit_a_1", "cell": Vector2i(2, 1)},
		{"at": 24.0, "unit_id": "unit_b_1", "cell": Vector2i(4, 1)},
		{"at": 32.0, "unit_id": "unit_a_1", "cell": Vector2i(2, 3)},
		{"at": 40.0, "unit_id": "unit_b_1", "cell": Vector2i(4, 3)},
		{"at": 48.0, "unit_id": "unit_a_1", "cell": Vector2i(2, 0)},
		{"at": 56.0, "unit_id": "unit_a_1", "cell": Vector2i(2, 4)},
		{"at": 72.0, "unit_id": "unit_b_1", "cell": Vector2i(4, 4)},
	]
	var base_index := 0
	for _step in range(5000):
		battle.tick(0.05)
		if base_index < base_schedule.size():
			var event := base_schedule[base_index]
			var unit_id := String(event["unit_id"])
			var required := int(repository.unit_def(unit_id).get("cost", 0))
			if battle.elapsed + 0.0001 >= float(event["at"]) and battle.resources.amount >= required:
				results.append(battle.deploy(unit_id, event["cell"]))
				base_index += 1
		if battle.state != BattleSession.STATE_RUNNING:
			break
	return {
		"state": battle.state,
		"elapsed": battle.elapsed,
		"insurance": _remaining_insurance(battle),
		"survivors": battle.board.unit_positions().size(),
		"resource": battle.resources.amount,
		"results": results,
	}

func test_world01_04_economy_and_upgrade_strategy_wins_real_runtime() -> void:
	var outcome := _run_world01_04_strategy(true)
	for result in outcome["results"]:
		assert_true(result.get("ok", false), str(result))
	assert_eq(String(outcome["state"]), BattleSession.STATE_VICTORY, str(outcome))
	assert_eq(int(outcome["insurance"]), 5,
		"the intended economy plus A2 plan should remain stable")

func test_world01_04_no_upgrade_control_holds_then_faces_more_pressure() -> void:
	var upgraded := _run_world01_04_strategy(true)
	var control := _run_world01_04_strategy(false)
	for result in control["results"]:
		assert_true(result.get("ok", false), str(result))
	assert_gt(float(control["elapsed"]), 70.0,
		"A1-only defense must hold for a while; there is no scripted instant failure")
	assert_lt(int(control["insurance"]), int(upgraded["insurance"]), str(control))
	assert_true(
		String(control["state"]) == BattleSession.STATE_FAILURE \
		or int(control["survivors"]) < int(upgraded["survivors"]),
		"without upgrades the same pressure must cost more defensive state"
	)
