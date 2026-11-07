extends SceneTree

const CanvasViewScript = preload("res://addons/object_builder/ui/canvas_view.gd")
const CanvasGeometry = preload("res://addons/object_builder/ui/canvas_geometry.gd")

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
	var interaction: RefCounted = canvas.get("_interaction_controller")
	_expect(interaction != null, "canvas delegates pointer handling to a separate controller")
	_expect(bool(canvas.get("_grid_enabled")) and bool(canvas.get("_snap_enabled")), "grid and pixel snapping are enabled by default")

	var preview_root := canvas.get("_preview_instance") as Node
	var preview_sprite := preview_root.get_node("Sprite") as Sprite2D if preview_root != null else null
	_expect(preview_sprite != null, "canvas owns an isolated copy of the scene tree")
	if preview_sprite != null:
		_expect(preview_sprite != sprite, "canvas never edits the original scene node directly")
		_expect(CanvasGeometry.find_visual_at(preview_root, preview_sprite.global_position) == preview_sprite, "canvas hit testing finds a sprite by its transformed bounds")

		var viewport_point := viewport.get_canvas_transform() * preview_sprite.global_position
		var screen_position := viewport_point * surface.size / Vector2(viewport.size)
		interaction.call("_begin_selection", screen_position)
		_expect(not selected_paths.is_empty() and selected_paths[-1] == NodePath("Sprite"), "clicking the sprite emits its scene-relative path")
		var world_delta := Vector2(10.0, 0.0)
		var viewport_delta := (viewport.get_canvas_transform() * world_delta) - (viewport.get_canvas_transform() * Vector2.ZERO)
		var screen_delta := viewport_delta * surface.size / Vector2(viewport.size)
		interaction.call("_update_drag", screen_position + screen_delta)
		_expect(preview_sprite.position == Vector2(72.0, 32.0), "dragging applies the configured eight-pixel snap step")
		interaction.call("_finish_drag")
		_expect(committed_transforms.size() == 1, "releasing a moved part commits one transform")
		if not committed_transforms.is_empty():
			_expect(committed_transforms[0].get("path") == NodePath("Sprite"), "transform commit retains the selected part path")
			_expect(committed_transforms[0].get("property") == "position", "canvas commits position changes through a property contract")
			_expect(committed_transforms[0].get("old") == Vector2(64.0, 32.0), "canvas preserves the original position for Undo")
			_expect(committed_transforms[0].get("new") == Vector2(72.0, 32.0), "canvas emits the snapped final position")
		_expect(sprite.position == Vector2(64.0, 32.0), "dragging the isolated preview leaves the original scene unchanged")

		var handles: Dictionary = interaction.call("_get_transform_handle_positions")
		_expect(handles.has("scale") and handles.has("rotate"), "selected parts expose scale and rotation handles")
		if handles.has("scale"):
			var scale_handle: Vector2 = handles["scale"]
			interaction.call("_begin_selection", scale_handle)
			_expect(str(interaction.get("_drag_mode")) == "scale", "scale handle starts a scale drag")
			var scale_start_world: Vector2 = interaction.call("_screen_to_world", scale_handle)
			var scale_end_world := preview_sprite.global_position + (scale_start_world - preview_sprite.global_position) * 1.5
			var scale_end_viewport := viewport.get_canvas_transform() * scale_end_world
			var scale_end_screen := scale_end_viewport * surface.size / Vector2(viewport.size)
			interaction.call("_update_drag", scale_end_screen)
			interaction.call("_finish_drag")
			_expect(is_equal_approx(preview_sprite.scale.x, 1.5) and is_equal_approx(preview_sprite.scale.y, 1.5), "scale handle changes both sprite axes uniformly")
			_expect(committed_transforms.size() == 2 and committed_transforms[1].get("property") == "scale", "scale drag commits one undoable scale change")

		handles = interaction.call("_get_transform_handle_positions")
		if handles.has("rotate"):
			var rotate_handle: Vector2 = handles["rotate"]
			interaction.call("_begin_selection", rotate_handle)
			_expect(str(interaction.get("_drag_mode")) == "rotate", "rotation handle starts a rotation drag")
			var rotate_start_world: Vector2 = interaction.call("_screen_to_world", rotate_handle)
			var rotate_vector := rotate_start_world - preview_sprite.global_position
			var rotate_end_world := preview_sprite.global_position + rotate_vector.rotated(PI / 4.0)
			var rotate_end_viewport := viewport.get_canvas_transform() * rotate_end_world
			var rotate_end_screen := rotate_end_viewport * surface.size / Vector2(viewport.size)
			interaction.call("_update_drag", rotate_end_screen)
			interaction.call("_finish_drag")
			_expect(is_equal_approx(preview_sprite.rotation_degrees, 45.0), "rotation handle rotates the selected part around its origin")
			_expect(committed_transforms.size() == 3 and committed_transforms[2].get("property") == "rotation_degrees", "rotation drag commits one undoable rotation change")

	var locked_paths: Array[NodePath] = [NodePath("Sprite")]
	canvas.call("set_locked_paths", locked_paths)
	_expect(bool(interaction.call("is_path_locked", NodePath("Sprite"))), "canvas forwards locked part paths to the interaction controller")
	if preview_sprite != null:
		var locked_start := preview_sprite.position
		var locked_viewport_point := viewport.get_canvas_transform() * preview_sprite.global_position
		var locked_screen_point := locked_viewport_point * surface.size / Vector2(viewport.size)
		interaction.call("_begin_selection", locked_screen_point)
		interaction.call("_update_drag", locked_screen_point + Vector2(40.0, 24.0))
		interaction.call("_finish_drag")
		_expect(preview_sprite.position == locked_start, "locked visual parts cannot be moved on the canvas")

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

	var animated_scene := Node2D.new()
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"idle")
	var animation_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	animation_image.fill(Color.WHITE)
	var animation_texture := ImageTexture.create_from_image(animation_image)
	frames.add_frame(&"idle", animation_texture)
	var animated_sprite := AnimatedSprite2D.new()
	animated_sprite.name = "Animated"
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = &"idle"
	animated_scene.add_child(animated_sprite)
	var logic_node := Node.new()
	logic_node.name = "GameLogic"
	logic_node.set_process(true)
	animated_scene.add_child(logic_node)

	canvas.call("set_preview_instance", animated_scene.duplicate(), false, true)
	var animation_button := canvas.get("_animation_button") as Button
	_expect(not animation_button.disabled, "canvas enables animation preview when AnimatedSprite2D exists")
	animation_button.toggled.emit(true)
	var animated_preview := (canvas.get("_preview_instance") as Node).get_node("Animated") as AnimatedSprite2D
	var disabled_logic := (canvas.get("_preview_instance") as Node).get_node("GameLogic") as Node
	_expect(animated_preview.is_playing(), "play starts AnimatedSprite2D inside the isolated canvas")
	_expect(animated_preview.process_mode == Node.PROCESS_MODE_ALWAYS, "only animated sprites opt into processing")
	_expect(disabled_logic.process_mode == Node.PROCESS_MODE_DISABLED, "game logic stays disabled while animation preview plays")
	animation_button.toggled.emit(false)
	_expect(not animated_preview.is_playing(), "pause stops the isolated animation")
	_expect(animated_preview.process_mode == Node.PROCESS_MODE_DISABLED, "pause disables animated sprite processing again")
	canvas.call("clear_canvas", "No scene")
	_expect((canvas.get("_animation_button") as Button).disabled, "clearing canvas disables animation preview controls")
	animated_scene.free()

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
