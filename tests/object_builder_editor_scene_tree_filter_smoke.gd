extends SceneTree

const FilterScript = preload("res://addons/object_builder/services/editor_scene_tree_filter.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node2D.new()
	scene_root.name = "EditedScene"
	root.add_child(scene_root)

	var direct_child := Node2D.new()
	direct_child.name = "Visuals"
	scene_root.add_child(direct_child)
	direct_child.owner = scene_root
	var nested_child := Sprite2D.new()
	nested_child.name = "Sprite"
	direct_child.add_child(nested_child)
	nested_child.owner = scene_root

	var plugin_ui := Control.new()
	plugin_ui.name = "ObjectBuilderUI"
	root.add_child(plugin_ui)
	var canvas_preview := Node2D.new()
	canvas_preview.name = "CanvasPreview"
	plugin_ui.add_child(canvas_preview)

	_expect(FilterScript.belongs_to_scene(scene_root, scene_root), "the edited scene root is accepted")
	_expect(FilterScript.belongs_to_scene(scene_root, direct_child), "direct scene children are accepted")
	_expect(FilterScript.belongs_to_scene(scene_root, nested_child), "nested scene descendants are accepted")
	_expect(not FilterScript.belongs_to_scene(scene_root, plugin_ui), "plugin UI is ignored")
	_expect(not FilterScript.belongs_to_scene(scene_root, canvas_preview), "Canvas preview is ignored")
	_expect(not FilterScript.belongs_to_scene(null, nested_child), "a missing edited scene is ignored")
	_expect(not FilterScript.belongs_to_scene(scene_root, null), "a missing changed node is ignored")

	if failures.is_empty():
		print("Object Builder editor scene tree filter: all checks passed.")
	else:
		for failure in failures:
			push_error(failure)
		print("Object Builder editor scene tree filter: %d failure(s)." % failures.size())

	plugin_ui.free()
	scene_root.free()
	quit(1 if not failures.is_empty() else 0)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
