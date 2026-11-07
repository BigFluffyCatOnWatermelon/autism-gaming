@tool
extends RefCounted
class_name ObjectEditorSession
## Owns the editable object draft and its last accepted snapshot.


var _working_definition: ObjectDefinition
var _original_definition: ObjectDefinition
var _is_new := false
var _is_dirty := false


func begin_edit(definition: ObjectDefinition) -> ObjectDefinition:
	if definition == null:
		clear()
		return null
	_original_definition = definition.duplicate(true) as ObjectDefinition
	_working_definition = definition.duplicate(true) as ObjectDefinition
	_is_new = false
	_is_dirty = false
	return _working_definition


func begin_new(definition: ObjectDefinition) -> ObjectDefinition:
	if definition == null:
		clear()
		return null
	_original_definition = null
	_working_definition = definition.duplicate(true) as ObjectDefinition
	_is_new = true
	_is_dirty = true
	return _working_definition


func get_working_definition() -> ObjectDefinition:
	return _working_definition


func get_original_definition() -> ObjectDefinition:
	if _original_definition == null:
		return null
	return _original_definition.duplicate(true) as ObjectDefinition


func is_new() -> bool:
	return _is_new


func is_dirty() -> bool:
	return _is_dirty


func mark_changed() -> void:
	if _working_definition != null:
		_is_dirty = true


func accept_saved_state(saved_definition: ObjectDefinition = null) -> void:
	if saved_definition != null:
		_working_definition = saved_definition.duplicate(true) as ObjectDefinition
	if _working_definition == null:
		clear()
		return
	_original_definition = _working_definition.duplicate(true) as ObjectDefinition
	_is_new = false
	_is_dirty = false


func discard_changes() -> ObjectDefinition:
	if _original_definition == null:
		clear()
		return null
	_working_definition = _original_definition.duplicate(true) as ObjectDefinition
	_is_new = false
	_is_dirty = false
	return _working_definition


func clear() -> void:
	_working_definition = null
	_original_definition = null
	_is_new = false
	_is_dirty = false
