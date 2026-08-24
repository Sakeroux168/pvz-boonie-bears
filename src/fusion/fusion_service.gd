class_name FusionService
extends RefCounted

var repository: GameDataRepository

func _init(p_repository: GameDataRepository) -> void:
	repository = p_repository

func preview(input_a: String, input_b: String) -> Dictionary:
	return repository.recipe_for(input_a, input_b)

func can_fuse(input_a: String, input_b: String) -> bool:
	return not preview(input_a, input_b).is_empty()
