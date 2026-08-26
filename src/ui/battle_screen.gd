extends Node2D

const BOARD_ORIGIN := Vector2(120.0, 105.0)
const BOARD_SIZE := Vector2(900.0, 500.0)
# Cards are laid out from the level's deck config; no per-unit constants here.
const CARD_ORIGIN := Vector2(1060.0, 170.0)
const CARD_SIZE := Vector2(170.0, 70.0)
const CARD_SPACING := 90.0
const CARD_COLORS := [Color(0.15, 0.55, 0.75), Color(0.72, 0.4, 0.12), Color(0.4, 0.62, 0.2), Color(0.55, 0.35, 0.7)]

var repository := GameDataRepository.new()
var session: BattleSession
var pointer_router := PointerRouter.new()
var drag_payload: Dictionary = {}
var pointer_position := Vector2.ZERO
var hover_cell := Vector2i(-1, -1)
var status_text := "Drag cards to deploy. Drag a unit onto another to merge."
# Deck entries: [{"unit_id": String, "rect": Rect2, "cost": int}] — built once
# from level.deck + repository unit definitions (single source of truth for cost).
var deck_cards: Array[Dictionary] = []

func _ready() -> void:
	if not repository.load_all():
		push_error("P2 data failed to load")
		return
	_build_deck_cards()
	session = BattleSession.new(repository)
	queue_redraw()

# Deck comes from the level config; cost always reads the unit definition so
# JSON and Battle Core share one source of truth. Adding a third or fourth
# character is a data edit, not a UI code change.
func _build_deck_cards() -> void:
	deck_cards.clear()
	var deck: Array = repository.level.get("deck", [])
	for index in deck.size():
		var unit_id := String(deck[index])
		var definition := repository.unit_def(unit_id)
		if definition.is_empty():
			push_error("Deck references unknown unit '%s' — card skipped." % unit_id)
			continue
		deck_cards.append({
			"unit_id": unit_id,
			"rect": Rect2(CARD_ORIGIN + Vector2(0.0, CARD_SPACING * index), CARD_SIZE),
			"cost": int(definition.get("cost", 0)),
		})

func _card_at(point: Vector2) -> Dictionary:
	for card in deck_cards:
		if (card["rect"] as Rect2).has_point(point):
			return card
	return {}

func _process(delta: float) -> void:
	if session == null:
		return
	session.tick(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var pointer := pointer_router.decode(event)
	if pointer.is_empty():
		return
	pointer_position = pointer["position"]
	hover_cell = _cell_from_point(pointer_position)
	match pointer["type"]:
		"down":
			_begin_drag(pointer_position)
		"move":
			pass
		"up":
			_finish_drag(pointer_position)
	queue_redraw()

func _begin_drag(point: Vector2) -> void:
	if session == null or session.state != BattleSession.STATE_RUNNING:
		return
	var card := _card_at(point)
	if not card.is_empty():
		drag_payload = {"kind": "card", "unit_id": String(card["unit_id"])}
		return
	var cell := _cell_from_point(point)
	var value = session.board.cell_value(cell)
	if value is UnitState:
		drag_payload = {"kind": "unit", "source": cell, "unit_id": value.unit_id}

func _finish_drag(point: Vector2) -> void:
	if drag_payload.is_empty() or session == null:
		return
	var target := _cell_from_point(point)
	var result: Dictionary
	if drag_payload["kind"] == "card":
		result = session.deploy(String(drag_payload["unit_id"]), target)
		status_text = "Deployed." if result.get("ok", false) else "Rejected: %s" % result.get("reason", "unknown")
	else:
		result = session.merge_cells(drag_payload["source"], target)
		status_text = "Merged -> %s" % result.get("result", "") if result.get("ok", false) else "Rejected: %s" % result.get("reason", "unknown")
	drag_payload = {}
	hover_cell = Vector2i(-1, -1)

func _cell_from_point(point: Vector2) -> Vector2i:
	if session == null or not Rect2(BOARD_ORIGIN, BOARD_SIZE).has_point(point):
		return Vector2i(-1, -1)
	var local := point - BOARD_ORIGIN
	return Vector2i(int(local.x / _cell_width()), int(local.y / _lane_height()))

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(float(cell.x) * _cell_width(), float(cell.y) * _lane_height()), Vector2(_cell_width(), _lane_height()))

func _cell_width() -> float:
	return BOARD_SIZE.x / float(session.board.columns)

func _lane_height() -> float:
	return BOARD_SIZE.y / float(session.board.lanes)

func _draw() -> void:
	if session == null:
		return
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40, 45), "P2 PLAYABLE PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(font, Vector2(40, 74), "5 lanes | %d columns | resource %d" % [session.board.columns, session.resources.amount], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.85, 0.93))
	_draw_board(font)
	_draw_cards(font)
	_draw_status(font)
	if not drag_payload.is_empty():
		_draw_drag_preview(font)

