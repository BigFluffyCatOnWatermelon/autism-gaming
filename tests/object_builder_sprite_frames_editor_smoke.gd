extends SceneTree

const DialogScript = preload("res://addons/object_builder/ui/sprite_frames_editor_dialog.gd")

var failures: Array[String] = []
var accepted_frames: Array[SpriteFrames] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := SpriteFrames.new()
	source.clear_all()
	source.remove_animation(&"default")
	source.add_animation(&"idle")
	var first_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	first_image.fill(Color.WHITE)
	var first_texture := ImageTexture.create_from_image(first_image)
	source.add_frame(&"idle", first_texture)

	var dialog = DialogScript.new()
	root.add_child(dialog)
	await process_frame
	dialog.connect("frames_accepted", Callable(self, "_on_frames_accepted"))
	dialog.call("open_for_sprite_frames", source)
	var working := dialog.call("get_working_frames") as SpriteFrames
	_expect(working != null and working != source, "editor works on an isolated SpriteFrames copy")
	_expect(int(dialog.call("get_animation_count")) == 1, "existing animations are loaded")

	dialog.call("_add_animation")
	_expect(int(dialog.call("get_animation_count")) == 2, "new animation can be created")
	var animation_name := dialog.get("_animation_name") as LineEdit
	animation_name.text = "walk"
	dialog.call("_rename_current_animation")
	_expect(working.has_animation(&"walk"), "selected animation can be renamed")

	var second_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	second_image.fill(Color.RED)
	var second_texture := ImageTexture.create_from_image(second_image)
	_expect(bool(dialog.call("add_frame", first_texture, 0.5)), "frame can be appended to the selected animation")
	_expect(bool(dialog.call("add_frame", second_texture, 0.75)), "multiple frames can be appended")
	_expect(int(dialog.call("get_frame_count")) == 2, "frame list reflects added frames")
	_expect(bool(dialog.call("move_selected_frame", -1)), "selected frame can be moved in the animation")
	var reordered_texture := working.get_frame_texture(&"walk", 0)
	_expect(reordered_texture != null and reordered_texture.get_image().get_pixel(0, 0) == Color.RED, "frame reordering changes the actual SpriteFrames order")
	_expect(bool(dialog.call("replace_selected_frame", first_texture)), "selected frame texture can be replaced")
	dialog.call("_on_fps_changed", 12.0)
	dialog.call("_on_loop_mode_selected", 2)
	_expect(int(working.get_animation_loop_mode(&"walk")) == 2, "ping-pong loop mode is editable")
	dialog.call("_on_loop_mode_selected", 0)
	_expect(is_equal_approx(working.get_animation_speed(&"walk"), 12.0), "animation FPS is editable")
	_expect(int(working.get_animation_loop_mode(&"walk")) == 0, "no-loop mode is editable")
	_expect(bool(dialog.call("remove_selected_frame")), "selected frame can be removed")
	_expect(int(dialog.call("get_frame_count")) == 1, "removing a frame updates the frame list")

	dialog.call("open_for_sprite_frames", null)
	var new_resource := dialog.call("get_working_frames") as SpriteFrames
	_expect(int(dialog.call("get_animation_count")) == 1 and new_resource.has_animation(&"default"), "new SpriteFrames resource starts with an editable default animation")
	_expect(int(dialog.call("get_frame_count")) == 0, "new default animation starts empty")
	dialog.call("_remove_current_animation")
	_expect(int(dialog.call("get_animation_count")) == 1 and (dialog.call("get_working_frames") as SpriteFrames).has_animation(&"default"), "removing the last animation safely recreates an empty default")
	dialog.call("_on_confirmed")
	_expect(accepted_frames.size() == 1, "applying the editor emits a completed resource")
	if not accepted_frames.is_empty():
		_expect(accepted_frames[0] != source and accepted_frames[0] != working, "accepted resource is isolated from source and editing buffer")
		_expect(accepted_frames[0].has_animation(&"walk"), "accepted resource contains edited animation metadata")
		_expect(accepted_frames[0].get_frame_count(&"walk") == 1, "accepted resource contains the final frame list")

	dialog.queue_free()
	await process_frame
	if failures.is_empty():
		print("Object Builder SpriteFrames editor tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_frames_accepted(frames: SpriteFrames) -> void:
	accepted_frames.append(frames)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
