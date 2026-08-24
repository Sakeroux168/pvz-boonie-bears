extends GutTest
## GUT 9.7.1 tests for the P2 Playable Prototype core rules.
## All rule logic is exercised headless through BattleCore — no scene/UI.

const UNITS_JSON := "res://src/data/units.json"
const RECIPES_JSON := "res://src/data/recipes.json"
const ENEMIES_JSON := "res://src/data/enemies.json"
const LEVEL_JSON := "res://src/data/level_proto_01.json"


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text())


func _make_core(columns: int = 9, strip_trees: bool = false) -> BattleCore:
	var level: Dictionary = _read_json(LEVEL_JSON)
	level["columns"] = columns
	if strip_trees:
		# Pure state-machine scenarios: the level's trees sit at columns 4/5
		# and would be dropped on a narrow board, instantly failing a
		# min=1 tree objective. Tree rules are covered separately in
		# test_protected_tree_rules on the full-size board.
		level["protected_trees"] = []
		level["minimum_protected_trees"] = 0
	var core := BattleCore.new(level)
	core.load_data(_read_json(UNITS_JSON), _read_json(RECIPES_JSON), _read_json(ENEMIES_JSON))
	return core


# 1. 5 lanes and parameterized column counts (8/9/10).
func test_grid_lanes_and_variable_columns() -> void:
	for columns in [8, 9, 10]:
		var core := _make_core(columns)
		assert_eq(core.board.lanes, 5, "lanes fixed at 5")
		assert_eq(core.board.columns, columns)
		assert_true(core.board.is_inside(Vector2i(columns - 1, 4)))
		assert_false(core.board.is_inside(Vector2i(columns, 0)))


# 2. Occupancy conflict.
func test_cell_occupancy_conflict_rejected() -> void:
	var core := _make_core()
	assert_eq(core.deploy("unit_a1", Vector2i(2, 2))["ok"], true)
	var second := core.deploy("unit_a1", Vector2i(2, 2))
	assert_eq(second["ok"], false)
	assert_eq(second["reason"], "cell_occupied")


# 3. Insufficient resource rejects deployment.
func test_insufficient_resource_rejects_deploy() -> void:
	var core := _make_core()
	# Drain the wallet below unit_b1 cost (75).
	core.wallet.spend(core.wallet.current)
	core.wallet.add(60)
	var result := core.deploy("unit_b1", Vector2i(0, 0))
	assert_eq(result["ok"], false)
	assert_eq(result["reason"], "insufficient_resource")
	assert_null(core.board.cell_state(Vector2i(0, 0)).get("unit_id"), "nothing placed")


# 4. Enemies advance along their own lane only.
func test_enemies_advance_in_lane() -> void:
	var core := _make_core()
	core.start([{
		"start_time": 0.0,
		"spawns": [{"enemy_id": "enemy_basic", "lane": 2, "delay": 0.0}],
	}])
	core.tick(1.5)
	assert_eq(core.waves.active_enemies.size(), 1)
	var enemy := core.waves.active_enemies[0]
	assert_eq(enemy.lane, 2)
	var start_column := enemy.progress_column
	core.tick(1.0)
	assert_lt(core.waves.active_enemies[0].progress_column, start_column)


# 5. Lane insurance triggers exactly once per lane.
func test_lane_insurance_only_once() -> void:
	var core := _make_core(3)
	assert_true(core.board.insurance_available(1))
	assert_true(core.board.consume_insurance(1))
	assert_false(core.board.consume_insurance(1), "second trigger must fail")
	assert_false(core.board.insurance_available(1))


# Helper: force a placed unit pair for merge tests.
# Cells are explicit so a test can place multiple pairs on one board.
func _place_pair(core: BattleCore, id_left: String, id_right: String,
		left_cell: Vector2i = Vector2i(1, 0), right_cell: Vector2i = Vector2i(3, 0)) -> void:
	# Give free resource so deploy costs don't matter here.
	core.wallet.add(10000)
	assert_eq(core.deploy(id_left, left_cell)["ok"], true)
	assert_eq(core.deploy(id_right, right_cell)["ok"], true)


# 6. A1 + A1 -> A2.
func test_upgrade_a1_plus_a1_to_a2() -> void:
	var core := _make_core()
	_place_pair(core, "unit_a1", "unit_a1")
	var result := core.merge_cells(Vector2i(1, 0), Vector2i(3, 0))
	assert_eq(result["ok"], true)
	assert_eq(String(result["result_unit"]), "unit_a2")
	assert_null(core.board.cell_state(Vector2i(1, 0)).get("unit_id"), "source cell emptied")
	assert_eq(String(core.board.cell_state(Vector2i(3, 0))["unit_id"]), "unit_a2")


# 7. A2 + A2 -> A3.
func test_upgrade_a2_plus_a2_to_a3() -> void:
	var core := _make_core()
	_place_pair(core, "unit_a2", "unit_a2")
	var result := core.merge_cells(Vector2i(1, 0), Vector2i(3, 0))
	assert_eq(result["ok"], true)
	assert_eq(String(result["result_unit"]), "unit_a3")


