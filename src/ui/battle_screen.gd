extends Node2D

const BOARD_ORIGIN := Vector2(120.0, 105.0)
const BOARD_SIZE := Vector2(900.0, 500.0)
# Cards are laid out from the level's deck config; no per-unit constants here.
const CARD_ORIGIN := Vector2(1060.0, 170.0)
const CARD_SIZE := Vector2(170.0, 70.0)
const CARD_SPACING := 90.0
const CARD_COLORS := [Color(0.15, 0.55, 0.75), Color(0.72, 0.4, 0.12), Color(0.4, 0.62, 0.2), Color(0.55, 0.35, 0.7)]
const START_LEVEL_ID := "world01_01"
const RESTART_RECT := Rect2(505.0, 365.0, 130.0, 40.0)
const NEXT_LEVEL_RECT := Rect2(645.0, 365.0, 130.0, 40.0)
const DEV_RESOURCE_RECT := Rect2(1040.0, 520.0, 220.0, 34.0)
const DEV_INFINITE_RECT := Rect2(1040.0, 562.0, 220.0, 34.0)

var repository := GameDataRepository.new()
var session: BattleSession
var pointer_router := PointerRouter.new()
var drag_payload: Dictionary = {}
var pointer_position := Vector2.ZERO
var hover_cell := Vector2i(-1, -1)
var status_text := "Drag cards to deploy. Drag a unit onto another to merge."
# Formal content identity (H4B): level title/briefing and unit display names
# come from data; internal ids stay internal.
var level_title := ""
var level_briefing := ""
# Deck entries: [{"unit_id": String, "rect": Rect2, "cost": int}] — built once
# from level.deck + repository unit definitions (single source of truth for cost).
var deck_cards: Array[Dictionary] = []
var dev_tools_enabled := OS.is_debug_build()
var dev_infinite_resources := false

func _ready() -> void:
	# H4B: the game boots into the formal World 01 level 1-1. The old
	# level_playable.json stays as a dev/regression fixture, still loadable
	# via BattleSession tests or by passing a path here.
	if not _load_level_by_id(START_LEVEL_ID):
		push_error("World01 level 1-1 failed to load")

func _load_level_by_id(level_id: String) -> bool:
	# Load into a candidate first: a bad/missing next level cannot poison the
	# currently playable repository or session.
	var candidate := GameDataRepository.new()
	if not candidate.load_level_by_id(level_id):
		push_error("Level '%s' failed to load" % level_id)
		return false
	repository = candidate
	level_title = String(repository.level.get("title", "World 01"))
	level_briefing = String(repository.level.get("briefing", ""))
	_build_deck_cards()
	session = BattleSession.new(repository)
	status_text = _initial_status_text()
	drag_payload = {}
	hover_cell = Vector2i(-1, -1)
	queue_redraw()
	return true

func _initial_status_text() -> String:
	var has_available_recipe := false
	for recipe in repository.recipes:
		var recipe_id := String(recipe.get("id", ""))
		if not session.recipe_gate_active or session.enabled_recipe_ids.has(recipe_id):
			has_available_recipe = true
			break
	if has_available_recipe:
		return "Drag cards to deploy. Drag a unit onto another to merge."
	return "Drag cards to deploy."

func _wave_total() -> int:
	if session == null:
		return 0
	var waves: Array = session.level.get("waves", [])
	return waves.size()

func _wave_progress_text() -> String:
	var total := _wave_total()
	var current := 0
	if session != null:
		current = clampi(session.next_wave_index, 0, total)
	return "波次 %d / %d" % [current, total]

func _next_wave_seconds() -> float:
	if session == null:
		return 0.0
	var waves: Array = session.level.get("waves", [])
	if session.next_wave_index < 0 or session.next_wave_index >= waves.size():
		return 0.0
	var wave: Dictionary = waves[session.next_wave_index]
	return maxf(0.0, float(wave.get("at", 0.0)) - session.elapsed)

func _next_wave_text() -> String:
	if session == null:
		return "下一波：0.0s"
	var waves: Array = session.level.get("waves", [])
	if session.next_wave_index >= waves.size():
		return "全部波次已出"
	return "下一波：%.1fs" % _next_wave_seconds()

