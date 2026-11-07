@tool
extends Node
## Owns Object Builder dialogs and their controls. It returns form data to the editor controller.

signal creation_profile_selected(profile_id: String)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")
const DialogService = preload("res://addons/object_builder/services/dialog_service.gd")

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
var _creation_mode_option: OptionButton
var _creation_profile_host: VBoxContainer
var _creation_profile_option: OptionButton
var _creation_profile_hint: Label
var _creation_source_host: VBoxContainer
var _creation_source_option: OptionButton
var _creation_template_sources: Array[Dictionary] = []
var _creation_object_sources: Array[Dictionary] = []
var _creation_import_host: VBoxContainer
var _creation_import_path_label: Label
var _creation_import_path := ""
var _creation_file_dialog: FileDialog
var _creation_name_edit: LineEdit
var _creation_suggested_name := ""
var _creation_category_option: OptionButton
var _creation_tags_edit: LineEdit
var _creation_description_edit: TextEdit

var _node_dialog: AcceptDialog
var _node_type_list: ItemList
var _node_name_edit: LineEdit


func build(property_types: Array, creation_profiles: Array, child_node_types: Array) -> void:
	_build_property_dialog(property_types)
	_build_creation_dialog(creation_profiles)
	_build_node_dialog(child_node_types)


func get_property_dialog() -> AcceptDialog:
	return _property_dialog


func get_creation_dialog() -> AcceptDialog:
	return _creation_dialog


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
	_creation_dialog.title = "Создание объекта"
	add_child(_creation_dialog)
	var form := UIFactory.create_scrollable_dialog_body(_creation_dialog, Vector2i(500, 500))
	form.add_theme_constant_override("separation", 7)

	_creation_mode_option = OptionButton.new()
	_creation_mode_option.add_item("С нуля")
	_creation_mode_option.set_item_metadata(0, "new")
	_creation_mode_option.add_item("Из шаблона")
	_creation_mode_option.set_item_metadata(1, "template")
	_creation_mode_option.add_item("Копия существующего объекта")
	_creation_mode_option.set_item_metadata(2, "duplicate")
	_creation_mode_option.add_item("Импортировать сцену Godot")
	_creation_mode_option.set_item_metadata(3, "import")
	_creation_mode_option.item_selected.connect(_on_creation_mode_selected)
	UIFactory.add_labeled_control(form, "Что хочешь сделать?", _creation_mode_option)

	_creation_profile_host = VBoxContainer.new()
	_creation_profile_host.add_theme_constant_override("separation", 3)
	form.add_child(_creation_profile_host)
	_creation_profile_option = OptionButton.new()
	_creation_profile_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creation_profile_option.add_item("Не знаю — обычный объект")
	_creation_profile_option.set_item_metadata(0, "")
	for entry in profiles:
		if not entry is Dictionary:
			continue
		_creation_profile_option.add_item(str(entry.get("label", "")))
		_creation_profile_option.set_item_metadata(_creation_profile_option.item_count - 1, str(entry.get("id", "")))
	_creation_profile_option.item_selected.connect(_on_creation_profile_selected)
	UIFactory.add_labeled_control(_creation_profile_host, "Начальный профиль (необязательно)", _creation_profile_option)
	_creation_profile_hint = Label.new()
	_creation_profile_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creation_profile_hint.custom_minimum_size = Vector2(0, 34)
	_creation_profile_host.add_child(_creation_profile_hint)

	_creation_source_host = VBoxContainer.new()
	_creation_source_host.add_theme_constant_override("separation", 3)
	form.add_child(_creation_source_host)
	_creation_source_option = OptionButton.new()
	_creation_source_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creation_source_option.item_selected.connect(_on_creation_source_selected)
	UIFactory.add_labeled_control(_creation_source_host, "На основе", _creation_source_option)
	var source_hint := Label.new()
	source_hint.text = "Будет создана независимая копия. Исходная запись и сцена не изменятся."
	source_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creation_source_host.add_child(source_hint)

	_creation_import_host = VBoxContainer.new()
	_creation_import_host.add_theme_constant_override("separation", 3)
	form.add_child(_creation_import_host)
	var import_row := HBoxContainer.new()
	_creation_import_host.add_child(import_row)
	var browse_button := Button.new()
	browse_button.text = "Выбрать сцену…"
	browse_button.pressed.connect(_on_creation_import_browse_pressed)
	import_row.add_child(browse_button)
	_creation_import_path_label = Label.new()
	_creation_import_path_label.text = "Файл не выбран"
	_creation_import_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creation_import_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	import_row.add_child(_creation_import_path_label)
	var import_hint := Label.new()
	import_hint.text = "Поддерживаются .tscn и .scn с корнем Node2D. Исходный файл останется без изменений; неизвестные узлы и ресурсы сохраняются."
	import_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creation_import_host.add_child(import_hint)

	_creation_name_edit = LineEdit.new()
	_creation_name_edit.placeholder_text = "Например, Дуб или Каменный сундук"
	_creation_name_edit.text_changed.connect(_on_creation_name_changed)
	UIFactory.add_labeled_control(form, "Название", _creation_name_edit)

	_creation_category_option = OptionButton.new()
	_creation_category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIFactory.add_labeled_control(form, "Категория", _creation_category_option)

	_creation_tags_edit = LineEdit.new()
	_creation_tags_edit.placeholder_text = "дерево, ресурс, лес (необязательно)"
	UIFactory.add_labeled_control(form, "Теги через запятую", _creation_tags_edit)

	_creation_description_edit = TextEdit.new()
	_creation_description_edit.custom_minimum_size = Vector2(0, 64)
	_creation_description_edit.placeholder_text = "Короткое описание объекта (необязательно)"
	UIFactory.add_labeled_control(form, "Описание", _creation_description_edit)

	_creation_file_dialog = FileDialog.new()
	_creation_file_dialog.title = "Импортировать сцену Godot"
	_creation_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_creation_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_creation_file_dialog.filters = PackedStringArray(["*.tscn, *.scn ; Godot Scene"])
	_creation_file_dialog.file_selected.connect(_on_creation_import_file_selected)
	add_child(_creation_file_dialog)
	_creation_mode_option.select(0)
	_creation_profile_option.select(0)
	_on_creation_mode_selected(0)


