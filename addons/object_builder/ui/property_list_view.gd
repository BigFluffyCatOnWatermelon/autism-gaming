@tool
extends VBoxContainer
## Renders custom-property rows and forwards user actions to the owning editor controller.

signal numeric_default_changed(value: float, property_definition: ObjectPropertyDefinition)
signal boolean_default_changed(value: bool, property_definition: ObjectPropertyDefinition)
signal text_default_submitted(value: String, property_definition: ObjectPropertyDefinition)
signal text_default_focus_exited(text_edit: LineEdit, property_definition: ObjectPropertyDefinition)
signal edit_requested(property_definition: ObjectPropertyDefinition)
signal remove_requested(property_definition: ObjectPropertyDefinition)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")
const ValueCodec = preload("res://scripts/object_system/object_property_value_codec.gd")


func set_properties(properties: Array[ObjectPropertyDefinition]) -> void:
	UIFactory.clear_children(self)
	if properties.is_empty():
		UIFactory.add_empty_state(self, "Пока нет пользовательских свойств.")
		return

	var groups: Dictionary = {}
	var group_order: Array[String] = []
	for property_definition in properties:
		if property_definition == null:
			continue
		var group_name := property_definition.group_name.strip_edges()
		if group_name.is_empty():
			group_name = "Основное"
		if not groups.has(group_name):
			groups[group_name] = []
			group_order.append(group_name)
		groups[group_name].append(property_definition)

	for group_name in group_order:
		var group_label := Label.new()
		group_label.text = group_name
		add_child(group_label)
		for property_definition in groups[group_name]:
			add_child(_create_property_row(property_definition))


func _create_property_row(property_definition: ObjectPropertyDefinition) -> HBoxContainer:
	var row := HBoxContainer.new()
	var description_label := Label.new()
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var property_suffix := " · Доп." if property_definition.advanced else ""
	if property_definition.has_range:
		property_suffix += " · [%s…%s]" % [
			str(property_definition.minimum),
			str(property_definition.maximum)
		]
	description_label.text = "%s · %s%s" % [
		property_definition.display_name,
		property_definition.value_type,
		property_suffix
	]
	description_label.clip_text = true
	description_label.tooltip_text = "%s\nЗначение по умолчанию: %s" % [
		property_definition.description,
		str(property_definition.default_value)
	]
	row.add_child(description_label)
	row.add_child(_create_default_control(property_definition))

	var edit_button := Button.new()
	edit_button.text = "✎"
	edit_button.tooltip_text = "Изменить определение свойства"
	edit_button.pressed.connect(_on_edit_pressed.bind(property_definition))
	row.add_child(edit_button)

	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.tooltip_text = "Удалить свойство из определения"
	remove_button.pressed.connect(_on_remove_pressed.bind(property_definition))
	row.add_child(remove_button)
	return row


func _create_default_control(property_definition: ObjectPropertyDefinition) -> Control:
	if property_definition.value_type == "Integer" or property_definition.value_type == "Float":
		var number_edit := SpinBox.new()
		number_edit.custom_minimum_size = Vector2(88, 0)
		number_edit.size_flags_horizontal = Control.SIZE_SHRINK_END
		number_edit.step = 1.0 if property_definition.value_type == "Integer" else 0.1
		number_edit.min_value = property_definition.minimum if property_definition.has_range else -1000000.0
		number_edit.max_value = property_definition.maximum if property_definition.has_range else 1000000.0
		number_edit.allow_greater = false
		number_edit.allow_lesser = false
		number_edit.set_value_no_signal(float(property_definition.default_value))
		number_edit.value_changed.connect(_on_numeric_value_changed.bind(property_definition))
		return number_edit

	if property_definition.value_type == "Boolean":
		var bool_edit := CheckBox.new()
		bool_edit.custom_minimum_size = Vector2(48, 0)
		bool_edit.button_pressed = bool(property_definition.default_value)
		bool_edit.toggled.connect(_on_boolean_value_changed.bind(property_definition))
		return bool_edit

	var text_edit := LineEdit.new()
	text_edit.custom_minimum_size = Vector2(88, 0)
	text_edit.size_flags_horizontal = Control.SIZE_SHRINK_END
	text_edit.text = ValueCodec.format_default_value(
		property_definition.default_value,
		property_definition.value_type
	)
	text_edit.tooltip_text = "Измени значение по умолчанию и нажми Enter"
	text_edit.text_submitted.connect(_on_text_submitted.bind(property_definition))
	text_edit.focus_exited.connect(_on_text_focus_exited.bind(text_edit, property_definition))
	return text_edit


func _on_numeric_value_changed(value: float, property_definition: ObjectPropertyDefinition) -> void:
	numeric_default_changed.emit(value, property_definition)


func _on_boolean_value_changed(value: bool, property_definition: ObjectPropertyDefinition) -> void:
	boolean_default_changed.emit(value, property_definition)


func _on_text_submitted(value: String, property_definition: ObjectPropertyDefinition) -> void:
	text_default_submitted.emit(value, property_definition)


func _on_text_focus_exited(text_edit: LineEdit, property_definition: ObjectPropertyDefinition) -> void:
	text_default_focus_exited.emit(text_edit, property_definition)


func _on_edit_pressed(property_definition: ObjectPropertyDefinition) -> void:
	edit_requested.emit(property_definition)


func _on_remove_pressed(property_definition: ObjectPropertyDefinition) -> void:
	remove_requested.emit(property_definition)