func _advance_to_next_level() -> bool:
	if session == null or session.state != BattleSession.STATE_VICTORY:
		return false
	var next_level_id := String(repository.level.get("next_level_id", ""))
	if next_level_id.is_empty():
		return false
	return _load_level_by_id(next_level_id)

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

# Content identity: prefer the formal display_name from data; fall back to
# the internal id only when metadata is missing (e.g. dev fixtures).
func _display_name_for_unit(unit_id: String) -> String:
	var def := repository.unit_def(unit_id)
	return String(def.get("display_name", unit_id)) if not def.is_empty() else unit_id

func _display_name_for_enemy(enemy_id: String) -> String:
	var def := repository.enemy_def(enemy_id)
	return String(def.get("display_name", enemy_id)) if not def.is_empty() else enemy_id

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
			if _handle_dev_pointer_down(pointer_position):
				queue_redraw()
				return
			# Restart button is only visible/clickable once the battle ended.
			if session != null and session.state != BattleSession.STATE_RUNNING:
				if RESTART_RECT.has_point(pointer_position):
					_restart_level()
					queue_redraw()
					return
				if session.state == BattleSession.STATE_VICTORY \
						and NEXT_LEVEL_RECT.has_point(pointer_position):
					_advance_to_next_level()
					queue_redraw()
					return
			_begin_drag(pointer_position)
		"move":
			pass
		"up":
			_finish_drag(pointer_position)
	queue_redraw()

func _restart_level() -> void:
	status_text = "Level restarted."
	drag_payload = {}
	hover_cell = Vector2i(-1, -1)
	session = BattleSession.new(repository)

func _dev_tools_available() -> bool:
	return dev_tools_enabled and OS.is_debug_build()

func _handle_dev_pointer_down(point: Vector2) -> bool:
	if not _dev_tools_available() or session == null:
		return false
	if DEV_RESOURCE_RECT.has_point(point):
		session.resources.add(500)
		status_text = "DEV: +500 \u68ee\u6797\u7269\u8d44\u3002"
		return true
	if DEV_INFINITE_RECT.has_point(point):
		dev_infinite_resources = not dev_infinite_resources
		status_text = "DEV infinite resources: ON" if dev_infinite_resources else "DEV infinite resources: OFF"
		return true
	return false

func _refund_dev_spend(resource_before: int, result: Dictionary) -> void:
	if not _dev_tools_available() or not dev_infinite_resources or not result.get("ok", false):
		return
	var spent := resource_before - session.resources.amount
	if spent > 0:
		session.resources.add(spent)

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
	var resource_before := session.resources.amount
	var target := _cell_from_point(point)
	var result: Dictionary
	if drag_payload["kind"] == "card":
		result = session.deploy(String(drag_payload["unit_id"]), target)
		status_text = "Deployed." if result.get("ok", false) else "Rejected: %s" % result.get("reason", "unknown")
	else:
		result = session.merge_cells(drag_payload["source"], target)
		status_text = "Merged -> %s" % _display_name_for_unit(String(result.get("result", ""))) if result.get("ok", false) else "Rejected: %s" % result.get("reason", "unknown")
	_refund_dev_spend(resource_before, result)
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
	draw_string(font, Vector2(40, 45), level_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(font, Vector2(40, 74), "5 lanes | %d columns | \u68ee\u6797\u7269\u8d44 %d" % [session.board.columns, session.resources.amount], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.85, 0.93))
	if not level_briefing.is_empty():
		draw_string(font, Vector2(620, 74), level_briefing, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.85, 0.6))
	draw_string(font, Vector2(40, 98), _wave_progress_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.65, 0.9, 1.0))
	draw_string(font, Vector2(205, 98), _next_wave_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.85, 0.55))
	_draw_board(font)
	_draw_cards(font)
	if _dev_tools_available():
		_draw_dev_controls(font)
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
				_draw_unit(rect.get_center(), value.unit_id, font, value.health, value.max_health)
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

