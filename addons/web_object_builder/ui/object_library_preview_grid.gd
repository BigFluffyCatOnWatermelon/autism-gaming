@tool
extends ItemList
class_name WebObjectBuilderLibraryPreviewGrid

signal object_activated(object_id: String)

const ObjectLibraryService = preload("res://scripts/object_system/object_library_service.gd")
const LibraryDragService = preload("res://addons/web_object_builder/services/library_drag_service.gd")

var _generation := 0


func _ready() -> void:
	icon_mode = ItemList.ICON_MODE_TOP
	set_preview_size(104)
	max_text_lines = 2
	same_column_width = true
	allow_reselect = true
	select_mode = ItemList.SELECT_SINGLE
	auto_height = false
	item_activated.connect(_on_item_activated)


func set_preview_size(size: int) -> void:
	var normalized := clampi(size, 64, 256)
	if normalized % 8 != 0:
		normalized = clampi(roundi(float(normalized) / 8.0) * 8, 64, 256)
	fixed_icon_size = Vector2i(normalized, normalized)


func get_preview_size() -> int:
	return fixed_icon_size.x


func set_objects(objects: Array[ObjectDefinition]) -> void:
	_generation += 1
	var request_generation := _generation
	clear()

	var fallback_icon := EditorInterface.get_editor_theme().get_icon("PackedScene", "EditorIcons")
	for definition in objects:
		if definition == null or definition.is_template:
			continue
		var initial_icon: Texture2D = (
			definition.preview_texture
			if definition.preview_texture != null
			else fallback_icon
		)
		add_item(definition.display_name, initial_icon)
		var item_index := get_item_count() - 1
		set_item_metadata(item_index, definition.object_id)
		set_item_tooltip(
			item_index,
			"%s\n%s" % [definition.display_name, definition.scene_path]
		)

		if definition.scene_path.is_empty() or not FileAccess.file_exists(definition.scene_path):
			continue
		EditorInterface.get_resource_previewer().queue_resource_preview(
			definition.scene_path,
			self,
			"_on_scene_preview_ready",
			{
				"object_id": definition.object_id,
				"generation": request_generation
			}
		)


func get_selected_object_id() -> String:
	var selected_items := get_selected_items()
	if selected_items.is_empty():
		return ""
	var metadata: Variant = get_item_metadata(selected_items[0])
	return str(metadata) if metadata is String else ""


func _on_item_activated(index: int) -> void:
	if index < 0 or index >= get_item_count():
		return
	var metadata: Variant = get_item_metadata(index)
	if metadata is String and not str(metadata).is_empty():
		object_activated.emit(str(metadata))


func _on_scene_preview_ready(
	path: String,
	preview: Texture2D,
	thumbnail_preview: Texture2D,
	user_data: Variant
) -> void:
	if not user_data is Dictionary:
		return
	var request: Dictionary = user_data
	if int(request.get("generation", -1)) != _generation:
		return
	var object_id := str(request.get("object_id", ""))
	if object_id.is_empty():
		return
	var texture := preview if preview != null else thumbnail_preview
	if texture == null:
		return

	for index in range(get_item_count()):
		if str(get_item_metadata(index)) != object_id:
			continue
		set_item_icon(index, texture)
		set_item_tooltip(index, "%s\n%s" % [get_item_text(index), path])
		return


func _get_drag_data(at_position: Vector2) -> Variant:
	var item_index := get_item_at_position(at_position, true)
	if item_index < 0:
		return null
	var metadata: Variant = get_item_metadata(item_index)
	if not metadata is String or str(metadata).is_empty():
		return null
	var definition := ObjectLibraryService.load_definition(str(metadata))
	if definition == null:
		return null

	var scene_path := LibraryDragService.get_scene_path(definition)
	if scene_path.is_empty():
		return null

	var preview := VBoxContainer.new()
	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(84.0, 84.0)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture = get_item_icon(item_index)
	preview.add_child(texture_rect)
	var name_label := Label.new()
	name_label.text = definition.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(name_label)
	set_drag_preview(preview)

	# Same payload consumed by Godot's 2D/3D editor viewport and Scene Palette.
	return {
		"type": "files",
		"files": [scene_path],
		"from": ""
	}