# 8. Illegal upgrade / recipe rejected.
func test_illegal_recipes_rejected() -> void:
	var core := _make_core()
	_place_pair(core, "unit_a3", "unit_a3")  # no tier beyond 3
	var result := core.merge_cells(Vector2i(1, 0), Vector2i(3, 0))
	assert_eq(result["ok"], false)
	assert_eq(result["reason"], "illegal_recipe")
	_place_pair(core, "unit_b1", "unit_b1", Vector2i(1, 1), Vector2i(3, 1))  # no B+B recipe
	result = core.merge_cells(Vector2i(1, 1), Vector2i(3, 1))
	assert_eq(result["ok"], false)
	assert_eq(result["reason"], "illegal_recipe")


# 9. A + B -> AB (cross-unit fusion).
func test_fusion_a_plus_b_to_ab() -> void:
	var core := _make_core()
	_place_pair(core, "unit_a1", "unit_b1")
	var result := core.merge_cells(Vector2i(1, 0), Vector2i(3, 0))
	assert_eq(result["ok"], true)
	assert_eq(String(result["result_unit"]), "unit_ab")
	assert_eq(core.recipe_book.preview_result("unit_a1", "unit_b1"), "unit_ab")
	# Two cells collapsed into one — coverage opportunity cost.
	assert_false(core.board.is_empty(Vector2i(3, 0)))
	assert_true(core.board.is_empty(Vector2i(1, 0)))


# 10. Fusion state inheritance — no free heal / cooldown refresh.
func test_fusion_inherits_worse_state() -> void:
	var core := _make_core()
	core.wallet.add(10000)
	assert_eq(core.deploy("unit_a1", Vector2i(1, 0))["ok"], true)
	assert_eq(core.deploy("unit_a1", Vector2i(3, 0))["ok"], true)
	# Damage one input badly and set cooldowns asymmetrically.
	var hurt := core.board.cell_state(Vector2i(3, 0))
	hurt["current_health"] = 20  # ratio ~0.25 vs 1.0
	hurt["attack_cooldown_remaining"] = 2.5
	core.board.set_cell_state(Vector2i(3, 0), hurt)
	var result := core.merge_cells(Vector2i(1, 0), Vector2i(3, 0))
	assert_eq(result["ok"], true)
	var merged := core.board.cell_state(Vector2i(3, 0))
	var expected_health := int(round(105 * (20.0 / 80.0)))
	assert_eq(int(merged["current_health"]), expected_health, "keeps worse health ratio, no free heal")
	assert_gt(float(merged["attack_cooldown_remaining"]), 0.0, "cooldown not refreshed")


# 11. protected_tree occupancy, damage and objective condition.
func test_protected_tree_rules() -> void:
	var core := _make_core()
	var tree_cell := Vector2i(4, 1)
	assert_eq(core.deploy("unit_a1", tree_cell)["ok"], false, "cannot deploy on tree cell")
	assert_eq(core.board.damage_protected_tree_at(tree_cell, 120), true)
	assert_false(core.board.protected_target_at(tree_cell)["alive"], "tree dies at 0 hp")
	# Level has two trees, minimum is 1: one surviving tree still meets it.
	assert_true(core.board.protected_objective_met(1),
			"one surviving tree meets min=1")
	# A stricter objective (need both trees alive) must fail once one dies.
	assert_false(core.board.protected_objective_met(2),
			"objective with min=2 fails when a tree dies")


# 12. Victory / defeat state machine core rules.
func test_victory_and_defeat_outcomes() -> void:
	# Defeat: enemy crosses finish without insurance.
	var core := _make_core(3, true)
	core.start([{"start_time": 0.0, "spawns": [{"enemy_id": "enemy_basic", "lane": 0, "delay": 0.0}]}])
	core.board._lane_insurance[0] = false  # insurance already spent
	for i in range(600):
		core.tick(0.05)
		if core.outcome != "ongoing":
			break
	assert_eq(core.outcome, "defeat", "unstopped enemy crossing loses the game")

	# Insurance saves the lane exactly once: first crosser is stopped.
	var core_ins := _make_core(3, true)
	core_ins.start([{"start_time": 0.0, "spawns": [{"enemy_id": "enemy_basic", "lane": 2, "delay": 0.0}]}])
	for i in range(600):
		core_ins.tick(0.05)
		if core_ins.outcome != "ongoing":
			break
	assert_true(core_ins.waves.active_enemies[0].insurance_triggered,
			"insurance consumed on first crossing")
	assert_false(core_ins.waves.active_enemies[0].crossed_finish and not core_ins.waves.active_enemies[0].defeated,
			"insured crossing does not lose the game")
	assert_eq(core_ins.outcome, "victory", "sole enemy cleared by insurance ends in victory")

	# Victory: waves all spawned and all enemies defeated.
	var core2 := _make_core(3, true)
	core2.start([{"start_time": 0.0, "spawns": [{"enemy_id": "enemy_basic", "lane": 0, "delay": 0.0}]}])
	core2.tick(0.5)
	assert_eq(core2.outcome, "ongoing")
	for enemy in core2.waves.active_enemies:
		enemy.take_damage(enemy.current_health + 1)
	core2.tick(0.05)
	assert_eq(core2.outcome, "victory", "all enemies dead after final wave wins")

	# Ongoing while enemies remain.
	var core3 := _make_core(3, true)
	core3.start([{"start_time": 0.0, "spawns": [{"enemy_id": "enemy_basic", "lane": 0, "delay": 0.0}]}])
	core3.tick(0.5)
	assert_eq(core3.outcome, "ongoing")