func _draw_unit(center: Vector2, unit_id: String, font: Font,
		health: int = -1, max_health: int = -1) -> void:
	if unit_id.begins_with("unit_a"):
		var tier := 1
		if unit_id.ends_with("_2"):
			tier = 2
		elif unit_id.ends_with("_3"):
			tier = 3
		draw_circle(center, 20.0 + tier * 4.0, Color(0.2, 0.75, 1.0))
	elif unit_id == "unit_b_1":
		draw_rect(Rect2(center - Vector2(27, 27), Vector2(54, 54)), Color(1.0, 0.62, 0.22), true)
	elif unit_id == "unit_c_1":
		var producer_points := PackedVector2Array([
			center + Vector2(0, -27),
			center + Vector2(26, -8),
			center + Vector2(16, 23),
			center + Vector2(-16, 23),
			center + Vector2(-26, -8),
		])
		draw_colored_polygon(producer_points, Color(0.35, 0.76, 0.25))
		draw_circle(center, 8.0, Color(0.95, 0.78, 0.2))
	else:
		draw_circle(center - Vector2(13, 0), 23.0, Color(0.2, 0.75, 1.0))
		draw_rect(Rect2(center + Vector2(-2, -23), Vector2(46, 46)), Color(1.0, 0.62, 0.22), true)
	if max_health > 0 and health >= 0:
		var ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
		var bar_rect := Rect2(center + Vector2(-34.0, -40.0), Vector2(68.0, 7.0))
		draw_rect(bar_rect, Color(0.12, 0.12, 0.12), true)
		draw_rect(Rect2(bar_rect.position + Vector2(1.0, 1.0),
				Vector2((bar_rect.size.x - 2.0) * ratio, bar_rect.size.y - 2.0)),
				Color(0.25, 0.85, 0.35) if ratio > 0.35 else Color(0.95, 0.28, 0.2), true)
	draw_string(font, center + Vector2(-45, 42), _display_name_for_unit(unit_id), HORIZONTAL_ALIGNMENT_CENTER, 90, 13, Color.WHITE)

func _draw_tree(center: Vector2, tree: Dictionary, font: Font) -> void:
	var color := Color(0.58, 0.36, 0.16) if tree.get("alive", false) else Color(0.24, 0.21, 0.19)
	var points := PackedVector2Array([center + Vector2(0, -30), center + Vector2(28, 0), center + Vector2(0, 30), center + Vector2(-28, 0)])
	draw_colored_polygon(points, color)
	draw_string(font, center + Vector2(-45, 46), "tree %d" % int(tree.get("health", 0)), HORIZONTAL_ALIGNMENT_CENTER, 90, 12, Color(0.92, 0.82, 0.65))

func _draw_enemy(center: Vector2, enemy: EnemyState, font: Font) -> void:
	if enemy.enemy_id == "enemy_armored":
		var armor_rect := Rect2(center - Vector2(29, 25), Vector2(58, 50))
		draw_rect(armor_rect, Color(0.25, 0.31, 0.38), true)
		draw_rect(armor_rect.grow(-6.0), Color(0.48, 0.58, 0.67), true)
		draw_circle(center + Vector2(-17, 25), 7.0, Color(0.08, 0.1, 0.12))
		draw_circle(center + Vector2(17, 25), 7.0, Color(0.08, 0.1, 0.12))
	else:
		var color := Color(0.78, 0.28, 0.85) if enemy.prefers_tree else Color(1.0, 0.25, 0.32)
		var points := PackedVector2Array([center + Vector2(-26, -23), center + Vector2(28, 0), center + Vector2(-26, 23)])
		draw_colored_polygon(points, color)
	draw_string(font, center + Vector2(-42, 43), "%s %d" % [_display_name_for_enemy(enemy.enemy_id), enemy.health], HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color.WHITE)

