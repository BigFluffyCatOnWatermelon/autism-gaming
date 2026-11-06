@tool
extends Node
## Owns Object Builder dialogs and their controls. It returns form data to the editor controller.

signal creation_profile_selected(profile_id: String)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

var _property_dialog: AcceptDialog
var _property_name_edit: LineEdit
var _property_type_option: OptionButton
var _property_default_edit: LineEdit
var _property_group_edit: LineEdit
var _property_description_edit: TextEdit
var _property_advanced_check: CheckBox
var _property_range_check: CheckBox
var _property_minimum_edit: LineEdit
var _property_maximum_edit: LineEdit

var _creation_dialog: AcceptDialog
var _creation_profile_option: OptionButton
var _creation_profile_hint: Label

var _template_dialog: AcceptDialog
var _template_option: OptionButton

var _node_dialog: AcceptDialog
var _node_type_list: ItemList
var _node_name_edit: LineEdit


func build(property_types: Array, creation_profiles: Array, child_node_types: Array) -> void:
	_build_property_dialog(property_types)
	_build_creation_dialog(creation_profiles)
	_build_template_dialog()
	_build_node_dialog(child_node_types)


func get_property_dialog() -> AcceptDialog:
	return _property_dialog


func get_creation_dialog() -> AcceptDialog:
	return _creation_dialog


func get_template_dialog() -> AcceptDialog:
	return _template_dialog


func get_node_dialog() -> AcceptDialog:
	return _node_dialog


func _build_property_dialog(property_types: Array) -> void:
	_property_dialog = AcceptDialog.new()
	_property_dialog.title = "Новое пользовательское свойство"
	add_child(_property_dialog)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 320)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_property_dialog.add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	_property_name_edit = LineEdit.new()
	_property_name_edit.placeholder_text = "Например, Максимальное здоровье"
	UIFactory.add_labeled_control(form, "Название", _property_name_edit)

	_property_type_option = OptionButton.new()
	for type_name in property_types:
		_property_type_option.add_item(str(type_name))
	_property_type_option.item_selected.connect(_on_property_type_selected)
	UIFactory.add_labeled_control(form, "Тип", _property_type_option)

	_property_default_edit = LineEdit.new()
	_property_default_edit.text = "0"
	UIFactory.add_labeled_control(form, "Значение по умолчанию", _property_default_edit)

	_property_group_edit = LineEdit.new()
	_property_group_edit.text = "Основное"
	UIFactory.add_labeled_control(form, "Группа инспектора", _property_group_edit)

	_property_description_edit = TextEdit.new()
	_property_description_edit.custom_minimum_size = Vector2(0, 54)
	_property_description_edit.placeholder_text = "Подсказка о назначении свойства…"
	UIFactory.add_labeled_control(form, "Описание", _property_description_edit)

	_property_advanced_check = CheckBox.new()
	_property_advanced_check.text = "Дополнительный параметр"
	_property_advanced_check.tooltip_text = "Отмечает настройку как редко используемую."
	form.add_child(_property_advanced_check)

	_property_range_check = CheckBox.new()
	_property_range_check.text = "Ограничить числовой диапазон"
	_property_range_check.toggled.connect(_on_property_range_toggled)
	form.add_child(_property_range_check)

	var range_row := HBoxContainer.new()
	form.add_child(range_row)
	var minimum_label := Label.new()
	minimum_label.text = "Мин."
	range_row.add_child(minimum_label)
	_property_minimum_edit = LineEdit.new()
	_property_minimum_edit.text = "0"
	_property_minimum_edit.custom_minimum_size = Vector2(75, 0)
	_property_minimum_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_row.add_child(_property_minimum_edit)

	var maximum_label := Label.new()
	maximum_label.text = "Макс."
	range_row.add_child(maximum_label)
	_property_maximum_edit = LineEdit.new()
	_property_maximum_edit.text = "100"
	_property_maximum_edit.custom_minimum_size = Vector2(75, 0)
	_property_maximum_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_row.add_child(_property_maximum_edit)
	_update_property_range_controls()


func configure_property_form(values: Dictionary) -> void:
	if _property_dialog == null:
		return
	_property_dialog.title = str(values.get("title", "Новое пользовательское свойство"))
	_property_name_edit.text = str(values.get("display_name", ""))
	var requested_type := str(values.get("value_type", "String"))
	var type_index := 0
	for index in range(_property_type_option.item_count):
		if _property_type_option.get_item_text(index) == requested_type:
			type_index = index
			break
	_property_type_option.select(type_index)
	_property_default_edit.text = str(values.get("default_value", ""))
	_property_group_edit.text = str(values.get("group_name", "Основное"))
	_property_description_edit.text = str(values.get("description", ""))
	_property_advanced_check.button_pressed = bool(values.get("advanced", false))
	_property_range_check.disabled = not requested_type in ["Integer", "Float"]
	_property_range_check.button_pressed = bool(values.get("has_range", false)) and not _property_range_check.disabled
	_property_minimum_edit.text = str(values.get("minimum", "0"))
	_property_maximum_edit.text = str(values.get("maximum", "100"))
	_update_property_range_controls()


func get_property_form_values() -> Dictionary:
	var value_type := ""
	if _property_type_option.selected >= 0:
		value_type = _property_type_option.get_item_text(_property_type_option.selected)
	return {
		"display_name": _property_name_edit.text,
		"value_type": value_type,
		"default_value": _property_default_edit.text,
		"group_name": _property_group_edit.text,
		"description": _property_description_edit.text,
		"advanced": _property_advanced_check.button_pressed,
		"has_range": _property_range_check.button_pressed,
		"minimum": _property_minimum_edit.text,
		"maximum": _property_maximum_edit.text
	}


