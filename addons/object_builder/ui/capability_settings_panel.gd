@tool
extends VBoxContainer
## Inline context panel for editing one installed capability.

signal apply_requested
signal close_requested

var _title_label: Label
var _subtitle_label: Label
var _scroll: ScrollContainer
var _form: VBoxContainer
var _search_input: LineEdit
var _level_filter: OptionButton
var _empty_state: Label
var _apply_button: Button
var _setting_controls: Array[Dictionary] = []
var _capability_id := ""
var _show_all_levels := false
var _search_query := ""


func build() -> void:
	if _form != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
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
	add_child(header)
	add_child(HSeparator.new())

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 5)
	add_child(toolbar)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Найти параметр…"
	_search_input.clear_button_enabled = true
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_search_changed)
	toolbar.add_child(_search_input)

	_level_filter = OptionButton.new()
	_level_filter.add_item("Основные", 0)
	_level_filter.add_item("Все доступные", 1)
	_level_filter.tooltip_text = "Показывать только основные или все параметры возможности."
	_level_filter.item_selected.connect(_on_level_filter_selected)
	toolbar.add_child(_level_filter)

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
	_search_input.text = ""
	_search_query = ""
	_show_all_levels = false
	_level_filter.select(0)
	_clear_form()
	_setting_controls.clear()

	var previous_group := ""
	var current_group_header: Label
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
		var unit := str(descriptor.get("unit", "")).strip_edges()
		if not unit.is_empty():
			label_text += " · " + unit

		var label_row := HBoxContainer.new()
		row.add_child(label_row)
		if value_type != "Boolean":
			var setting_label := Label.new()
			setting_label.text = label_text
			setting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			setting_label.tooltip_text = str(descriptor.get("description", ""))
			setting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label_row.add_child(setting_label)

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
				check.text = str(descriptor.get("display_name", setting_key))
				check.button_pressed = bool(current_value)
				check.tooltip_text = str(descriptor.get("description", ""))
				control = check
			"String":
				var line := LineEdit.new()
				line.text = str(current_value)
				line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.placeholder_text = str(descriptor.get("placeholder", ""))
				control = line
			"Vector2":
				var vector_value: Vector2 = current_value if current_value is Vector2 else Vector2.ZERO
				var vector_row := HBoxContainer.new()
				for axis in ["x", "y"]:
					var axis_spin := SpinBox.new()
					axis_spin.prefix = axis.to_upper() + " "
					axis_spin.min_value = float(descriptor.get("minimum", -1000000.0))
					axis_spin.max_value = float(descriptor.get("maximum", 1000000.0))
					axis_spin.step = float(descriptor.get("step", 1.0))
					axis_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					axis_spin.value = vector_value.x if axis == "x" else vector_value.y
					vector_row.add_child(axis_spin)
				control = vector_row
			_:
				var unsupported := Label.new()
				unsupported.text = "Этот тип параметра пока редактируется в расширенном режиме."
				unsupported.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				unsupported.modulate = Color(0.72, 0.76, 0.82)
				control = unsupported

		var reset_button := Button.new()
		reset_button.text = "↺"
		reset_button.tooltip_text = "Вернуть значение по умолчанию: %s" % str(descriptor.get("default_value", "—"))
		reset_button.custom_minimum_size.x = 28
		reset_button.disabled = value_type not in ["Integer", "Float", "Boolean", "String"]
		reset_button.pressed.connect(_reset_setting.bind(_setting_controls.size()))
		label_row.add_child(reset_button)
		row.add_child(control)

		var level := str(descriptor.get("level", "Basic"))
		var searchable_text := (
			label_text + " " +
			str(descriptor.get("description", "")) + " " +
			group_name + " " + setting_key + " " + component_id
		).to_lower()
		_setting_controls.append({
			"component_id": component_id,
			"setting_key": setting_key,
			"value_type": value_type,
			"level": level,
			"control": control,
			"row": row,
			"group_header": current_group_header,
			"reset_button": reset_button,
			"default_value": descriptor.get("default_value"),
			"searchable_text": searchable_text
		})
		supported_count += 1 if value_type in ["Integer", "Float", "Boolean", "String", "Vector2"] else 0

	_empty_state = Label.new()
	_empty_state.text = "Параметры не найдены. Измени запрос или фильтр."
	_empty_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_state.modulate = Color(0.72, 0.76, 0.82)
	_empty_state.visible = false
	_form.add_child(_empty_state)

	if _setting_controls.is_empty():
		_empty_state.text = "У этой возможности пока нет настроек. Её поведение определяется автоматически."
		_empty_state.visible = true
	_apply_button.disabled = supported_count == 0
	_update_filters()
	_scroll.scroll_vertical = 0


