extends Node2D

const BOARD_ORIGIN := Vector2(120.0, 105.0)
const BOARD_SIZE := Vector2(900.0, 500.0)
const CARD_A_RECT := Rect2(1060.0, 170.0, 170.0, 70.0)
const CARD_B_RECT := Rect2(1060.0, 260.0, 170.0, 70.0)

var battle: BattleState
var config: Dictionary
var enemies: Array = []
var spawn_elapsed := 0.0
var spawn_index := 0
var drag_payload: Dictionary = {}
var drag_position := Vector2.ZERO
var hover_cell := Vector2i(-1, -1)
var status_text := "Drag a card to an empty cell. Drag one unit onto another to merge."
var minimum_protected_trees := 1


func _ready() -> void:
	config = _load_level_config()
	battle = BattleState.new(
		int(config.get("lanes", 5)),
		int(config.get("columns", 9)),
		int(config.get("initial_resource", 450))
	)
	minimum_protected_trees = int(config.get("minimum_protected_trees", 1))
	for target in config.get("protected_trees", []):
		battle.add_protected_tree(
			target["id"],
			Vector2i(int(target["column"]), int(target["lane"])),
			int(target.get("health", 120))
		)
	_spawn_enemy(false)
	queue_redraw()


func _load_level_config() -> Dictionary:
	var file := FileAccess.open("res://src/data/level_graybox.json", FileAccess.READ)
	if file == null:
		return {"lanes": 5, "columns": 9, "initial_resource": 450, "protected_trees": []}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _process(delta: float) -> void:
	if battle.level_failed:
		queue_redraw()
		return
	spawn_elapsed += delta
	if spawn_elapsed >= 3.5:
		spawn_elapsed = 0.0
		spawn_index += 1
		_spawn_enemy(spawn_index % 3 == 2)
	battle.tick(delta, enemies)
	for enemy in enemies:
		if enemy.insurance_triggered:
			status_text = "Lane %d insurance consumed." % [enemy.lane + 1]
	enemies = enemies.filter(func(enemy): return not enemy.defeated and not enemy.crossed_finish)
	queue_redraw()


func _spawn_enemy(tree_attacker: bool) -> void:
	var lane := spawn_index % battle.board.lanes
	var enemy_id := "enemy_tree_targeter" if tree_attacker else "enemy_basic"
	var speed := 0.34 if tree_attacker else 0.46
	var health := 95 if tree_attacker else 70
	enemies.append(EnemyState.new(enemy_id, lane, float(battle.board.columns) + 0.4, speed, health, tree_attacker))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		drag_position = event.position
		hover_cell = _cell_from_point(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_finish_drag(event.position)


func _begin_drag(point: Vector2) -> void:
	drag_position = point
	if CARD_A_RECT.has_point(point):
		drag_payload = {"kind": "card", "unit_id": "unit_a_1"}
		return
	if CARD_B_RECT.has_point(point):
		drag_payload = {"kind": "card", "unit_id": "unit_b_1"}
		return
	var cell := _cell_from_point(point)
	var state := battle.board.cell_state(cell)
	if state.get("kind", "") == "unit":
		drag_payload = {"kind": "board_unit", "source": cell, "unit_id": state["unit_id"]}


func _finish_drag(point: Vector2) -> void:
	if drag_payload.is_empty():
		return
	var target := _cell_from_point(point)
	if drag_payload["kind"] == "card":
		var result := battle.deploy(drag_payload["unit_id"], target)
		status_text = _result_message(result, "Deployed %s." % drag_payload["unit_id"])
	else:
		var result := battle.merge_cells(drag_payload["source"], target)
		var success_message := "Merged into %s; one-cell coverage is the tradeoff." % result.get("after_target", {}).get("unit_id", "result")
		status_text = _result_message(result, success_message)
	drag_payload = {}
	hover_cell = Vector2i(-1, -1)
	queue_redraw()


func _result_message(result: Dictionary, success_message: String) -> String:
	return success_message if result.get("ok", false) else "Rejected: %s" % result.get("reason", "unknown")


func _cell_from_point(point: Vector2) -> Vector2i:
	if not Rect2(BOARD_ORIGIN, BOARD_SIZE).has_point(point):
		return Vector2i(-1, -1)
	var local := point - BOARD_ORIGIN
	return Vector2i(int(local.x / _cell_width()), int(local.y / _lane_height()))


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		BOARD_ORIGIN + Vector2(float(cell.x) * _cell_width(), float(cell.y) * _lane_height()),
		Vector2(_cell_width(), _lane_height())
	)


