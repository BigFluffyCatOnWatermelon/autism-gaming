@tool
extends AcceptDialog
## Owns the capability-settings form. The plugin reads values and applies them to its working model.

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

var _scroll: ScrollContainer
var _form: VBoxContainer
var _advanced_check: CheckBox
var _setting_controls: Array[Dictionary] = []


func configure(
	capability: ObjectCapabilityDefinition,
	selection: ObjectCapabilitySelection,
	descriptors: Array[Dictionary]
) -> void:
	if capability == null or selection == null:
		return
	_build()
	title = capability.display_name + " · настройки"
	UIFactory.clear_children(_form)
	_setting_controls.clear()

	_advanced_check = CheckBox.new()
	_advanced_check.text = "Показать дополнительные настройки"
	_advanced_check.tooltip_text = "Показывает дополнительные и экспертные параметры. Основные настройки доступны сразу."
	_advanced_check.toggled.connect(_on_advanced_toggled)
	_form.add_child(_advanced_check)

	var previous_group := ""
	var current_group_header: Label
	var has_advanced_settings := false
	for descriptor in descriptors:
		var component_id := str(descriptor.get("component_id", "")).strip_edges().to_lower()
		var setting_key := str(descriptor.get("setting_key", descriptor.get("key", "")))
		if setting_key.is_empty() or component_id.is_empty():
			continue

		var group_name := str(descriptor.get("group_name", "")).strip_edges()
		if not group_name.is_empty() and group_name != previous_group:
			current_group_header = Label.new()
			current_group_header.text = group_name
			current_group_header.add_theme_font_size_override("font_size", 12)
			_form.add_child(current_group_header)
			previous_group = group_name
		elif group_name.is_empty():
			current_group_header = null

		var component_settings := selection.get_component_settings(component_id)
		var row := HBoxContainer.new()
		_form.add_child(row)
		var setting_label := Label.new()
		setting_label.text = str(descriptor.get("display_name", setting_key))
		setting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		setting_label.tooltip_text = str(descriptor.get("description", ""))
		row.add_child(setting_label)

		var value_type := str(descriptor.get("value_type", ""))
		var current_value: Variant = component_settings.get(
			setting_key,
			descriptor.get("default_value")
		)
		var control: Control
		match value_type:
			"Integer", "Float":
				var spin := SpinBox.new()
				spin.min_value = float(descriptor.get("minimum", 0.0)) if descriptor.has("minimum") else -1000000.0
				spin.max_value = float(descriptor.get("maximum", 1000000.0)) if descriptor.has("maximum") else 1000000.0
				spin.step = float(descriptor.get("step", 1.0 if value_type == "Integer" else 0.1))
				spin.value = float(current_value)
				spin.custom_minimum_size = Vector2(120, 0)
				control = spin
			"Boolean":
				var check := CheckBox.new()
				check.button_pressed = bool(current_value)
				control = check
			"String":
				var line := LineEdit.new()
				line.text = str(current_value)
				line.custom_minimum_size = Vector2(150, 0)
				control = line
			_:
				var unsupported := Label.new()
				unsupported.text = "Подробная настройка"
				unsupported.tooltip_text = "Для этого параметра пока нет простого редактора."
				control = unsupported
		row.add_child(control)

		var setting_level := str(descriptor.get("level", "Basic"))
		var is_basic := setting_level == "Basic"
		has_advanced_settings = has_advanced_settings or not is_basic
		row.visible = is_basic
		_setting_controls.append({
			"component_id": component_id,
			"setting_key": setting_key,
			"value_type": value_type,
			"level": setting_level,
			"control": control,
			"row": row,
			"group_header": current_group_header
		})

	if _form.get_child_count() <= 1:
		var empty_label := Label.new()
		empty_label.text = "У этой возможности пока нет дополнительных настроек."
		_form.add_child(empty_label)
	_advanced_check.visible = has_advanced_settings
	_update_advanced_visibility(false)


func get_values() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _setting_controls:
		var control := entry.get("control") as Control
		if control == null:
			continue
		var value: Variant
		match str(entry.get("value_type", "")):
			"Integer":
				value = int(round((control as SpinBox).value))
			"Float":
				value = (control as SpinBox).value
			"Boolean":
				value = (control as CheckBox).button_pressed
			"String":
				value = (control as LineEdit).text
			_:
				continue
		result.append({
			"component_id": str(entry.get("component_id", "")),
			"setting_key": str(entry.get("setting_key", "")),
			"value": value
		})
	return result


func _build() -> void:
	if _form != null:
		return
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(460, 320)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 7)
	_scroll.add_child(_form)


func _on_advanced_toggled(show_advanced: bool) -> void:
	_update_advanced_visibility(show_advanced)


func _update_advanced_visibility(show_advanced: bool) -> void:
	var group_headers: Array[Label] = []
	for entry in _setting_controls:
		var group_header := entry.get("group_header") as Label
		if group_header != null and not group_headers.has(group_header):
			group_headers.append(group_header)
			group_header.visible = false

		var row := entry.get("row") as Control
		if row == null:
			continue
		var visible := str(entry.get("level", "Basic")) == "Basic" or show_advanced
		row.visible = visible
		if visible and group_header != null:
			group_header.visible = true
