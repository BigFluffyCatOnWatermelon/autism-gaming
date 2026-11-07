@tool
extends RefCounted
## Handles pointer selection and transforms on an Object Builder canvas.

signal part_selected(path: NodePath)
signal context_menu_requested(path: NodePath)
signal pointer_position_changed(world_position: Vector2)
signal transform_committed(path: NodePath, property_name: String, new_value: Variant, old_value: Variant)
signal zoom_requested(factor: float)
signal batch_transform_committed(changes: Array[Dictionary])
signal pivot_committed(path: NodePath, new_value: Vector2, old_value: Variant)
signal guides_changed(vertical_guides: Array[float], horizontal_guides: Array[float])

const CanvasGeometry = preload("res://addons/object_builder/ui/canvas_geometry.gd")
const SNAP_STEP := 8.0

var _viewport: SubViewport
var _surface: Control
var _camera: Camera2D
var _preview_instance: Node
var _selected_path := NodePath("")
var _selected_paths: Array[NodePath] = []
var _marquee_active := false
var _marquee_start := Vector2.ZERO
var _marquee_end := Vector2.ZERO
var _pivot_edit_mode := false
var _guide_vertical: Array[float] = []
var _guide_horizontal: Array[float] = []
var _guide_drag_axis := ""
var _guide_drag_index := -1
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
var _drag_group_nodes: Array[Node2D] = []
var _drag_group_paths: Array[NodePath] = []
var _drag_group_old_positions: Array[Vector2] = []
var _drag_start_world := Vector2.ZERO
var _drag_start_pivot_world := Vector2.ZERO
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
	_selected_paths.clear()
	if not selected_path.is_empty():
		_selected_paths.append(selected_path)
	_marquee_active = false
	if _surface != null:
		_surface.queue_redraw()


func set_selected_path(path: NodePath) -> void:
	_selected_path = path
	_selected_paths.clear()
	if not path.is_empty():
		_selected_paths.append(path)
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


func set_pivot_edit_mode(enabled: bool) -> void:
	_pivot_edit_mode = enabled
	_clear_drag()
	if _surface != null:
		_surface.queue_redraw()


func set_guides(vertical_guides: Array[float], horizontal_guides: Array[float]) -> void:
	_guide_vertical = vertical_guides.duplicate()
	_guide_horizontal = horizontal_guides.duplicate()
	if _surface != null:
		_surface.queue_redraw()


func add_guide(axis: String) -> void:
	if _camera == null:
		return
	if axis == "vertical":
		_guide_vertical.append(_camera.global_position.x)
	elif axis == "horizontal":
		_guide_horizontal.append(_camera.global_position.y)
	else:
		return
	_emit_guides_changed()


func clear_guides() -> void:
	_guide_vertical.clear()
	_guide_horizontal.clear()
	_emit_guides_changed()


func get_guides() -> Dictionary:
	return {"vertical": _guide_vertical.duplicate(), "horizontal": _guide_horizontal.duplicate()}


func _emit_guides_changed() -> void:
	guides_changed.emit(_guide_vertical.duplicate(), _guide_horizontal.duplicate())
	if _surface != null:
		_surface.queue_redraw()


func get_selected_paths() -> Array[NodePath]:
	return _selected_paths.duplicate()


func _set_selected_paths(paths: Array[NodePath], active_path: NodePath = NodePath("")) -> void:
	_selected_paths.clear()
	for path in paths:
		if not path.is_empty() and not _selected_paths.has(path):
			_selected_paths.append(path)
	_selected_path = active_path if not active_path.is_empty() else (
		_selected_paths.back() if not _selected_paths.is_empty() else NodePath("")
	)
	if _surface != null:
		_surface.queue_redraw()
	if not _selected_path.is_empty():
		part_selected.emit(_selected_path)
	else:
		part_selected.emit(NodePath(""))


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
		if button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				_begin_context_selection(button.position)
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
			elif _marquee_active:
				_finish_marquee()
			elif not _guide_drag_axis.is_empty():
				_guide_drag_axis = ""
				_guide_drag_index = -1
				_emit_guides_changed()
			else:
				_finish_drag()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _pan_active:
			var delta := motion.position - _last_mouse_position
			_camera.position -= delta / _zoom
			_last_mouse_position = motion.position
			_surface.queue_redraw()
		elif _marquee_active:
			_marquee_end = motion.position
			_surface.queue_redraw()
		elif not _guide_drag_axis.is_empty():
			_update_guide_drag(motion.position)
		elif not _drag_group_nodes.is_empty():
			_update_drag(motion.position)
		elif _drag_node != null and is_instance_valid(_drag_node):
			_update_drag(motion.position)
		pointer_position_changed.emit(_screen_to_world(motion.position))


