extends RefCounted


static func board_dimensions() -> Dictionary:
	var board_8 := BoardState.new(5, 8)
	var board_10 := BoardState.new(5, 10)
	return _result(board_8.lanes == 5 and board_8.columns == 8 and board_10.columns == 10, "5 lanes and configured columns")


static func occupancy_conflict() -> Dictionary:
	var battle := BattleState.new(5, 9, 500)
	var first := battle.deploy("unit_a_1", Vector2i(2, 1))
	var second := battle.deploy("unit_b_1", Vector2i(2, 1))
	return _result(first["ok"] and not second["ok"] and second["reason"] == "cell_occupied", "occupied cell rejects deployment")


static func enemy_lane_progress() -> Dictionary:
	var enemy := EnemyState.new("enemy_basic", 3, 9.5, 0.5, 70, false)
	enemy.advance(2.0)
	return _result(enemy.lane == 3 and is_equal_approx(enemy.progress_column, 8.5), "enemy remains in lane and moves right-to-left")


static func same_unit_upgrade() -> Dictionary:
	var battle := BattleState.new(5, 9, 1000)
	battle.deploy("unit_a_1", Vector2i(1, 0))
	battle.deploy("unit_a_1", Vector2i(2, 0))
	var wounded := battle.board.cell_state(Vector2i(1, 0))
	wounded["current_health"] = 40
	wounded["attack_cooldown_remaining"] = 0.7
	battle.board.set_cell_state(Vector2i(1, 0), wounded)
	var before_resource := battle.resource
	var merged := battle.merge_cells(Vector2i(1, 0), Vector2i(2, 0), 1000)
	var result := battle.board.cell_state(Vector2i(2, 0))
	var behavior: String = battle.catalog.definition(result.get("unit_id", "")).get("behavior", "")
	var ok: bool = bool(merged["ok"]) and result["unit_id"] == "unit_a_2" and behavior == "double_ranged"
	ok = ok and int(result["current_health"]) < int(battle.catalog.definition("unit_a_2")["max_health"])
	ok = ok and float(result["attack_cooldown_remaining"]) >= 0.7 and battle.resource == before_resource - 30
	ok = ok and battle.undo_window_open(2000) and not battle.undo_last_merge(2000)["ok"]
	return _result(ok, "A1+A1 becomes behavior-changing A2 without state refresh")


static func invalid_upgrade_rejected() -> Dictionary:
	var battle := BattleState.new(5, 9, 1000)
	battle.deploy("unit_a_1", Vector2i(1, 0))
	battle.deploy("unit_b_1", Vector2i(2, 0))
	var state := battle.board.cell_state(Vector2i(1, 0))
	state["unit_id"] = "unit_a_2"
	battle.board.set_cell_state(Vector2i(1, 0), state)
	var merged := battle.merge_cells(Vector2i(1, 0), Vector2i(2, 0))
	return _result(not merged["ok"] and merged["reason"] == "illegal_recipe", "invalid same-unit upgrade is rejected")


static func fixed_cross_fusion() -> Dictionary:
	var battle := BattleState.new(5, 9, 1000)
	battle.deploy("unit_a_1", Vector2i(1, 2))
	battle.deploy("unit_b_1", Vector2i(5, 2))
	var before_cells := battle.board.unit_positions().size()
	var merged := battle.merge_cells(Vector2i(1, 2), Vector2i(5, 2), 1000)
	var result := battle.board.cell_state(Vector2i(5, 2))
	var definition := battle.catalog.definition(result.get("unit_id", ""))
	var ok: bool = bool(merged["ok"]) and result["unit_id"] == "unit_ab" and before_cells == 2
	ok = ok and battle.board.unit_positions().size() == 1 and definition["behavior"] == "ranged_plus_guard_collaboration"
	return _result(ok, "A+B deterministically becomes collaborative AB and loses one-cell coverage")


static func invalid_recipe_rejected() -> Dictionary:
	var book := RecipeBook.new()
	return _result(not book.is_legal("unit_b_1", "unit_b_1") and book.find_recipe("unit_b_1", "unit_a_2").is_empty(), "unknown recipes are rejected")


static func protected_target_condition() -> Dictionary:
	var battle := BattleState.new(5, 9, 500)
	var placed := battle.add_protected_tree("protected_tree_test", Vector2i(4, 2), 20)
	var blocked := battle.deploy("unit_a_1", Vector2i(4, 2))
	var before := battle.board.protected_objective_met(1)
	battle.board.damage_protected_tree_at(Vector2i(4, 2), 20)
	var after := battle.board.protected_objective_met(1)
	return _result(placed and not blocked["ok"] and before and not after, "protected target blocks deployment and controls objective")


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