func _on_property_type_selected(_index: int) -> void:
	if _property_type_option.selected < 0:
		return
	var type_name := _property_type_option.get_item_text(_property_type_option.selected)
	_property_range_check.disabled = not type_name in ["Integer", "Float"]
	if _property_range_check.disabled:
		_property_range_check.button_pressed = false
	_update_property_range_controls()


func _on_property_range_toggled(_enabled: bool) -> void:
	_update_property_range_controls()


func _update_property_range_controls() -> void:
	if _property_minimum_edit == null or _property_maximum_edit == null:
		return
	var range_enabled := _property_range_check.button_pressed and not _property_range_check.disabled
	_property_minimum_edit.editable = range_enabled
	_property_maximum_edit.editable = range_enabled


func _build_creation_dialog(profiles: Array) -> void:
	_creation_dialog = AcceptDialog.new()
	_creation_dialog.title = "Новый объект · выбери тип"
	add_child(_creation_dialog)
	var form := UIFactory.create_scrollable_dialog_body(_creation_dialog, Vector2i(420, 190))
	_creation_profile_option = OptionButton.new()
	_creation_profile_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creation_profile_option.add_item("Без профиля · обычный объект")
	_creation_profile_option.set_item_metadata(0, "")
	for entry in profiles:
		if not entry is Dictionary:
			continue
		_creation_profile_option.add_item(str(entry.get("label", "")))
		_creation_profile_option.set_item_metadata(
			_creation_profile_option.item_count - 1,
			str(entry.get("id", ""))
		)
	_creation_profile_option.item_selected.connect(_on_creation_profile_selected)
	UIFactory.add_labeled_control(form, "Что создаём?", _creation_profile_option)
	_creation_profile_hint = Label.new()
	_creation_profile_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creation_profile_hint.custom_minimum_size = Vector2(0, 58)
	form.add_child(_creation_profile_hint)
	var help_label := Label.new()
	help_label.text = "После подтверждения появятся параметры, подходящие выбранному типу."
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(help_label)
	_creation_profile_option.select(0)


func _on_creation_profile_selected(_index: int) -> void:
	creation_profile_selected.emit(get_selected_creation_profile_id())


func get_selected_creation_profile_id() -> String:
	if _creation_profile_option == null or _creation_profile_option.selected < 0:
		return ""
	return str(_creation_profile_option.get_item_metadata(_creation_profile_option.selected))


func set_creation_profile_hint(value: String) -> void:
	if _creation_profile_hint != null:
		_creation_profile_hint.text = value


func reset_creation_profile() -> void:
	if _creation_profile_option != null and _creation_profile_option.item_count > 0:
		_creation_profile_option.select(0)


func _build_template_dialog() -> void:
	_template_dialog = AcceptDialog.new()
	_template_dialog.title = "Создать объект из шаблона"
	add_child(_template_dialog)
	var form := UIFactory.create_scrollable_dialog_body(_template_dialog, Vector2i(420, 150))
	_template_option = OptionButton.new()
	UIFactory.add_labeled_control(form, "Шаблон", _template_option)
	var hint := Label.new()
	hint.text = "Будет создана независимая копия определения и сцены."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(hint)


func set_template_options(names: Array) -> void:
	if _template_option == null:
		return
	_template_option.clear()
	for entry in names:
		_template_option.add_item(str(entry))
	if _template_option.item_count > 0:
		_template_option.select(0)


func get_selected_template_index() -> int:
	return _template_option.selected if _template_option != null else -1


func _build_node_dialog(child_node_types: Array) -> void:
	_node_dialog = AcceptDialog.new()
	_node_dialog.title = "Добавить дочерний узел"
	add_child(_node_dialog)
	var form := UIFactory.create_scrollable_dialog_body(_node_dialog, Vector2i(430, 250))
	form.add_theme_constant_override("separation", 5)
	var type_label := Label.new()
	type_label.text = "Выбери тип узла:"
	form.add_child(type_label)
	_node_type_list = ItemList.new()
	_node_type_list.custom_minimum_size = Vector2(0, 142)
	_node_type_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_type_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_node_type_list.select_mode = ItemList.SELECT_SINGLE
	for type_name in child_node_types:
		_node_type_list.add_item(str(type_name))
	form.add_child(_node_type_list)
	_node_name_edit = LineEdit.new()
	_node_name_edit.placeholder_text = "Имя (необязательно)"
	UIFactory.add_labeled_control(form, "Название", _node_name_edit)


func reset_node_dialog(default_type: String) -> void:
	if _node_type_list == null:
		return
	_node_name_edit.text = ""
	_node_type_list.deselect_all()
	for index in range(_node_type_list.item_count):
		if _node_type_list.get_item_text(index) == default_type:
			_node_type_list.select(index)
			_node_type_list.ensure_current_is_visible()
			return


func get_selected_node_type() -> String:
	if _node_type_list == null:
		return ""
	var selected := _node_type_list.get_selected_items()
	if selected.is_empty():
		return ""
	return _node_type_list.get_item_text(selected[0])


func get_node_name() -> String:
	return _node_name_edit.text if _node_name_edit != null else ""


func popup_property_dialog() -> void:
	UIFactory.popup_window_safely(_property_dialog, Vector2i(470, 430), 0.82)


func popup_creation_dialog() -> void:
	UIFactory.popup_window_safely(_creation_dialog, Vector2i(460, 250), 0.82)


func popup_template_dialog() -> void:
	UIFactory.popup_window_safely(_template_dialog, Vector2i(440, 170), 0.82)


func popup_node_dialog() -> void:
	UIFactory.popup_window_safely(_node_dialog, Vector2i(430, 300), 0.82)
