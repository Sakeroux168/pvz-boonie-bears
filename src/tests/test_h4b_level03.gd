extends GutTest

const WORLD01_02_PATH := "res://src/data/levels/world01_02.json"
const WORLD01_03_PATH := "res://src/data/levels/world01_03.json"

var repository: GameDataRepository

func before_each() -> void:
	repository = GameDataRepository.new()
	assert_true(repository.load_all())

func _running_level(initial_resource: int = 500) -> Dictionary:
	return {
		"id": "producer_test",
		"lanes": 5,
		"columns": 9,
		"initial_resource": initial_resource,
		"minimum_protected_trees": 0,
		"protected_trees": [],
		"waves": [{"at": 999.0, "enemy": "enemy_basic", "lane": 4}],
	}

func _producer_battle(initial_resource: int = 100) -> BattleSession:
	var battle := BattleSession.new(repository, _running_level(initial_resource))
	assert_true(battle.deploy("unit_c_1", Vector2i(0, 0))["ok"])
	return battle

func test_resource_producer_waits_a_full_period_before_first_income() -> void:
	var battle := _producer_battle()
	assert_eq(battle.resources.amount, 50)
	battle.tick(7.99)
	assert_eq(battle.resources.amount, 50)
	battle.tick(0.01)
	assert_eq(battle.resources.amount, 75)

func test_resource_producer_large_delta_catches_up_every_period() -> void:
	var battle := _producer_battle()
	battle.tick(24.0)
	assert_eq(battle.resources.amount, 125, "three periods must add 3 x 25")

func test_two_resource_producers_accumulate_independently() -> void:
	var battle := _producer_battle(200)
	assert_true(battle.deploy("unit_c_1", Vector2i(0, 1))["ok"])
	assert_eq(battle.resources.amount, 100)
	battle.tick(8.0)
	assert_eq(battle.resources.amount, 150)

func test_resource_producer_does_not_attack() -> void:
	var battle := _producer_battle()
	var enemy := EnemyState.from_definition({
		"id": "stationary",
		"move_speed": 0.0,
		"max_health": 100,
		"attack_damage": 0,
		"attack_period": 1.0,
	}, 0, 3.0)
	battle.enemies.append(enemy)
	battle.tick(8.0)
	assert_eq(enemy.health, 100)
	assert_eq(battle.resources.amount, 75)

func test_producer_killed_in_enemy_phase_cannot_produce_that_tick() -> void:
	var battle := _producer_battle()
	var enemy := EnemyState.from_definition({
		"id": "executioner",
		"move_speed": 0.0,
		"max_health": 100,
		"attack_damage": 100,
		"attack_period": 1.0,
	}, 0, 0.5)
	battle.enemies.append(enemy)
	battle.tick(8.0)
	assert_false(battle.board.cell_value(Vector2i(0, 0)) is UnitState)
	assert_eq(battle.resources.amount, 50)

func test_resource_producer_schema_does_not_require_attack_fields() -> void:
	var definition := repository.unit_def("unit_c_1")
	for field in ["range_cells", "attack_period", "damage", "burst_count"]:
		assert_false(definition.has(field))
	assert_true(LevelValidator.is_valid(
		_running_level(),
		repository.units,
		repository.enemies,
		repository.recipes
	))

func test_validator_rejects_invalid_production_period_and_amount() -> void:
	var units := repository.units.duplicate(true)
	units["unit_c_1"]["production_period"] = 0.0
	units["unit_c_1"]["production_amount"] = 0
	var problems := LevelValidator.validate(
		_running_level(),
		units,
		repository.enemies,
		repository.recipes
	)
	assert_true(problems.any(func(problem: String) -> bool:
		return problem.contains("production_period must be > 0")))
	assert_true(problems.any(func(problem: String) -> bool:
		return problem.contains("production_amount must be > 0")))

func _load_world01_03_repo() -> GameDataRepository:
	var repo := GameDataRepository.new()
	assert_true(repo.load_all(WORLD01_03_PATH))
	return repo

func test_world01_02_points_to_world01_03() -> void:
	var repo := GameDataRepository.new()
	assert_true(repo.load_all(WORLD01_02_PATH))
	assert_eq(String(repo.level.get("next_level_id")), "world01_03")

func test_world01_03_formal_data_has_exact_tutorial_scope() -> void:
	var repo := _load_world01_03_repo()
	assert_eq(String(repo.level.get("id")), "world01_03")
	assert_eq(String(repo.level.get("title")), "1-3 \u677e\u679c\u4e0d\u591f\u5566\uff01")
	assert_eq(int(repo.level.get("lanes")), 5)
	assert_eq(int(repo.level.get("columns")), 9)
	assert_eq(int(repo.level.get("initial_resource")), 200)
	assert_eq(repo.level.get("deck", []), ["unit_a_1", "unit_b_1", "unit_c_1"])
	assert_eq(repo.level.get("enabled_recipe_ids", []), [])
	assert_eq(int(repo.level.get("minimum_protected_trees")), 0)
	assert_eq(repo.level.get("protected_trees", []), [])
	var waves: Array = repo.level.get("waves", [])
	assert_eq(waves.size(), 10)
	assert_between(float(waves[-1].get("at")), 90.0, 120.0)
	for wave in waves:
		assert_eq(String(wave.get("enemy")), "enemy_basic")
	assert_eq(String(repo.level.get("next_level_id")), "world01_04")

