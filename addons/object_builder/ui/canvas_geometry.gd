@tool
extends RefCounted
## Geometry helpers shared by the Object Builder canvas.

static func collect_visual_bounds(node: Node) -> Dictionary:
	var result: Dictionary = {}
	_collect_visual_bounds(node, result)
	return result


static func _collect_visual_bounds(node: Node, result: Dictionary) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			_include_rect(sprite.global_transform, sprite.get_rect(), result)
	elif node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if sprite.sprite_frames != null and sprite.sprite_frames.get_frame_count(sprite.animation) > 0:
			_include_rect(sprite.global_transform, sprite.get_rect(), result)
	elif node is Polygon2D:
		var polygon := node as Polygon2D
		for point in polygon.polygon:
			_include_point(polygon.global_transform * point, result)
	elif node is Line2D:
		var line := node as Line2D
		for point in line.points:
			_include_point(line.global_transform * point, result)
	for child in node.get_children():
		_collect_visual_bounds(child, result)


static func _include_rect(transform: Transform2D, rect: Rect2, result: Dictionary) -> void:
	if rect.size == Vector2.ZERO:
		return
	_include_point(transform * rect.position, result)
	_include_point(transform * Vector2(rect.end.x, rect.position.y), result)
	_include_point(transform * rect.end, result)
	_include_point(transform * Vector2(rect.position.x, rect.end.y), result)


static func _include_point(point: Vector2, result: Dictionary) -> void:
	if not result.has("rect"):
		result["rect"] = Rect2(point, Vector2.ZERO)
	else:
		var current: Rect2 = result["rect"]
		result["rect"] = current.expand(point)


static func find_visual_at(node: Node, world_position: Vector2) -> Node2D:
	if node == null or not is_instance_valid(node):
		return null
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return null
	var children := node.get_children()
	for index in range(children.size() - 1, -1, -1):
		var found := find_visual_at(children[index], world_position)
		if found != null:
			return found
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null and sprite.get_rect().has_point(sprite.to_local(world_position)):
			return sprite
	elif node is AnimatedSprite2D:
		var animated := node as AnimatedSprite2D
		if animated.sprite_frames != null and animated.sprite_frames.get_frame_count(animated.animation) > 0:
			if animated.get_rect().has_point(animated.to_local(world_position)):
				return animated
	elif node is Polygon2D:
		var polygon := node as Polygon2D
		if polygon.polygon.size() >= 3 and Geometry2D.is_point_in_polygon(polygon.to_local(world_position), polygon.polygon):
			return polygon
	elif node is Line2D:
		var line := node as Line2D
		var local_point := line.to_local(world_position)
		for index in range(line.points.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(
				local_point,
				line.points[index],
				line.points[index + 1]
			)
			if local_point.distance_to(closest) <= maxf(line.width * 0.5, 4.0):
				return line
	return null


static func selected_screen_corners(
	preview_instance: Node,
	selected_path: NodePath,
	viewport: SubViewport
) -> PackedVector2Array:
	if preview_instance == null or not is_instance_valid(preview_instance) or selected_path.is_empty():
		return PackedVector2Array()
	var selected := preview_instance if selected_path == NodePath(".") else preview_instance.get_node_or_null(selected_path)
	if not selected is Node2D:
		return PackedVector2Array()
	var points: Array[Vector2] = []
	_collect_node_points(selected, points)
	if points.is_empty():
		var center := viewport.get_canvas_transform() * (selected as Node2D).global_position
		return PackedVector2Array([
			center + Vector2(-6, -6),
			center + Vector2(6, -6),
			center + Vector2(6, 6),
			center + Vector2(-6, 6),
			center + Vector2(-6, -6)
		])
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var canvas_transform := viewport.get_canvas_transform()
	var top_left := canvas_transform * bounds.position
	var bottom_right := canvas_transform * bounds.end
	return PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y),
		top_left
	])


static func _collect_node_points(node: Node, points: Array[Vector2]) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			_append_rect_points(sprite.global_transform, sprite.get_rect(), points)
	elif node is AnimatedSprite2D:
		var animated := node as AnimatedSprite2D
		if animated.sprite_frames != null and animated.sprite_frames.get_frame_count(animated.animation) > 0:
			_append_rect_points(animated.global_transform, animated.get_rect(), points)
	elif node is Polygon2D:
		var polygon := node as Polygon2D
		for point in polygon.polygon:
			points.append(polygon.global_transform * point)
	elif node is Line2D:
		var line := node as Line2D
		for point in line.points:
			points.append(line.global_transform * point)
	for child in node.get_children():
		_collect_node_points(child, points)


static func _append_rect_points(transform: Transform2D, rect: Rect2, points: Array[Vector2]) -> void:
	if rect.size == Vector2.ZERO:
		return
	points.append(transform * rect.position)
	points.append(transform * Vector2(rect.end.x, rect.position.y))
	points.append(transform * rect.end)
	points.append(transform * Vector2(rect.position.x, rect.end.y))


static func get_transform_handle_positions(
	corners: PackedVector2Array,
	surface_size: Vector2,
	viewport_size: Vector2
) -> Dictionary:
	if corners.size() < 4:
		return {}
	var scale_to_surface := Vector2(
		surface_size.x / maxf(viewport_size.x, 1.0),
		surface_size.y / maxf(viewport_size.y, 1.0)
	)
	var top_middle := (corners[0] + corners[1]) * 0.5
	return {
		"scale": corners[2] * scale_to_surface,
		"rotate": top_middle * scale_to_surface + Vector2(0.0, -20.0)
	}
