class_name EnemyState
extends RefCounted
## Enemy progression along one lane. Behaviour differences come from the
## definition payload (speed, health, tree preference, etc.), not from ID
## if/else chains in core code.

var enemy_id: String
var lane: int
var progress_column: float
var move_speed: float
var current_health: int
var max_health: int
var attack_damage: int
var attack_period: float
var prefers_protected_tree: bool
var attack_cooldown_remaining := 0.0
var crossed_finish := false
var defeated := false
var insurance_triggered := false


func _init(p_enemy_id: String = "enemy_basic", p_lane: int = 0,
		p_start_column: float = 9.5, definition: Dictionary = {}) -> void:
	enemy_id = p_enemy_id
	lane = p_lane
	progress_column = p_start_column
	move_speed = float(definition.get("move_speed", 0.45))
	max_health = int(definition.get("max_health", 70))
	current_health = max_health
	attack_damage = int(definition.get("attack_damage", 10))
	attack_period = float(definition.get("attack_period", 1.0))
	prefers_protected_tree = bool(definition.get("prefers_protected_tree", false))


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


static func from_definition(def_id: String, definitions: Dictionary, lane: int,
		start_column: float) -> EnemyState:
	var def: Dictionary = definitions.get(def_id, {})
	return EnemyState.new(def_id, lane, start_column, def)
