extends Node2D
## Battle scene controller: loads data, drives BattleCore.tick, draws geometry
## placeholders and handles mouse drag deploy/fusion. NO rule logic here — all
## rules live in BattleCore and its data layer.

const CELL_SIZE := 96.0
const GRID_ORIGIN := Vector2(120.0, 110.0)

var core: BattleCore
var level: Dictionary = {}

var _dragging := false
var _drag_unit_id := ""
var _drag_from_cell := Vector2i(-1, -1)
var _drag_pos := Vector2.ZERO
var _message := ""
var _message_until_ms := 0


func _ready() -> void:
	level = _load_json("res://src/data/level_proto_01.json")
	core = BattleCore.new(level)
	core.load_data(
			_load_json("res://src/data/units.json"),
			_load_json("res://src/data/recipes.json"),
			_load_json("res://src/data/enemies.json"))
	core.start(level.get("waves", []))


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _process(delta: float) -> void:
	core.tick(delta)
	queue_redraw()


func _draw() -> void:
	_draw_grid()
	_draw_protected_trees()
	_draw_insurance()
	_draw_units()
	_draw_enemies()
	_draw_hand()
	_draw_hud()
	if _dragging:
		var preview := core.preview_merge(_drag_from_cell, _cell_at(_drag_pos)) if _drag_unit_id == "" else {}
		_draw_drag_cursor(preview)


func _draw_grid() -> void:
	for lane in range(core.board.lanes):
		for column in range(core.board.columns):
			var rect := Rect2(GRID_ORIGIN + Vector2(column * CELL_SIZE, lane * CELL_SIZE),
					Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0))
			draw_rect(rect, Color(0.13, 0.16, 0.14), true)


func _draw_protected_trees() -> void:
	for cell in core.board.protected_positions():
		var tree := core.board.protected_target_at(cell)
		var center := _cell_center(cell)
		var color := Color(0.2, 0.65, 0.3) if bool(tree.get("alive", false)) else Color(0.35, 0.3, 0.25)
		draw_circle(center, 30.0, color)
		draw_string(ThemeDB.fallback_font, center + Vector2(-38, 44),
				"tree %d/%d" % [int(tree.get("current_health", 0)), int(tree.get("max_health", 0))],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.9, 0.8))


func _draw_insurance() -> void:
	for lane in range(core.board.lanes):
		var available := core.board.insurance_available(lane)
		var rect := Rect2(GRID_ORIGIN + Vector2(-52.0, lane * CELL_SIZE + 18.0), Vector2(40.0, 56.0))
		draw_rect(rect, Color(0.85, 0.7, 0.2) if available else Color(0.25, 0.25, 0.22), true)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 32), "rock",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK if available else Color(0.5, 0.5, 0.45))


func _draw_units() -> void:
	for cell in core.board.unit_positions():
		var state := core.board.cell_state(cell)
		var def: Dictionary = core.catalog.definition(String(state["unit_id"]))
		var center := _cell_center(cell)
		var color := Color(0.3, 0.55, 0.95) if String(def.get("family")) != "unit_b" else Color(0.9, 0.6, 0.2)
		if String(def.get("family")) == "unit_ab":
			color = Color(0.65, 0.4, 0.9)
		draw_rect(Rect2(center - Vector2(28, 28), Vector2(56, 56)), color, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(-26, -34), String(state["unit_id"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_rect(Rect2(center + Vector2(-28, 30), Vector2(56 * float(state["current_health"]) / float(def["max_health"]), 5)),
				Color(0.3, 0.9, 0.4), true)


func _draw_enemies() -> void:
	for enemy in core.waves.active_enemies:
		if enemy.defeated:
			continue
		var pos := GRID_ORIGIN + Vector2(enemy.progress_column * CELL_SIZE, enemy.lane * CELL_SIZE + CELL_SIZE * 0.5)
		var color := Color(0.85, 0.25, 0.25) if not enemy.prefers_protected_tree else Color(0.6, 0.2, 0.75)
		draw_circle(pos, 20.0, color)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-46, -24), String(enemy.enemy_id),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.85))


func _draw_hand() -> void:
	var cards := [
		{"id": "unit_a1", "cost": 50},
		{"id": "unit_b1", "cost": 75},
	]
	for index in cards.size():
		var rect := Rect2(Vector2(140 + index * 120, 640), Vector2(100, 60))
		draw_rect(rect, Color(0.2, 0.3, 0.5), true)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 24), String(cards[index]["id"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 46), "cost %d" % int(cards[index]["cost"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.85, 1))


func _draw_hud() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(24, 36), "resource: %d" % core.wallet.current,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.95, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(280, 36), "outcome: %s" % core.outcome,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(0.4, 1, 0.4) if core.outcome == "victory" else Color(1, 0.5, 0.4) if core.outcome == "defeat" else Color.WHITE)
	if Time.get_ticks_msec() < _message_until_ms:
		draw_string(ThemeDB.fallback_font, Vector2(520, 36), _message,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.8, 0.5))


func _cell_at(pos: Vector2) -> Vector2i:
	var local := (pos - GRID_ORIGIN) / CELL_SIZE
	return Vector2i(int(floor(local.x)), int(floor(local.y)))


func _cell_center(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5 - 2.0,
			cell.y * CELL_SIZE + CELL_SIZE * 0.5 - 2.0)


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_drag_pos = event.position


func _begin_drag(pos: Vector2) -> void:
	# Pick from hand cards.
	for index in 2:
		var rect := Rect2(Vector2(140 + index * 120, 640), Vector2(100, 60))
		if rect.has_point(pos):
			_dragging = true
			_drag_unit_id = "unit_a1" if index == 0 else "unit_b1"
			_drag_from_cell = Vector2i(-1, -1)
			_drag_pos = pos
			return
	# Pick from a placed unit (for fusion drag).
	var cell := _cell_at(pos)
	if core.board.cell_state(cell).get("kind") == "unit":
		_dragging = true
		_drag_unit_id = ""
		_drag_from_cell = cell
		_drag_pos = pos


func _end_drag(pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var cell := _cell_at(pos)
	if not core.board.is_inside(cell):
		return
	if _drag_unit_id != "":
		var result := core.deploy(_drag_unit_id, cell)
		_flash(result)
	else:
		var result := core.merge_cells(_drag_from_cell, cell)
		_flash(result)
	_drag_unit_id = ""


func _flash(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_message = "%s ok" % String(result["kind"])
	else:
		_message = "rejected: %s" % String(result["reason"])
	_message_until_ms = Time.get_ticks_msec() + 2000


func _draw_drag_cursor(preview: Dictionary) -> void:
	var legal := bool(preview.get("legal", true))
	draw_circle(_drag_pos, 10.0, Color(0.4, 1, 0.4) if legal else Color(1, 0.3, 0.3))
