extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/visual_parts_view.gd")

var failures: Array[String] = []
var selected_paths: Array[NodePath] = []
var visibility_events: Array[Dictionary] = []
var duplicate_paths: Array[NodePath] = []
var remove_paths: Array[NodePath] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	root.add_child(view)
	view.call("build")
	view.connect("part_selected", Callable(self, "_on_part_selected"))
	view.connect("part_visibility_changed, Callable(self, "_on_visibility_changed"))
	view.connect("duplicate_requested", Callable(self, "_on_duplicate_requested"))
	view.connect("remove_requested", Callable(self, "_on_remove_requested"))

	var scene_root := Node2D.new()
	scene_root.name = "ObjectRoot"
	root.add_child(scene_root)
	var visuals := Node2D.new()
	visuals.name = "Visuals"
	scene_root.add_child(visuals)

	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var sprite := Sprite2D.new()
	sprite.name = "Leaf"
	sprite.texture = texture
	visuals.add_child(sprite)

	var animated := AnimatedSprite2D.new()
	animated.name = "Glow"
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", texture)
	animated.sprite_frames = frames
	animated.animation = &"idle"
	visuals.add_child(animated)

	var polygon := Polygon2D.new()
	polygon.name = "Shadow"
	polygon.polygon = PackedVector2Array([Vector2.ZERO, Vector2(12, 0), Vector2(8, 8)])
	visuals.add_child(polygon)

	view.call("set_scene_root", scene_root, NodePath("Visuals/Leaf"))
	_expect(int(view.call("get_part_count")) == 3, "list discovers static sprites, animated sprites and polygons")
	_expect(view.call("get_part_paths") == [
		NodePath("Visuals/Leaf"),
		NodePath("Visuals/Glow"),
		NodePath("Visuals/Shadow")
	], "visual parts keep stable paths relative to the object root")
	_expect(int(view.call("get_visible_row_count")) == 3, "all discovered parts render as rows")
	_expect(str(view.call("get_selected_path")) == "Visuals/Leaf", "initial selected part is retained")
	var row_buttons: Array = view.get("_row_buttons")
	_expect(row_buttons.size() == 3, "each visual part has a selection control")

	view.call("_on_part_selected", NodePath("Visuals/Glow"))
	_expect(selected_paths == [NodePath("Visuals/Glow")], "part selection emits the relative scene path")
	_expect(str(view.call("get_selected_path")) == "Visuals/Glow", "selected part state updates")

	view.call("_on_visibility_toggled", false, NodePath("Visuals/Leaf"))
	view.call("_on_duplicate_requested", NodePath("Visuals/Glow"))
	view.call("_on_remove_requested", NodePath("Visuals/Shadow"))
	_expect(visibility_events == [{"path": NodePath("Visuals/Leaf"), "visible": false}], "visibility requests carry the part path and new state")
	_expect(duplicate_paths == [NodePath("Visuals/Glow")], "duplicate action forwards the selected path")
	_expect(remove_paths == [NodePath("Visuals/Shadow")], "remove action forwards the selected path")

	var search_input := view.get("_search_input") as LineEdit
	search_input.text = "glow"
	_expect(int(view.call("get_visible_row_count")) == 1, "search filters the visible rows by part name")
	search_input.clear()
	_expect(int(view.call("get_visible_row_count")) == 3, "clearing search restores all part rows")

	view.call("set_scene_root", null)
	_expect(int(view.call("get_part_count")) == 0, "closing the object scene clears the parts model")
	_expect(int(view.call("get_visible_row_count")) == 0, "closing the object scene clears rendered rows")

	root.remove_child(view)
	view.free()
	root.remove_child(scene_root)
	scene_root.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder visual parts view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_part_selected(path: NodePath) -> void:
	selected_paths.append(path)


func _on_visibility_changed(path: NodePath, visible: bool) -> void:
	visibility_events.append({"path": path, "visible": visible})


func _on_duplicate_requested(path: NodePath) -> void:
	duplicate_paths.append(path)


func _on_remove_requested(path: NodePath) -> void:
	remove_paths.append(path)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
