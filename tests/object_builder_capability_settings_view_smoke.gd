extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/capability_settings_view.gd")
const CapabilityScript = preload("res://scripts/object_system/object_capability_definition.gd")
const SelectionScript = preload("res://scripts/object_system/object_capability_selection.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	root.add_child(view)
	var capability = CapabilityScript.new()
	capability.capability_id = "has_health"
	capability.display_name = "Здоровье"
	var selection = SelectionScript.new()
	selection.capability_id = "has_health"
	selection.enabled = true
	selection.set_component_setting("health", "max_health", 50.0)
	selection.set_component_setting("health", "invulnerable", false)
	selection.set_component_setting("health", "label", "Обычный")

	var descriptors: Array[Dictionary] = [
		{
			"component_id": "health",
			"setting_key": "max_health",
			"display_name": "Максимальное здоровье",
			"value_type": "Float",
			"default_value": 100.0,
			"level": "Basic",
			"group_name": "Здоровье",
			"minimum": 1.0,
			"maximum": 1000.0,
			"step": 1.0
		},
		{
			"component_id": "health",
			"setting_key": "invulnerable",
			"display_name": "Неуязвимость",
			"value_type": "Boolean",
			"default_value": false,
			"level": "Advanced",
			"group_name": "Защита"
		},
		{
			"component_id": "health",
			"setting_key": "label",
			"display_name": "Название",
			"value_type": "String",
			"default_value": "",
			"level": "Expert",
			"group_name": "Защита"
		}
	]
	view.call("configure", capability, selection, descriptors)
	_expect(view.title == "Здоровье · настройки", "settings dialog title uses the capability display name")
	_expect(view.get_child_count() == 1, "settings view owns one persistent scroll container")
	var scroll := view.get_child(0) as ScrollContainer
	var form := scroll.get_child(0) as VBoxContainer
	_expect(form.get_child_count() == 5, "settings view renders advanced toggle, group headers and controls")

	var health_row := form.get_child(2) as HBoxContainer
	var health_spin := health_row.get_child(1) as SpinBox
	_expect(is_equal_approx(health_spin.value, 50.0), "settings use the selected object's stored component values")
	_expect(health_row.visible, "basic settings are visible by default")
	var defense_header := form.get_child(3) as Label
	var invulnerable_row := form.get_child(4) as HBoxContainer
	_expect(not invulnerable_row.visible, "advanced settings are hidden by default")
	var advanced_check := form.get_child(0) as CheckBox
	advanced_check.toggled.emit(true)
	_expect(invulnerable_row.visible and defense_header.visible, "advanced toggle reveals advanced rows and their group")

	var setting_values: Array[Dictionary] = view.call("get_values")
	_expect(setting_values.size() == 3, "supported setting values are returned for the controller")
	_expect(setting_values[0].get("component_id") == "health" and setting_values[0].get("setting_key") == "max_health", "setting identity is returned with its value")
	_expect(is_equal_approx(float(setting_values[0].get("value", 0.0)), 50.0), "float setting values retain their numeric type")
	_expect(typeof(setting_values[1].get("value")) == TYPE_BOOL, "boolean setting values retain their type")
	_expect(setting_values[2].get("value") == "Обычный", "string setting values are returned")

	var empty_descriptors: Array[Dictionary] = []
	view.call("configure", capability, selection, empty_descriptors)
	var refreshed_form := (view.get_child(0) as ScrollContainer).get_child(0) as VBoxContainer
	_expect(refreshed_form.get_child_count() == 2, "reconfiguring clears old controls and shows an empty state")
	_expect(view.call("get_values").is_empty(), "empty schemas return no values")

	root.remove_child(view)
	view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder capability settings view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
