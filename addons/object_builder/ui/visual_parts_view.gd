@tool
extends VBoxContainer
## Compact visual-parts list for the Object Builder canvas.

signal part_selected(path: NodePath)
signal part_visibility_changed(path: NodePath, visible: bool)
signal duplicate_requested(path: NodePath)
signal remove_requested(path: NodePath)
signal visibility_batch_requested(visible: bool)
signal part_lock_changed(path: NodePath, locked: bool)
signal draw_order_change_requested(path: NodePath, delta: int)
signal rename_requested(path: NodePath, new_name: String)
signal resource_edit_requested(path: NodePath)
signal sprite_frames_editor_requested(path: NodePath)
signal draw_order_reorder_requested(source_path: NodePath, target_path: NodePath)

const VisualPartRowScript = preload("res://addons/object_builder/ui/visual_part_row.gd")
const VisualPartDragHandleScript = preload("res://addons/object_builder/ui/visual_part_drag_handle.gd")

const ROW_HEIGHT := 44.0
const THUMB_SIZE := Vector2(34.0, 34.0)

var _scene_root: Node
var _parts: Array[Dictionary] = []
var _search_input: LineEdit
var _rows_host: VBoxContainer
var _scroll: ScrollContainer
var _status_label: Label
var _resource_button: Button
var _frames_editor_button: Button
var _selected_path := NodePath("")
var _row_buttons: Array[Button] = []
var _row_paths: Array[NodePath] = []
var _row_lock_checkboxes: Array[CheckBox] = []
var _row_name_buttons: Array[Button] = []
var _row_name_edits: Array[LineEdit] = []
var _locked_paths: Dictionary = {}
var _renaming_path := NodePath("")
var _renaming_button: Button
var _renaming_edit: LineEdit


func build() -> void:
	if _rows_host != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 5)

	var heading_row := HBoxContainer.new()
	add_child(heading_row)
	var heading := Label.new()
	heading.text = "ЧАСТИ ОБЪЕКТА"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 13)
	heading_row.add_child(heading)
	var show_all_button := Button.new()
	show_all_button.text = "Показать"
	show_all_button.tooltip_text = "Сделать видимыми все визуальные части"
	show_all_button.pressed.connect(_on_show_all_pressed)
	heading_row.add_child(show_all_button)
	var hide_all_button := Button.new()
	hide_all_button.text = "Скрыть"
	hide_all_button.tooltip_text = "Скрыть все визуальные части"
	hide_all_button.pressed.connect(_on_hide_all_pressed)
	heading_row.add_child(hide_all_button)
	_resource_button = Button.new()
	_resource_button.text = "Ресурс…"
	_resource_button.tooltip_text = "Изменить текстуру или набор кадров выбранной части"
	_resource_button.disabled = true
	_resource_button.pressed.connect(_on_resource_edit_pressed)
	heading_row.add_child(_resource_button)
	_frames_editor_button = Button.new()
	_frames_editor_button.text = "Анимации…"
	_frames_editor_button.tooltip_text = "Создать и редактировать анимации, кадры, FPS и зацикливание."
	_frames_editor_button.disabled = true
	_frames_editor_button.pressed.connect(_on_frames_editor_pressed)
	heading_row.add_child(_frames_editor_button)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Найти часть…"
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
	_update_resource_button()


func set_selected_path(path: NodePath) -> void:
	_selected_path = path
	_update_row_selection()
	_update_resource_button()


func request_inline_rename(path: NodePath) -> bool:
	if path.is_empty() or path == NodePath("."):
		return false
	var row_index := _row_paths.find(path)
	if row_index < 0:
		var part_exists := false
		for entry in _parts:
			if entry.get("path", NodePath("")) == path:
				part_exists = true
				break
		if not part_exists:
			return false
		_search_input.clear()
		_render_rows()
		row_index = _row_paths.find(path)
	if row_index < 0 or row_index >= _row_name_buttons.size() or row_index >= _row_name_edits.size():
		return false
	_begin_inline_rename(path, _row_name_buttons[row_index], _row_name_edits[row_index])
	return true