func _draw_board(font: Font) -> void:
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), Color(0.08, 0.12, 0.15), true)
	for lane in range(session.board.lanes):
		for column in range(session.board.columns):
			var cell := Vector2i(column, lane)
			var rect := _cell_rect(cell)
			var fill := Color(0.11, 0.18, 0.18) if (lane + column) % 2 == 0 else Color(0.09, 0.15, 0.17)
			draw_rect(rect.grow(-1.0), fill, true)
			var value = session.board.cell_value(cell)
			if value is UnitState:
				_draw_unit(rect.get_center(), value.unit_id, font)
			elif value is Dictionary and value.get("kind", "") == "protected_tree":
				_draw_tree(rect.get_center(), session.board.tree_at(cell), font)
		var insurance_color := Color(0.2, 0.85, 0.45) if session.board.insurance_available(lane) else Color(0.25, 0.27, 0.3)
		draw_rect(Rect2(BOARD_ORIGIN.x - 42.0, BOARD_ORIGIN.y + lane * _lane_height() + 28.0, 26.0, 44.0), insurance_color, true)
	for enemy in session.enemies:
		var center := Vector2(BOARD_ORIGIN.x + (enemy.progress_column + 0.5) * _cell_width(), BOARD_ORIGIN.y + (float(enemy.lane) + 0.5) * _lane_height())
		_draw_enemy(center, enemy, font)
	if session.board.is_inside(hover_cell):
		var preview_color := Color(0.25, 0.85, 1.0, 0.28)
		if drag_payload.get("kind", "") == "unit":
			var recipe := session.fusion_preview(drag_payload["source"], hover_cell)
			preview_color = Color(0.3, 1.0, 0.5, 0.38) if not recipe.is_empty() else Color(1.0, 0.25, 0.25, 0.28)
		draw_rect(_cell_rect(hover_cell).grow(-3.0), preview_color, true)

func _draw_unit(center: Vector2, unit_id: String, font: Font) -> void:
	if unit_id.begins_with("unit_a"):
		var tier := 1
		if unit_id.ends_with("_2"):
			tier = 2
		elif unit_id.ends_with("_3"):
			tier = 3
		draw_circle(center, 20.0 + tier * 4.0, Color(0.2, 0.75, 1.0))
	elif unit_id == "unit_b_1":
		draw_rect(Rect2(center - Vector2(27, 27), Vector2(54, 54)), Color(1.0, 0.62, 0.22), true)
	else:
		draw_circle(center - Vector2(13, 0), 23.0, Color(0.2, 0.75, 1.0))
		draw_rect(Rect2(center + Vector2(-2, -23), Vector2(46, 46)), Color(1.0, 0.62, 0.22), true)
	draw_string(font, center + Vector2(-45, 42), unit_id, HORIZONTAL_ALIGNMENT_CENTER, 90, 13, Color.WHITE)

func _draw_tree(center: Vector2, tree: Dictionary, font: Font) -> void:
	var color := Color(0.58, 0.36, 0.16) if tree.get("alive", false) else Color(0.24, 0.21, 0.19)
	var points := PackedVector2Array([center + Vector2(0, -30), center + Vector2(28, 0), center + Vector2(0, 30), center + Vector2(-28, 0)])
	draw_colored_polygon(points, color)
	draw_string(font, center + Vector2(-45, 46), "tree %d" % int(tree.get("health", 0)), HORIZONTAL_ALIGNMENT_CENTER, 90, 12, Color(0.92, 0.82, 0.65))

func _draw_enemy(center: Vector2, enemy: EnemyState, font: Font) -> void:
	var color := Color(0.78, 0.28, 0.85) if enemy.prefers_tree else Color(1.0, 0.25, 0.32)
	var points := PackedVector2Array([center + Vector2(-26, -23), center + Vector2(28, 0), center + Vector2(-26, 23)])
	draw_colored_polygon(points, color)
	draw_string(font, center + Vector2(-42, 43), "%s %d" % [enemy.enemy_id, enemy.health], HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color.WHITE)

func _draw_cards(font: Font) -> void:
	draw_string(font, Vector2(1060, 125), "CARDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	for index in deck_cards.size():
		var card: Dictionary = deck_cards[index]
		var rect: Rect2 = card["rect"]
		draw_rect(rect, CARD_COLORS[index % CARD_COLORS.size()], true)
		# Cost shown on the card comes from the same unit definition the
		# Battle Session spends against.
		draw_string(font, rect.position + Vector2(20, 42),
				"%s  cost %d" % [card["unit_id"], int(card["cost"])],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(font, Vector2(1060, 385), "A1+A1 -> A2", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 0.95))
	draw_string(font, Vector2(1060, 410), "A2+A2 -> A3", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 0.95))
	draw_string(font, Vector2(1060, 435), "A1+B1 -> AB", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 0.95))

func _draw_status(font: Font) -> void:
	draw_string(font, Vector2(40, 642), status_text, HORIZONTAL_ALIGNMENT_LEFT, 930, 16, Color(0.78, 0.86, 0.92))
	draw_string(font, Vector2(40, 678), "State: %s | protected alive %d" % [session.state, session.board.alive_tree_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if session.state != BattleSession.STATE_RUNNING:
		var text := "VICTORY" if session.state == BattleSession.STATE_VICTORY else "FAILURE"
		draw_rect(Rect2(330, 270, 620, 130), Color(0.03, 0.05, 0.07, 0.92), true)
		draw_string(font, Vector2(560, 345), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)

func _draw_drag_preview(font: Font) -> void:
	var unit_id := String(drag_payload.get("unit_id", ""))
	_draw_unit(pointer_position, unit_id, font)
	if drag_payload.get("kind", "") == "unit" and session.board.is_inside(hover_cell):
		var recipe := session.fusion_preview(drag_payload["source"], hover_cell)
		if not recipe.is_empty():
			draw_string(font, pointer_position + Vector2(-80, -42), "-> %s" % recipe.get("result", ""), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(0.35, 1.0, 0.58))
