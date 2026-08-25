class_name ProtectedTreeRule
extends RefCounted

var minimum_alive: int

func _init(p_minimum_alive: int = 0) -> void:
	minimum_alive = maxi(0, p_minimum_alive)

func is_met(board: BoardState) -> bool:
	return board.alive_tree_count() >= minimum_alive
