class_name WaveSystem
extends RefCounted
## Minimal data-driven wave system. A level defines waves as arrays of spawn
## entries; the system tracks spawning over battle time and reports completion.

signal enemy_spawned(enemy: EnemyState)
signal all_waves_done

var _waves: Array = []
var _spawned_counts: Array[int] = []
var _wave_start_times: Array[float] = []
var _elapsed := 0.0
var active_enemies: Array[EnemyState] = []


func setup(waves: Array) -> void:
	_waves = waves.duplicate(true)
	_spawned_counts.clear()
	_wave_start_times.clear()
	for wave in _waves:
		_spawned_counts.append(0)
		_wave_start_times.append(float(wave.get("start_time", 0.0)))
	_elapsed = 0.0
	active_enemies.clear()


func tick(delta: float, columns: int, enemy_definitions: Dictionary) -> void:
	_elapsed += delta
	var pending := false
	for wave_index in _waves.size():
		var wave: Dictionary = _waves[wave_index]
		if _spawned_counts[wave_index] >= (wave["spawns"] as Array).size():
			continue
		pending = true
		var start_time := _wave_start_times[wave_index]
		if _elapsed < start_time:
			continue
		var spawns: Array = wave["spawns"]
		while _spawned_counts[wave_index] < spawns.size():
			var entry: Dictionary = spawns[_spawned_counts[wave_index]]
			var at_time := start_time + float(entry.get("delay", 0.0))
			if _elapsed < at_time:
				break
			_spawn_enemy(String(entry.get("enemy_id", "enemy_basic")),
					int(entry.get("lane", 0)), float(columns), enemy_definitions)
			_spawned_counts[wave_index] += 1
	if not pending and not _is_done_reported:
		_is_done_reported = true
		all_waves_done.emit()


var _is_done_reported := false


func is_finished() -> bool:
	for index in _waves.size():
		if _spawned_counts[index] < (_waves[index]["spawns"] as Array).size():
			return false
	return true


func alive_count() -> int:
	var count := 0
	for enemy in active_enemies:
		if not enemy.defeated:
			count += 1
	return count


func purge_defeated() -> void:
	active_enemies = active_enemies.filter(
			func(enemy: EnemyState) -> bool: return not enemy.defeated)


func _spawn_enemy(enemy_id: String, lane: int, columns: float,
		definitions: Dictionary) -> void:
	var enemy: EnemyState = EnemyState.from_definition(enemy_id, definitions, lane, columns + 0.5)
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
