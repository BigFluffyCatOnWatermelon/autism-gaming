@tool
extends VBoxContainer
## Inline editor for one installed capability. UI state is isolated from the saved selection until Apply.

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
var _reset_all_button: Button
var _change_summary: Label
var _setting_controls: Array[Dictionary] = []
var _initial_values: Dictionary = {}
var _group_bodies: Dictionary = {}
var _capability_id := ""
var _level_mode := 0
var _search_query := ""
var _editable_count := 0
var _updating_controls := false


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
	close_button.tooltip_text = "Вернуться к настройкам объекта"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	add_child(header)
	add_child(HSeparator.new())

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 5)
	add_child(toolbar)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Найти параметр по названию или описанию…"
	_search_input.clear_button_enabled = true
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_search_changed)
	toolbar.add_child(_search_input)

	_level_filter = OptionButton.new()
	_level_filter.add_item("Основные", 0)
	_level_filter.add_item("До Advanced", 1)
	_level_filter.add_item("Все уровни", 2)
	_level_filter.tooltip_text = "Основные параметры, основные + дополнительные или все параметры, включая экспертные."
	_level_filter.item_selected.connect(_on_level_filter_selected)
	toolbar.add_child(_level_filter)

	_reset_all_button = Button.new()
	_reset_all_button.text = "Сбросить"
	_reset_all_button.tooltip_text = "Вернуть все параметры этой механики к значениям по умолчанию."
	_reset_all_button.disabled = true
	_reset_all_button.pressed.connect(_on_reset_all_pressed)
	toolbar.add_child(_reset_all_button)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 8)
	_scroll.add_child(_form)

	_empty_state = Label.new()
	_empty_state.text = "Параметры не найдены. Измени запрос или фильтр."
	_empty_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_state.modulate = Color(0.72, 0.76, 0.82)
	_empty_state.visible = false
	_form.add_child(_empty_state)

	add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 5)
	add_child(footer)

	_change_summary = Label.new()
	_change_summary.text = "Нет изменений"
	_change_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_change_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_change_summary)

	var cancel_button := Button.new()
	cancel_button.text = "Отмена"
	cancel_button.pressed.connect(_on_close_pressed)
	footer.add_child(cancel_button)

	_apply_button = Button.new()
	_apply_button.text = "Применить"
	_apply_button.tooltip_text = "Применить только изменённые параметры одной Undo/Redo-командой."
	_apply_button.disabled = true
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
	_subtitle_label.text = "Настройки механики · изменения сохраняются только после нажатия «Применить»"
	_search_input.text = ""
	_search_query = ""
	_level_mode = 0
	_level_filter.select(0)
	_clear_form()
	_setting_controls.clear()
	_initial_values.clear()
	_group_bodies.clear()
	_editable_count = 0

	var previous_group := ""
	var current_group_header: Button
	var current_group_body: VBoxContainer
	for descriptor in descriptors:
		var component_id := str(descriptor.get("component_id", "")).strip_edges().to_lower()
		var setting_key := str(descriptor.get("setting_key", descriptor.get("key", ""))).strip_edges()
		if component_id.is_empty() or setting_key.is_empty():
			continue

		var group_name := str(descriptor.get("group_name", "")).strip_edges()
		if group_name.is_empty():
			group_name = "Основные параметры"
		if group_name != previous_group:
			var group_panel := PanelContainer.new()
			group_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_form.add_child(group_panel)
			var group_content := VBoxContainer.new()
			group_content.add_theme_constant_override("separation", 5)
			group_panel.add_child(group_content)
			current_group_header = Button.new()
			current_group_header.text = "▾  " + group_name
			current_group_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
			current_group_header.flat = true
			current_group_header.toggle_mode = true
			current_group_header.button_pressed = true
			group_content.add_child(current_group_header)
			current_group_body = VBoxContainer.new()
			current_group_body.add_theme_constant_override("separation", 7)
			group_content.add_child(current_group_body)
			current_group_header.toggled.connect(_on_group_toggled.bind(current_group_body, group_name))
			_group_bodies[group_name] = {"header": current_group_header, "body": current_group_body}
			previous_group = group_name

		var value_type := str(descriptor.get("value_type", ""))
		var component_settings := selection.get_component_settings(component_id)
		var current_value: Variant = component_settings.get(setting_key, descriptor.get("default_value"))
		var default_value: Variant = descriptor.get("default_value")
		var label_text := str(descriptor.get("display_name", setting_key))
		var unit := str(descriptor.get("unit", "")).strip_edges()
		if not unit.is_empty():
			label_text += " · " + unit

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		current_group_body.add_child(row)

		var label_row := HBoxContainer.new()
		row.add_child(label_row)
		if value_type != "Boolean":
			var setting_label := Label.new()
			setting_label.text = label_text
			setting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			setting_label.tooltip_text = str(descriptor.get("description", ""))
			setting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label_row.add_child(setting_label)

		var control: Control = _create_setting_control(value_type, current_value, descriptor)
		if control == null:
			var unsupported := Label.new()
			unsupported.text = "Тип «%s» пока не поддерживается редактором. Значение сохранено без изменений." % value_type
			unsupported.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			unsupported.modulate = Color(0.72, 0.76, 0.82)
			control = unsupported
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(control)
		var range_slider: HSlider
		if value_type in ["Integer", "Float"] and bool(descriptor.get("has_range", false)):
			var minimum := float(descriptor.get("minimum", 0.0))
			var maximum := float(descriptor.get("maximum", 0.0))
			if maximum > minimum and maximum - minimum <= 10000.0:
				range_slider = HSlider.new()
				range_slider.min_value = minimum
				range_slider.max_value = maximum
				range_slider.step = float(descriptor.get("step", 1.0 if value_type == "Integer" else 0.1))
				range_slider.value = float(current_value)
				range_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				range_slider.custom_minimum_size.y = 14
				range_slider.tooltip_text = "Перетащи ползунок или введи точное значение в поле выше."
				row.add_child(range_slider)
				range_slider.value_changed.connect(_on_numeric_slider_changed.bind(control as SpinBox))

		var reset_button := Button.new()
		reset_button.text = "↺"
		reset_button.tooltip_text = "Вернуть значение по умолчанию: %s" % str(default_value)
		reset_button.custom_minimum_size.x = 28
		reset_button.disabled = not _is_supported_type(value_type)
		reset_button.pressed.connect(_reset_setting.bind(_setting_controls.size()))
		label_row.add_child(reset_button)

		var level := str(descriptor.get("level", "Basic")).to_lower()
		var searchable_text := (
			label_text + " " + str(descriptor.get("description", "")) + " " +
			group_name + " " + setting_key + " " + component_id
		).to_lower()
		var entry := {
			"component_id": component_id,
			"setting_key": setting_key,
			"value_type": value_type,
			"level": level,
			"control": control,
			"range_slider": range_slider,
			"row": row,
			"group_name": group_name,
			"group_header": current_group_header,
			"group_body": current_group_body,
			"reset_button": reset_button,
			"default_value": default_value,
			"initial_value": current_value,
			"required": bool(descriptor.get("required", false)),
			"searchable_text": searchable_text
		}
		_setting_controls.append(entry)
		_initial_values[_entry_key(component_id, setting_key)] = current_value
		if _is_supported_type(value_type):
			_editable_count += 1
			_connect_control_changes(control, value_type)

	_empty_state.visible = _setting_controls.is_empty()
	if _setting_controls.is_empty():
		_empty_state.text = "У этой механики пока нет настраиваемых параметров."
	_update_filters()
	_update_dirty_state()
	_scroll.scroll_vertical = 0


