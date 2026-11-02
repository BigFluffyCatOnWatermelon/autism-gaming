extends Button
class_name InventorySlot

signal drop_requested(from_index: int, to_index: int)

var slot_index := -1
var item_id := ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or slot_index < 0 or disabled:
		return null
	var preview := Label.new()
	preview.text = item_id.capitalize()
	preview.add_theme_color_override("font_color", Color("#f4e6c8"))
	preview.add_theme_font_size_override("font_size", 13)
	preview.add_theme_color_override("font_shadow_color", Color.BLACK)
	preview.add_theme_constant_override("shadow_offset_x", 1)
	preview.add_theme_constant_override("shadow_offset_y", 1)
	set_drag_preview(preview)
	return {"from": slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if disabled or not (data is Dictionary) or not data.has("from"):
		return false
	return int(data["from"]) != slot_index

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("from"):
		drop_requested.emit(int(data["from"]), slot_index)