func _begin_context_selection(screen_position: Vector2) -> void:
	if not _editing_enabled or _preview_instance == null or not is_instance_valid(_preview_instance):
		return
	var world_position := _screen_to_world(screen_position)
	var hit := CanvasGeometry.find_visual_at(_preview_instance, world_position)
	if hit == null:
		_selected_path = NodePath("")
		_surface.queue_redraw()
		part_selected.emit(NodePath(""))
		return
	_selected_path = _preview_instance.get_path_to(hit)
	_surface.queue_redraw()
	part_selected.emit(_selected_path)
	context_menu_requested.emit(_selected_path)

func draw_selection(target: Control) -> void:
	var scale_to_surface := Vector2(
		target.size.x / maxf(_viewport.size.x, 1.0),
		target.size.y / maxf(_viewport.size.y, 1.0)
	)
	for guide_x in _guide_vertical:
		var guide_screen := _world_to_surface(Vector2(guide_x, 0.0), scale_to_surface)
		target.draw_line(Vector2(guide_screen.x, 0.0), Vector2(guide_screen.x, target.size.y), Color(0.25, 0.82, 1.0, 0.72), 1.0, true)
	for guide_y in _guide_horizontal:
		var guide_screen := _world_to_surface(Vector2(0.0, guide_y), scale_to_surface)
		target.draw_line(Vector2(0.0, guide_screen.y), Vector2(target.size.x, guide_screen.y), Color(0.25, 0.82, 1.0, 0.72), 1.0, true)

	for path in _selected_paths:
		var corners: PackedVector2Array = CanvasGeometry.selected_screen_corners(_preview_instance, path, _viewport)
		if corners.size() < 2:
			continue
		var surface_corners := PackedVector2Array()
		for point in corners:
			surface_corners.append(point * scale_to_surface)
		target.draw_polyline(surface_corners, Color(0.35, 0.85, 1.0, 0.95), 2.0, true)
		if path != _selected_path or _selected_paths.size() > 1:
			continue
		var handles := _get_transform_handle_positions()
		if handles.is_empty() or is_path_locked(path):
			continue
		var rotate_point: Vector2 = handles["rotate"]
		var pivot_point: Vector2 = handles["pivot"]
		var top_middle := (surface_corners[0] + surface_corners[1]) * 0.5
		target.draw_line(top_middle, rotate_point, Color(0.95, 0.75, 0.32), 1.5)
		target.draw_circle(rotate_point, 6.0, Color(0.95, 0.75, 0.32))
		target.draw_circle(handles["scale"], 6.0, Color(0.35, 0.9, 0.55))
		target.draw_line(pivot_point + Vector2(-8, 0), pivot_point + Vector2(8, 0), Color(1.0, 0.65, 0.25), 2.0)
		target.draw_line(pivot_point + Vector2(0, -8), pivot_point + Vector2(0, 8), Color(1.0, 0.65, 0.25), 2.0)

	if _marquee_active:
		var marquee := Rect2(_marquee_start, _marquee_end - _marquee_start).abs()
		target.draw_rect(marquee, Color(0.25, 0.72, 1.0, 0.12), true)
		target.draw_rect(marquee, Color(0.25, 0.72, 1.0, 0.95), false, 1.5)


func _world_to_surface(world_position: Vector2, scale_to_surface: Vector2) -> Vector2:
	return (_viewport.get_canvas_transform() * world_position) * scale_to_surface


func _get_pivot_local(node: Node2D) -> Vector2:
	if node.has_meta("object_builder_pivot"):
		var value: Variant = node.get_meta("object_builder_pivot")
		if value is Vector2:
			return value
	return Vector2.ZERO


func _get_pivot_world(node: Node2D) -> Vector2:
	return node.global_transform * _get_pivot_local(node)


func _get_guide_at_screen_position(screen_position: Vector2) -> Dictionary:
	var scale_to_surface := Vector2(
		_surface.size.x / maxf(_viewport.size.x, 1.0),
		_surface.size.y / maxf(_viewport.size.y, 1.0)
	)
	var world_position := _screen_to_world(screen_position)
	for index in range(_guide_vertical.size()):
		var guide_screen := _world_to_surface(Vector2(_guide_vertical[index], world_position.y), scale_to_surface)
		if absf(guide_screen.x - screen_position.x) <= 6.0:
			return {"axis": "vertical", "index": index}
	for index in range(_guide_horizontal.size()):
		var guide_screen := _world_to_surface(Vector2(world_position.x, _guide_horizontal[index]), scale_to_surface)
		if absf(guide_screen.y - screen_position.y) <= 6.0:
			return {"axis": "horizontal", "index": index}
	return {}


