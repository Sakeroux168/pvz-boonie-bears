class_name ResourcePool
extends RefCounted

var amount: int

func _init(initial_amount: int = 0) -> void:
	amount = initial_amount

func can_spend(cost: int) -> bool:
	return cost >= 0 and amount >= cost

func spend(cost: int) -> bool:
	if not can_spend(cost):
		return false
	amount -= cost
	return true

func add(value: int) -> void:
	amount += maxi(0, value)