func test_world01_03_recipe_gate_blocks_upgrade_and_cross_fusion() -> void:
	var battle := BattleSession.new(_load_world01_03_repo())
	battle.resources.add(500)
	assert_true(battle.deploy("unit_a_1", Vector2i(1, 0))["ok"])
	assert_true(battle.deploy("unit_a_1", Vector2i(2, 0))["ok"])
	assert_true(battle.deploy("unit_a_1", Vector2i(1, 1))["ok"])
	assert_true(battle.deploy("unit_b_1", Vector2i(2, 1))["ok"])
	var before := battle.resources.amount
	assert_eq(
		String(battle.merge_cells(Vector2i(1, 0), Vector2i(2, 0)).get("reason")),
		"recipe_disabled_in_level"
	)
	assert_eq(
		String(battle.merge_cells(Vector2i(1, 1), Vector2i(2, 1)).get("reason")),
		"recipe_disabled_in_level"
	)
	assert_eq(battle.resources.amount, before)
	assert_eq(battle.board.unit_positions().size(), 4)

func test_restart_rebuilds_world01_03_and_resets_production_state() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_03"))
	assert_true(screen.session.deploy("unit_c_1", Vector2i(0, 0))["ok"])
	screen.session.tick(7.0)
	screen._restart_level()
	assert_eq(String(screen.repository.level.get("id")), "world01_03")
	assert_eq(screen.session.resources.amount, 200)
	assert_eq(screen.session.elapsed, 0.0)
	assert_eq(screen.session.board.unit_positions().size(), 0)
	assert_true(screen.session.deploy("unit_c_1", Vector2i(0, 0))["ok"])
	screen.session.tick(1.0)
	assert_eq(screen.session.resources.amount, 150)
	screen.free()

func _run_world01_03_expansion(use_producers: bool) -> Dictionary:
	var battle := BattleSession.new(_load_world01_03_repo())
	var schedule: Array[Dictionary] = []
	if use_producers:
		battle.deploy("unit_c_1", Vector2i(0, 1))
		battle.deploy("unit_c_1", Vector2i(0, 3))
		battle.deploy("unit_a_1", Vector2i(2, 2))
		battle.deploy("unit_a_1", Vector2i(2, 1))
		schedule = [
			{"at": 8.0, "lane": 3},
			{"at": 16.0, "lane": 0},
			{"at": 24.0, "lane": 4},
		]
	else:
		for lane in [2, 1, 3, 0]:
			battle.deploy("unit_a_1", Vector2i(2, lane))
		schedule = [{"at": 24.0, "lane": 4}]
	var next_deploy := 0
	var results: Array[Dictionary] = []
	for _i in range(5000):
		battle.tick(0.05)
		if next_deploy < schedule.size() and battle.elapsed + 0.0001 >= float(schedule[next_deploy]["at"]) and (not use_producers or battle.resources.amount >= 50):
			var result := battle.deploy(
				"unit_a_1",
				Vector2i(2, int(schedule[next_deploy]["lane"]))
			)
			results.append(result)
			next_deploy += 1
		if battle.state != BattleSession.STATE_RUNNING:
			break
	return {
		"state": battle.state,
		"results": results,
		"resource": battle.resources.amount,
	}

func test_world01_03_economy_strategy_wins_real_runtime() -> void:
	var outcome := _run_world01_03_expansion(true)
	for result in outcome["results"]:
		assert_true(result.get("ok", false), str(result))
	assert_eq(outcome["results"].size(), 3)
	assert_eq(String(outcome["state"]), BattleSession.STATE_VICTORY, str(outcome))

func test_world01_03_same_expansion_without_producers_hits_resource_wall() -> void:
	var outcome := _run_world01_03_expansion(false)
	assert_eq(outcome["results"].size(), 1)
	assert_false(outcome["results"][0].get("ok", false))
	assert_eq(String(outcome["results"][0].get("reason")), "insufficient_resource")
	assert_eq(String(outcome["state"]), BattleSession.STATE_FAILURE)

func test_dev_infinite_refund_does_not_suppress_producer_income() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_03"))
	screen.dev_tools_enabled = true
	if not screen._dev_tools_available():
		pending("debug-only DEV contract requires a debug build")
		screen.free()
		return
	screen.dev_infinite_resources = true
	var before: int = screen.session.resources.amount
	var result: Dictionary = screen.session.deploy("unit_c_1", Vector2i(0, 0))
	screen._refund_dev_spend(before, result)
	assert_eq(screen.session.resources.amount, before)
	screen.session.tick(8.0)
	assert_eq(screen.session.resources.amount, before + 25)
	screen.free()

func test_battle_screen_advances_full_world01_chain_to_level04() -> void:
	var screen_script = load("res://src/ui/battle_screen.gd")
	var screen = screen_script.new()
	assert_true(screen._load_level_by_id("world01_01"))
	screen.session.state = BattleSession.STATE_VICTORY
	assert_true(screen._advance_to_next_level())
	assert_eq(String(screen.repository.level.get("id")), "world01_02")
	screen.session.state = BattleSession.STATE_VICTORY
	assert_true(screen._advance_to_next_level())
	assert_eq(String(screen.repository.level.get("id")), "world01_03")
	assert_eq(screen.deck_cards.size(), 3)
	assert_eq(String(screen.deck_cards[2].get("unit_id")), "unit_c_1")
	assert_eq(int(screen.deck_cards[2].get("cost")), 50)
	screen.session.state = BattleSession.STATE_VICTORY
	assert_true(screen._advance_to_next_level())
	assert_eq(String(screen.repository.level.get("id")), "world01_04")
	screen.free()