func _update_guide_drag(screen_position: Vector2) -> void:
	var world_position := _screen_to_world(screen_position)
	if _guide_drag_axis == "vertical" and _guide_drag_index >= 0 and _guide_drag_index < _guide_vertical.size():
		_guide_vertical[_guide_drag_index] = world_position.x
	elif _guide_drag_axis == "horizontal" and _guide_drag_index >= 0 and _guide_drag_index < _guide_horizontal.size():
		_guide_horizontal[_guide_drag_index] = world_position.y
	if _surface != null:
		_surface.queue_redraw()


func _finish_marquee() -> void:
	_marquee_active = false
	var start_world := _screen_to_world(_marquee_start)
	var end_world := _screen_to_world(_marquee_end)
	var selection_rect := Rect2(start_world, end_world - start_world).abs()
	var paths: Array[NodePath] = []
	_collect_marquee_hits(_preview_instance, selection_rect, paths)
	_set_selected_paths(paths)
	if _surface != null:
		_surface.queue_redraw()


func _collect_marquee_hits(node: Node, selection_rect: Rect2, paths: Array[NodePath]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if CanvasGeometry.is_visual_node(node):
		var bounds: Dictionary = CanvasGeometry.collect_visual_bounds(node)
		if bounds.has("rect") and selection_rect.intersects(bounds["rect"], true):
			var path := _preview_instance.get_path_to(node)
			if not path.is_empty() and not paths.has(path):
				paths.append(path)
	for child in node.get_children():
		_collect_marquee_hits(child, selection_rect, paths)


func _toggle_selected_path(path: NodePath) -> void:
	if _selected_paths.has(path):
		_selected_paths.erase(path)
		_set_selected_paths(_selected_paths)
	else:
		_selected_paths.append(path)
		_set_selected_paths(_selected_paths, path)


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
	var handles := CanvasGeometry.get_transform_handle_positions(corners, _surface.size, Vector2(_viewport.size))
	var selected := _get_selected_node() as Node2D
	if selected != null:
		var scale_to_surface := Vector2(
			_surface.size.x / maxf(_viewport.size.x, 1.0),
			_surface.size.y / maxf(_viewport.size.y, 1.0)
		)
		var pivot_screen := _world_to_surface(_get_pivot_world(selected), scale_to_surface)
		handles["pivot"] = pivot_screen
		handles["rotate"] = pivot_screen + Vector2(0.0, -28.0)
	return handles


func _begin_selection(screen_position: Vector2) -> void:
	if not _editing_enabled or _preview_instance == null:
		return
	var guide := _get_guide_at_screen_position(screen_position)
	if not guide.is_empty():
		_guide_drag_axis = str(guide.get("axis", ""))
		_guide_drag_index = int(guide.get("index", -1))
		return
	var world_position := _screen_to_world(screen_position)
	var selected := _get_selected_node() as Node2D
	if _pivot_edit_mode and selected != null:
		var old_pivot: Variant = selected.get_meta("object_builder_pivot") if selected.has_meta("object_builder_pivot") else null
		var new_pivot := selected.to_local(world_position)
		selected.set_meta("object_builder_pivot", new_pivot)
		pivot_committed.emit(_selected_path, new_pivot, old_pivot)
		_surface.queue_redraw()
		return
	var handles := _get_transform_handle_positions()
	if selected != null and _selected_paths.size() == 1 and not is_path_locked(_selected_path) and handles.has("scale") and screen_position.distance_to(handles["scale"]) <= 10.0:
		_begin_transform_drag("scale", selected, screen_position)
		return
	if selected != null and _selected_paths.size() == 1 and not is_path_locked(_selected_path) and handles.has("rotate") and screen_position.distance_to(handles["rotate"]) <= 10.0:
		_begin_transform_drag("rotate", selected, screen_position)
		return

	var hit := CanvasGeometry.find_visual_at(_preview_instance, world_position)
	if hit == null:
		_marquee_active = true
		_marquee_start = screen_position
		_marquee_end = screen_position
		return

	var hit_path := _preview_instance.get_path_to(hit)
	var additive_selection := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)
	if additive_selection:
		_toggle_selected_path(hit_path)
		if not _selected_paths.has(hit_path):
			return
	elif not _selected_paths.has(hit_path):
		_set_selected_paths([hit_path], hit_path)
	else:
		_set_selected_paths(_selected_paths, hit_path)
	if hit == _preview_instance or hit.get_parent() == null or is_path_locked(hit_path):
		return
	_drag_group_nodes.clear()
	_drag_group_paths.clear()
	_drag_group_old_positions.clear()
	for path in _selected_paths:
		if is_path_locked(path):
			continue
		var selected_node := _preview_instance.get_node_or_null(path) as Node2D
		if selected_node == null:
			continue
		_drag_group_nodes.append(selected_node)
		_drag_group_paths.append(path)
		_drag_group_old_positions.append(selected_node.global_position)
	if _drag_group_nodes.is_empty():
		return
	_drag_group_start_world = world_position
	_drag_node = _drag_group_nodes[0]
	_drag_path = _drag_group_paths[0]
	_drag_mode = "move"
	_drag_old_position = _drag_node.position
	_drag_start_parent_position = _drag_node.position


