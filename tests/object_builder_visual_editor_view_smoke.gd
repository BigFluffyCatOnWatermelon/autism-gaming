extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/visual_editor_view.gd")

var failures: Array[String] = []
var texture_paths: Array[String] = []
var texture_file_paths: Array[String] = []
var frame_paths: Array[String] = []
var frame_file_paths: Array[String] = []
var grid_events: Array[Dictionary] = []
var offset_events: Array[Dictionary] = []
var toggle_events: Array[Dictionary] = []
var animation_events: Array[int] = []
var frame_events: Array[float] = []
var speed_events: Array[float] = []
var texture_browse_count := 0
var frames_browse_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	root.add_child(view)
	view.call("build")
	view.connect("texture_path_submitted", Callable(self, "_on_texture_path"))
	view.connect("texture_file_selected", Callable(self, "_on_texture_file"))
	view.connect("frames_path_submitted", Callable(self, "_on_frames_path"))
	view.connect("frames_file_selected", Callable(self, "_on_frames_file"))
	view.connect("sprite_grid_value_changed", Callable(self, "_on_grid_changed"))
	view.connect("sprite_offset_changed", Callable(self, "_on_offset_changed"))
	view.connect("sprite_toggle_changed", Callable(self, "_on_toggle_changed"))
	view.connect("animation_selected", Callable(self, "_on_animation_selected"))
	view.connect("animation_frame_changed", Callable(self, "_on_frame_changed"))
	view.connect("animation_speed_changed", Callable(self, "_on_speed_changed"))
	view.connect("texture_browse_requested", Callable(self, "_on_texture_browse"))
	view.connect("frames_browse_requested", Callable(self, "_on_frames_browse"))

	_expect(view.get_child_count() == 3, "visual editor owns the panel and both resource dialogs")
	var panel := view.get("_visual_panel") as VBoxContainer
	var static_controls := view.get("_sprite_visual_controls") as VBoxContainer
	var animated_controls := view.get("_animated_visual_controls") as VBoxContainer
	_expect(panel != null and not panel.visible, "visual editor starts hidden")
	_expect(static_controls != null and animated_controls != null, "static and animated controls are created")

	var sprite := Sprite2D.new()
	sprite.name = "StaticSprite"
	sprite.hframes = 3
	sprite.vframes = 2
	sprite.frame = 4
	sprite.offset = Vector2(12.0, -6.0)
	sprite.centered = false
	sprite.flip_h = true
	sprite.flip_v = false
	view.call("show_sprite", sprite)
	_expect(panel.visible and static_controls.visible and not animated_controls.visible, "Sprite2D displays only static controls")
	_expect((view.get("_visual_type_label") as Label).text == "Выбрано изображение: StaticSprite", "static editor identifies the selected node")
	_expect(is_equal_approx((view.get("_sprite_hframes") as SpinBox).value, 3.0), "horizontal frame count is populated")
	_expect(is_equal_approx((view.get("_sprite_vframes") as SpinBox).value, 2.0), "vertical frame count is populated")
	_expect(is_equal_approx((view.get("_sprite_frame") as SpinBox).value, 4.0), "static frame index is populated")
	_expect((view.get("_sprite_offset_x") as SpinBox).value == 12.0, "horizontal sprite offset is populated")
	_expect((view.get("_sprite_offset_y") as SpinBox).value == -6.0, "vertical sprite offset is populated")
	_expect(not (view.get("_sprite_centered") as CheckBox).button_pressed, "centered toggle is populated")
	_expect((view.get("_sprite_flip_h") as CheckBox).button_pressed, "horizontal flip toggle is populated")

	view.call("set_texture_path", "res://images/initial.png")
	_expect((view.get("_texture_path_edit") as LineEdit).text == "res://images/initial.png", "texture path can be updated by the controller")
	(view.get("_texture_path_edit") as LineEdit).text_submitted.emit("res://images/submitted.png")
	(view.get("_texture_dialog") as FileDialog).file_selected.emit("res://images/selected.png")
	_expect(texture_paths == ["res://images/submitted.png"], "submitted texture path is forwarded")
	_expect(texture_file_paths == ["res://images/selected.png"], "selected texture file is forwarded")
	(view.get("_sprite_hframes") as SpinBox).value_changed.emit(4.0)
	(view.get("_sprite_offset_x") as SpinBox).value_changed.emit(20.0)
	(view.get("_sprite_flip_h") as CheckBox).toggled.emit(false)
	_expect(grid_events.size() == 1 and grid_events[0].get("property_name") == "hframes", "sprite grid edits are forwarded with their property key")
	_expect(offset_events.size() == 1 and offset_events[0].get("axis") == "x", "sprite offset edits are forwarded with their axis")
	_expect(toggle_events.size() == 1 and toggle_events[0].get("property_name") == "flip_h", "sprite toggles are forwarded with their property key")
	var static_texture_row := static_controls.get_child(0) as HBoxContainer
	(static_texture_row.get_child(1) as Button).pressed.emit()
	_expect(texture_browse_count == 1, "texture browse requests are forwarded")

	var animated_sprite := AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite"
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"idle")
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = &"idle"
	animated_sprite.speed_scale = 1.5
	view.call("show_animated_sprite", animated_sprite)
	_expect(panel.visible and not static_controls.visible and animated_controls.visible, "AnimatedSprite2D displays only animation controls")
	_expect((view.get("_visual_type_label") as Label).text == "Выбрана анимация: AnimatedSprite", "animated editor identifies the selected node")
	_expect((view.get("_animation_option") as OptionButton).item_count == 1, "SpriteFrames animation names are listed")
	_expect(view.call("get_animation_id", 0) == StringName("idle"), "animation IDs are available to the controller")
	_expect(not (view.get("_animated_frame") as SpinBox).editable, "empty animations disable frame selection")
	_expect(is_equal_approx((view.get("_animated_speed") as SpinBox).value, 1.5), "animation speed is populated")

	view.call("set_frames_path", "res://animations/initial.tres")
	_expect((view.get("_frames_path_edit") as LineEdit).text == "res://animations/initial.tres", "SpriteFrames path can be updated by the controller")
	(view.get("_frames_path_edit") as LineEdit).text_submitted.emit("res://animations/submitted.tres")
	(view.get("_frames_dialog") as FileDialog).file_selected.emit("res://animations/selected.tres")
	_expect(frame_paths == ["res://animations/submitted.tres"], "submitted SpriteFrames path is forwarded")
	_expect(frame_file_paths == ["res://animations/selected.tres"], "selected SpriteFrames resource is forwarded")
	(view.get("_animation_option") as OptionButton).item_selected.emit(0)
	(view.get("_animated_frame") as SpinBox).value_changed.emit(2.0)
	(view.get("_animated_speed") as SpinBox).value_changed.emit(2.0)
	_expect(animation_events == [0], "animation selection is forwarded")
	_expect(frame_events == [2.0], "animation frame edits are forwarded")
	_expect(speed_events == [2.0], "animation speed edits are forwarded")
	var frames_row := animated_controls.get_child(1) as HBoxContainer
	(frames_row.get_child(1) as Button).pressed.emit()
	_expect(frames_browse_count == 1, "SpriteFrames browse requests are forwarded")

	view.call("hide_editor")
	_expect(not panel.visible, "controller can hide the visual editor")
	root.remove_child(view)
	view.free()
	sprite.free()
	animated_sprite.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder visual editor view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_texture_path(value: String) -> void:
	texture_paths.append(value)


func _on_texture_file(value: String) -> void:
	texture_file_paths.append(value)


func _on_frames_path(value: String) -> void:
	frame_paths.append(value)


func _on_frames_file(value: String) -> void:
	frame_file_paths.append(value)


func _on_grid_changed(value: float, property_name: String) -> void:
	grid_events.append({"value": value, "property_name": property_name})


func _on_offset_changed(value: float, axis: String) -> void:
	offset_events.append({"value": value, "axis": axis})


func _on_toggle_changed(value: bool, property_name: String) -> void:
	toggle_events.append({"value": value, "property_name": property_name})


func _on_animation_selected(index: int) -> void:
	animation_events.append(index)


func _on_frame_changed(value: float) -> void:
	frame_events.append(value)


func _on_speed_changed(value: float) -> void:
	speed_events.append(value)


func _on_texture_browse() -> void:
	texture_browse_count += 1


func _on_frames_browse() -> void:
	frames_browse_count += 1


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
