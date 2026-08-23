class_name RecipeBook
extends RefCounted

const RECIPES := {
	"unit_a_1|unit_a_1": {
		"id": "upgrade_a_1_to_2", "input_a": "unit_a_1", "input_b": "unit_a_1",
		"result": "unit_a_2", "resource_cost": 30, "kind": "same_unit_upgrade"
	},
	"unit_a_2|unit_a_2": {
		"id": "upgrade_a_2_to_3", "input_a": "unit_a_2", "input_b": "unit_a_2",
		"result": "unit_a_3", "resource_cost": 60, "kind": "same_unit_upgrade"
	},
	"unit_a_1|unit_b_1": {
		"id": "fusion_a_b", "input_a": "unit_a_1", "input_b": "unit_b_1",
		"result": "unit_ab", "resource_cost": 100, "kind": "fixed_cross_unit_fusion"
	}
}


func recipe_key(input_a: String, input_b: String) -> String:
	var inputs := [input_a, input_b]
	inputs.sort()
	return "%s|%s" % [inputs[0], inputs[1]]


func find_recipe(input_a: String, input_b: String) -> Dictionary:
	var key := recipe_key(input_a, input_b)
	if not RECIPES.has(key):
		return {}
	return RECIPES[key].duplicate(true)


func is_legal(input_a: String, input_b: String) -> bool:
	return not find_recipe(input_a, input_b).is_empty()
