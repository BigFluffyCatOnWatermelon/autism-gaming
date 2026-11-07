@tool
extends RefCounted
## Handles pointer selection and transforms on an Object Builder canvas.

signal part_selected(path: NodePath)
signal transform_committed(path: NodePath, property_name: String, new_value: Variant, old_value: Variant)
signal zoom_requested(factor: float)

const CanvasGeometry = preload("res://addons/object_builder/ui/canvas_geometry.gd")
const SNAP_STEP := 8.0

var _viewport: SubViewport
var _surface: Control
var _camera: Camera2D
var _preview_instance: Node
var _selected_path := NodePath("")
var _editing_enabled := false
var _snap_enabled := true
var _locked_paths: Dictionary = {}
var _zoom := 1.0
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


func configure(viewport: SubViewport, surface: Control, camera: Camera2D) -> void:
	_viewport = viewport
	_surface = surface
	_camera = camera


func set_scene(instance: Node, editing_enabled: bool, selected_path: NodePath = NodePath("")) -> void:
	_clear_drag()
	_pan_active = false
	_left_pan_active = false
	_preview_instance = instance
	_editing_enabled = editing_enabled
	_selected_path = selected_path
	if _surface != null:
		_surface.queue_redraw()


func set_selected_path(path: NodePath) -> void:
	_selected_path = path
	if _surface != null:
		_surface.queue_redraw()


func set_snap_enabled(enabled: bool) -> void:
	_snap_enabled = enabled


func set_locked_paths(paths: Array[NodePath]) -> void:
	_locked_paths.clear()
	for path in paths:
		_locked_paths[path] = true
	if _surface != null:
		_surface.queue_redraw()


func is_path_locked(path: NodePath) -> bool:
	return _locked_paths.has(path)


func set_zoom(value: float) -> void:
	_zoom = maxf(value, 0.001)


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			zoom_requested.emit(1.2)
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			zoom_requested.emit(1.0 / 1.2)
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
				_begin_selection(button.position)
			elif _left_pan_active:
				_pan_active = false
				_left_pan_active = false
			else:
				_finish_drag()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _pan_active:
			var delta := motion.position - _last_mouse_position
			_camera.position -= delta / _zoom
			_last_mouse_position = motion.position
			_surface.queue_redraw()
		elif _drag_node != null and is_instance_valid(_drag_node):
			_update_drag(motion.position)


func draw_selection(target: Control) -> void:
	var corners: PackedVector2Array = CanvasGeometry.selected_screen_corners(
		_preview_instance,
		_selected_path,
		_viewport
	)
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
	if handles.is_empty() or is_path_locked(_selected_path):
		return
	var rotate_point: Vector2 = handles["rotate"]
	var top_middle := (surface_corners[0] + surface_corners[1]) * 0.5
	target.draw_line(top_middle, rotate_point, Color(0.95, 0.75, 0.32), 1.5)
	target.draw_circle(rotate_point, 6.0, Color(0.95, 0.75, 0.32))
	target.draw_circle(handles["scale"], 6.0, Color(0.35, 0.9, 0.55))


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var surface_size := Vector2(maxf(_surface.size.x, 1.0), maxf(_surface.size.y, 1.0))
	var viewport_position := screen_position * Vector2(_viewport.size) / surface_size
	return _viewport.get_canvas_transform().affine_inverse() * viewport_position


func _get_selected_node() -> Node:
	if _preview_instance == null or not is_instance_valid(_preview_instance) or _selected_path.is_empty():
		return null
	if _selected_path == NodePath("."):
		return _preview_instance
	return _preview_instance.get_node_or_null(_selected_path)


func _get_transform_handle_positions() -> Dictionary:
	var corners: PackedVector2Array = CanvasGeometry.selected_screen_corners(
		_preview_instance,
		_selected_path,
		_viewport
	)
	return CanvasGeometry.get_transform_handle_positions(corners, _surface.size, Vector2(_viewport.size))


func _begin_selection(screen_position: Vector2) -> void:
	if not _editing_enabled or _preview_instance == null:
		return
	var selected := _get_selected_node() as Node2D
	var handles := _get_transform_handle_positions()
	if selected != null and not is_path_locked(_selected_path) and handles.has("scale") and screen_position.distance_to(handles["scale"]) <= 10.0:
		_begin_transform_drag("scale", selected, screen_position)
		return
	if selected != null and not is_path_locked(_selected_path) and handles.has("rotate") and screen_position.distance_to(handles["rotate"]) <= 10.0:
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
	if hit == _preview_instance or hit.get_parent() == null or is_path_locked(_selected_path):
		return
	var parent_canvas := hit.get_parent() as CanvasItem
	_drag_start_parent_position = (
		parent_canvas.get_global_transform().affine_inverse() * world_position
		if parent_canvas != null else world_position
	)
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


func _update_drag(screen_position: Vector2) -> void:
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
		var current_parent_position := (
			parent_canvas.get_global_transform().affine_inverse() * world_position
			if parent_canvas != null else world_position
		)
		var next_position := _drag_old_position + current_parent_position - _drag_start_parent_position
		if _snap_enabled:
			next_position.x = roundf(next_position.x / SNAP_STEP) * SNAP_STEP
			next_position.y = roundf(next_position.y / SNAP_STEP) * SNAP_STEP
		_drag_node.position = next_position
	_surface.queue_redraw()


func _finish_drag() -> void:
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
	_clear_drag()
	if old_value != new_value:
		transform_committed.emit(node_path, property_name, new_value, old_value)
	elif _surface != null:
		_surface.queue_redraw()


func _clear_drag() -> void:
	_drag_node = null
	_drag_path = NodePath("")
	_drag_mode = "move"
