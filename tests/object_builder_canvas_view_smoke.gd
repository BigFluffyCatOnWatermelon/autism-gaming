extends SceneTree

const CanvasViewScript = preload("res://addons/object_builder/ui/canvas_view.gd")
const CanvasGeometry = preload("res://addons/object_builder/ui/canvas_geometry.gd")

var failures: Array[String] = []
var selected_paths: Array[NodePath] = []
var committed_transforms: Array[Dictionary] = []
var open_scene_requests := 0
var context_action_events: Array[String] = []
var batch_transform_events: Array[Dictionary] = []
var pivot_events: Array[Dictionary] = []
var guide_events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas = CanvasViewScript.new()
	root.add_child(canvas)
	canvas.call("build")
	canvas.size = Vector2(760, 430)
	canvas.connect("part_selected", Callable(self, "_on_part_selected"))
	canvas.connect("transform_committed", Callable(self, "_on_transform_committed"))
	canvas.connect("batch_transform_committed", Callable(self, "_on_batch_transform_committed"))
	canvas.connect("pivot_committed", Callable(self, "_on_pivot_committed"))
	canvas.connect("guides_changed", Callable(self, "_on_guides_changed"))
	canvas.connect("open_scene_requested", Callable(self, "_on_open_scene_requested"))
	canvas.connect("part_context_action_requested", Callable(self, "_on_part_context_action_requested"))

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
	var second_sprite := Sprite2D.new()
	second_sprite.name = "SecondSprite"
	second_sprite.texture = texture
	second_sprite.position = Vector2(128.0, 32.0)
	scene_root.add_child(second_sprite)

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
		_expect(preview_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixel-art canvas preview uses nearest texture filtering")
		_expect(CanvasGeometry.find_visual_at(preview_root, preview_sprite.global_position) == preview_sprite, "canvas hit testing finds a sprite by its transformed bounds")

		var viewport_point := viewport.get_canvas_transform() * preview_sprite.global_position
		var screen_position := viewport_point * surface.size / Vector2(viewport.size)
		var context_click := InputEventMouseButton.new()
		context_click.button_index = MOUSE_BUTTON_RIGHT
		context_click.pressed = true
		context_click.position = screen_position
		interaction.call("handle_input", context_click)
		_expect(not selected_paths.is_empty() and selected_paths[-1] == NodePath("Sprite"), "right-click selects the visual part under the pointer")
		var context_menu := canvas.get("_context_menu") as PopupMenu
		_expect(context_menu != null, "canvas creates a dedicated part context menu")
		if context_menu != null:
			_expect(context_menu.get_item_index(0) >= 0, "context menu exposes inline rename")
			_expect(context_menu.get_item_index(1) >= 0, "context menu exposes duplicate")
			_expect(context_menu.get_item_index(2) >= 0, "context menu exposes visibility toggle")
			_expect(context_menu.get_item_index(3) >= 0, "context menu exposes canvas lock toggle")
			_expect(context_menu.get_item_index(4) >= 0 and context_menu.get_item_index(5) >= 0, "context menu exposes draw order actions")
			_expect(context_menu.get_item_index(6) >= 0, "context menu exposes delete")
		canvas.call("_on_context_menu_item_selected", 1)
		_expect(context_action_events == ["duplicate:Sprite"], "context menu forwards a stable duplicate action and selected path")
		if context_menu != null:
			context_menu.hide()
		var pointer_motion := InputEventMouseMotion.new()
		pointer_motion.position = screen_position
		interaction.call("handle_input", pointer_motion)
		_expect((canvas.get("_coordinates_label") as Label).text == "X: 64 · Y: 32", "canvas displays live world coordinates under the pointer")
		canvas.call("set_locked_paths", [NodePath("Sprite")])
		canvas.call("_on_context_menu_requested", NodePath("Sprite"))
		if context_menu != null:
			var lock_item_index := context_menu.get_item_index(3)
			_expect(context_menu.get_item_text(lock_item_index) == "Снять фиксацию", "context menu reflects the current locked state")
		canvas.call("set_locked_paths", [])
		if context_menu != null:
			context_menu.hide()
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

		# Marquee selection is independent of the single active Inspector selection.
		var first_corner := viewport.get_canvas_transform() * Vector2(40.0, 8.0)
		var second_corner := viewport.get_canvas_transform() * Vector2(152.0, 56.0)
		interaction.set("_marquee_start", first_corner * surface.size / Vector2(viewport.size))
		interaction.set("_marquee_end", second_corner * surface.size / Vector2(viewport.size))
		interaction.call("_finish_marquee")
		var selected_group: Array = interaction.call("get_selected_paths")
		_expect(selected_group.size() == 2, "marquee selects multiple visual parts inside its rectangle")
		_expect(selected_group.has(NodePath("Sprite")) and selected_group.has(NodePath("SecondSprite")), "marquee retains stable scene-relative paths")

		# Group movement is committed as one batch rather than independent Undo entries.
		var second_preview := preview_root.get_node("SecondSprite") as Sprite2D
		var before_first := preview_sprite.global_position
		var before_second := second_preview.global_position
		var group_start_world := Vector2(64.0, 32.0)
		var group_start_screen := (viewport.get_canvas_transform() * group_start_world) * surface.size / Vector2(viewport.size)
		interaction.call("_begin_selection", group_start_screen)
		var group_end_world := group_start_world + Vector2(16.0, 8.0)
		var group_end_screen := (viewport.get_canvas_transform() * group_end_world) * surface.size / Vector2(viewport.size)
		interaction.call("_update_drag", group_end_screen)
		interaction.call("_finish_drag")
		_expect(preview_sprite.global_position == before_first + Vector2(16.0, 8.0), "group drag moves the first selected part")
		_expect(second_preview.global_position == before_second + Vector2(16.0, 8.0), "group drag moves every selected part")
		_expect(batch_transform_events.size() == 1 and batch_transform_events[0].get("changes", []).size() == 2, "group movement emits one batch containing both part transforms")

		# The same shared handles scale and rotate the complete multi-selection.
		var group_handles: Dictionary = interaction.call("_get_transform_handle_positions")
		_expect(group_handles.has("scale") and group_handles.has("rotate") and group_handles.has("pivot"), "multi-selection exposes shared scale, rotate and pivot handles")
		var group_pivot_world: Vector2 = interaction.call("_screen_to_world", group_handles["pivot"])
		var scale_handle_world: Vector2 = interaction.call("_screen_to_world", group_handles["scale"])
		var scale_end_world := group_pivot_world + (scale_handle_world - group_pivot_world) * 1.5
		var scale_end_screen := (viewport.get_canvas_transform() * scale_end_world) * surface.size / Vector2(viewport.size)
		interaction.call("_begin_selection", group_handles["scale"])
		interaction.call("_update_drag", scale_end_screen)
		interaction.call("_finish_drag")
		_expect(is_equal_approx(preview_sprite.scale.x, 1.5) and is_equal_approx(second_preview.scale.x, 1.5), "group scale applies one uniform factor to every selected part")
		_expect(batch_transform_events.size() == 2 and batch_transform_events[1].get("changes", []).size() >= 4, "group scale commits positions and scales in one batch")

		group_handles = interaction.call("_get_transform_handle_positions")
		group_pivot_world = interaction.call("_screen_to_world", group_handles["pivot"])
		var rotate_handle_world: Vector2 = interaction.call("_screen_to_world", group_handles["rotate"])
		var rotate_end_world := group_pivot_world + (rotate_handle_world - group_pivot_world).rotated(PI / 2.0)
		var rotate_end_screen := (viewport.get_canvas_transform() * rotate_end_world) * surface.size / Vector2(viewport.size)
		interaction.call("_begin_selection", group_handles["rotate"])
		interaction.call("_update_drag", rotate_end_screen)
		interaction.call("_finish_drag")
		_expect(is_equal_approx(preview_sprite.rotation_degrees, 90.0) and is_equal_approx(second_preview.rotation_degrees, 90.0), "group rotation applies the same angle to every selected part")
		_expect(batch_transform_events.size() == 3 and batch_transform_events[2].get("changes", []).size() >= 4, "group rotation commits as one batch")

		# Independent pivot metadata is editable and emits a scene commit request.
		canvas.call("set_selected_path", NodePath("Sprite"))
		interaction.call("set_pivot_edit_mode", true)
		var pivot_world := preview_sprite.global_position + Vector2(4.0, 6.0)
		var pivot_screen := (viewport.get_canvas_transform() * pivot_world) * surface.size / Vector2(viewport.size)
		interaction.call("_begin_selection", pivot_screen)
		_expect(preview_sprite.has_meta("object_builder_pivot"), "pivot mode stores an independent local pivot on the preview node")
		_expect(pivot_events.size() == 1 and pivot_events[0].get("path") == NodePath("Sprite"), "pivot edit emits a stable scene path for Undo/Redo persistence")
		interaction.call("set_pivot_edit_mode", false)
		second_preview.visible = false
		interaction.set("_marquee_start", first_corner * surface.size / Vector2(viewport.size))
		interaction.set("_marquee_end", second_corner * surface.size / Vector2(viewport.size))
		interaction.call("_finish_marquee")
		_expect(interaction.call("get_selected_paths") == [NodePath("Sprite")], "marquee ignores hidden visual parts")
		second_preview.visible = true
		sprite.set_meta("object_builder_pivot", Vector2(4.0, 6.0))
		sprite.owner = scene_root
		second_sprite.owner = scene_root
		var packed_pivot_scene := PackedScene.new()
		var pack_error := packed_pivot_scene.pack(scene_root)
		_expect(pack_error == OK, "scene can be packed with custom pivot metadata")
		if pack_error == OK:
			var restored_pivot_scene := packed_pivot_scene.instantiate() as Node2D
			var restored_pivot_sprite := restored_pivot_scene.get_node("Sprite") as Sprite2D
			_expect(restored_pivot_sprite.has_meta("object_builder_pivot"), "custom pivot metadata survives PackedScene serialization")
			_expect(restored_pivot_sprite.get_meta("object_builder_pivot") == Vector2(4.0, 6.0), "serialized pivot retains its local coordinates")
			restored_pivot_scene.free()

		canvas.call("set_guides", [12.0], [24.0])
		var guide_state: Dictionary = canvas.call("get_guides")
		_expect(guide_state.get("vertical", []).size() == 1 and guide_state.get("horizontal", []).size() == 1, "canvas stores vertical and horizontal guides")
		var guide_screen := (viewport.get_canvas_transform() * Vector2(12.0, 0.0)) * surface.size / Vector2(viewport.size)
		var guide_hit: Dictionary = interaction.call("_get_guide_at_screen_position", guide_screen)
		_expect(guide_hit.get("axis", "") == "vertical", "guide hit testing detects a vertical guide")
		interaction.call("_begin_selection", guide_screen)
		var moved_guide_screen := (viewport.get_canvas_transform() * Vector2(40.0, 0.0)) * surface.size / Vector2(viewport.size)
		interaction.call("_update_guide_drag", moved_guide_screen)
		var guide_release := InputEventMouseButton.new()
		guide_release.button_index = MOUSE_BUTTON_LEFT
		guide_release.pressed = false
		interaction.call("handle_input", guide_release)
		guide_state = canvas.call("get_guides")
		_expect(is_equal_approx(float(guide_state.get("vertical", [])[0]), 40.0), "guides can be dragged to a new world coordinate")
		canvas.call("_on_add_vertical_guide_pressed")
		_expect(guide_events.size() >= 1, "adding a guide emits project-layout state")
		canvas.call("_on_clear_guides_pressed")

		# Single-part rotation keeps its custom pivot at the same world coordinate.
		var custom_pivot_before: Vector2 = preview_sprite.global_transform * Vector2(4.0, 6.0)
		var single_handles: Dictionary = interaction.call("_get_transform_handle_positions")
		var single_rotate_world: Vector2 = interaction.call("_screen_to_world", single_handles["rotate"])
		var single_pivot_world: Vector2 = interaction.call("_screen_to_world", single_handles["pivot"])
		var single_rotate_end := single_pivot_world + (single_rotate_world - single_pivot_world).rotated(PI / 4.0)
		var single_rotate_screen := (viewport.get_canvas_transform() * single_rotate_end) * surface.size / Vector2(viewport.size)
		interaction.call("_begin_selection", single_handles["rotate"])
		interaction.call("_update_drag", single_rotate_screen)
		interaction.call("_finish_drag")
		var custom_pivot_after: Vector2 = preview_sprite.global_transform * Vector2(4.0, 6.0)
		_expect(custom_pivot_after.distance_to(custom_pivot_before) <= 0.001, "rotating a part preserves its independent pivot in world space")
		guide_state = canvas.call("get_guides")
		_expect(guide_state.get("vertical", []).is_empty() and guide_state.get("horizontal", []).is_empty(), "clear guides removes both guide directions")

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
	var readonly_context_click := InputEventMouseButton.new()
	readonly_context_click.button_index = MOUSE_BUTTON_RIGHT
	readonly_context_click.pressed = true
	readonly_context_click.position = screen_position
	interaction.call("handle_input", readonly_context_click)
	_expect(context_action_events.size() == 1, "read-only preview ignores right-click context actions")
	_expect(not (canvas.get("_context_menu") as PopupMenu).visible, "read-only preview never opens the part context menu")

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


func _on_batch_transform_committed(changes: Array[Dictionary]) -> void:
	batch_transform_events.append({"changes": changes})


func _on_pivot_committed(path: NodePath, new_value: Vector2, old_value: Variant) -> void:
	pivot_events.append({"path": path, "new": new_value, "old": old_value})


func _on_guides_changed(vertical_guides: Array[float], horizontal_guides: Array[float]) -> void:
	guide_events.append({"vertical": vertical_guides, "horizontal": horizontal_guides})


func _on_open_scene_requested() -> void:
	open_scene_requests += 1


func _on_part_context_action_requested(action: String, path: NodePath) -> void:
	context_action_events.append(action + ":" + str(path))


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
