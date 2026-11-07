extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/capability_settings_panel.gd")
const CapabilityScript = preload("res://scripts/object_system/object_capability_definition.gd")
const SelectionScript = preload("res://scripts/object_system/object_capability_selection.gd")

var failures: Array[String] = []
var apply_count := 0
var close_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	view.call("build")
	root.add_child(view)
	view.connect("apply_requested", Callable(self, "_on_apply_requested"))
	view.connect("close_requested", Callable(self, "_on_close_requested"))

	_expect(view.visible, "inline settings panel can be displayed by its parent")
	_expect(view.get_child_count() == 5, "panel has one header, a scroll area, separators and a fixed footer")
	_expect(view.get_child(0) is HBoxContainer, "capability name and close action share the header row")
	_expect(view.get_child(2) is ScrollContainer, "capability settings use an independently scrollable area")
	_expect(view.get_child(4) is HBoxContainer, "apply and cancel actions remain fixed below the scroll area")

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

	_expect(view.call("get_capability_id") == "has_health", "panel stores the active capability ID")
	var title_label := view.get("_title_label") as Label
	_expect(title_label.text == "Здоровье", "panel title uses the capability display name")

	var form := view.get("_form") as VBoxContainer
	_expect(form.get_child_count() == 6, "panel renders advanced toggle, groups and three setting rows")
	var health_row := form.get_child(2) as VBoxContainer
	var health_spin := health_row.get_child(1) as SpinBox
	_expect(is_equal_approx(health_spin.value, 50.0), "panel loads the selected object's current setting")
	_expect(health_row.visible, "basic setting is visible by default")

	var defense_header := form.get_child(3) as Label
	var invulnerable_row := form.get_child(4) as VBoxContainer
	_expect(not invulnerable_row.visible, "advanced setting is hidden by default")
	var advanced_check := form.get_child(0) as CheckBox
	advanced_check.toggled.emit(true)
	_expect(invulnerable_row.visible and defense_header.visible, "advanced toggle reveals extended settings and their group")

	health_spin.value = 75.0
	var setting_values: Array[Dictionary] = view.call("get_values")
	_expect(setting_values.size() == 3, "panel returns all supported setting values")
	_expect(setting_values[0].get("component_id") == "health", "setting value includes its component ID")
	_expect(setting_values[0].get("setting_key") == "max_health", "setting value includes its stable key")
	_expect(is_equal_approx(float(setting_values[0].get("value", 0.0)), 75.0), "numeric value is read from the inline control")
	_expect(typeof(setting_values[1].get("value")) == TYPE_BOOL, "boolean value preserves its type")
	_expect(setting_values[2].get("value") == "Обычный", "string value is read from the inline control")

	var footer := view.get_child(view.get_child_count() - 1) as HBoxContainer
	var cancel_button := footer.get_child(0) as Button
	var apply_button := footer.get_child(1) as Button
	apply_button.pressed.emit()
	cancel_button.pressed.emit()
	_expect(apply_count == 1, "apply button emits a single apply request")
	_expect(close_count == 1, "cancel button emits a close request")

	var empty_descriptors: Array[Dictionary] = []
	view.call("configure", capability, selection, empty_descriptors)
	_expect(view.call("get_capability_id") == "has_health", "empty settings state retains the capability context")
	_expect(view.call("get_setting_control_count") == 0, "empty schema clears the previous settings controls")
	_expect((view.get("_apply_button") as Button).disabled, "apply is disabled when there are no editable settings")
	var empty_values: Array[Dictionary] = view.call("get_values")
	_expect(empty_values.is_empty(), "empty schema returns no values")

	view.call("clear")
	_expect(view.call("get_capability_id").is_empty(), "closing clears the active capability context")

	root.remove_child(view)
	view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder capability settings panel tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_apply_requested() -> void:
	apply_count += 1


func _on_close_requested() -> void:
	close_count += 1


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