func set_creation_category_options(options: Array[Dictionary], selected_id: String = "Other") -> void:
	if _creation_category_option == null:
		return
	_creation_category_option.clear()
	for option in options:
		_creation_category_option.add_item(str(option.get("label", option.get("id", ""))))
		_creation_category_option.set_item_metadata(_creation_category_option.item_count - 1, str(option.get("id", "")))
	_select_option_metadata(_creation_category_option, selected_id)


func set_creation_category(category_id: String) -> void:
	_select_option_metadata(_creation_category_option, category_id)


func set_creation_sources(template_sources: Array[Dictionary], object_sources: Array[Dictionary]) -> void:
	_creation_template_sources = template_sources.duplicate(true)
	_creation_object_sources = object_sources.duplicate(true)
	_creation_mode_option.set_item_disabled(1, _creation_template_sources.is_empty())
	_creation_mode_option.set_item_disabled(2, _creation_object_sources.is_empty())
	_populate_creation_source_options()


func _populate_creation_source_options() -> void:
	if _creation_source_option == null or _creation_mode_option == null:
		return
	_creation_source_option.clear()
	var source_items := _creation_template_sources if get_creation_mode() == "template" else _creation_object_sources
	for source in source_items:
		_creation_source_option.add_item(str(source.get("label", "Без названия")))
		_creation_source_option.set_item_metadata(_creation_source_option.item_count - 1, str(source.get("id", "")))
	if _creation_source_option.item_count > 0:
		_creation_source_option.select(0)
		_suggest_creation_name_from_source()
	else:
		_creation_source_option.add_item("Список пока пуст")
		_creation_source_option.set_item_metadata(0, "")
		_creation_source_option.set_item_disabled(0, true)


