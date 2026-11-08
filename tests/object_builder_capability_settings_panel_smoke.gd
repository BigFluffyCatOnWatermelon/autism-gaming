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
	_expect(view.get_child_count() == 6, "panel has header, search/filter toolbar, scroll area and fixed footer")
	_expect(view.get_child(0) is HBoxContainer, "capability name and close action share the header row")
	_expect(view.get_child(2) is HBoxContainer, "search and level filter share one compact toolbar")
	_expect(view.get_child(3) is ScrollContainer, "capability settings use an independently scrollable area")
	_expect(view.get_child(5) is HBoxContainer, "apply and cancel actions remain fixed below the scroll area")

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
			"description": "Количество единиц здоровья.",
			"value_type": "Float",
			"default_value": 100.0,
			"level": "Basic",
			"group_name": "Здоровье",
			"unit": "ед.",
			"minimum": 1.0,
			"maximum": 1000.0,
			"step": 1.0
		},
		{
			"component_id": "health",
			"setting_key": "invulnerable",
			"display_name": "Неуязвимость",
			"description": "Запрещает получать урон.",
			"value_type": "Boolean",
			"default_value": false,
			"level": "Advanced",
			"group_name": "Защита"
		},
		{
			"component_id": "health",
			"setting_key": "parts_offset",
			"display_name": "Смещение частей",
			"value_type": "Vector2",
			"default_value": Vector2(0, 8),
			"level": "Basic",
			"group_name": "Геометрия",
			"step": 1.0
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
	_expect(view.call("get_setting_control_count") == 4, "panel builds every setting descriptor")
	_expect((view.call("get_visible_setting_keys") as PackedStringArray) == PackedStringArray(["max_health", "parts_offset"]), "basic filter shows only basic settings by default")
	var health_spin := view.call("get_setting_control", "health", "max_health") as SpinBox
	_expect(health_spin != null and is_equal_approx(health_spin.value, 50.0), "panel loads the selected object's current setting")
	_expect((view.get("_apply_button") as Button).disabled, "Apply starts disabled until a value actually changes")
	_expect((view.get("_reset_all_button") as Button).disabled, "reset-all starts disabled when there are no pending changes")
	var offset_control := view.call("get_setting_control", "health", "parts_offset") as HBoxContainer
	_expect(offset_control != null and offset_control.get_child_count() == 2, "Vector2 settings use two numeric axis controls")
	(offset_control.get_child(0) as SpinBox).value = 12.0
	(offset_control.get_child(1) as SpinBox).value = 24.0
	var health_entry: Dictionary = view.call("get_setting_entry", "health", "max_health")
	var health_label_row := (health_entry.get("row") as VBoxContainer).get_child(0) as HBoxContainer
	var health_label := health_label_row.get_child(0) as Label
	_expect(health_label.text == "Максимальное здоровье · ед.", "parameter unit is displayed beside its label")
	var reset_button := health_entry.get("reset_button") as Button
	var range_slider := health_entry.get("range_slider") as HSlider
	_expect(range_slider != null and is_equal_approx(range_slider.value, 50.0), "bounded numeric settings show a slider beside the exact value field")
	range_slider.value = 75.0
	_expect(is_equal_approx(health_spin.value, 75.0), "range slider updates the exact numeric field")
	health_spin.value = 50.0
	_expect(is_equal_approx(range_slider.value, 50.0), "exact numeric field updates the range slider")
	reset_button.pressed.emit()
	_expect(is_equal_approx(health_spin.value, 100.0), "per-setting reset restores its declared default value")
	_expect(not (view.get("_apply_button") as Button).disabled, "changing a Vector2 value enables Apply")
	_expect(not (view.get("_reset_all_button") as Button).disabled, "reset-all becomes available while edits are pending")
	_expect((view.call("get_changed_values") as Array).size() == 2, "pending payload contains only values changed from the initial state")

	view.call("_on_level_filter_selected", 1)
	_expect((view.call("get_visible_setting_keys") as PackedStringArray).size() == 3, "intermediate filter reveals basic and advanced settings without expert fields")
	view.call("_on_level_filter_selected", 2)
	_expect((view.call("get_visible_setting_keys") as PackedStringArray).size() == 4, "all-level filter reveals expert settings too")
	view.call("_on_search_changed", "неуязвимость")
	_expect((view.call("get_visible_setting_keys") as PackedStringArray) == PackedStringArray(["invulnerable"]), "search matches localized setting labels")
	view.call("_on_search_changed", "количество")
	_expect((view.call("get_visible_setting_keys") as PackedStringArray) == PackedStringArray(["max_health"]), "search also matches setting descriptions")
	view.call("_on_search_changed", "no-such-setting")
	_expect((view.get("_empty_state") as Label).visible, "empty search results show a helpful empty state")
	view.call("_on_search_changed", "")
	view.call("_on_level_filter_selected", 0)

	var setting_values: Array[Dictionary] = view.call("get_values")
	_expect(setting_values.size() == 4, "filtering never drops values from the pending apply payload")
	_expect(is_equal_approx(float(setting_values[0].get("value", 0.0)), 100.0), "reset value is included in the pending apply payload")
	_expect(setting_values[1].get("value") == Vector2(12.0, 24.0), "Vector2 value preserves both edited axes")
	_expect(setting_values[2].get("value") == false, "boolean value preserves its type")
	_expect(setting_values[3].get("value") == "Обычный", "string value is read from the inline control")

	var footer := view.get_child(view.get_child_count() - 1) as HBoxContainer
	_expect(footer.get_child(0) is Label, "fixed footer explains the pending edit state")
	var cancel_button := footer.get_child(1) as Button
	var apply_button := footer.get_child(2) as Button
	apply_button.pressed.emit()
	cancel_button.pressed.emit()
	_expect(apply_count == 1, "apply button emits a single apply request")
	_expect(close_count == 1, "cancel button emits a close request")

	var rich_descriptors: Array[Dictionary] = [
		{
			"component_id": "visual",
			"setting_key": "tint_color",
			"display_name": "Цвет оттенка",
			"value_type": "String",
			"default_value": "#ffffff",
			"editor_hint": "color",
			"level": "Basic",
			"group_name": "Цвет"
		},
		{
			"component_id": "visual",
			"setting_key": "palette_json",
			"display_name": "Карта палитры",
			"value_type": "String",
			"default_value": "{}",
			"editor_hint": "json",
			"level": "Advanced",
			"group_name": "Палитра"
		},
		{
			"component_id": "visual",
			"setting_key": "texture_path",
			"display_name": "Текстура",
			"value_type": "String",
			"default_value": "",
			"editor_hint": "texture",
			"level": "Basic",
			"group_name": "Изображение"
		}
	]
	selection.set_component_setting("visual", "tint_color", "#ffffff")
	selection.set_component_setting("visual", "palette_json", "{}")
	selection.set_component_setting("visual", "texture_path", "")
	view.call("configure", capability, selection, rich_descriptors)
	var color_control := view.call("get_setting_control", "visual", "tint_color") as ColorPickerButton
	var json_control := view.call("get_setting_control", "visual", "palette_json") as TextEdit
	var texture_control := view.call("get_setting_control", "visual", "texture_path") as LineEdit
	_expect(color_control != null and color_control.color == Color.WHITE, "color hint uses a native color picker while retaining string serialization")
	_expect(json_control != null and json_control.text == "{}", "JSON hint uses a multiline editor")
	_expect(texture_control != null, "texture paths retain a string value for the runtime component")
	var texture_entry: Dictionary = view.call("get_setting_entry", "visual", "texture_path")
	var texture_label_row := (texture_entry.get("row") as VBoxContainer).get_child(0) as HBoxContainer
	_expect(texture_label_row.get_child_count() == 3, "texture path setting includes reset and resource browse actions")
	json_control.text = "{"
	view.call("_update_dirty_state")
	_expect((view.get("_apply_button") as Button).disabled, "invalid JSON cannot be applied")
	_expect((view.get("_change_summary") as Label).text.contains("JSON"), "invalid JSON reports the exact validation problem")
	json_control.text = "{\"grass\":\"#00ff00\"}"
	color_control.color = Color.RED
	texture_control.text = "res://icon.svg"
	view.call("_update_dirty_state")
	_expect(not (view.get("_apply_button") as Button).disabled, "valid JSON, color and resource path edits can be applied")
	var rich_values: Array[Dictionary] = view.call("get_changed_values")
	_expect(rich_values.size() == 3, "rich editors return normalized String values to the existing component model")
	var color_value := ""
	for rich_entry in rich_values:
		if str(rich_entry.get("setting_key", "")) == "tint_color":
			color_value = str(rich_entry.get("value", ""))
	_expect(color_value == "#ff0000", "color picker converts its value back to the component's expected HTML color string")

	view.call("configure", capability, selection, [])
	_expect(view.call("get_capability_id") == "has_health", "empty settings state retains the capability context")
	_expect(view.call("get_setting_control_count") == 0, "empty schema clears the previous settings controls")
	_expect((view.get("_apply_button") as Button).disabled, "apply is disabled when there are no editable settings")
	_expect((view.get("_empty_state") as Label).visible, "empty schemas show a descriptive empty state")
	_expect((view.call("get_values") as Array).is_empty(), "empty schema returns no values")

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
