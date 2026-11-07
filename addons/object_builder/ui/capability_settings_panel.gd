@tool
extends VBoxContainer
## Inline context panel for editing one installed capability.

signal apply_requested
signal close_requested

var _title_label: Label
var _subtitle_label: Label
var _scroll: ScrollContainer
var _form: VBoxContainer
var _advanced_check: CheckBox
var _apply_button: Button
var _setting_controls: Array[Dictionary] = []
var _capability_id := ""


func build() -> void:
	if _form != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	add_child(header)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Настройки выбранной возможности"
	_subtitle_label.add_theme_font_size_override("font_size", 10)
	_subtitle_label.modulate = Color(0.72, 0.76, 0.82)
	title_column.add_child(_subtitle_label)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Вернуться к сведениям об объекте"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 8)
	_scroll.add_child(_form)

	add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 5)
	add_child(footer)

	var cancel_button := Button.new()
	cancel_button.text = "Отмена"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_on_close_pressed)
	footer.add_child(cancel_button)

	_apply_button = Button.new()
	_apply_button.text = "Применить"
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button.tooltip_text = "Применить настройки одной командой Undo/Redo"
	_apply_button.pressed.connect(_on_apply_pressed)
	footer.add_child(_apply_button)

	clear()


func configure(
	capability: ObjectCapabilityDefinition,
	selection: ObjectCapabilitySelection,
	descriptors: Array[Dictionary]
) -> void:
	if capability == null or selection == null:
		clear()
		return
	build()
	_capability_id = capability.capability_id
	_title_label.text = capability.display_name
	_subtitle_label.text = "Настройки · основные параметры показаны сразу"
	UIFactory_clear_form()
	_setting_controls.clear()

	_advanced_check = CheckBox.new()
	_advanced_check.text = "Дополнительные настройки"
	_advanced_check.tooltip_text = "Показывает расширенные и экспертные параметры."
	_advanced_check.toggled.connect(_on_advanced_toggled)
	_form.add_child(_advanced_check)

	var previous_group := ""
	var current_group_header: Label
	var has_advanced_settings := false
	var supported_count := 0
	for descriptor in descriptors:
		var component_id := str(descriptor.get("component_id", "")).strip_edges().to_lower()
		var setting_key := str(descriptor.get("setting_key", descriptor.get("key", ""))).strip_edges()
		if component_id.is_empty() or setting_key.is_empty():
			continue

		var group_name := str(descriptor.get("group_name", "")).strip_edges()
		if not group_name.is_empty() and group_name != previous_group:
			current_group_header = Label.new()
			current_group_header.text = group_name
			current_group_header.add_theme_font_size_override("font_size", 11)
			_form.add_child(current_group_header)
			previous_group = group_name
		elif group_name.is_empty():
			current_group_header = null

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		_form.add_child(row)

		var value_type := str(descriptor.get("value_type", ""))
		var component_settings := selection.get_component_settings(component_id)
		var current_value: Variant = component_settings.get(
			setting_key,
			descriptor.get("default_value")
		)
		var label_text := str(descriptor.get("display_name", setting_key))
		var control: Control
		match value_type:
			"Integer", "Float":
				var spin := SpinBox.new()
				spin.min_value = float(descriptor.get("minimum", -1000000.0))
				spin.max_value = float(descriptor.get("maximum", 1000000.0))
				spin.step = float(descriptor.get("step", 1.0 if value_type == "Integer" else 0.1))
				spin.value = float(current_value)
				spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				control = spin
			"Boolean":
				var check := CheckBox.new()
				check.text = label_text
				check.button_pressed = bool(current_value)
				check.tooltip_text = str(descriptor.get("description", ""))
				control = check
				label_text = ""
			"String":
				var line := LineEdit.new()
				line.text = str(current_value)
				line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.placeholder_text = str(descriptor.get("placeholder", ""))
				control = line
			_:
				var unsupported := Label.new()
				unsupported.text = "Этот тип параметра пока редактируется в расширенном режиме."
				unsupported.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				unsupported.modulate = Color(0.72, 0.76, 0.82)
				control = unsupported

		if not label_text.is_empty():
			var setting_label := Label.new()
			setting_label.text = label_text
			setting_label.tooltip_text = str(descriptor.get("description", ""))
			setting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(setting_label)
		row.add_child(control)

		var level := str(descriptor.get("level", "Basic"))
		var is_basic := level == "Basic"
		has_advanced_settings = has_advanced_settings or not is_basic
		row.visible = is_basic
		_setting_controls.append({
			"component_id": component_id,
			"setting_key": setting_key,
			"value_type": value_type,
			"level": level,
			"control": control,
			"row": row,
			"group_header": current_group_header
		})
		supported_count += 1 if value_type in ["Integer", "Float", "Boolean", "String"] else 0

	if _setting_controls.is_empty():
		var empty_label := Label.new()
		empty_label.text = "У этой возможности пока нет настроек. Её поведение определяется автоматически."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.modulate = Color(0.72, 0.76, 0.82)
		_form.add_child(empty_label)
	elif supported_count == 0:
		var unsupported_hint := Label.new()
		unsupported_hint.text = "Подробные параметры доступны в расширенном режиме."
		unsupported_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_form.add_child(unsupported_hint)

	_advanced_check.visible = has_advanced_settings
	_apply_button.disabled = supported_count == 0
	_update_advanced_visibility(false)
	_scroll.scroll_vertical = 0


func clear() -> void:
	if _form == null:
		return
	_capability_id = ""
	_title_label.text = "Выбери возможность"
	_subtitle_label.text = "Контекстные настройки"
	UIFactory_clear_form()
	_setting_controls.clear()
	_apply_button.disabled = true


func get_capability_id() -> String:
	return _capability_id


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


func get_setting_control_count() -> int:
	return _setting_controls.size()


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
		var is_visible := str(entry.get("level", "Basic")) == "Basic" or show_advanced
		row.visible = is_visible
		if is_visible and group_header != null:
			group_header.visible = true


func UIFactory_clear_form() -> void:
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()


func _on_advanced_toggled(show_advanced: bool) -> void:
	_update_advanced_visibility(show_advanced)


func _on_apply_pressed() -> void:
	if not _capability_id.is_empty() and not _apply_button.disabled:
		apply_requested.emit()


func _on_close_pressed() -> void:
	close_requested.emit()