func set_locked_paths(paths: Array[NodePath]) -> void:
	_locked_paths.clear()
	for path in paths:
		_locked_paths[path] = true
	_update_row_locks()


func _update_resource_button() -> void:
	if _resource_button == null:
		return
	var selected_node := _scene_root.get_node_or_null(_selected_path) if _scene_root != null and not _selected_path.is_empty() else null
	_resource_button.disabled = not (selected_node is Sprite2D or selected_node is AnimatedSprite2D)
	_frames_editor_button.disabled = not (selected_node is AnimatedSprite2D)
	if selected_node is AnimatedSprite2D:
		_resource_button.text = "Кадры…"
	else:
		_resource_button.text = "Текстура…"


func _on_resource_edit_pressed() -> void:
	if not _resource_button.disabled and not _selected_path.is_empty():
		resource_edit_requested.emit(_selected_path)


func _on_frames_editor_pressed() -> void:
	if not _frames_editor_button.disabled and not _selected_path.is_empty():
		sprite_frames_editor_requested.emit(_selected_path)


func get_locked_paths() -> Array[NodePath]:
	var result: Array[NodePath] = []
	for path in _locked_paths:
		result.append(path)
	return result


func get_part_count() -> int:
	return _parts.size()


func get_visible_row_count() -> int:
	return _row_buttons.size()


func get_selected_path() -> NodePath:
	return _selected_path


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
			"parent_path": scene_root.get_path_to(node.get_parent()),
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
	_cancel_inline_rename()
	for child in _rows_host.get_children():
		child.free()
	_row_buttons.clear()
	_row_paths.clear()
	_row_lock_checkboxes.clear()
	_row_name_buttons.clear()
	_row_name_edits.clear()

	if _scene_root == null or not is_instance_valid(_scene_root):
		_status_label.text = "Открой сцену объекта, чтобы управлять её частями."
		_update_resource_button()
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
	var row = VisualPartRowScript.new()
	row.part_path = path
	row.parent_path = entry.get("parent_path", NodePath(""))
	row.connect("reorder_requested", Callable(self, "_on_row_reorder_requested"))
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_rows_host.add_child(row)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	row.add_child(content)

	var drag_handle = VisualPartDragHandleScript.new()
	drag_handle.text = "⋮⋮"
	drag_handle.tooltip_text = "Перетащить часть и изменить порядок отрисовки"
	drag_handle.part_path = path
	drag_handle.parent_path = entry.get("parent_path", NodePath(""))
	content.add_child(drag_handle)

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
	_row_paths.append(path)
	_row_name_buttons.append(name_button)

	var name_edit := LineEdit.new()
	name_edit.text = str(entry.get("name", ""))
	name_edit.visible = false
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(_on_inline_rename_submitted.bind(path))
	name_edit.focus_exited.connect(_on_inline_rename_focus_exited.bind(path))
	name_edit.gui_input.connect(_on_inline_rename_gui_input.bind(path))
	content.add_child(name_edit)
	_row_name_edits.append(name_edit)

	var rename_button := Button.new()
	rename_button.text = "✎"
	rename_button.tooltip_text = "Переименовать часть"
	rename_button.pressed.connect(_begin_inline_rename.bind(path, name_button, name_edit))
	content.add_child(rename_button)

	var locked := CheckBox.new()
	locked.button_pressed = _locked_paths.has(path)
	locked.tooltip_text = "Зафиксировать часть на холсте"
	locked.toggled.connect(_on_lock_toggled.bind(path))
	content.add_child(locked)
	_row_lock_checkboxes.append(locked)

	var visibility := CheckBox.new()
	visibility.button_pressed = bool(entry.get("visible", true))
	visibility.tooltip_text = "Показывать эту часть"
	visibility.toggled.connect(_on_visibility_toggled.bind(path))
	content.add_child(visibility)

	var raise_button := Button.new()
	raise_button.text = "↑"
	raise_button.tooltip_text = "Переместить часть выше в порядке отрисовки"
	raise_button.pressed.connect(_on_draw_order_change_requested.bind(path, 1))
	content.add_child(raise_button)
	var lower_button := Button.new()
	lower_button.text = "↓"
	lower_button.tooltip_text = "Переместить часть ниже в порядке отрисовки"
	lower_button.pressed.connect(_on_draw_order_change_requested.bind(path, -1))
	content.add_child(lower_button)

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
	_set_child_mouse_filter_recursive(content, Control.MOUSE_FILTER_PASS)
	drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP


