@tool
extends VBoxContainer
## Owns the single contextual Properties surface. Exactly one context view is visible.

var _details_view: Control
var _capability_settings_view: Control
var _active_context := "details"


func build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)


func set_details_view(view: Control) -> void:
	if view == null:
		return
	_details_view = view
	add_child(view)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.visible = true
	_active_context = "details"
	_update_context_visibility()


func set_capability_settings_view(view: Control) -> void:
	if view == null:
		return
	_capability_settings_view = view
	add_child(view)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_update_context_visibility()


func show_object_details() -> void:
	_active_context = "details"
	_update_context_visibility()


func show_capability_settings() -> void:
	if _capability_settings_view == null:
		return
	_active_context = "capability"
	_update_context_visibility()


func is_showing_capability_settings() -> bool:
	return _active_context == "capability"


func get_active_context() -> String:
	return _active_context


func _update_context_visibility() -> void:
	if _details_view != null:
		_details_view.visible = _active_context == "details"
	if _capability_settings_view != null:
		_capability_settings_view.visible = _active_context == "capability"
