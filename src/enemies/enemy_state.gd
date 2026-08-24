class_name EnemyState
extends RefCounted

var enemy_id := ""
var lane := 0
var progress_column := 0.0
var move_speed := 0.5
var max_health := 1
var health := 1
var attack_damage := 10
var attack_period := 1.0
var attack_cooldown := 0.0
var prefers_tree := false
var defeated := false
var crossed_finish := false

static func from_definition(definition: Dictionary, p_lane: int, start_column: float) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.enemy_id = String(definition.get("id", ""))
	enemy.lane = p_lane
	enemy.progress_column = start_column
	enemy.move_speed = float(definition.get("move_speed", 0.5))
	enemy.max_health = int(definition.get("max_health", 1))
	enemy.health = enemy.max_health
	enemy.attack_damage = int(definition.get("attack_damage", 10))
	enemy.attack_period = float(definition.get("attack_period", 1.0))
	enemy.prefers_tree = bool(definition.get("prefers_tree", false))
	return enemy

func advance(delta: float) -> void:
	if defeated or crossed_finish:
		return
	progress_column -= move_speed * delta
	if progress_column < 0.0:
		crossed_finish = true

func take_damage(amount: int) -> void:
	if defeated:
		return
	health = maxi(0, health - maxi(0, amount))
	defeated = health == 0
