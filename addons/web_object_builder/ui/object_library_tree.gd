@tool
extends Tree
class_name WebObjectBuilderLibraryTree

const ObjectLibraryService = preload("res://scripts/object_system/object_library_service.gd")
const LibraryDragService = preload("res://addons/web_object_builder/services/library_drag_service.gd")

signal object_activated(object_id: String)

var _objects_by_id: Dictionary = {}


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


func set_objects(objects: Array[ObjectDefinition]) -> void:
	_objects_by_id.clear()
	clear()
	hide_root = true
	var root := create_item()
	var grouped: Dictionary = {}
	for definition in objects:
		if definition == null or definition.is_template:
			continue
		var category := definition.category.strip_edges()
		if category.is_empty():
			category = "Без категории"
		if not grouped.has(category):
			grouped[category] = []
		var category_objects: Array = grouped[category]
		category_objects.append(definition)
		grouped[category] = category_objects
		_objects_by_id[definition.object_id] = definition
	var category_names: Array = grouped.keys()
	category_names.sort_custom(func(a: String, b: String) -> bool:
		return a.naturalnocasecmp_to(b) < 0
	)
	for category in category_names:
		var category_item := create_item(root)
		category_item.set_text(0, _category_display_name(str(category)))
		category_item.set_selectable(0, false)
		category_item.set_custom_color(0, Color(0.67, 0.77, 0.86))
		var category_objects: Array = grouped[category]
		category_objects.sort_custom(func(a: ObjectDefinition, b: ObjectDefinition) -> bool:
			return a.display_name.naturalnocasecmp_to(b.display_name) < 0
		)
		for definition in category_objects:
			var item := create_item(category_item)
			item.set_text(0, definition.display_name)
			item.set_icon(0, EditorInterface.get_editor_theme().get_icon("PackedScene", "EditorIcons"))
			item.set_tooltip_text(0, "%s\n%s" % [definition.display_name, definition.scene_path])
			item.set_metadata(0, definition.object_id)
			item.set_selectable(0, true)
			item.set_editable(0, false)
		category_item.collapsed = false
	if get_root() != null and get_root().get_child_count() == 0:
		var empty_item := create_item(root)
		empty_item.set_text(0, "Пока нет сохранённых объектов")
		empty_item.set_selectable(0, false)


func get_selected_object_id() -> String:
	var selected := get_selected()
	if selected == null:
		return ""
	var metadata: Variant = selected.get_metadata(0)
	return str(metadata) if metadata is String else ""


func _get_drag_data(at_position: Vector2) -> Variant:
	var item := get_item_at_position(at_position)
	if item == null:
		return null
	var metadata: Variant = item.get_metadata(0)
	if not metadata is String or str(metadata).is_empty():
		return null
	var object_id := str(metadata)
	var definition := ObjectLibraryService.load_definition(object_id)
	if definition == null:
		push_warning("Object Builder: объект для перетаскивания больше не существует: " + object_id)
		return null

	var scene_path := LibraryDragService.get_scene_path(definition)
	if scene_path.is_empty():
		return null

	var preview := HBoxContainer.new()
	var preview_texture := TextureRect.new()
	preview_texture.custom_minimum_size = Vector2(48.0, 48.0)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if definition.preview_texture != null:
		preview_texture.texture = definition.preview_texture
	preview.add_child(preview_texture)
	var preview_label := Label.new()
	preview_label.text = definition.display_name
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(preview_label)
	set_drag_preview(preview)

	# Match Scene Palette's native editor file-drop payload exactly.
	return {
		"type": "files",
		"files": [scene_path],
		"from": ""
	}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		var selected_id := get_selected_object_id()
		if not selected_id.is_empty():
			object_activated.emit(selected_id)
