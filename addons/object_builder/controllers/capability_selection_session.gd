@tool
extends RefCounted
class_name CapabilitySelectionSession
## Keeps catalog selection independent from search, filters and visible pages.

var _selected_ids: PackedStringArray = []


func toggle(capability_id: String) -> bool:
	var normalized_id := _normalize_id(capability_id)
	if normalized_id.is_empty():
		return false
	if _selected_ids.has(normalized_id):
		_selected_ids.erase(normalized_id)
		return false
	_selected_ids.append(normalized_id)
	return true


func select(capability_id: String) -> bool:
	var normalized_id := _normalize_id(capability_id)
	if normalized_id.is_empty() or _selected_ids.has(normalized_id):
		return false
	_selected_ids.append(normalized_id)
	return true


func deselect(capability_id: String) -> bool:
	var normalized_id := _normalize_id(capability_id)
	if normalized_id.is_empty() or not _selected_ids.has(normalized_id):
		return false
	_selected_ids.erase(normalized_id)
	return true


func contains(capability_id: String) -> bool:
	return _selected_ids.has(_normalize_id(capability_id))


func clear() -> void:
	_selected_ids.clear()


func get_selected_ids() -> PackedStringArray:
	return _selected_ids.duplicate()


func get_count() -> int:
	return _selected_ids.size()


func is_empty() -> bool:
	return _selected_ids.is_empty()


func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower()
