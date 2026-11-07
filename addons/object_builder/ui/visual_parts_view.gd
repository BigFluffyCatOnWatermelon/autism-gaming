@tool
extends VBoxContainer
## Compact visual-parts list for the Object Builder canvas.

signal part_selected(path: NodePath)
signal visibility_changed(path: NodePath, visible: bool)
signal duplicate_requested(path: NodePath)
signal remove_requested(path: NodePath)

const ROW_HEIGHT := 44.0
const THUMB_SIZE := Vector2(34.0, 34.0)

var _scene_root: Node
var _parts: Array[Dictionary] = []
var _search_input: LineEdit
var _rows_host: VBoxContainer
var _scroll: ScrollContainer
var _status_label: Label
var _selected_path := NodePath("")
var _row_buttons: Array[Button] = []


func build() -> void:
	if _rows_host != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 5)

	var heading := Label.new()
	heading.text = "ЧАСТИ ОБЪЕКТА"
	heading.add_theme_font_size_override("font_size", 13)
	add_child(heading)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Найти часть…"
	_search_input.clear_button_enabled = true
	_search_input.text_changed.connect(_on_search_changed)
	add_child(_search_input)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 132)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_rows_host = VBoxContainer.new()
	_rows_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_host.add_theme_constant_override("separation", 3)
	_scroll.add_child(_rows_host)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 10)
	add_child(_status_label)
	_render_rows()


func set_scene_root(scene_root: Node, selected_path: NodePath = NodePath("")) -> void:
	_scene_root = scene_root
	_selected_path = selected_path
	_parts.clear()
	if scene_root != null and is_instance_valid(scene_root):
		for child in scene_root.get_children():
			_collect_visual_parts(child, scene_root)
	_render_rows()


func set_selected_path(path: NodePath) -> void:
	_selected_path = path
	_update_row_selection()


func get_part_count() -> int:
	return _parts.size()


func get_part_paths() -> Array[NodePath]:
	var result: Array[NodePath] = []
	for entry in _parts:
		result.append(entry.get("path", NodePath("")))
	return result


func _collect_visual_parts(node: Node, scene_root: Node) -> void:
	if node is Sprite2D or node is AnimatedSprite2D or node is Polygon2D or node is Line2D:
		var texture: Texture2D
		if node is Sprite2D:
			texture = (node as Sprite2D).texture
		elif node is AnimatedSprite2D:
			var animated := node as AnimatedSprite2D
			if animated.sprite_frames != null:
				var frame_count := animated.sprite_frames.get_frame_count(animated.animation)
				if frame_count > 0:
					var frame_index := clampi(animated.frame, 0, frame_count - 1)
					texture = animated.sprite_frames.get_frame_texture(animated.animation, frame_index)
		_parts.append({
			"path": scene_root.get_path_to(node),
			"name": str(node.name),
			"type": node.get_class(),
			"texture": texture,
			"visible": (node as CanvasItem).visible
		})
	for child in node.get_children():
		_collect_visual_parts(child, scene_root)


func _render_rows() -> void:
	if _rows_host == null:
		return
	for child in _rows_host.get_children():
		_rows_host.remove_child(child)
		child.queue_free()
	_row_buttons.clear()

	if _scene_root == null or not is_instance_valid(_scene_root):
		_status_label.text = "Открой сцену объекта, чтобы управлять её частями."
		return

	var query := _search_input.text.strip_edges().to_lower()
	var visible_count := 0
	for entry in _parts:
		var part_name := str(entry.get("name", ""))
		var part_type := str(entry.get("type", ""))
		var part_path := str(entry.get("path", ""))
		var search_text := (part_name + " " + part_type + " " + part_path).to_lower()
		if not query.is_empty() and not search_text.contains(query):
			continue
		_add_part_row(entry)
		visible_count += 1

	if _parts.is_empty():
		_status_label.text = "В сцене пока нет визуальных частей. Добавь изображение или Sprite2D."
	elif visible_count == 0:
		_status_label.text = "По запросу ничего не найдено."
	else:
		_status_label.text = "Частей: %d" % _parts.size()


func _add_part_row(entry: Dictionary) -> void:
	var path: NodePath = entry.get("path", NodePath(""))
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_rows_host.add_child(row)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	row.add_child(content)

	var thumbnail_host := CenterContainer.new()
	thumbnail_host.custom_minimum_size = THUMB_SIZE
	content.add_child(thumbnail_host)
	var texture := entry.get("texture") as Texture2D
	if texture != null:
		var thumbnail := TextureRect.new()
		thumbnail.texture = texture
		thumbnail.custom_minimum_size = THUMB_SIZE
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumbnail_host.add_child(thumbnail)
	else:
		var placeholder := Label.new()
		placeholder.text = _get_type_glyph(str(entry.get("type", "")))
		placeholder.tooltip_text = str(entry.get("type", ""))
		thumbnail_host.add_child(placeholder)

	var name_button := Button.new()
	name_button.text = str(entry.get("name", ""))
	name_button.tooltip_text = "%s\n%s" % [entry.get("type", ""), path]
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.toggle_mode = true
	name_button.flat = true
	name_button.pressed.connect(_on_part_selected.bind(path))
	content.add_child(name_button)
	_row_buttons.append(name_button)

	var visibility := CheckBox.new()
	visibility.button_pressed = bool(entry.get("visible", true))
	visibility.tooltip_text = "Показывать эту часть"
	visibility.toggled.connect(_on_visibility_toggled.bind(path))
	content.add_child(visibility)

	var duplicate_button := Button.new()
	duplicate_button.text = "⧉"
	duplicate_button.tooltip_text = "Дублировать часть со всеми дочерними узлами"
	duplicate_button.pressed.connect(_on_duplicate_requested.bind(path))
	content.add_child(duplicate_button)

	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.tooltip_text = "Удалить часть (можно отменить через Undo)"
	remove_button.pressed.connect(_on_remove_requested.bind(path))
	content.add_child(remove_button)


func _get_type_glyph(type_name: String) -> String:
	match type_name:
		"Sprite2D":
			return "IMG"
		"AnimatedSprite2D":
			return "ANIM"
		"Polygon2D":
			return "POLY"
		"Line2D":
			return "LINE"
	return "NODE"


func _update_row_selection() -> void:
	if _rows_host == null:
		return
	var query := _search_input.text.strip_edges().to_lower()
	var row_index := 0
	for entry in _parts:
		var search_text := (
			str(entry.get("name", "")) + " "
			+ str(entry.get("type", "")) + " "
			+ str(entry.get("path", ""))
		).to_lower()
		if not query.is_empty() and not search_text.contains(query):
			continue
		if row_index < _row_buttons.size():
			var button := _row_buttons[row_index]
			button.set_pressed_no_signal(entry.get("path", NodePath("")) == _selected_path)
		row_index += 1


func _on_search_changed(_value: String) -> void:
	_render_rows()


func _on_part_selected(path: NodePath) -> void:
	_selected_path = path
	_update_row_selection()
	part_selected.emit(path)


func _on_visibility_toggled(visible: bool, path: NodePath) -> void:
	visibility_changed.emit(path, visible)


func _on_duplicate_requested(path: NodePath) -> void:
	duplicate_requested.emit(path)


func _on_remove_requested(path: NodePath) -> void:
	remove_requested.emit(path)
