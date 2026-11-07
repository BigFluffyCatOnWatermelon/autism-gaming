extends SceneTree

const CanvasViewScript = preload("res://addons/object_builder/ui/canvas_view.gd")

var failures: Array[String] = []
var selected_paths: Array[NodePath] = []
var committed_transforms: Array[Dictionary] = []
var open_scene_requests := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas = CanvasViewScript.new()
	root.add_child(canvas)
	canvas.call("build")
	canvas.size = Vector2(760, 430)
	canvas.connect("part_selected", Callable(self, "_on_part_selected"))
	canvas.connect("transform_committed", Callable(self, "_on_transform_committed"))
	canvas.connect("open_scene_requested", Callable(self, "_on_open_scene_requested"))

	var scene_root := Node2D.new()
	scene_root.name = "ObjectRoot"
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.position = Vector2(64.0, 32.0)
	scene_root.add_child(sprite)

	canvas.call("set_preview_instance", scene_root.duplicate(), true, true, NodePath("Sprite"))
	await process_frame
	await process_frame

	var viewport := canvas.get("_viewport") as SubViewport
	var surface := canvas.get("_surface") as Control
	var camera := canvas.get("_camera") as Camera2D
	_expect(viewport != null and surface != null and camera != null, "canvas creates a viewport, input surface and camera")
	_expect(surface.size.x > 0.0 and surface.size.y > 0.0, "canvas surface receives its layout size")
	_expect(bool(canvas.get("_editing_enabled")), "canvas enables edits for an open scene")
	_expect(bool(canvas.get("_grid_enabled")) and bool(canvas.get("_snap_enabled")), "grid and pixel snapping are enabled by default")

	var preview_root := canvas.get("_preview_instance") as Node
	var preview_sprite := preview_root.get_node("Sprite") as Sprite2D if preview_root != null else null
	_expect(preview_sprite != null, "canvas owns an isolated copy of the scene tree")
	if preview_sprite != null:
		_expect(preview_sprite != sprite, "canvas never edits the original scene node directly")
		_expect(canvas.call("_find_visual_at", preview_root, preview_sprite.global_position) == preview_sprite, "canvas hit testing finds a sprite by its transformed bounds")

		var viewport_point := viewport.get_canvas_transform() * preview_sprite.global_position
		var screen_position := viewport_point * surface.size / Vector2(viewport.size)
		canvas.call("_begin_canvas_selection", screen_position)
		_expect(not selected_paths.is_empty() and selected_paths[-1] == NodePath("Sprite"), "clicking the sprite emits its scene-relative path")
		var world_delta := Vector2(10.0, 0.0)
		var viewport_delta := (viewport.get_canvas_transform() * world_delta) - (viewport.get_canvas_transform() * Vector2.ZERO)
		var screen_delta := viewport_delta * surface.size / Vector2(viewport.size)
		canvas.call("_update_canvas_drag", screen_position + screen_delta)
		_expect(preview_sprite.position == Vector2(72.0, 32.0), "dragging applies the configured eight-pixel snap step")
		canvas.call("_finish_canvas_drag")
		_expect(committed_transforms.size() == 1, "releasing a moved part commits one transform")
		if not committed_transforms.is_empty():
			_expect(committed_transforms[0].get("path") == NodePath("Sprite"), "transform commit retains the selected part path")
			_expect(committed_transforms[0].get("property") == "position", "canvas commits position changes through a property contract")
			_expect(committed_transforms[0].get("old") == Vector2(64.0, 32.0), "canvas preserves the original position for Undo")
			_expect(committed_transforms[0].get("new") == Vector2(72.0, 32.0), "canvas emits the snapped final position")
		_expect(sprite.position == Vector2(64.0, 32.0), "dragging the isolated preview leaves the original scene unchanged")

	var initial_zoom := float(canvas.get("_zoom"))
	canvas.call("_on_zoom_in_pressed")
	_expect(float(canvas.get("_zoom")) > initial_zoom, "toolbar zoom increases the canvas scale")
	canvas.call("_on_grid_toggled", false)
	canvas.call("_on_snap_toggled", false)
	_expect(not bool(canvas.get("_grid_enabled")), "grid toggle hides the grid")
	_expect(not bool(canvas.get("_snap_enabled")), "snap toggle disables pixel snapping")

	(canvas.get("_open_scene_button") as Button).pressed.emit()
	_expect(open_scene_requests == 1, "open scene action is forwarded to the editor controller")
	canvas.call("set_preview_instance", scene_root.duplicate(), false, true)
	_expect(not bool(canvas.get("_editing_enabled")), "read-only preview disables transform editing")
	_expect((canvas.get("_open_scene_button") as Button).visible, "read-only preview exposes the open-scene action")

	canvas.call("clear_canvas", "No scene")
	_expect(canvas.get("_preview_instance") == null, "clearing canvas releases the preview instance")
	_expect((canvas.get("_status_label") as Label).text == "No scene", "clearing canvas displays its diagnostic message")

	root.remove_child(canvas)
	canvas.free()
	scene_root.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder canvas view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_part_selected(path: NodePath) -> void:
	selected_paths.append(path)


func _on_transform_committed(path: NodePath, property_name: String, new_value: Variant, old_value: Variant) -> void:
	committed_transforms.append({
		"path": path,
		"property": property_name,
		"new": new_value,
		"old": old_value
	})


func _on_open_scene_requested() -> void:
	open_scene_requests += 1


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