func clear() -> void:
	if _form == null:
		return
	_capability_id = ""
	_title_label.text = "Выбери возможность"
	_subtitle_label.text = "Контекстные настройки"
	_search_input.text = ""
	_search_query = ""
	_show_all_levels = false
	_level_filter.select(0)
	_clear_form()
	_setting_controls.clear()
	_apply_button.disabled = true


func _clear_form() -> void:
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()


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
			"Vector2":
				var vector_row := control as HBoxContainer
				if vector_row == null or vector_row.get_child_count() != 2:
					continue
				value = Vector2(
					(vector_row.get_child(0) as SpinBox).value,
					(vector_row.get_child(1) as SpinBox).value
				)
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


func get_setting_entry(component_id: String, setting_key: String) -> Dictionary:
	for entry in _setting_controls:
		if str(entry.get("component_id", "")) == component_id and str(entry.get("setting_key", "")) == setting_key:
			return entry
	return {}


func get_setting_control(component_id: String, setting_key: String) -> Control:
	return get_setting_entry(component_id, setting_key).get("control") as Control


func get_visible_setting_keys() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in _setting_controls:
		var row := entry.get("row") as Control
		if row != null and row.visible:
			result.append(str(entry.get("setting_key", "")))
	return result


func _update_filters() -> void:
	if _form == null:
		return
	var visible_count := 0
	var group_headers: Array[Label] = []
	for entry in _setting_controls:
		var group_header := entry.get("group_header") as Label
		if group_header != null and not group_headers.has(group_header):
			group_headers.append(group_header)
			group_header.visible = false
		var row := entry.get("row") as Control
		if row == null:
			continue
		var level_matches := _show_all_levels or str(entry.get("level", "Basic")) == "Basic"
		var query_matches := _search_query.is_empty() or str(entry.get("searchable_text", "")).contains(_search_query)
		var is_visible := level_matches and query_matches
		row.visible = is_visible
		if is_visible:
			visible_count += 1
			if group_header != null:
				group_header.visible = true
	if _empty_state != null:
		_empty_state.visible = visible_count == 0
		if _setting_controls.is_empty():
			_empty_state.text = "У этой возможности пока нет настроек. Её поведение определяется автоматически."
		else:
			_empty_state.text = "Параметры не найдены. Измени запрос или фильтр."


func _reset_setting(index: int) -> void:
	if index < 0 or index >= _setting_controls.size():
		return
	var entry: Dictionary = _setting_controls[index]
	var control := entry.get("control") as Control
	if control == null:
		return
	_set_control_value(control, str(entry.get("value_type", "")), entry.get("default_value"))


func _set_control_value(control: Control, value_type: String, value: Variant) -> void:
	match value_type:
		"Integer", "Float":
			(control as SpinBox).value = float(value)
		"Boolean":
			(control as CheckBox).button_pressed = bool(value)
		"String":
			(control as LineEdit).text = str(value)
		"Vector2":
			var vector_row := control as HBoxContainer
			if vector_row != null and vector_row.get_child_count() == 2:
				var vector_value: Vector2 = value if value is Vector2 else Vector2.ZERO
				(vector_row.get_child(0) as SpinBox).value = vector_value.x
				(vector_row.get_child(1) as SpinBox).value = vector_value.y


func _on_search_changed(value: String) -> void:
	_search_query = value.strip_edges().to_lower()
	_update_filters()


func _on_level_filter_selected(index: int) -> void:
	_show_all_levels = index == 1
	_update_filters()


func _on_apply_pressed() -> void:
	if not _capability_id.is_empty() and not _apply_button.disabled:
		apply_requested.emit()


func _on_close_pressed() -> void:
	close_requested.emit()
