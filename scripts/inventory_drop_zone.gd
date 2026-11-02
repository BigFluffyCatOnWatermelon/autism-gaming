extends Control
class_name InventoryDropZone

signal drop_requested(from_index: int)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and data.has("from")
		and int(data["from"]) >= 0
		and data.has("item_id")
	)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("from"):
		drop_requested.emit(int(data["from"]))