func _draw_cards(font: Font) -> void:
	draw_string(font, Vector2(1060, 125), "CARDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	for index in deck_cards.size():
		var card: Dictionary = deck_cards[index]
		var rect: Rect2 = card["rect"]
		draw_rect(rect, CARD_COLORS[index % CARD_COLORS.size()], true)
		# Cost shown on the card comes from the same unit definition the
		# Battle Session spends against; the label is the formal display name.
		draw_string(font, rect.position + Vector2(20, 42),
				"%s  cost %d" % [_display_name_for_unit(String(card["unit_id"])), int(card["cost"])],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		var definition := repository.unit_def(String(card["unit_id"]))
		if String(definition.get("behavior", "")) == "resource_producer":
			var period_text := ("%.1f" % float(definition.get("production_period", 0.0))).trim_suffix(".0")
			draw_string(font, rect.position + Vector2(20, 63),
					"\u6bcf%ss +%d" % [period_text, int(definition.get("production_amount", 0))],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 1.0, 0.8))
	var fusion_title_y := maxf(385.0, CARD_ORIGIN.y + CARD_SPACING * deck_cards.size() + 10.0)
	draw_string(font, Vector2(1060, fusion_title_y), "FUSIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	# Recipe hints are data-driven and level-gated: only recipes enabled by the
	# current level's enabled_recipe_ids are shown (GPT review on PR #8).
	var shown := 0
	for recipe in _visible_recipes():
		draw_string(font, Vector2(1060, fusion_title_y + 25.0 + shown * 25.0),
				"%s + %s -> %s" % [_display_name_for_unit(String(recipe.get("input_a", ""))),
						_display_name_for_unit(String(recipe.get("input_b", ""))),
						_display_name_for_unit(String(recipe.get("result", "")))],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 0.95))
		shown += 1
	if shown == 0:
		draw_string(font, Vector2(1060, fusion_title_y + 25.0), "\u672c\u5173\u672a\u89e3\u9501\u5408\u6210", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.55, 0.6))

func _visible_recipes() -> Array:
	var visible: Array = []
	for recipe in repository.recipes:
		var recipe_id := String(recipe.get("id", ""))
		if session.recipe_gate_active and not session.enabled_recipe_ids.has(recipe_id):
			continue
		visible.append(recipe)
	return visible

func _draw_dev_controls(font: Font) -> void:
	draw_string(font, Vector2(1040, 505), "DEV TOOLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.75, 0.35))
	draw_rect(DEV_RESOURCE_RECT, Color(0.3, 0.25, 0.1), true)
	draw_string(font, DEV_RESOURCE_RECT.position + Vector2(14, 23), "DEV +500\u68ee\u6797\u7269\u8d44", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var infinite_color := Color(0.18, 0.45, 0.25) if dev_infinite_resources else Color(0.25, 0.28, 0.32)
	draw_rect(DEV_INFINITE_RECT, infinite_color, true)
	var infinite_label := "DEV 无限资源：ON" if dev_infinite_resources else "DEV 无限资源：OFF"
	draw_string(font, DEV_INFINITE_RECT.position + Vector2(14, 23), infinite_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func _draw_status(font: Font) -> void:
	draw_string(font, Vector2(40, 642), status_text, HORIZONTAL_ALIGNMENT_LEFT, 930, 16, Color(0.78, 0.86, 0.92))
	draw_string(font, Vector2(40, 678), "State: %s | protected alive %d" % [session.state, session.board.alive_tree_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if session.state != BattleSession.STATE_RUNNING:
		var text := "VICTORY" if session.state == BattleSession.STATE_VICTORY else "FAILURE"
		draw_rect(Rect2(330, 270, 620, 130), Color(0.03, 0.05, 0.07, 0.92), true)
		draw_string(font, Vector2(560, 345), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
		# Restart always rebuilds the current level (or press R).
		draw_rect(RESTART_RECT, Color(0.15, 0.45, 0.25), true)
		draw_string(font, RESTART_RECT.position + Vector2(30, 30), "再来一局 (R)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		if session.state == BattleSession.STATE_VICTORY \
				and not String(repository.level.get("next_level_id", "")).is_empty():
			draw_rect(NEXT_LEVEL_RECT, Color(0.18, 0.42, 0.72), true)
			draw_string(font, NEXT_LEVEL_RECT.position + Vector2(32, 30), "下一关", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R \
			and session != null and session.state != BattleSession.STATE_RUNNING:
		_restart_level()

func _draw_drag_preview(font: Font) -> void:
	var unit_id := String(drag_payload.get("unit_id", ""))
	_draw_unit(pointer_position, unit_id, font)
	if drag_payload.get("kind", "") == "unit" and session.board.is_inside(hover_cell):
		var recipe := session.fusion_preview(drag_payload["source"], hover_cell)
		if not recipe.is_empty():
			draw_string(font, pointer_position + Vector2(-80, -42), "-> %s" % _display_name_for_unit(String(recipe.get("result", ""))), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(0.35, 1.0, 0.58))
