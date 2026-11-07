@tool
extends VBoxContainer
## Interactive 2D canvas for the current Object Builder scene.

const CanvasGridScript = preload("res://addons/object_builder/ui/canvas_grid.gd")
const CanvasOverlayScript = preload("res://addons/object_builder/ui/canvas_overlay.gd")
const CanvasGeometry = preload("res://addons/object_builder/ui/canvas_geometry.gd")
## The canvas edits an isolated preview copy; committed values are applied to the real scene by the plugin.

signal part_selected(path: NodePath)
signal transform_committed(path: NodePath, property_name: String, new_value: Variant, old_value: Variant)
signal open_scene_requested

const MIN_ZOOM := 0.08
const MAX_ZOOM := 8.0
const ZOOM_FACTOR := 1.2
const GRID_STEP := 32.0
const SNAP_STEP := 8.0



var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _surface: Control
var _stage: Node2D
var _grid: Node2D
var _camera: Camera2D
var _preview_instance: Node
var _selected_path := NodePath("")
var _zoom := 1.0
var _grid_enabled := true
var _snap_enabled := true
var _editing_enabled := false
var _drag_node: Node2D
var _drag_path := NodePath("")
var _drag_old_position := Vector2.ZERO
var _drag_old_scale := Vector2.ONE
var _drag_old_rotation := 0.0
var _drag_start_vector := Vector2.ZERO
var _drag_start_angle := 0.0
var _drag_mode := "move"
var _drag_start_parent_position := Vector2.ZERO
var _pan_active := false
var _left_pan_active := false
var _last_mouse_position := Vector2.ZERO
var _status_label: Label
var _zoom_label: Label
var _grid_button: Button
var _snap_button: CheckBox
var _open_scene_button: Button


func build() -> void:
	if _viewport != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 300)
	add_theme_constant_override("separation", 5)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	add_child(toolbar)
	var heading := Label.new()
	heading.text = "ХОЛСТ ОБЪЕКТА"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(heading)

	_add_toolbar_button(toolbar, "−", "Уменьшить масштаб", _on_zoom_out_pressed)
	_zoom_label = Label.new()
	_zoom_label.custom_minimum_size = Vector2(48, 0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(_zoom_label)
	_add_toolbar_button(toolbar, "+", "Увеличить масштаб", _on_zoom_in_pressed)
	_add_toolbar_button(toolbar, "Вписать", "Показать объект целиком", _fit_canvas)
	_add_toolbar_button(toolbar, "Центр", "Вернуть камеру к началу координат", _center_canvas)

	_grid_button = Button.new()
	_grid_button.text = "Сетка"
	_grid_button.toggle_mode = true
	_grid_button.button_pressed = true
	_grid_button.toggled.connect(_on_grid_toggled)
	toolbar.add_child(_grid_button)

	_snap_button = CheckBox.new()
	_snap_button.text = "Привязка"
	_snap_button.button_pressed = true
	_snap_button.tooltip_text = "Перемещать части шагом 8 пикселей"
	_snap_button.toggled.connect(_on_snap_toggled)
	toolbar.add_child(_snap_button)

	_open_scene_button = Button.new()
	_open_scene_button.text = "Открыть сцену"
	_open_scene_button.tooltip_text = "Открыть сцену в редакторе Godot, чтобы включить редактирование на холсте"
	_open_scene_button.pressed.connect(_on_open_scene_pressed)
	toolbar.add_child(_open_scene_button)

	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.custom_minimum_size = Vector2(0, 220)
	add_child(canvas_panel)

	var surface_host := Control.new()
	surface_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_child(surface_host)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.stretch = false
	surface_host.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)

	_stage = Node2D.new()
	_viewport.add_child(_stage)
	_grid = CanvasGridScript.new()
	_grid.z_index = -4096
	_grid.z_as_relative = false
	_stage.add_child(_grid)

	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	_stage.add_child(_camera)
	_camera.call_deferred("make_current")

	_surface = CanvasOverlayScript.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	_surface.focus_mode = Control.FOCUS_ALL
	_surface.set("canvas_owner", self)
	_surface.resized.connect(_on_surface_resized)
	surface_host.add_child(_surface)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Выбери объект в библиотеке, чтобы показать его части."
	add_child(_status_label)
	_set_zoom(1.0)
	call_deferred("_on_surface_resized")


func _add_toolbar_button(
	toolbar: HBoxContainer,
	button_text: String,
	tooltip: String,
	action: Callable
) -> Button:
	var button := Button.new()
	button.text = button_text
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	toolbar.add_child(button)
	return button


func set_preview_instance(
	instance: Node,
	editing_enabled: bool,
	can_open_scene: bool,
	selected_path: NodePath = NodePath("")
) -> void:
	if _viewport == null:
		return
	_clear_preview()
	if instance == null or not is_instance_valid(instance):
		clear_canvas("Не удалось собрать предпросмотр сцены.")
		return
	_preview_instance = instance
	_disable_preview_processing(_preview_instance)
	_stage.add_child(_preview_instance)
	_editing_enabled = editing_enabled
	_selected_path = selected_path
	_open_scene_button.disabled = not can_open_scene
	_open_scene_button.visible = not editing_enabled
	if editing_enabled:
		_status_label.text = "Выбирай части щелчком и перемещай перетаскиванием. Средняя кнопка или пробел + ЛКМ — панорамирование."
	else:
		_status_label.text = "Предпросмотр. Чтобы редактировать части, открой сцену объекта кнопкой справа."
	call_deferred("_fit_canvas")
	_surface.queue_redraw()


