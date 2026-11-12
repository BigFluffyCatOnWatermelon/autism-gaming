@tool
extends VBoxContainer
class_name WebObjectBuilderLibraryDock

signal open_object_requested(object_id: String)
signal scene_path_selected_requested(scene_path: String)
signal refresh_requested

const ObjectLibraryTreeScript = preload("res://addons/web_object_builder/ui/object_library_tree.gd")
const ObjectLibraryPreviewGridScript = preload("res://addons/web_object_builder/ui/object_library_preview_grid.gd")
const ObjectLibraryService = preload("res://scripts/object_system/object_library_service.gd")
const SceneDraftService = preload("res://addons/web_object_builder/services/scene_draft_service.gd")

var _search: LineEdit
var _category: OptionButton
var _preview_size_spin: SpinBox
var _tree: Tree
var _preview_grid: Variant
var _list_mode_button: Button
var _preview_mode_button: Button
var _refresh_button: Button
var _view_mode := "list"
var _open_button: Button
var _locate_button: Button
var _definitions: Array[ObjectDefinition] = []
var _built := false


func build() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(220, 180)

	var header := HBoxContainer.new()
	add_child(header)
	var title := Label.new()
	title.text = "Объекты проекта"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	_list_mode_button = Button.new()
	_list_mode_button.text = "Список"
	_list_mode_button.tooltip_text = "Показывать объекты деревом"
	_list_mode_button.toggle_mode = true
	_list_mode_button.button_pressed = true
	_list_mode_button.pressed.connect(func() -> void:
		_set_view_mode("list")
	)
	header.add_child(_list_mode_button)

	_preview_mode_button = Button.new()
	_preview_mode_button.text = "Превью"
	_preview_mode_button.tooltip_text = "Показывать миниатюры сцен"
	_preview_mode_button.toggle_mode = true
	_preview_mode_button.pressed.connect(func() -> void:
		_set_view_mode("preview")
	)
	header.add_child(_preview_mode_button)

	_refresh_button = Button.new()
	_refresh_button.text = "↻"
	_refresh_button.tooltip_text = "Обновить список объектов"
	_refresh_button.pressed.connect(func() -> void:
		refresh_requested.emit()
	)
	header.add_child(_refresh_button)

	_search = LineEdit.new()
	_search.placeholder_text = "Поиск по названию…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_refresh_tree)
	add_child(_search)

	_category = OptionButton.new()
	_category.item_selected.connect(func(_index: int) -> void:
		_refresh_tree()
	)
	add_child(_category)

	var preview_size_row := HBoxContainer.new()
	var preview_size_label := Label.new()
	preview_size_label.text = "Размер превью"
	preview_size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_size_row.add_child(preview_size_label)
	_preview_size_spin = SpinBox.new()
	_preview_size_spin.min_value = 64
	_preview_size_spin.max_value = 256
	_preview_size_spin.step = 8
	_preview_size_spin.value = _get_saved_preview_size()
	_preview_size_spin.custom_minimum_size = Vector2(76.0, 0.0)
	_preview_size_spin.tooltip_text = "Размер квадратной миниатюры в режиме «Превью», 64–256 px"
	_preview_size_spin.value_changed.connect(_on_preview_size_changed)
	preview_size_row.add_child(_preview_size_spin)
	add_child(preview_size_row)

	_tree = ObjectLibraryTreeScript.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.object_activated.connect(_on_tree_object_activated)
	_tree.item_selected.connect(_update_action_buttons)
	add_child(_tree)

	_preview_grid = ObjectLibraryPreviewGridScript.new()
	_preview_grid.set_preview_size(roundi(_preview_size_spin.value))
	_preview_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_grid.object_activated.connect(_on_tree_object_activated)
	_preview_grid.item_selected.connect(_update_action_buttons)
	_preview_grid.hide()
	add_child(_preview_grid)

	var note := Label.new()
	note.text = "Перетащи объект на 2D-холст, чтобы добавить его в сцену."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.63, 0.70, 0.77))
	note.add_theme_font_size_override("font_size", 10)
	add_child(note)

	_open_button = Button.new()
	_open_button.text = "Открыть в Web Object Builder"
	_open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_button.disabled = true
	_open_button.pressed.connect(_open_selected)
	add_child(_open_button)

	_locate_button = Button.new()
	_locate_button.text = "Показать сцену в файловой системе"
	_locate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_locate_button.disabled = true
	_locate_button.pressed.connect(_locate_selected)
	add_child(_locate_button)
	_rebuild_category_options()
	_refresh_tree()


func _get_saved_preview_size() -> int:
	var settings := EditorInterface.get_editor_settings()
	return clampi(int(settings.get_project_metadata("ObjectBuilder", "library_preview_icon_size", 104)), 64, 256)


func _on_preview_size_changed(value: float) -> void:
	var normalized := clampi(roundi(value / 8.0) * 8, 64, 256)
	EditorInterface.get_editor_settings().set_project_metadata(
		"ObjectBuilder", "library_preview_icon_size", normalized
	)
	if _preview_grid != null:
		_preview_grid.set_preview_size(normalized)


func set_refreshing(refreshing: bool) -> void:
	if _refresh_button == null or not is_instance_valid(_refresh_button):
		return
	_refresh_button.disabled = refreshing
	_refresh_button.text = "…" if refreshing else "↻"
	_refresh_button.tooltip_text = (
		"Обновление библиотеки…" if refreshing else "Обновить список объектов"
	)


