class_name ResourceWallet
extends RefCounted
## Single-resource economy (D021). Deploy, same-unit upgrade and fixed fusion
## all spend from this one pool.

signal changed(current: int)

var current: int


func _init(initial: int = 450) -> void:
	current = maxi(0, initial)


func can_afford(cost: int) -> bool:
	return current >= cost


func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	current -= cost
	changed.emit(current)
	return true


func add(amount: int) -> void:
	if amount <= 0:
		return
	current += amount
	changed.emit(current)