func clear_canvas(message: String) -> void:
	_clear_preview()
	_editing_enabled = false
	_selected_path = NodePath("")
	_open_scene_button.disabled = true
	_open_scene_button.visible = false
	_status_label.text = message
	if _surface != null:
		_surface.queue_redraw()


func set_selected_path(path: NodePath) -> void:
	_selected_path = path
	if _surface != null:
		_surface.queue_redraw()


func _disable_preview_processing(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_disable_preview_processing(child)


func _clear_preview() -> void:
	_drag_node = null
	_drag_path = NodePath("")
	_drag_mode = "move"
	_pan_active = false
	_left_pan_active = false
	if _preview_instance != null and is_instance_valid(_preview_instance):
		var parent := _preview_instance.get_parent()
		if parent != null:
			parent.remove_child(_preview_instance)
		_preview_instance.free()
	_preview_instance = null


func _on_surface_resized() -> void:
	if _viewport == null or _surface == null:
		return
	var target_size := Vector2i(
		maxi(1, roundi(_surface.size.x)),
		maxi(1, roundi(_surface.size.y))
	)
	if _viewport.size != target_size:
		_viewport.size = target_size


func _on_grid_toggled(enabled: bool) -> void:
	_grid_enabled = enabled
	if _grid != null:
		_grid.set("grid_enabled", enabled)
		_grid.queue_redraw()


func _on_snap_toggled(enabled: bool) -> void:
	_snap_enabled = enabled


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom * ZOOM_FACTOR)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom / ZOOM_FACTOR)


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	if _camera != null:
		_camera.zoom = Vector2.ONE * _zoom
	if _zoom_label != null:
		_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)


func _center_canvas() -> void:
	if _camera == null:
		return
	if _preview_instance is Node2D:
		_camera.position = (_preview_instance as Node2D).global_position
	else:
		_camera.position = Vector2.ZERO


func _fit_canvas() -> void:
	if _camera == null or _preview_instance == null or not is_instance_valid(_preview_instance):
		_center_canvas()
		_set_zoom(1.0)
		return
	var bounds: Dictionary = CanvasGeometry.collect_visual_bounds(_preview_instance)
	if not bounds.has("rect"):
		_center_canvas()
		_set_zoom(1.0)
		return
	var rect: Rect2 = bounds["rect"]
	var available := Vector2(_viewport.size) * 0.78
	var object_size := Vector2(maxf(rect.size.x, 32.0), maxf(rect.size.y, 32.0))
	var fit_zoom := minf(available.x / object_size.x, available.y / object_size.y)
	_camera.position = rect.get_center()
	_set_zoom(clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM))




func _screen_to_world(screen_position: Vector2) -> Vector2:
	var surface_size := Vector2(maxf(_surface.size.x, 1.0), maxf(_surface.size.y, 1.0))
	var viewport_position := screen_position * Vector2(_viewport.size) / surface_size
	return _viewport.get_canvas_transform().affine_inverse() * viewport_position




func _get_selected_node() -> Node:
	if _preview_instance == null or not is_instance_valid(_preview_instance):
		return null
	if _selected_path.is_empty():
		return null
	if _selected_path == NodePath("."):
		return _preview_instance
	return _preview_instance.get_node_or_null(_selected_path)


func _get_transform_handle_positions() -> Dictionary:
	var corners: PackedVector2Array = CanvasGeometry.selected_screen_corners(_preview_instance, _selected_path, _viewport)
	return CanvasGeometry.get_transform_handle_positions(corners, _surface.size, Vector2(_viewport.size))


func _draw_selection(target: Control) -> void:
	var corners: PackedVector2Array = CanvasGeometry.selected_screen_corners(_preview_instance, _selected_path, _viewport)
	if corners.size() < 2:
		return
	var scale_to_surface := Vector2(
		target.size.x / maxf(_viewport.size.x, 1.0),
		target.size.y / maxf(_viewport.size.y, 1.0)
	)
	var surface_corners := PackedVector2Array()
	for point in corners:
		surface_corners.append(point * scale_to_surface)
	target.draw_polyline(surface_corners, Color(0.35, 0.85, 1.0, 0.95), 2.0, true)
	for index in range(surface_corners.size() - 1):
		target.draw_circle(surface_corners[index], 3.0, Color(0.35, 0.85, 1.0))
	var handles := _get_transform_handle_positions()
	if handles.is_empty():
		return
	var rotate_point: Vector2 = handles["rotate"]
	var top_middle := (surface_corners[0] + surface_corners[1]) * 0.5
	target.draw_line(top_middle, rotate_point, Color(0.95, 0.75, 0.32), 1.5)
	target.draw_circle(rotate_point, 6.0, Color(0.95, 0.75, 0.32))
	target.draw_circle(handles["scale"], 6.0, Color(0.35, 0.9, 0.55))


