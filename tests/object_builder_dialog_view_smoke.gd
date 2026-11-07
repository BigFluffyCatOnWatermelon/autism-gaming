extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/dialog_view.gd")

var failures: Array[String] = []
var profile_events: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	root.add_child(view)
	var property_types: Array[String] = ["String", "Integer", "Float", "Boolean", "Vector2"]
	var profiles: Array[Dictionary] = [
		{"id": "npc", "label": "Персонаж"},
		{"id": "resource", "label": "Ресурс"}
	]
	var node_types: Array[String] = ["Node2D", "Sprite2D", "Area2D"]
	view.call("build", property_types, profiles, node_types)
	view.connect("creation_profile_selected", Callable(self, "_on_profile_selected"))

	_expect(view.get_child_count() == 4, "dialog view owns the editor dialogs and import file picker")
	_expect(view.call("get_property_dialog") is AcceptDialog, "property dialog is available to the controller")
	_expect(view.call("get_creation_dialog") is AcceptDialog, "creation dialog is available to the controller")
	_expect(view.call("get_node_dialog") is AcceptDialog, "node dialog is available to the controller")

	view.call("configure_property_form", {
		"title": "Новое пользовательское свойство",
		"display_name": "Здоровье",
		"value_type": "Integer",
		"default_value": "50",
		"group_name": "Характеристики",
		"description": "Запас здоровья",
		"advanced": true,
		"has_range": true,
		"minimum": "1",
		"maximum": "100"
	})
	var property_values: Dictionary = view.call("get_property_form_values")
	_expect(property_values.get("display_name") == "Здоровье", "property form receives and returns the display name")
	_expect(property_values.get("value_type") == "Integer", "property form preserves the selected value type")
	_expect(property_values.get("default_value") == "50", "property form preserves the default value")
	_expect(property_values.get("group_name") == "Характеристики", "property form preserves inspector group")
	_expect(property_values.get("description") == "Запас здоровья", "property form preserves description")
	_expect(bool(property_values.get("advanced", false)), "property form preserves advanced state")
	_expect(bool(property_values.get("has_range", false)), "numeric property range is enabled")
	_expect((view.get("_property_minimum_edit") as LineEdit).editable, "numeric range minimum becomes editable")
	view.call("configure_property_form", {"value_type": "String", "has_range": true})
	property_values = view.call("get_property_form_values")
	_expect(not bool(property_values.get("has_range", true)), "non-numeric types cannot retain a range")
	_expect(not (view.get("_property_minimum_edit") as LineEdit).editable, "non-numeric range controls are disabled")

	var creation_dialog := view.call("get_creation_dialog") as AcceptDialog
	_expect(view.call("get_selected_creation_profile_id") == "", "creation dialog starts with no profile")
	var profile_option := view.get("_creation_profile_option") as OptionButton
	profile_option.select(1)
	profile_option.item_selected.emit(1)
	_expect(view.call("get_selected_creation_profile_id") == "npc", "creation dialog returns profile ID rather than display text")
	_expect(profile_events == ["npc"], "creation profile selection is forwarded")
	view.call("set_creation_profile_hint", "Описание профиля")
	_expect((view.get("_creation_profile_hint") as Label).text == "Описание профиля", "controller can update creation hint")
	view.call("reset_creation_profile")
	_expect(view.call("get_selected_creation_profile_id") == "", "creation dialog can reset to the generic object option")

	var category_options: Array[Dictionary] = [{"id": "Other", "label": "Другое"}, {"id": "Nature", "label": "Природа"}]
	var template_options: Array[Dictionary] = [{"id": "template_tree", "label": "Дерево"}, {"id": "template_stone", "label": "Камень"}]
	view.call("set_creation_category_options", category_options, "Nature")
	view.call("set_creation_sources", template_options, [])
	view.call("reset_creation_wizard", "template")
	var creation_values: Dictionary = view.call("get_creation_form_values")
	_expect(creation_values.get("mode") == "template", "creation dialog exposes the template mode")
	_expect(creation_values.get("source_id") == "template_tree", "creation wizard resolves the selected template by ID")
	_expect(creation_values.get("display_name") == "Дерево — копия", "creation wizard suggests a copy title")
	_expect(creation_values.get("category") == "Nature", "creation wizard keeps category IDs independent of labels")

	view.call("reset_node_dialog", "Sprite2D")
	_expect(view.call("get_selected_node_type") == "Sprite2D", "node dialog selects a requested default type")
	_expect(view.call("get_node_name") == "", "node dialog clears the optional node name")
	var node_option := view.get("_node_type_list") as ItemList
	node_option.select(2)
	_expect(view.call("get_selected_node_type") == "Area2D", "node dialog returns the selected Godot node type")
	(view.get("_node_name_edit") as LineEdit).text = "Hitbox"
	_expect(view.call("get_node_name") == "Hitbox", "node dialog exposes the entered node name")

	root.remove_child(view)
	view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder dialog view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_profile_selected(profile_id: String) -> void:
	profile_events.append(profile_id)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
