@tool
extends VBoxContainer
## Renders component selection and rows. The owning plugin handles catalog and model changes.

signal category_selected(category_id: String)
signal add_requested(component_id: String)
signal enabled_changed(enabled: bool, component_definition: ObjectComponentDefinition)
signal settings_requested(component_definition: ObjectComponentDefinition)
signal remove_requested(component_definition: ObjectComponentDefinition)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

var category_option: OptionButton
var component_option: OptionButton
var add_button: Button
var component_list: VBoxContainer


func build(categories: Array[Dictionary], selected_category: String) -> void:
	if category_option != null:
		return
	UIFactory.create_section_title(self, "КОМПОНЕНТЫ")
	var hint := Label.new()
	hint.text = "Компоненты добавляют объекту поведение. Типизированные настройки открываются в штатном Inspector и сохраняются вместе с определением."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	var picker_row := HBoxContainer.new()
	add_child(picker_row)
	category_option = OptionButton.new()
	category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in categories:
		category_option.add_item(str(entry.get("display_name", "")))
		category_option.set_item_metadata(category_option.item_count - 1, str(entry.get("id", "")))
	category_option.item_selected.connect(_on_category_selected)
	picker_row.add_child(category_option)
	_select_category(selected_category)

	component_option = OptionButton.new()
	component_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_row.add_child(component_option)

	add_button = Button.new()
	add_button.text = "+ Добавить"
	add_button.pressed.connect(_on_add_pressed)
	picker_row.add_child(add_button)

	component_list = VBoxContainer.new()
	component_list.add_theme_constant_override("separation", 4)
	add_child(component_list)


func get_selected_category() -> String:
	if category_option == null or category_option.selected < 0:
		return ""
	return str(category_option.get_item_metadata(category_option.selected))


func set_component_options(options: Array[Dictionary]) -> void:
	if component_option == null or add_button == null:
		return
	component_option.clear()
	for entry in options:
		component_option.add_item(str(entry.get("label", "")))
		component_option.set_item_metadata(component_option.item_count - 1, str(entry.get("id", "")))
	var has_options := not options.is_empty()
	if not has_options:
		component_option.add_item("Нет доступных компонентов")
	component_option.disabled = not has_options
	add_button.disabled = not has_options
	if has_options:
		component_option.select(0)


func set_components(entries: Array[Dictionary]) -> void:
	if component_list == null:
		return
	UIFactory.clear_children(component_list)
	var valid_entries := 0
	for entry in entries:
		var component_definition := entry.get("definition") as ObjectComponentDefinition
		if component_definition == null:
			continue
		valid_entries += 1
		component_list.add_child(_create_component_row(
			component_definition,
			str(entry.get("description", "Компонент без описания."))
		))
	if valid_entries == 0:
		UIFactory.add_empty_state(component_list, "Компоненты не добавлены.")


func _select_category(category_id: String) -> void:
	if category_option == null or category_option.item_count == 0:
		return
	for index in range(category_option.item_count):
		if str(category_option.get_item_metadata(index)) == category_id:
			category_option.select(index)
			return
	category_option.select(0)


func _create_component_row(
	component_definition: ObjectComponentDefinition,
	description: String
) -> HBoxContainer:
	var row := HBoxContainer.new()
	var enabled_check := CheckBox.new()
	enabled_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enabled_check.button_pressed = component_definition.enabled
	enabled_check.text = component_definition.display_name
	enabled_check.tooltip_text = "%s\nID: %s" % [description, component_definition.component_id]
	enabled_check.toggled.connect(_on_enabled_toggled.bind(component_definition))
	row.add_child(enabled_check)

	var settings_button := Button.new()
	settings_button.text = "Inspector"
	settings_button.tooltip_text = "Открыть типизированные настройки компонента в штатном Inspector"
	settings_button.pressed.connect(_on_settings_pressed.bind(component_definition))
	row.add_child(settings_button)

	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.tooltip_text = "Удалить компонент из определения"
	remove_button.pressed.connect(_on_remove_pressed.bind(component_definition))
	row.add_child(remove_button)
	return row


func _on_category_selected(_index: int) -> void:
	category_selected.emit(get_selected_category())


func _on_add_pressed() -> void:
	if component_option == null or component_option.disabled or component_option.selected < 0:
		return
	add_requested.emit(str(component_option.get_item_metadata(component_option.selected)))


func _on_enabled_toggled(
	enabled: bool,
	component_definition: ObjectComponentDefinition
) -> void:
	enabled_changed.emit(enabled, component_definition)


func _on_settings_pressed(component_definition: ObjectComponentDefinition) -> void:
	settings_requested.emit(component_definition)


func _on_remove_pressed(component_definition: ObjectComponentDefinition) -> void:
	remove_requested.emit(component_definition)
