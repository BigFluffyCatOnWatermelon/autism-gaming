@tool
extends Label
## Dedicated drag source for a visual-part row.

var part_path := NodePath("")
var parent_path := NodePath("")


func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload := get_drag_payload()
	if payload.is_empty():
		return null
	var preview := Label.new()
	preview.text = "Переместить часть"
	set_drag_preview(preview)
	return payload


func get_drag_payload() -> Dictionary:
	if part_path.is_empty():
		return {}
	return {"part_path": str(part_path), "parent_path": str(parent_path)}