func get_creation_mode() -> String:
	return str(_creation_mode_option.get_item_metadata(_creation_mode_option.selected)) if _creation_mode_option != null and _creation_mode_option.selected >= 0 else "new"


func get_creation_form_values() -> Dictionary:
	var tags := PackedStringArray()
	for raw_tag in _creation_tags_edit.text.replace(";", ",").split(","):
		var tag := str(raw_tag).strip_edges()
		if not tag.is_empty() and not tags.has(tag):
			tags.append(tag)
	var source_id := ""
	if _creation_source_option != null and _creation_source_option.selected >= 0:
		source_id = str(_creation_source_option.get_item_metadata(_creation_source_option.selected))
	var category_id := "Other"
	if _creation_category_option != null and _creation_category_option.selected >= 0:
		category_id = str(_creation_category_option.get_item_metadata(_creation_category_option.selected))
	return {
		"mode": get_creation_mode(),
		"profile_id": get_selected_creation_profile_id(),
		"display_name": _creation_name_edit.text.strip_edges(),
		"category": category_id,
		"tags": tags,
		"description": _creation_description_edit.text.strip_edges(),
		"source_id": source_id,
		"import_path": _creation_import_path
	}


func reset_creation_wizard(mode: String = "new") -> void:
	if _creation_name_edit == null:
		return
	_creation_suggested_name = ""
	_creation_name_edit.text = ""
	_creation_tags_edit.text = ""
	_creation_description_edit.text = ""
	_creation_import_path = ""
	_creation_import_path_label.text = "Файл не выбран"
	_select_option_metadata(_creation_mode_option, mode)
	_creation_profile_option.select(0)
	_select_option_metadata(_creation_category_option, "Other")
	_on_creation_mode_selected(_creation_mode_option.selected)


func _on_creation_mode_selected(_index: int) -> void:
	var mode := get_creation_mode()
	_creation_profile_host.visible = mode == "new"
	_creation_source_host.visible = mode in ["template", "duplicate"]
	_creation_import_host.visible = mode == "import"
	_populate_creation_source_options()


func _on_creation_source_selected(_index: int) -> void:
	_suggest_creation_name_from_source()


func _suggest_creation_name_from_source() -> void:
	if _creation_name_edit == null or _creation_source_option == null:
		return
	if _creation_source_option.selected < 0 or _creation_source_option.item_count == 0:
		return
	if not _creation_name_edit.text.is_empty() and _creation_name_edit.text != _creation_suggested_name:
		return
	_creation_suggested_name = _creation_source_option.get_item_text(_creation_source_option.selected) + " — копия"
	_creation_name_edit.text = _creation_suggested_name


func _on_creation_name_changed(next_name: String) -> void:
	if next_name != _creation_suggested_name:
		_creation_suggested_name = ""

func _on_creation_import_browse_pressed() -> void:
	DialogService.popup_window_safely(_creation_file_dialog, Vector2i(780, 540), 0.82)


func _on_creation_import_file_selected(path: String) -> void:
	_creation_import_path = path
	_creation_import_path_label.text = path.get_file()
	_creation_import_path_label.tooltip_text = path
	if _creation_name_edit.text.is_empty() or _creation_name_edit.text == _creation_suggested_name:
		_creation_suggested_name = path.get_file().get_basename()
		_creation_name_edit.text = _creation_suggested_name


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
	reset_creation_wizard("new")
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


func _select_option_metadata(option: OptionButton, metadata_value: String) -> void:
	if option == null or option.item_count == 0:
		return
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == metadata_value:
			option.select(index)
			return
	option.select(0)


func popup_property_dialog() -> void:
	DialogService.popup_window_safely(_property_dialog, Vector2i(470, 430), 0.82)


func popup_creation_dialog() -> void:
	DialogService.popup_window_safely(_creation_dialog, Vector2i(540, 560), 0.90)


func popup_node_dialog() -> void:
	DialogService.popup_window_safely(_node_dialog, Vector2i(430, 300), 0.82)