func _create_setting_control(value_type: String, value: Variant, descriptor: Dictionary) -> Control:
	match value_type:
		"Integer", "Float":
			var spin := SpinBox.new()
			spin.min_value = float(descriptor.get("minimum", -1000000.0))
			spin.max_value = float(descriptor.get("maximum", 1000000.0))
			spin.step = float(descriptor.get("step", 1.0 if value_type == "Integer" else 0.1))
			spin.value = float(value)
			spin.allow_greater = not bool(descriptor.get("has_range", false))
			spin.allow_lesser = not bool(descriptor.get("has_range", false))
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return spin
		"Boolean":
			var check := CheckBox.new()
			check.text = str(descriptor.get("display_name", descriptor.get("setting_key", "Включено")))
			check.button_pressed = bool(value)
			check.tooltip_text = str(descriptor.get("description", ""))
			return check
		"String":
			var line := LineEdit.new()
			line.text = str(value)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.placeholder_text = str(descriptor.get("placeholder", ""))
			line.tooltip_text = str(descriptor.get("description", ""))
			return line
		"Vector2":
			var vector_value: Vector2 = value if value is Vector2 else Vector2.ZERO
			var vector_row := HBoxContainer.new()
			for axis in ["x", "y"]:
				var axis_spin := SpinBox.new()
				axis_spin.prefix = axis.to_upper() + " "
				axis_spin.min_value = float(descriptor.get("minimum", -1000000.0))
				axis_spin.max_value = float(descriptor.get("maximum", 1000000.0))
				axis_spin.step = float(descriptor.get("step", 1.0))
				axis_spin.value = vector_value.x if axis == "x" else vector_value.y
				axis_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vector_row.add_child(axis_spin)
			return vector_row
	return null


