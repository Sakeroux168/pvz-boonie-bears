class_name BoardState
extends RefCounted

var lanes: int
var columns: int
var _cells: Dictionary = {}
var _trees: Dictionary = {}
var _lane_insurance: Array[bool] = []

func _init(p_lanes: int = 5, p_columns: int = 9) -> void:
	lanes = p_lanes
	columns = p_columns
	for _lane in range(lanes):
		_lane_insurance.append(true)

func is_inside(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < lanes and cell.x >= 0 and cell.x < columns

func is_empty(cell: Vector2i) -> bool:
	return is_inside(cell) and not _cells.has(cell)

func cell_value(cell: Vector2i):
	return _cells.get(cell, null)

func place_unit(cell: Vector2i, unit: UnitState) -> bool:
	if not is_empty(cell):
		return false
	_cells[cell] = unit
	return true

func remove_unit(cell: Vector2i):
	var value = _cells.get(cell, null)
	if value is not UnitState:
		return null
	_cells.erase(cell)
	return value

func unit_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _cells:
		if _cells[cell] is UnitState:
			result.append(cell)
	return result

func place_tree(tree_id: String, cell: Vector2i, health: int) -> bool:
	if tree_id.is_empty() or not is_empty(cell) or _trees.has(tree_id):
		return false
	_cells[cell] = {"kind": "protected_tree", "tree_id": tree_id}
	_trees[tree_id] = {
		"id": tree_id,
		"cell": cell,
		"max_health": health,
		"health": health,
		"alive": true
	}
	return true

func tree_at(cell: Vector2i) -> Dictionary:
	var marker = _cells.get(cell, null)
	if marker is Dictionary and marker.get("kind", "") == "protected_tree":
		return _trees.get(marker.get("tree_id", ""), {}).duplicate(true)
	return {}

func tree_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tree in _trees.values():
		result.append(tree["cell"])
	return result

func damage_tree(cell: Vector2i, amount: int) -> bool:
	var marker = _cells.get(cell, null)
	if marker is not Dictionary or marker.get("kind", "") != "protected_tree":
		return false
	var tree_id: String = marker["tree_id"]
	var tree: Dictionary = _trees[tree_id]
	tree["health"] = maxi(0, int(tree["health"]) - amount)
	tree["alive"] = int(tree["health"]) > 0
	_trees[tree_id] = tree
	return true

func alive_tree_count() -> int:
	var count := 0
	for tree in _trees.values():
		if bool(tree.get("alive", false)):
			count += 1
	return count

func insurance_available(lane: int) -> bool:
	return lane >= 0 and lane < lanes and _lane_insurance[lane]

func consume_insurance(lane: int) -> bool:
	if not insurance_available(lane):
		return false
	_lane_insurance[lane] = false
	return true
