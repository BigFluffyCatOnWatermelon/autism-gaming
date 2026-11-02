extends Button
class_name InventorySlot

signal drop_requested(from_index: int, to_index: int)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item_id := str(get_meta("item_id", ""))
	var slot_index := int(get_meta("slot_index", -1))
	if item_id.is_empty() or slot_index < 0 or disabled:
		return null
	var preview: Control
	var icon_rect := get_node_or_null("Icon") as TextureRect
	if icon_rect != null and icon_rect.texture != null:
		var preview_icon := TextureRect.new()
		preview_icon.texture = icon_rect.texture
		preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_icon.custom_minimum_size = Vector2(38, 38)
		preview = preview_icon
	else:
		var label := Label.new()
		label.text = item_id.capitalize()
		label.add_theme_color_override("font_color", Color("#f4e6c8"))
		label.add_theme_font_size_override("font_size", 13)
		preview = label
	set_drag_preview(preview)
	return {"from": slot_index, "item_id": item_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if disabled or not (data is Dictionary) or not data.has("from"):
		return false
	var from_index := int(data["from"])
	return from_index >= 0 and from_index != int(get_meta("slot_index", -1))

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("from"):
		drop_requested.emit(int(data["from"]), int(get_meta("slot_index", -1)))