func _connect_control_changes(control: Control, value_type: String) -> void:
	if control is SpinBox:
		(control as SpinBox).value_changed.connect(_on_numeric_spin_changed.bind(_find_slider_for_control(control)))
	elif control is CheckBox:
		(control as CheckBox).toggled.connect(_on_control_toggled)
	elif control is LineEdit:
		(control as LineEdit).text_changed.connect(_on_control_text_changed)
	elif value_type == "Vector2" and control is HBoxContainer:
		for child in control.get_children():
			if child is SpinBox:
				(child as SpinBox).value_changed.connect(_on_control_value_changed)


func clear() -> void:
	if _form == null:
		return
	_capability_id = ""
	_title_label.text = "Выбери механику"
	_subtitle_label.text = "Изменения не применяются, пока ты не нажмёшь «Применить»."
	_search_input.text = ""
	_search_query = ""
	_level_mode = 0
	_level_filter.select(0)
	_clear_form()
	_setting_controls.clear()
	_initial_values.clear()
	_group_bodies.clear()
	_editable_count = 0
	_apply_button.disabled = true
	_reset_all_button.disabled = true
	_change_summary.text = "Нет изменений"


func _clear_form() -> void:
	for child in _form.get_children():
		if child != _empty_state:
			_form.remove_child(child)
			child.queue_free()
	if _empty_state != null:
		_empty_state.visible = false


func get_capability_id() -> String:
	return _capability_id


func get_values() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _setting_controls:
		var value := _read_entry_value(entry)
		if value == null and not _is_supported_type(str(entry.get("value_type", ""))):
			continue
		result.append({
			"component_id": str(entry.get("component_id", "")),
			"setting_key": str(entry.get("setting_key", "")),
			"value": value
		})
	return result


func get_changed_values() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _setting_controls:
		if not _is_supported_type(str(entry.get("value_type", ""))):
			continue
		var value := _read_entry_value(entry)
		var initial: Variant = entry.get("initial_value")
		if value != initial:
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


func _read_entry_value(entry: Dictionary) -> Variant:
	var control := entry.get("control") as Control
	if control == null:
		return null
	match str(entry.get("value_type", "")):
		"Integer":
			return int(round((control as SpinBox).value))
		"Float":
			return (control as SpinBox).value
		"Boolean":
			return (control as CheckBox).button_pressed
		"String":
			return (control as LineEdit).text
		"Vector2":
			var vector_row := control as HBoxContainer
			if vector_row == null or vector_row.get_child_count() != 2:
				return null
			return Vector2(
				(vector_row.get_child(0) as SpinBox).value,
				(vector_row.get_child(1) as SpinBox).value
			)
	return null