func _begin_transform_drag(mode: String, node: Node2D, screen_position: Vector2) -> void:
	if node == null:
		return
	var world_position := _screen_to_world(screen_position)
	_drag_node = node
	_drag_group_nodes = [node]
	_drag_group_paths = [_selected_path]
	_drag_group_old_positions = [node.global_position]
	_drag_start_pivot_world = _get_pivot_world(node)
	_drag_path = _selected_path
	_drag_mode = mode
	if mode == "scale":
		_drag_old_scale = node.scale
		_drag_start_vector = world_position - _drag_start_pivot_world
	elif mode == "rotate":
		_drag_old_rotation = node.rotation_degrees
		_drag_start_vector = world_position - _drag_start_pivot_world
		_drag_start_angle = _drag_start_vector.angle()


func _update_drag(screen_position: Vector2) -> void:
	if _drag_group_nodes.is_empty():
		return
	var world_position := _screen_to_world(screen_position)
	if _drag_mode == "scale":
		var current_vector := world_position - _drag_start_pivot_world
		var start_distance := maxf(_drag_start_vector.length(), 0.001)
		var scale_factor := clampf(current_vector.length() / start_distance, 0.02, 100.0)
		_drag_node.scale = _drag_old_scale * scale_factor
		_drag_node.global_position += _drag_start_pivot_world - _get_pivot_world(_drag_node)
	elif _drag_mode == "rotate":
		var current_vector := world_position - _drag_start_pivot_world
		var rotation_delta := wrapf(current_vector.angle() - _drag_start_angle, -PI, PI)
		_drag_node.rotation_degrees = _drag_old_rotation + rad_to_deg(rotation_delta)
		_drag_node.global_position += _drag_start_pivot_world - _get_pivot_world(_drag_node)
	else:
		var delta := world_position - _drag_group_start_world
		for index in range(_drag_group_nodes.size()):
			var node := _drag_group_nodes[index]
			if node == null or not is_instance_valid(node):
				continue
			var next_global := _drag_group_old_positions[index] + delta
			if _snap_enabled:
				next_global.x = roundf(next_global.x / SNAP_STEP) * SNAP_STEP
				next_global.y = roundf(next_global.y / SNAP_STEP) * SNAP_STEP
			node.global_position = next_global
	_surface.queue_redraw()


func _finish_drag() -> void:
	if _drag_group_nodes.is_empty():
		return
	var changes: Array[Dictionary] = []
	for index in range(_drag_group_nodes.size()):
		var node := _drag_group_nodes[index]
		if node == null or not is_instance_valid(node):
			continue
		var path := _drag_group_paths[index]
		var old_position := _drag_group_old_positions[index]
		if node.global_position != old_position:
			changes.append({
				"path": path,
				"property": "global_position",
				"new": node.global_position,
				"old": old_position
			})
	if _drag_mode == "scale" and _drag_node != null:
		if _drag_node.scale != _drag_old_scale:
			changes.append({
				"path": _drag_path,
				"property": "scale",
				"new": _drag_node.scale,
				"old": _drag_old_scale
			})
	elif _drag_mode == "rotate" and _drag_node != null:
		if not is_equal_approx(_drag_node.rotation_degrees, _drag_old_rotation):
			changes.append({
				"path": _drag_path,
				"property": "rotation_degrees",
				"new": _drag_node.rotation_degrees,
				"old": _drag_old_rotation
			})
	_clear_drag()
	if changes.size() == 1:
		transform_committed.emit(
			changes[0].get("path", NodePath("")),
			str(changes[0].get("property", "")),
			changes[0].get("new"),
			changes[0].get("old")
		)
	elif not changes.is_empty():
		batch_transform_committed.emit(changes)
	elif _surface != null:
		_surface.queue_redraw()


func _clear_drag() -> void:
	_marquee_active = false
	_guide_drag_axis = ""
	_guide_drag_index = -1
	_drag_group_nodes.clear()
	_drag_group_paths.clear()
	_drag_group_old_positions.clear()
	_drag_node = null
	_drag_path = NodePath("")
	_drag_mode = "move"