func set_definitions(definitions: Array[ObjectDefinition]) -> void:
	_definitions.clear()
	for definition in definitions:
		if definition != null and not definition.is_template:
			_definitions.append(definition)
	if not _built:
		build()
	_rebuild_category_options()
	_refresh_tree()


func _rebuild_category_options() -> void:
	if _category == null:
		return
	var previous := str(_category.get_item_metadata(_category.selected)) if _category.item_count > 0 else ""
	var names := PackedStringArray()
	for definition in _definitions:
		if definition != null and not definition.category.strip_edges().is_empty() and not names.has(definition.category):
			names.append(definition.category)
	names.sort()
	_category.clear()
	_category.add_item("Все категории")
	_category.set_item_metadata(0, "")
	for category_name in names:
		_category.add_item(_category_display_name(category_name))
		_category.set_item_metadata(_category.item_count - 1, category_name)
	var selected_index := 0
	for index in range(_category.item_count):
		if str(_category.get_item_metadata(index)) == previous:
			selected_index = index
			break
	_category.select(selected_index)


func _category_display_name(category_id: String) -> String:
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
		"Other": "Другое",
		"Environment": "Окружение",
		"Resources": "Ресурсы",
		"Weapons": "Оружие",
		"Tools": "Инструменты",
		"NPC": "Персонажи"
	}
	return str(CATEGORY_LABELS.get(category_id, category_id))


func _refresh_tree(_value: String = "") -> void:
	if _tree == null:
		return
	var search_text := _search.text.strip_edges().to_lower() if _search != null else ""
	var selected_category := str(_category.get_item_metadata(_category.selected)) if _category != null and _category.item_count > 0 else ""
	var filtered: Array[ObjectDefinition] = []
	for definition in _definitions:
		if definition == null:
			continue
		if not selected_category.is_empty() and definition.category != selected_category:
			continue
		if not search_text.is_empty():
			var tag_text := ""
			for tag in definition.tags:
				tag_text += " " + str(tag)
			var search_source := (definition.display_name + " " + definition.category + tag_text).to_lower()
			if not search_source.contains(search_text):
				continue
		filtered.append(definition)
	_tree.set_objects(filtered)
	if _preview_grid != null:
		_preview_grid.set_objects(filtered)
	_update_action_buttons()


func _set_view_mode(mode: String) -> void:
	_view_mode = "preview" if mode == "preview" else "list"
	if _tree != null:
		_tree.visible = _view_mode == "list"
	if _preview_grid != null:
		_preview_grid.visible = _view_mode == "preview"
	if _list_mode_button != null:
		_list_mode_button.button_pressed = _view_mode == "list"
	if _preview_mode_button != null:
		_preview_mode_button.button_pressed = _view_mode == "preview"
	_update_action_buttons()


func _get_selected_object_id() -> String:
	if _view_mode == "preview" and _preview_grid != null:
		return _preview_grid.get_selected_object_id()
	if _tree != null:
		return _tree.get_selected_object_id()
	return ""


func _on_tree_object_activated(object_id: String) -> void:
	if not object_id.is_empty():
		open_object_requested.emit(object_id)


func _update_action_buttons(_selected: Variant = null) -> void:
	var selected_id: String = _get_selected_object_id()
	var enabled: bool = not selected_id.is_empty()
	if _open_button != null:
		_open_button.disabled = not enabled
	if _locate_button != null:
		_locate_button.disabled = not enabled


func _open_selected() -> void:
	var selected_id: String = _get_selected_object_id()
	if not selected_id.is_empty():
		open_object_requested.emit(selected_id)


func _locate_selected() -> void:
	var selected_id: String = _get_selected_object_id()
	if selected_id.is_empty():
		return
	var definition := ObjectLibraryService.load_definition(selected_id)
	if definition == null:
		return
	var expected_path := ObjectLibraryService.get_scene_path_for_definition(definition)
	if definition.scene_path != expected_path or not FileAccess.file_exists(expected_path):
		var previous_scene_path := definition.scene_path
		var previous_scene_bytes := (
			FileAccess.get_file_as_bytes(previous_scene_path)
			if not previous_scene_path.is_empty() and FileAccess.file_exists(previous_scene_path)
			else PackedByteArray()
		)
		var scene_result := SceneDraftService.sync_scene(definition)
		if not bool(scene_result.get("ok", false)):
			push_warning("Object Builder: не удалось подготовить сцену: " + str(scene_result.get("message", "")))
			return
		var save_error := ObjectLibraryService.save_definition(definition)
		if save_error != OK:
			ObjectLibraryService.remove_scene_if_unreferenced(definition.scene_path, definition.object_id)
			if not previous_scene_path.is_empty() and not previous_scene_bytes.is_empty():
				var restore_file := FileAccess.open(previous_scene_path, FileAccess.WRITE)
				if restore_file != null:
					restore_file.store_buffer(previous_scene_bytes)
					restore_file.close()
			definition.scene_path = previous_scene_path
			definition.scene = (
				ResourceLoader.load(previous_scene_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
				if not previous_scene_path.is_empty() and FileAccess.file_exists(previous_scene_path)
				else null
			)
			push_warning("Object Builder: не удалось сохранить новый путь сцены: %d" % save_error)
			return
		EditorInterface.get_resource_filesystem().scan()
	if not definition.scene_path.is_empty():
		scene_path_selected_requested.emit(definition.scene_path)