func _update_filters() -> void:
	if _form == null:
		return
	var visible_count := 0
	for entry in _setting_controls:
		var level := str(entry.get("level", "basic"))
		var level_matches := (
			_level_mode == 2
			or (_level_mode == 1 and level in ["basic", "advanced"])
			or (_level_mode == 0 and level == "basic")
		)
		var query_matches := _search_query.is_empty() or str(entry.get("searchable_text", "")).contains(_search_query)
		var row := entry.get("row") as Control
		if row == null:
			continue
		row.visible = level_matches and query_matches
		if row.visible:
			visible_count += 1

	for group_name in _group_bodies:
		var group: Dictionary = _group_bodies[group_name]
		var body := group.get("body") as Control
		var header := group.get("header") as Button
		var group_has_visible := false
		for entry in _setting_controls:
			if str(entry.get("group_name", "")) == str(group_name):
				var row := entry.get("row") as Control
				if row != null and row.visible:
					group_has_visible = true
					break
		if header != null:
			header.visible = group_has_visible
		if body != null:
			body.visible = group_has_visible and bool(header.button_pressed) if header != null else group_has_visible

	_empty_state.visible = visible_count == 0
	if _setting_controls.is_empty():
		_empty_state.text = "У этой механики пока нет настраиваемых параметров."
	else:
		_empty_state.text = "По этому запросу ничего не найдено. Измени поиск или уровень параметров."


func _on_group_toggled(expanded: bool, body: VBoxContainer, group_name: String) -> void:
	if body != null:
		body.visible = expanded
	var group: Dictionary = _group_bodies.get(group_name, {})
	var header := group.get("header") as Button
	if header != null:
		header.text = ("▾  " if expanded else "▸  ") + group_name


func _reset_setting(index: int) -> void:
	if index < 0 or index >= _setting_controls.size():
		return
	var entry: Dictionary = _setting_controls[index]
	_set_entry_value(entry, entry.get("default_value"))
	_update_dirty_state()


func _on_reset_all_pressed() -> void:
	for entry in _setting_controls:
		if _is_supported_type(str(entry.get("value_type", ""))):
			_set_entry_value(entry, entry.get("default_value"))
	_update_dirty_state()


func _set_entry_value(entry: Dictionary, value: Variant) -> void:
	var control := entry.get("control") as Control
	if control == null:
		return
	var value_type := str(entry.get("value_type", ""))
	_updating_controls = true
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
	var slider := entry.get("range_slider") as HSlider
	if slider != null:
		slider.value = float(value)
	_updating_controls = false


func _find_slider_for_control(control: Control) -> HSlider:
	for entry in _setting_controls:
		if entry.get("control") == control:
			return entry.get("range_slider") as HSlider
	return null


func _on_numeric_spin_changed(value: float, slider: HSlider) -> void:
	if _updating_controls:
		return
	if slider != null:
		slider.value = value
	_update_dirty_state()


func _on_numeric_slider_changed(value: float, spin: SpinBox) -> void:
	if _updating_controls or spin == null:
		return
	spin.value = value
	_update_dirty_state()


func _update_dirty_state() -> void:
	if _apply_button == null:
		return
	var changed := get_changed_values().size()
	var has_required_error := false
	for entry in _setting_controls:
		if not bool(entry.get("required", false)):
			continue
		if str(entry.get("value_type", "")) == "String" and str(_read_entry_value(entry)).strip_edges().is_empty():
			has_required_error = true
			break
	_apply_button.disabled = changed == 0 or has_required_error or _editable_count == 0
	_reset_all_button.disabled = changed == 0
	_change_summary.text = (
		"Изменено параметров: %d" % changed
		if changed > 0
		else "Нет изменений"
	)
	if has_required_error:
		_change_summary.text = "Заполни обязательные поля"


func _on_control_value_changed(_value: float) -> void:
	if not _updating_controls:
		_update_dirty_state()


func _on_control_toggled(_value: bool) -> void:
	if not _updating_controls:
		_update_dirty_state()


func _on_control_text_changed(_value: String) -> void:
	if not _updating_controls:
		_update_dirty_state()


func _is_supported_type(value_type: String) -> bool:
	return value_type in ["Integer", "Float", "Boolean", "String", "Vector2"]


func _entry_key(component_id: String, setting_key: String) -> String:
	return component_id + "@" + setting_key


func _on_search_changed(value: String) -> void:
	_search_query = value.strip_edges().to_lower()
	_update_filters()


func _on_level_filter_selected(index: int) -> void:
	_level_mode = clampi(index, 0, 2)
	_update_filters()


func _on_apply_pressed() -> void:
	if not _capability_id.is_empty() and not _apply_button.disabled:
		apply_requested.emit()


func _on_close_pressed() -> void:
	close_requested.emit()