func _set_child_mouse_filter_recursive(control: Control, filter: Control.MouseFilter) -> void:
	for child in control.get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
			_set_child_mouse_filter_recursive(child as Control, filter)


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


func _update_row_locks() -> void:
	for index in range(_row_paths.size()):
		if index < _row_lock_checkboxes.size():
			_row_lock_checkboxes[index].set_pressed_no_signal(_locked_paths.has(_row_paths[index]))


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
	part_visibility_changed.emit(path, visible)


func _on_duplicate_requested(path: NodePath) -> void:
	duplicate_requested.emit(path)


func _on_remove_requested(path: NodePath) -> void:
	remove_requested.emit(path)


func _begin_inline_rename(path: NodePath, name_button: Button, name_edit: LineEdit) -> void:
	_cancel_inline_rename()
	if name_button == null or name_edit == null:
		return
	_renaming_path = path
	_renaming_button = name_button
	_renaming_edit = name_edit
	_renaming_button.hide()
	_renaming_edit.show()
	_renaming_edit.text = _renaming_button.text
	_renaming_edit.grab_focus()
	_renaming_edit.select_all()


func _on_inline_rename_submitted(_value: String, path: NodePath) -> void:
	_commit_inline_rename(path)


func _on_inline_rename_focus_exited(path: NodePath) -> void:
	_commit_inline_rename(path)


func _on_inline_rename_gui_input(event: InputEvent, path: NodePath) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			var edit := _renaming_edit
			_cancel_inline_rename()
			if edit != null:
				edit.accept_event()


func _commit_inline_rename(path: NodePath) -> void:
	if path != _renaming_path or _renaming_edit == null or _renaming_button == null:
		return
	var clean_name := _renaming_edit.text.strip_edges()
	var previous_name := _renaming_button.text
	var name_button := _renaming_button
	var name_edit := _renaming_edit
	_finish_inline_rename()
	if is_instance_valid(name_button):
		name_button.show()
	if is_instance_valid(name_edit):
		name_edit.hide()
	if clean_name.is_empty() or clean_name == previous_name:
		return
	rename_requested.emit(path, clean_name)


func _cancel_inline_rename() -> void:
	var name_button := _renaming_button
	var name_edit := _renaming_edit
	_finish_inline_rename()
	if name_button != null and is_instance_valid(name_button):
		name_button.show()
	if name_edit != null and is_instance_valid(name_edit):
		name_edit.hide()


func _finish_inline_rename() -> void:
	_renaming_path = NodePath("")
	_renaming_button = null
	_renaming_edit = null


func _on_row_reorder_requested(source_path: NodePath, target_path: NodePath) -> void:
	if source_path.is_empty() or target_path.is_empty() or source_path == target_path:
		return
	draw_order_reorder_requested.emit(source_path, target_path)


func _on_draw_order_change_requested(path: NodePath, delta: int) -> void:
	if delta == 0:
		return
	draw_order_change_requested.emit(path, clampi(delta, -1, 1))


func _on_lock_toggled(locked: bool, path: NodePath) -> void:
	if locked:
		_locked_paths[path] = true
	else:
		_locked_paths.erase(path)
	part_lock_changed.emit(path, locked)


func _on_show_all_pressed() -> void:
	visibility_batch_requested.emit(true)


func _on_hide_all_pressed() -> void:
	visibility_batch_requested.emit(false)
