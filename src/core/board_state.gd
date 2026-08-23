class_name BoardState
extends RefCounted

var lanes: int
var columns: int
var _cells: Dictionary = {}
var _protected_targets: Dictionary = {}
var _lane_insurance: Array[bool] = []


func _init(p_lanes: int = 5, p_columns: int = 9) -> void:
	lanes = p_lanes
	columns = p_columns
	for lane in range(lanes):
		_lane_insurance.append(true)


func is_inside(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < lanes and cell.x >= 0 and cell.x < columns


func is_empty(cell: Vector2i) -> bool:
	return is_inside(cell) and not _cells.has(cell)


func cell_state(cell: Vector2i) -> Dictionary:
	if not _cells.has(cell):
		return {}
	return _cells[cell].duplicate(true)


func set_cell_state(cell: Vector2i, state: Dictionary) -> bool:
	if not is_inside(cell) or state.is_empty():
		return false
	_cells[cell] = state.duplicate(true)
	return true


func place_unit(cell: Vector2i, state: Dictionary) -> bool:
	if not is_empty(cell) or state.get("kind", "") != "unit":
		return false
	_cells[cell] = state.duplicate(true)
	return true


func remove_unit(cell: Vector2i) -> Dictionary:
	var previous := cell_state(cell)
	if previous.get("kind", "") != "unit":
		return {}
	_cells.erase(cell)
	return previous


func place_protected_tree(target_id: String, cell: Vector2i, health: int = 100) -> bool:
	if target_id.is_empty() or _protected_targets.has(target_id) or not is_empty(cell):
		return false
	_cells[cell] = {"kind": "protected_tree", "target_id": target_id}
	_protected_targets[target_id] = {
		"id": target_id, "cell": cell, "max_health": health,
		"current_health": health, "alive": true
	}
	return true


func damage_protected_tree_at(cell: Vector2i, amount: int) -> bool:
	var marker := cell_state(cell)
	if marker.get("kind", "") != "protected_tree":
		return false
	var target_id: String = marker["target_id"]
	var target: Dictionary = _protected_targets[target_id]
	target["current_health"] = maxi(0, int(target["current_health"]) - amount)
	target["alive"] = int(target["current_health"]) > 0
	_protected_targets[target_id] = target
	return true


func protected_target_at(cell: Vector2i) -> Dictionary:
	var marker := cell_state(cell)
	if marker.get("kind", "") != "protected_tree":
		return {}
	return _protected_targets[marker["target_id"]].duplicate(true)


func protected_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for target in _protected_targets.values():
		result.append(target["cell"])
	return result


func alive_protected_count() -> int:
	var count := 0
	for target in _protected_targets.values():
		if target["alive"]:
			count += 1
	return count


func protected_objective_met(minimum_alive: int) -> bool:
	return alive_protected_count() >= minimum_alive


func unit_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _cells:
		if _cells[cell].get("kind", "") == "unit":
			result.append(cell)
	return result


func insurance_available(lane: int) -> bool:
	return lane >= 0 and lane < lanes and _lane_insurance[lane]


func consume_insurance(lane: int) -> bool:
	if not insurance_available(lane):
		return false
	_lane_insurance[lane] = false
	return true


func snapshot() -> Dictionary:
	return {
		"lanes": lanes,
		"columns": columns,
		"cells": _cells.duplicate(true),
		"protected_targets": _protected_targets.duplicate(true),
		"lane_insurance": _lane_insurance.duplicate()
	}
