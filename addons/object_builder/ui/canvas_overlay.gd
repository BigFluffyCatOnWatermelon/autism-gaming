@tool
extends Control
## Input and selection overlay placed above the SubViewportContainer.

var canvas_owner: Node


func _gui_input(event: InputEvent) -> void:
	if canvas_owner != null and is_instance_valid(canvas_owner):
		canvas_owner.call("handle_input", event)
		accept_event()


func _draw() -> void:
	if canvas_owner != null and is_instance_valid(canvas_owner):
		canvas_owner.call("draw_selection", self)
