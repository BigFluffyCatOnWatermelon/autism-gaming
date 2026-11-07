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
	view.call("set_selected_node", animated, NodePath("Visuals/Animated"))
	_expect(not bool(view.call("is_visible_for_selection")), "Sprite2D-specific settings are hidden for AnimatedSprite2D")
	view.call("set_selected_node", null, NodePath(""))
	_expect(not bool(view.call("is_visible_for_selection")), "Sprite2D-specific settings are hidden when no part is selected")

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