func _cell_width() -> float:
	return BOARD_SIZE.x / float(battle.board.columns)


func _lane_height() -> float:
	return BOARD_SIZE.y / float(battle.board.lanes)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40, 45), "P1 LANE DEFENSE GRAYBOX", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(font, Vector2(40, 74), "5 lanes | %d configured columns | resource %d" % [battle.board.columns, battle.resource], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.72, 0.82, 0.9))
	_draw_board(font)
	_draw_cards(font)
	_draw_status(font)
	if not drag_payload.is_empty():
		_draw_drag_preview(font)


func _draw_board(font: Font) -> void:
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), Color(0.09, 0.13, 0.16), true)
	for lane in range(battle.board.lanes):
		for column in range(battle.board.columns):
			var cell := Vector2i(column, lane)
			var rect := _cell_rect(cell)
			var fill := Color(0.12, 0.18, 0.2) if (lane + column) % 2 == 0 else Color(0.105, 0.155, 0.18)
			draw_rect(rect.grow(-1.0), fill, true)
			var state := battle.board.cell_state(cell)
			if state.get("kind", "") == "unit":
				_draw_unit(rect.get_center(), state["unit_id"], font)
			elif state.get("kind", "") == "protected_tree":
				_draw_tree(rect.get_center(), battle.board.protected_target_at(cell), font)
		var insurance_color := Color(0.2, 0.85, 0.45) if battle.board.insurance_available(lane) else Color(0.25, 0.27, 0.3)
		draw_rect(Rect2(BOARD_ORIGIN.x - 42.0, BOARD_ORIGIN.y + lane * _lane_height() + 28.0, 26.0, 44.0), insurance_color, true)
		draw_string(font, Vector2(BOARD_ORIGIN.x - 105.0, BOARD_ORIGIN.y + lane * _lane_height() + 58.0), "L%d" % [lane + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	for enemy in enemies:
		var center := Vector2(
			BOARD_ORIGIN.x + (enemy.progress_column + 0.5) * _cell_width(),
			BOARD_ORIGIN.y + (float(enemy.lane) + 0.5) * _lane_height()
		)
		_draw_enemy(center, enemy, font)
	if hover_cell.x >= 0 and battle.board.is_inside(hover_cell):
		var preview_color := Color(0.25, 0.85, 1.0, 0.35)
		if drag_payload.get("kind", "") == "board_unit":
			var target_state := battle.board.cell_state(hover_cell)
			var recipe := battle.recipe_book.find_recipe(drag_payload.get("unit_id", ""), target_state.get("unit_id", ""))
			preview_color = Color(0.3, 1.0, 0.5, 0.45) if not recipe.is_empty() else Color(1.0, 0.25, 0.25, 0.35)
		draw_rect(_cell_rect(hover_cell).grow(-3.0), preview_color, true)


func _draw_unit(center: Vector2, unit_id: String, font: Font) -> void:
	match unit_id:
		"unit_a_1", "unit_a_2", "unit_a_3":
			var radius := 21.0 + float(unit_id.right(1).to_int()) * 3.0
			draw_circle(center, radius, Color(0.2, 0.75, 1.0))
		"unit_b_1":
			draw_rect(Rect2(center - Vector2(27, 27), Vector2(54, 54)), Color(1.0, 0.62, 0.22), true)
		"unit_ab":
			draw_circle(center - Vector2(13, 0), 23.0, Color(0.2, 0.75, 1.0))
			draw_rect(Rect2(center + Vector2(-2, -23), Vector2(46, 46)), Color(1.0, 0.62, 0.22), true)
	draw_string(font, center + Vector2(-38, 42), unit_id, HORIZONTAL_ALIGNMENT_CENTER, 76, 13, Color.WHITE)


func _draw_tree(center: Vector2, target: Dictionary, font: Font) -> void:
	var alive: bool = target.get("alive", false)
	var color := Color(0.58, 0.36, 0.16) if alive else Color(0.25, 0.21, 0.19)
	var points := PackedVector2Array([center + Vector2(0, -30), center + Vector2(28, 0), center + Vector2(0, 30), center + Vector2(-28, 0)])
	draw_colored_polygon(points, color)
	draw_string(font, center + Vector2(-45, 46), "protected_tree %d" % int(target.get("current_health", 0)), HORIZONTAL_ALIGNMENT_CENTER, 90, 12, Color(0.92, 0.82, 0.65))


func _draw_enemy(center: Vector2, enemy: EnemyState, font: Font) -> void:
	var color := Color(1.0, 0.25, 0.32) if not enemy.prefers_protected_tree else Color(0.78, 0.28, 0.85)
	var points := PackedVector2Array([center + Vector2(-26, -23), center + Vector2(28, 0), center + Vector2(-26, 23)])
	draw_colored_polygon(points, color)
	draw_string(font, center + Vector2(-35, 43), "%s %d" % [enemy.enemy_id, enemy.current_health], HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color.WHITE)


func _draw_cards(font: Font) -> void:
	draw_string(font, Vector2(1060, 125), "GEOMETRY CARDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_rect(CARD_A_RECT, Color(0.15, 0.55, 0.75), true)
	draw_circle(CARD_A_RECT.position + Vector2(35, 35), 21, Color(0.2, 0.82, 1.0))
	draw_string(font, CARD_A_RECT.position + Vector2(65, 31), "unit_a_1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, CARD_A_RECT.position + Vector2(65, 53), "cost 50", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.95, 1.0))
	draw_rect(CARD_B_RECT, Color(0.72, 0.4, 0.12), true)
	draw_rect(Rect2(CARD_B_RECT.position + Vector2(14, 14), Vector2(42, 42)), Color(1.0, 0.68, 0.28), true)
	draw_string(font, CARD_B_RECT.position + Vector2(65, 31), "unit_b_1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, CARD_B_RECT.position + Vector2(65, 53), "cost 75", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.94, 0.84))
	draw_string(font, Vector2(1060, 375), "Recipes", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	draw_string(font, Vector2(1060, 405), "A1 + A1 -> A2 (30)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.85, 0.9))
	draw_string(font, Vector2(1060, 430), "A2 + A2 -> A3 (60)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.85, 0.9))
	draw_string(font, Vector2(1060, 455), "A1 + B1 -> AB (100)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.85, 0.9))
	draw_string(font, Vector2(1060, 500), "AB uses one cell:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.35))
	draw_string(font, Vector2(1060, 522), "less lane coverage.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.35))


func _draw_status(font: Font) -> void:
	var objective_ok := battle.board.protected_objective_met(minimum_protected_trees)
	var objective_color := Color(0.35, 1.0, 0.55) if objective_ok else Color(1.0, 0.3, 0.3)
	draw_string(font, Vector2(40, 640), status_text, HORIZONTAL_ALIGNMENT_LEFT, 940, 16, Color(0.78, 0.86, 0.92))
	draw_string(font, Vector2(40, 676), "Objective: keep %d protected_tree alive | alive %d" % [minimum_protected_trees, battle.board.alive_protected_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, objective_color)
	if battle.level_failed:
		draw_rect(Rect2(300, 280, 680, 120), Color(0.2, 0.02, 0.04, 0.92), true)
		draw_string(font, Vector2(390, 350), "GRAYBOX FAILURE: LANE BREACHED", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.35, 0.35))


func _draw_drag_preview(font: Font) -> void:
	var unit_id: String = drag_payload.get("unit_id", "")
	_draw_unit(drag_position, unit_id, font)
	if drag_payload.get("kind", "") == "board_unit" and battle.board.is_inside(hover_cell):
		var target_state := battle.board.cell_state(hover_cell)
		var recipe := battle.recipe_book.find_recipe(unit_id, target_state.get("unit_id", ""))
		if not recipe.is_empty():
			draw_string(font, drag_position + Vector2(-80, -42), "FIXED PREVIEW -> %s" % recipe["result"], HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(0.35, 1.0, 0.58))
