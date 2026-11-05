@tool
extends EditorPlugin

const CATEGORY_LABELS := {
	"Nature": "Природа",
	"Buildings": "Здания",
	"Items": "Предметы",
	"Equipment": "Экипировка",
	"Furniture": "Мебель",
	"Characters": "Персонажи",
	"Animals": "Животные",
	"Interactive": "Интерактивные",
	"Effects": "Эффекты",
	"Transport": "Транспорт",
	"Decorations": "Декорации",
	"Other": "Другое"
}
const ROOT_TYPES := [
	"Node2D",
	"StaticBody2D",
	"Area2D",
	"CharacterBody2D",
	"RigidBody2D",
	"AnimatableBody2D"
]

var _dock: MarginContainer
var _search: LineEdit
var _category_filter: OptionButton
var _object_list: ItemList
var _name_edit: LineEdit
var _id_edit: LineEdit
var _category_edit: LineEdit
var _root_type: OptionButton
var _tags_edit: LineEdit
var _description_edit: TextEdit
var _template_check: CheckBox
var _property_list: VBoxContainer
var _property_dialog: AcceptDialog
var _property_name_edit: LineEdit
var _property_type_option: OptionButton
var _property_default_edit: LineEdit
var _property_group_edit: LineEdit
var _template_dialog: AcceptDialog
var _template_option: OptionButton
var _status_label: Label
var _open_scene_button: Button
var _definitions: Array[ObjectDefinition] = []
var _visible_definitions: Array[ObjectDefinition] = []
var _templates: Array[ObjectDefinition] = []
var _working_definition: ObjectDefinition
var _can_save_as_template := true


func _enter_tree() -> void:
	_build_ui()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_refresh_library()


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()


