class_name PointerRouter
extends RefCounted

func decode(event: InputEvent) -> Dictionary:
	if event is InputEventMouseMotion:
		return {"type": "move", "position": event.position}
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return {"type": "down" if event.pressed else "up", "position": event.position}
	if event is InputEventScreenDrag:
		return {"type": "move", "position": event.position}
	if event is InputEventScreenTouch:
		return {"type": "down" if event.pressed else "up", "position": event.position}
	return {}
