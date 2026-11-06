extends SceneTree

const PropertyListViewScript = preload("res://addons/object_builder/ui/property_list_view.gd")
const PropertyDefinitionScript = preload("res://scripts/object_system/object_property_definition.gd")

var failures: Array[String] = []
var numeric_events: Array[float] = []
var boolean_events: Array[bool] = []
var text_submit_events: Array[String] = []
var text_focus_count := 0
var edit_event_ids: Array[String] = []
var remove_event_ids: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = PropertyListViewScript.new()
	root.add_child(view)
	view.connect("numeric_default_changed", Callable(self, "_on_numeric_changed"))
	view.connect("boolean_default_changed", Callable(self, "_on_boolean_changed"))
	view.connect("text_default_submitted", Callable(self, "_on_text_submitted"))
	view.connect("text_default_focus_exited", Callable(self, "_on_text_focus_exited"))
	view.connect("edit_requested", Callable(self, "_on_edit_requested"))
	view.connect("remove_requested", Callable(self, "_on_remove_requested"))

	var integer_property = PropertyDefinitionScript.new()
	integer_property.property_id = "health"
	integer_property.display_name = "Здоровье"
	integer_property.value_type = "Integer"
	integer_property.default_value = 6
	integer_property.group_name = "Основное"
	integer_property.has_range = true
	integer_property.minimum = 1.0
	integer_property.maximum = 12.0

	var boolean_property = PropertyDefinitionScript.new()
	boolean_property.property_id = "enabled"
	boolean_property.display_name = "Включён"
	boolean_property.value_type = "Boolean"
	boolean_property.default_value = true
	boolean_property.group_name = "Основное"

	var text_property = PropertyDefinitionScript.new()
	text_property.property_id = "label"
	text_property.display_name = "Подпись"
	text_property.value_type = "String"
	text_property.default_value = "Дерево"
	text_property.group_name = "Дополнительно"

	var properties: Array[ObjectPropertyDefinition] = [integer_property, boolean_property, text_property]
	view.call("set_properties", properties)
	_expect(view.get_child_count() == 5, "properties are grouped without changing their original order")
	_expect((view.get_child(0) as Label).text == "Основное", "first group keeps its display name")
	_expect((view.get_child(3) as Label).text == "Дополнительно", "later groups keep their display name")

	var integer_row := view.get_child(1) as HBoxContainer
	var integer_edit := integer_row.get_child(1) as SpinBox
	_expect(integer_edit != null and is_equal_approx(integer_edit.value, 6.0), "integer properties use a SpinBox with the stored default")
	_expect(is_equal_approx(integer_edit.min_value, 1.0) and is_equal_approx(integer_edit.max_value, 12.0), "numeric fields retain the declared range")
	integer_edit.value_changed.emit(9.0)
	_expect(numeric_events.size() == 1 and is_equal_approx(numeric_events[0], 9.0), "numeric edits are forwarded through one signal")
	_expect(boolean_events.is_empty(), "numeric edits do not emit boolean changes")

	var edit_button := integer_row.get_child(2) as Button
	var remove_button := integer_row.get_child(3) as Button
	edit_button.pressed.emit()
	remove_button.pressed.emit()
	_expect(edit_event_ids == ["health"], "edit action identifies the selected property")
	_expect(remove_event_ids == ["health"], "remove action identifies the selected property")

	var boolean_row := view.get_child(2) as HBoxContainer
	var boolean_edit := boolean_row.get_child(1) as CheckBox
	_expect(boolean_edit != null and boolean_edit.button_pressed, "boolean properties use a CheckBox with the stored default")
	boolean_edit.toggled.emit(false)
	_expect(boolean_events == [false], "boolean edits are forwarded through one signal")

	var text_row := view.get_child(4) as HBoxContainer
	var text_edit := text_row.get_child(1) as LineEdit
	_expect(text_edit != null and text_edit.text == "Дерево", "string properties use a LineEdit with the stored default")
	text_edit.text_submitted.emit("Берёза")
	text_edit.focus_exited.emit()
	_expect(text_submit_events == ["Берёза"], "text submission is forwarded to the controller")
	_expect(text_focus_count == 1, "text focus exit is forwarded to the controller")

	var empty_properties: Array[ObjectPropertyDefinition] = []
	view.call("set_properties", empty_properties)
	_expect(view.get_child_count() == 1 and (view.get_child(0) is Label), "empty property lists show a single empty-state message")

	root.remove_child(view)
	view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder property list view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_numeric_changed(value: float, property_definition: ObjectPropertyDefinition) -> void:
	numeric_events.append(value)


func _on_boolean_changed(value: bool, property_definition: ObjectPropertyDefinition) -> void:
	boolean_events.append(value)


func _on_text_submitted(value: String, property_definition: ObjectPropertyDefinition) -> void:
	text_submit_events.append(value)


func _on_text_focus_exited(_text_edit: LineEdit, _property_definition: ObjectPropertyDefinition) -> void:
	text_focus_count += 1


func _on_edit_requested(property_definition: ObjectPropertyDefinition) -> void:
	edit_event_ids.append(property_definition.property_id)


func _on_remove_requested(property_definition: ObjectPropertyDefinition) -> void:
	remove_event_ids.append(property_definition.property_id)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
