extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/sprite_quick_settings_view.gd")

var failures: Array[String] = []
var changes: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	root.add_child(view)
	view.call("build")
	view.connect("property_changed", Callable(self, "_on_property_changed"))

	var sprite := Sprite2D.new()
	sprite.name = "AtlasSprite"
	sprite.hframes = 4
	sprite.vframes = 3
	sprite.frame = 6
	sprite.region_enabled = true
	sprite.region_rect = Rect2(12.0, 24.0, 96.0, 48.0)
	view.call("set_selected_node", sprite, NodePath("Visuals/AtlasSprite"))

	_expect(bool(view.call("is_visible_for_selection")), "quick settings are visible for Sprite2D")
	_expect(is_equal_approx((view.get("_hframes") as SpinBox).value, 4.0), "horizontal frame count is loaded")
	_expect(is_equal_approx((view.get("_vframes") as SpinBox).value, 3.0), "vertical frame count is loaded")
	_expect(is_equal_approx((view.get("_frame") as SpinBox).value, 6.0), "current frame is loaded")
	_expect((view.get("_region_enabled") as CheckBox).button_pressed, "region toggle follows the selected sprite")
	_expect(is_equal_approx((view.get("_region_x") as SpinBox).value, 12.0), "atlas region X is loaded")
	_expect(is_equal_approx((view.get("_region_y") as SpinBox).value, 24.0), "atlas region Y is loaded")
	_expect(is_equal_approx((view.get("_region_width") as SpinBox).value, 96.0), "atlas region width is loaded")
	_expect(is_equal_approx((view.get("_region_height") as SpinBox).value, 48.0), "atlas region height is loaded")

	(view.get("_hframes") as SpinBox).value_changed.emit(8.0)
	(view.get("_vframes") as SpinBox).value_changed.emit(2.0)
	(view.get("_frame") as SpinBox).value_changed.emit(3.0)
	(view.get("_region_enabled") as CheckBox).toggled.emit(false)
	(view.get("_region_x") as SpinBox).value_changed.emit(16.0)
	(view.get("_region_y") as SpinBox).value_changed.emit(32.0)
	(view.get("_region_width") as SpinBox).value_changed.emit(128.0)
	(view.get("_region_height") as SpinBox).value_changed.emit(64.0)
	_expect(changes.size() == 8, "all frame-grid and atlas controls emit a property change")
	_expect(changes[0].get("property") == "hframes" and changes[0].get("value") == 8, "HFrames uses the expected property key and integer value")
	_expect(changes[1].get("property") == "vframes" and changes[1].get("value") == 2, "VFrames uses the expected property key and integer value")
	_expect(changes[2].get("property") == "frame" and changes[2].get("value") == 3, "frame selection is forwarded")
	_expect(changes[3].get("property") == "region_enabled" and changes[3].get("value") == false, "region toggle is forwarded")
	_expect(changes[4].get("property") == "region_x" and changes[4].get("value") == 16.0, "region X is forwarded")
	_expect(changes[7].get("property") == "region_height" and changes[7].get("value") == 64.0, "region height is forwarded")

	var animated := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8)))
	frames.add_animation(&"walk")
	frames.add_frame(&"walk", ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8)))
	animated.sprite_frames = frames
	animated.animation = &"idle"
	animated.frame = 0
	animated.speed_scale = 1.5
	view.call("set_selected_node", animated, NodePath("Visuals/Animated"))
	_expect(bool(view.call("is_visible_for_selection")), "quick settings are visible for AnimatedSprite2D")
	_expect(view.get("_sprite_controls").visible == false and view.get("_animated_controls").visible, "AnimatedSprite2D displays animation controls instead of atlas controls")
	var animation_option := view.get("_animation_option") as OptionButton
	var idle_index := -1
	var walk_index := -1
	for index in range(animation_option.item_count):
		var animation_id := str(animation_option.get_item_metadata(index))
		if animation_id == "idle":
			idle_index = index
		elif animation_id == "walk":
			walk_index = index
	_expect(idle_index >= 0 and walk_index >= 0, "available SpriteFrames animations are listed")
	_expect(animation_option.selected == idle_index, "current animation is selected")
	_expect(is_equal_approx((view.get("_animated_speed") as SpinBox).value, 1.5), "animation speed is populated")
	animation_option.item_selected.emit(walk_index)
	(view.get("_animated_frame") as SpinBox).value_changed.emit(0.0)
	(view.get("_animated_speed") as SpinBox).value_changed.emit(2.0)
	_expect(changes.size() == 11, "animated sprite controls emit animation, frame and speed changes")
	_expect(changes[8].get("property") == "animation" and changes[8].get("value") == StringName("walk"), "animation selection emits the chosen StringName")
	_expect(changes[9].get("property") == "frame", "animated frame selection is forwarded")
	_expect(changes[10].get("property") == "speed_scale" and changes[10].get("value") == 2.0, "animation speed changes are forwarded")
	view.call("set_selected_node", null, NodePath(""))
	_expect(not bool(view.call("is_visible_for_selection")), "sprite quick settings are hidden when no part is selected")

	root.remove_child(view)
	view.free()
	sprite.free()
	animated.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder sprite quick settings tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_property_changed(path: NodePath, property_name: String, value: Variant) -> void:
	changes.append({"path": path, "property": property_name, "value": value})


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
