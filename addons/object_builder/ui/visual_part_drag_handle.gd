@tool
extends Label
## Dedicated drag source for a visual-part row.

var part_path := NodePath("")
var parent_path := NodePath("")


func _get_drag_data(_at_position: Vector2) -> Variant:
	if part_path.is_empty():
		return null
	var preview := Label.new()
	preview.text = "Переместить часть"
	var viewport := get_viewport()
	if viewport != null and viewport.gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.free()
	return {"part_path": str(part_path), "parent_path": str(parent_path)}
