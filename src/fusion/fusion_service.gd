class_name FusionService
extends RefCounted
## Formal fusion boundary (docs/architecture.md §6).
## - Legality: recipe lookup via the data repository (no ID if/else chains).
## - Planning: builds a complete fusion plan (result id + inherited runtime
##   state) that the battle layer only has to apply.
## Relationship locks, complex statuses and undo/split remain out of scope
## until product decisions land.

var repository: GameDataRepository

func _init(p_repository: GameDataRepository) -> void:
	repository = p_repository

func preview(input_a: String, input_b: String) -> Dictionary:
	return repository.recipe_for(input_a, input_b)

func can_fuse(input_a: String, input_b: String) -> bool:
	return not preview(input_a, input_b).is_empty()

## A complete, ready-to-apply plan for one merge:
##   ok            — always true when returned
##   recipe_id     — data-layer recipe id
##   kind          — same_unit_upgrade | fixed_cross_unit_fusion | ...
##   result_unit   — resulting unit id
##   resource_cost — resource the battle session must spend
##   unit          — UnitState with inheritance rules already applied
## Inheritance rules (fixed, reviewed in P2):
##   health  — the WORSE input ratio applied to the result max (no free heal)
##   cooldown— the LONGER of both inputs (no skill refresh)
##   shots   — summed history (keeps heavy-strike counters honest)
func build_plan(source: UnitState, target: UnitState) -> Dictionary:
	var recipe := preview(source.unit_id, target.unit_id)
	if recipe.is_empty():
		return {}
	var result_def := repository.unit_def(String(recipe.get("result", "")))
	if result_def.is_empty():
		return {}
	var result := UnitState.from_definition(result_def)
	var preserved_ratio := minf(source.health_ratio(), target.health_ratio())
	result.health = maxi(1, int(round(float(result.max_health) * preserved_ratio)))
	result.attack_cooldown = maxf(source.attack_cooldown, target.attack_cooldown)
	result.shots_fired = source.shots_fired + target.shots_fired
	return {
		"ok": true,
		"recipe_id": String(recipe.get("id", "")),
		"kind": String(recipe.get("kind", "")),
		"result_unit": result.unit_id,
		"resource_cost": int(recipe.get("resource_cost", 0)),
		"unit": result,
	}
