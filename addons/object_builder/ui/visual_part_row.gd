@tool
extends PanelContainer
## Drag source/target row for reordering visual siblings.

signal reorder_requested(source_path: NodePath, target_path: NodePath, insert_after: bool)

var part_path := NodePath("")
var parent_path := NodePath("")


func _get_drag_data(_at_position: Vector2) -> Variant:
	if part_path.is_empty():
		return null
	var preview := Label.new()
	preview.text = "Переместить часть"
	preview.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	set_drag_preview(preview)
	return {
		"part_path": str(part_path),
		"parent_path": str(parent_path)
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return (
		str(data.get("parent_path", "")) == str(parent_path)
		and str(data.get("part_path", "")) != str(part_path)
		and not part_path.is_empty()
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		reorder_requested.emit(
			NodePath(str(data.get("part_path", ""))),
			part_path,
			at_position.y >= size.y * 0.5
		)
