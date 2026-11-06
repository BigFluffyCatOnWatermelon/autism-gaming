extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/component_editor_view.gd")
const DefinitionScript = preload("res://scripts/object_system/object_component_definition.gd")

var failures: Array[String] = []
var category_events: Array[String] = []
var add_events: Array[String] = []
var enabled_events: Array[bool] = []
var settings_ids: Array[String] = []
var remove_ids: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	root.add_child(view)
	var categories: Array[Dictionary] = [
		{"id": "Stats", "display_name": "Характеристики"},
		{"id": "Combat", "display_name": "Бой"}
	]
	view.call("build", categories, "Stats")
	view.connect("category_selected", Callable(self, "_on_category_selected"))
	view.connect("add_requested", Callable(self, "_on_add_requested"))
	view.connect("enabled_changed", Callable(self, "_on_enabled_changed"))
	view.connect("settings_requested", Callable(self, "_on_settings_requested"))
	view.connect("remove_requested", Callable(self, "_on_remove_requested"))

	_expect(view.get_child_count() == 4, "component view owns title, hint, picker and component list")
	_expect(str(view.call("get_selected_category")) == "Stats", "component view selects the requested initial category")

	var category_option := view.get("category_option") as OptionButton
	category_option.select(1)
	category_option.item_selected.emit(1)
	_expect(category_events == ["Combat"], "category changes emit the selected category ID")

	var options: Array[Dictionary] = [
		{"id": "health", "label": "Здоровье"},
		{"id": "attack", "label": "Атака"}
	]
	view.call("set_component_options", options)
	var component_option := view.get("component_option") as OptionButton
	var add_button := view.get("add_button") as Button
	_expect(component_option.item_count == 2 and not component_option.disabled, "component options are displayed and enabled")
	component_option.select(1)
	add_button.pressed.emit()
	_expect(add_events == ["attack"], "add action emits the selected component ID")

	var definition = DefinitionScript.new()
	definition.component_id = "health"
	definition.display_name = "Здоровье"
	definition.enabled = true
	var entries: Array[Dictionary] = [{"definition": definition, "description": "Управляет запасом здоровья."}]
	view.call("set_components", entries)
	var component_list := view.get("component_list") as VBoxContainer
	_expect(component_list.get_child_count() == 1, "component view renders a row for each valid definition")
	var row := component_list.get_child(0) as HBoxContainer
	var enabled_check := row.get_child(0) as CheckBox
	var settings_button := row.get_child(1) as Button
	var remove_button := row.get_child(2) as Button
	_expect(enabled_check.text == "Здоровье", "component row displays the definition name")
	_expect(enabled_check.tooltip_text.contains("Управляет запасом здоровья.") and enabled_check.tooltip_text.contains("health"), "component row retains description and ID tooltip")
	enabled_check.toggled.emit(false)
	settings_button.pressed.emit()
	remove_button.pressed.emit()
	_expect(enabled_events == [false], "enabled changes are forwarded")
	_expect(settings_ids == ["health"], "Inspector action identifies its definition")
	_expect(remove_ids == ["health"], "remove action identifies its definition")

	var empty_options: Array[Dictionary] = []
	view.call("set_component_options", empty_options)
	_expect(component_option.disabled and add_button.disabled, "empty catalogs disable component addition")
	var empty_entries: Array[Dictionary] = []
	view.call("set_components", empty_entries)
	_expect(component_list.get_child_count() == 1 and component_list.get_child(0) is Label, "empty component lists show a helpful message")

	root.remove_child(view)
	view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder component editor view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_category_selected(value: String) -> void:
	category_events.append(value)


func _on_add_requested(value: String) -> void:
	add_events.append(value)


func _on_enabled_changed(value: bool, _definition: ObjectComponentDefinition) -> void:
	enabled_events.append(value)


func _on_settings_requested(definition: ObjectComponentDefinition) -> void:
	settings_ids.append(definition.component_id)


func _on_remove_requested(definition: ObjectComponentDefinition) -> void:
	remove_ids.append(definition.component_id)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