func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_set_zoom(_zoom * ZOOM_FACTOR)
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_set_zoom(_zoom / ZOOM_FACTOR)
			return
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_active = button.pressed
			_last_mouse_position = button.position
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and Input.is_key_pressed(KEY_SPACE):
				_pan_active = true
				_left_pan_active = true
				_last_mouse_position = button.position
				return
			if button.pressed:
				_begin_canvas_selection(button.position)
			else:
				if _left_pan_active:
					_pan_active = false
					_left_pan_active = false
				else:
					_finish_canvas_drag()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _pan_active:
			var delta := motion.position - _last_mouse_position
			_camera.position -= delta / _zoom
			_last_mouse_position = motion.position
			_surface.queue_redraw()
		elif _drag_node != null and is_instance_valid(_drag_node):
			_update_canvas_drag(motion.position)


func _begin_canvas_selection(screen_position: Vector2) -> void:
	if not _editing_enabled or _preview_instance == null:
		return
	var selected := _get_selected_node() as Node2D
	var handles := _get_transform_handle_positions()
	if selected != null and handles.has("scale") and screen_position.distance_to(handles["scale"]) <= 10.0:
		_begin_transform_drag("scale", selected, screen_position)
		return
	if selected != null and handles.has("rotate") and screen_position.distance_to(handles["rotate"]) <= 10.0:
		_begin_transform_drag("rotate", selected, screen_position)
		return
	var world_position := _screen_to_world(screen_position)
	var hit := CanvasGeometry.find_visual_at(_preview_instance, world_position)
	if hit == null:
		_selected_path = NodePath("")
		_surface.queue_redraw()
		part_selected.emit(NodePath(""))
		return
	_selected_path = _preview_instance.get_path_to(hit)
	part_selected.emit(_selected_path)
	_surface.queue_redraw()
	if hit == _preview_instance or hit.get_parent() == null:
		return
	var parent_canvas := hit.get_parent() as CanvasItem
	_drag_start_parent_position = parent_canvas.get_global_transform().affine_inverse() * world_position if parent_canvas != null else world_position
	_drag_node = hit
	_drag_path = _selected_path
	_drag_mode = "move"
	_drag_old_position = hit.position


func _begin_transform_drag(mode: String, node: Node2D, screen_position: Vector2) -> void:
	if node == null:
		return
	var world_position := _screen_to_world(screen_position)
	_drag_node = node
	_drag_path = _selected_path
	_drag_mode = mode
	if mode == "scale":
		_drag_old_scale = node.scale
		_drag_start_vector = world_position - node.global_position
	elif mode == "rotate":
		_drag_old_rotation = node.rotation_degrees
		_drag_start_vector = world_position - node.global_position
		_drag_start_angle = _drag_start_vector.angle()


func _update_canvas_drag(screen_position: Vector2) -> void:
	if _drag_node == null or not is_instance_valid(_drag_node):
		return
	var world_position := _screen_to_world(screen_position)
	if _drag_mode == "scale":
		var current_vector := world_position - _drag_node.global_position
		var start_distance := maxf(_drag_start_vector.length(), 0.001)
		var scale_factor := clampf(current_vector.length() / start_distance, 0.02, 100.0)
		_drag_node.scale = _drag_old_scale * scale_factor
	elif _drag_mode == "rotate":
		var current_vector := world_position - _drag_node.global_position
		var rotation_delta := wrapf(current_vector.angle() - _drag_start_angle, -PI, PI)
		_drag_node.rotation_degrees = _drag_old_rotation + rad_to_deg(rotation_delta)
	else:
		var parent_canvas := _drag_node.get_parent() as CanvasItem
		var current_parent_position := parent_canvas.get_global_transform().affine_inverse() * world_position if parent_canvas != null else world_position
		var next_position := _drag_old_position + current_parent_position - _drag_start_parent_position
		if _snap_enabled:
			next_position.x = roundf(next_position.x / SNAP_STEP) * SNAP_STEP
			next_position.y = roundf(next_position.y / SNAP_STEP) * SNAP_STEP
		_drag_node.position = next_position
	_surface.queue_redraw()


func _finish_canvas_drag() -> void:
	if _drag_node == null or not is_instance_valid(_drag_node):
		return
	var node_path := _drag_path
	var property_name := "position"
	var old_value: Variant = _drag_old_position
	var new_value: Variant = _drag_node.position
	match _drag_mode:
		"scale":
			property_name = "scale"
			old_value = _drag_old_scale
			new_value = _drag_node.scale
		"rotate":
			property_name = "rotation_degrees"
			old_value = _drag_old_rotation
			new_value = _drag_node.rotation_degrees
	_drag_node = null
	_drag_path = NodePath("")
	_drag_mode = "move"
	if old_value != new_value:
		transform_committed.emit(node_path, property_name, new_value, old_value)
	else:
		_surface.queue_redraw()


func _on_open_scene_pressed() -> void:
	open_scene_requested.emit()