func _build_ui() -> void:
	_dock = MarginContainer.new()
	_dock.name = "Object Builder"
	_dock.custom_minimum_size = Vector2(560, 360)
	_dock.add_theme_constant_override("margin_left", 8)
	_dock.add_theme_constant_override("margin_top", 8)
	_dock.add_theme_constant_override("margin_right", 8)
	_dock.add_theme_constant_override("margin_bottom", 8)

	var layout := VBoxContainer.new()
	_dock.add_child(layout)

	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	var title := Label.new()
	title.text = "Object Builder"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	var new_button := Button.new()
	new_button.text = "Новый"
	new_button.tooltip_text = "Создать пустой объект"
	new_button.pressed.connect(_on_new_object_pressed)
	toolbar.add_child(new_button)
	var template_button := Button.new()
	template_button.text = "Из шаблона"
	template_button.pressed.connect(_on_create_from_template_pressed)
	toolbar.add_child(template_button)
	var refresh_button := Button.new()
	refresh_button.text = "↻"
	refresh_button.tooltip_text = "Обновить библиотеку"
	refresh_button.pressed.connect(_refresh_library)
	toolbar.add_child(refresh_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(split)

	var library_panel := VBoxContainer.new()
	library_panel.custom_minimum_size = Vector2(190, 0)
	split.add_child(library_panel)

	_search = LineEdit.new()
	_search.placeholder_text = "Поиск объектов…"
	_search.text_changed.connect(_on_search_changed)
	library_panel.add_child(_search)

	_category_filter = OptionButton.new()
	_category_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_filter.item_selected.connect(_on_category_filter_changed)
	library_panel.add_child(_category_filter)

	_object_list = ItemList.new()
	_object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_object_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_object_list.item_selected.connect(_on_library_item_selected)
	library_panel.add_child(_object_list)

	var editor_scroll := ScrollContainer.new()
	editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(editor_scroll)

	var editor := VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 7)
	editor_scroll.add_child(editor)

	var basics_title := Label.new()
	basics_title.text = "ОСНОВНОЕ"
	editor.add_child(basics_title)

	_name_edit = _add_labeled_line_edit(editor, "Название", "Например, Дуб")
	_id_edit = _add_labeled_line_edit(editor, "Постоянный ID", "Создаётся автоматически")
	_id_edit.editable = false
	_category_edit = _add_labeled_line_edit(editor, "Категория", "Например, Nature")
	_tags_edit = _add_labeled_line_edit(editor, "Теги", "дерево, ресурс, лес")

	_root_type = OptionButton.new()
	for root_type in ROOT_TYPES:
		_root_type.add_item(root_type)
	_add_labeled_control(editor, "Тип корневого узла", _root_type)

	_template_check = CheckBox.new()
	_template_check.text = "Сохранить как шаблон"
	_template_check.tooltip_text = "Шаблон будет доступен для создания новых объектов."
	editor.add_child(_template_check)

	_description_edit = TextEdit.new()
	_description_edit.custom_minimum_size = Vector2(0, 72)
	_description_edit.placeholder_text = "Краткое описание объекта…"
	_add_labeled_control(editor, "Описание", _description_edit)

	var properties_title := Label.new()
	properties_title.text = "ПОЛЬЗОВАТЕЛЬСКИЕ СВОЙСТВА"
	editor.add_child(properties_title)

	var properties_hint := Label.new()
	properties_hint.text = "Свойства хранятся в определении отдельно от скриптов игры."
	properties_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(properties_hint)

	_property_list = VBoxContainer.new()
	editor.add_child(_property_list)

	var add_property_button := Button.new()
	add_property_button.text = "+ Добавить свойство"
	add_property_button.pressed.connect(_on_add_property_pressed)
	editor.add_child(add_property_button)

	var component_note := Label.new()
	component_note.text = "Компоненты и шаблоны с логикой будут расширяться отдельно."
	component_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(component_note)

	var action_row := HBoxContainer.new()
	editor.add_child(action_row)
	var save_button := Button.new()
	save_button.text = "Сохранить"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save_pressed)
	action_row.add_child(save_button)
	_open_scene_button = Button.new()
	_open_scene_button.text = "Открыть сцену"
	_open_scene_button.disabled = true
	_open_scene_button.pressed.connect(_on_open_scene_pressed)
	action_row.add_child(_open_scene_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(_status_label)

	_build_property_dialog()
	_build_template_dialog()


func _add_labeled_line_edit(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	_add_labeled_control(parent, label_text, edit)
	return edit


func _add_labeled_control(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)


func _build_property_dialog() -> void:
	_property_dialog = AcceptDialog.new()
	_property_dialog.title = "Новое пользовательское свойство"
	add_child(_property_dialog)

	var form := VBoxContainer.new()
	_property_dialog.add_child(form)
	_property_name_edit = LineEdit.new()
	_property_name_edit.placeholder_text = "Например, Максимальное здоровье"
	_add_labeled_control(form, "Название", _property_name_edit)

	_property_type_option = OptionButton.new()
	for type_name in ["String", "Integer", "Float", "Boolean", "Vector2"]:
		_property_type_option.add_item(type_name)
	_add_labeled_control(form, "Тип", _property_type_option)

	_property_default_edit = LineEdit.new()
	_property_default_edit.text = "0"
	_add_labeled_control(form, "Значение по умолчанию", _property_default_edit)

	_property_group_edit = LineEdit.new()
	_property_group_edit.text = "Основное"
	_add_labeled_control(form, "Группа инспектора", _property_group_edit)

	_property_dialog.confirmed.connect(_on_property_dialog_confirmed)


func _build_template_dialog() -> void:
	_template_dialog = AcceptDialog.new()
	_template_dialog.title = "Создать объект из шаблона"
	add_child(_template_dialog)

	var form := VBoxContainer.new()
	_template_dialog.add_child(form)
	_template_option = OptionButton.new()
	_add_labeled_control(form, "Шаблон", _template_option)
	var hint := Label.new()
	hint.text = "Будет создана независимая копия определения и сцены."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(hint)
	_template_dialog.confirmed.connect(_on_template_dialog_confirmed)


func _refresh_library() -> void:
	_definitions = ObjectLibraryService.load_definitions()
	_templates = ObjectLibraryService.load_templates()
	_rebuild_category_filter()
	_refresh_library_list()
	if _definitions.is_empty():
		_set_status("Библиотека пока пуста. Создай объект или начни с шаблона.", false)


func _rebuild_category_filter() -> void:
	var previous_category := ""
	if _category_filter.selected >= 0:
		previous_category = str(_category_filter.get_item_metadata(_category_filter.selected))

	var categories: Array[String] = []
	for category_key in CATEGORY_LABELS.keys():
		categories.append(str(category_key))
	for definition in _definitions:
		if definition != null and not definition.category.is_empty() and not categories.has(definition.category):
			categories.append(definition.category)
	categories.sort()

	_category_filter.clear()
	_category_filter.add_item("Все категории")
	_category_filter.set_item_metadata(0, "")
	for category_name in categories:
		var label_text := str(CATEGORY_LABELS.get(category_name, category_name))
		_category_filter.add_item(label_text)
		_category_filter.set_item_metadata(_category_filter.item_count - 1, category_name)

	for item_index in range(_category_filter.item_count):
		if str(_category_filter.get_item_metadata(item_index)) == previous_category:
			_category_filter.select(item_index)
			return
	_category_filter.select(0)


func _refresh_library_list() -> void:
	if _object_list == null:
		return
	_object_list.clear()
	_visible_definitions.clear()
	var query := _search.text.strip_edges().to_lower()
	var selected_category := ""
	if _category_filter.selected >= 0:
		selected_category = str(_category_filter.get_item_metadata(_category_filter.selected))

	for definition in _definitions:
		if definition == null:
			continue
		if not selected_category.is_empty() and definition.category != selected_category:
			continue
		var searchable_text := (
			definition.display_name + " " + definition.object_id + " "
			+ definition.description + " " + _join_tags(definition.tags)
		).to_lower()
		if not query.is_empty() and not searchable_text.contains(query):
			continue
		_visible_definitions.append(definition)
		_object_list.add_item(definition.display_name)
		_object_list.set_item_tooltip(_object_list.item_count - 1, definition.description)

	if _visible_definitions.is_empty():
		_object_list.add_item("Объекты не найдены")
		_object_list.set_item_disabled(0, true)


func _join_tags(tags: PackedStringArray) -> String:
	var values := PackedStringArray()
	for tag in tags:
		values.append(tag)
	return " ".join(values)


func _on_search_changed(_value: String) -> void:
	_refresh_library_list()


func _on_category_filter_changed(_index: int) -> void:
	_refresh_library_list()


func _on_library_item_selected(index: int) -> void:
	if index < 0 or index >= _visible_definitions.size():
		return
	_can_save_as_template = false
	_load_definition(_visible_definitions[index])


func _on_new_object_pressed() -> void:
	var definition := ObjectDefinition.new()
	definition.object_id = "object_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	definition.display_name = "Новый объект"
	definition.category = "Nature"
	definition.root_type = "Node2D"
	definition.is_template = false
	_can_save_as_template = true
	_load_definition(definition)
	_set_status("Новый объект ещё не сохранён.", false)


func _on_create_from_template_pressed() -> void:
	_templates = ObjectLibraryService.load_templates()
	_template_option.clear()
	if _templates.is_empty():
		_set_status("Шаблоны не найдены.", true)
		return
	for template_definition in _templates:
		_template_option.add_item(template_definition.display_name)
	_template_option.select(0)
	_template_dialog.popup_centered(Vector2i(440, 170))


func _on_template_dialog_confirmed() -> void:
	if _template_option.selected < 0 or _template_option.selected >= _templates.size():
		return
	var template_definition := _templates[_template_option.selected]
	var definition := template_definition.duplicate(true) as ObjectDefinition
	definition.object_id = "object_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	definition.display_name = template_definition.display_name + " — копия"
	definition.is_template = false
	definition.template_id = template_definition.object_id
	definition.scene = null
	definition.scene_path = ""
	_clone_template_scene(template_definition, definition)
	_can_save_as_template = true
	_load_definition(definition)
	_set_status("Создана копия шаблона. Измени параметры и сохрани объект.", false)


func _clone_template_scene(template_definition: ObjectDefinition, target_definition: ObjectDefinition) -> void:
	var source_scene: PackedScene = template_definition.scene
	if not template_definition.scene_path.is_empty() and FileAccess.file_exists(template_definition.scene_path):
		var loaded_scene := ResourceLoader.load(
			template_definition.scene_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		)
		if loaded_scene is PackedScene:
			source_scene = loaded_scene as PackedScene
	if source_scene == null:
		return

	var scene_root := source_scene.instantiate()
	scene_root.set_meta("object_definition_id", target_definition.object_id)
	scene_root.set_meta("object_category", target_definition.category)
	var copied_scene := PackedScene.new()
	var pack_error := copied_scene.pack(scene_root)
	scene_root.free()
	if pack_error != OK:
		push_warning("Object Builder: не удалось скопировать сцену шаблона.")
		return

	ObjectLibraryService.ensure_directories()
	var target_path := ObjectLibraryService.get_scene_path(target_definition.object_id)
	var save_error := ResourceSaver.save(copied_scene, target_path)
	if save_error != OK:
		push_warning("Object Builder: не удалось сохранить копию сцены шаблона.")
		return
	target_definition.scene = copied_scene
	target_definition.scene_path = target_path


func _load_definition(definition: ObjectDefinition) -> void:
	_working_definition = definition.duplicate(true) as ObjectDefinition
	_name_edit.text = _working_definition.display_name
	_id_edit.text = _working_definition.object_id
	_category_edit.text = _working_definition.category
	_tags_edit.text = _join_tags(_working_definition.tags)
	_description_edit.text = _working_definition.description
	_template_check.button_pressed = _working_definition.is_template
	_template_check.disabled = not _can_save_as_template
	_select_root_type(_working_definition.root_type)
	_open_scene_button.disabled = _working_definition.scene_path.is_empty() or not FileAccess.file_exists(_working_definition.scene_path)
	_rebuild_property_list()


func _select_root_type(type_name: String) -> void:
	for index in range(_root_type.item_count):
		if _root_type.get_item_text(index) == type_name:
			_root_type.select(index)
			return
	_root_type.select(0)


func _rebuild_property_list() -> void:
	for child in _property_list.get_children():
		child.queue_free()
	if _working_definition == null:
		return

	if _working_definition.custom_properties.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Пока нет пользовательских свойств."
		_property_list.add_child(empty_label)
		return

	for property_definition in _working_definition.custom_properties:
		if property_definition == null:
			continue
		var row := HBoxContainer.new()
		var description_label := Label.new()
		description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_label.text = "%s  ·  %s  ·  %s" % [
			property_definition.display_name,
			property_definition.value_type,
			str(property_definition.default_value)
		]
		description_label.clip_text = true
		row.add_child(description_label)
		var remove_button := Button.new()
		remove_button.text = "×"
		remove_button.tooltip_text = "Удалить свойство из определения"
		remove_button.pressed.connect(_on_remove_property_pressed.bind(property_definition))
		row.add_child(remove_button)
		_property_list.add_child(row)


func _on_add_property_pressed() -> void:
	if _working_definition == null:
		_on_new_object_pressed()
	_property_name_edit.text = ""
	_property_type_option.select(2)
	_property_default_edit.text = "0"
	_property_group_edit.text = "Основное"
	_property_dialog.popup_centered(Vector2i(420, 260))


func _on_property_dialog_confirmed() -> void:
	if _working_definition == null:
		return
	var display_name := _property_name_edit.text.strip_edges()
	if display_name.is_empty():
		_set_status("У свойства должно быть название.", true)
		return

	var property_definition := ObjectPropertyDefinition.new()
	property_definition.display_name = display_name
	property_definition.property_id = _make_property_id(display_name)
	var duplicate_index := 2
	var base_id := property_definition.property_id
	while _has_property_id(property_definition.property_id):
		property_definition.property_id = base_id + "_" + str(duplicate_index)
		duplicate_index += 1

	property_definition.value_type = _property_type_option.get_item_text(_property_type_option.selected)
	property_definition.default_value = _parse_default_value(
		_property_default_edit.text,
		property_definition.value_type
	)
	property_definition.group_name = _property_group_edit.text.strip_edges()
	if property_definition.group_name.is_empty():
		property_definition.group_name = "Основное"
	_working_definition.custom_properties.append(property_definition)
	_rebuild_property_list()
	_set_status("Свойство добавлено. Нажми «Сохранить».", false)


func _has_property_id(property_id: String) -> bool:
	for property_definition in _working_definition.custom_properties:
		if property_definition != null and property_definition.property_id == property_id:
			return true
	return false


func _make_property_id(value: String) -> String:
	var result := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	result = result.validate_filename()
	if result.is_empty():
		result = "property"
	return result


func _parse_default_value(value: String, type_name: String) -> Variant:
	match type_name:
		"Integer":
			return value.to_int()
		"Float":
			return value.to_float()
		"Boolean":
			return value.strip_edges().to_lower() in ["true", "1", "yes", "да"]
		"Vector2":
			var parts := value.split(",")
			if parts.size() == 2:
				return Vector2(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float())
			return Vector2.ZERO
		_:
			return value


func _on_remove_property_pressed(property_definition: ObjectPropertyDefinition) -> void:
	if _working_definition == null:
		return
	_working_definition.custom_properties.erase(property_definition)
	_rebuild_property_list()


func _on_save_pressed() -> void:
	if _working_definition == null:
		_on_new_object_pressed()
	_working_definition.display_name = _name_edit.text.strip_edges()
	_working_definition.category = _category_edit.text.strip_edges()
	_working_definition.description = _description_edit.text
	_working_definition.root_type = _root_type.get_item_text(_root_type.selected)
	_working_definition.is_template = _template_check.button_pressed

	var tags := PackedStringArray()
	for raw_tag in _tags_edit.text.split(","):
		var tag := raw_tag.strip_edges()
		if not tag.is_empty():
			tags.append(tag)
	_working_definition.tags = tags

	var validation_errors := ObjectLibraryService.validate_definition(_working_definition)
	if not validation_errors.is_empty():
		_set_status("Нельзя сохранить: " + "; ".join(validation_errors), true)
		return

	if _working_definition.scene_path.is_empty() or not FileAccess.file_exists(_working_definition.scene_path):
		if not _create_scene_for_definition():
			return

	var save_error: Error
	if _working_definition.is_template:
		save_error = ObjectLibraryService.save_template(_working_definition)
	else:
		save_error = ObjectLibraryService.save_definition(_working_definition)
	if save_error != OK:
		_set_status("Не удалось сохранить объект. Код ошибки: %d" % save_error, true)
		return

	_id_edit.text = _working_definition.object_id
	_open_scene_button.disabled = false
	if _working_definition.is_template:
		_set_status("Шаблон сохранён. Его можно выбрать кнопкой «Из шаблона».", false)
	else:
		_set_status("Объект сохранён в библиотеку: %s" % _working_definition.display_name, false)
	_refresh_library()


func _create_scene_for_definition() -> bool:
	ObjectLibraryService.ensure_directories()
	var created_object: Object = ClassDB.instantiate(_working_definition.root_type)
	if not created_object is Node:
		_set_status("Не удалось создать корневой узел типа " + _working_definition.root_type, true)
		return false

	var scene_root := created_object as Node
	scene_root.name = "Object"
	scene_root.set_meta("object_definition_id", _working_definition.object_id)
	scene_root.set_meta("object_category", _working_definition.category)

	var visuals := Node2D.new()
	visuals.name = "Visuals"
	scene_root.add_child(visuals)
	visuals.owner = scene_root

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(scene_root)
	scene_root.free()
	if pack_error != OK:
		_set_status("Не удалось собрать PackedScene. Код ошибки: %d" % pack_error, true)
		return false

	var scene_path := ObjectLibraryService.get_scene_path(_working_definition.object_id)
	var save_error := ResourceSaver.save(packed_scene, scene_path)
	if save_error != OK:
		_set_status("Не удалось сохранить сцену. Код ошибки: %d" % save_error, true)
		return false

	_working_definition.scene = packed_scene
	_working_definition.scene_path = scene_path
	EditorInterface.get_resource_filesystem().scan()
	return true


func _on_open_scene_pressed() -> void:
	if _working_definition == null or _working_definition.scene_path.is_empty():
		return
	if FileAccess.file_exists(_working_definition.scene_path):
		EditorInterface.open_scene_from_path(_working_definition.scene_path)


func _set_status(message: String, is_error: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	if is_error:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	else:
		_status_label.remove_theme_color_override("font_color")
