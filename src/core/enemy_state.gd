class_name EnemyState
extends RefCounted

var enemy_id: String
var lane: int
var progress_column: float
var move_speed: float
var current_health: int
var attack_damage: int
var attack_period: float
var prefers_protected_tree: bool
var attack_cooldown_remaining := 0.0
var crossed_finish := false
var defeated := false
var insurance_triggered := false


func _init(
	p_enemy_id: String = "enemy_basic",
	p_lane: int = 0,
	p_start_column: float = 9.5,
	p_move_speed: float = 0.45,
	p_health: int = 70,
	p_prefers_tree: bool = false
) -> void:
	enemy_id = p_enemy_id
	lane = p_lane
	progress_column = p_start_column
	move_speed = p_move_speed
	current_health = p_health
	attack_damage = 10 if not p_prefers_tree else 14
	attack_period = 1.0
	prefers_protected_tree = p_prefers_tree


func advance(delta: float) -> void:
	if defeated or crossed_finish:
		return
	progress_column -= move_speed * delta
	if progress_column < 0.0:
		crossed_finish = true


func take_damage(amount: int) -> void:
	if defeated:
		return
	current_health = maxi(0, current_health - amount)
	defeated = current_health == 0
