extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/scene_tree_view.gd")

var failures: Array[String] = []
var selected_paths: Array[NodePath] = []
var renamed_nodes: Array[Dictionary] = []
var add_requests := 0
var duplicate_requests := 0
var remove_requests := 0
var refresh_requests := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	root.add_child(view)
	view.call("build")
	view.connect("node_selected", Callable(self, "_on_node_selected"))
	view.connect("node_rename_requested", Callable(self, "_on_node_rename_requested"))
	view.connect("duplicate_node_requested", Callable(self, "_on_duplicate_requested"))
	view.connect("add_node_requested", Callable(self, "_on_add_requested"))
	view.connect("remove_node_requested", Callable(self, "_on_remove_requested"))
	view.connect("refresh_requested", Callable(self, "_on_refresh_requested"))

	_expect(view.get_child_count() == 4, "scene tree view owns title, toolbar, tree and status")
	var tree := view.get("tree") as Tree
	_expect(tree != null, "scene tree control is created by the view")
	_expect(tree.columns == 2, "scene tree separates editable part names from node types")

	var scene_root := Node2D.new()
	scene_root.name = "ObjectRoot"
	root.add_child(scene_root)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	scene_root.add_child(sprite)
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	sprite.add_child(collision)

	view.call("set_scene_root", scene_root)
	var root_item := tree.get_root()
	_expect(root_item != null and str(root_item.get_text(0)).contains("ObjectRoot"), "scene root is rendered")
	_expect(root_item != null and root_item.get_text(1) == "Node2D", "scene root type is displayed in its own column")
	var sprite_item: TreeItem = root_item.get_first_child() if root_item != null else null
	_expect(sprite_item != null and sprite_item.get_text(0) == "Sprite", "child nodes are rendered recursively")
	_expect(sprite_item != null and sprite_item.get_text(1) == "Sprite2D", "child node type is visible separately")
	_expect(sprite_item != null and sprite_item.is_editable(0), "child part names can be edited inline")
	if sprite_item != null:
		_expect(sprite_item.get_metadata(0) == NodePath("Sprite"), "tree entries retain paths relative to the edited scene")

	var selected := bool(view.call("select_node", scene_root, sprite))
	_expect(selected, "a node in the scene can be selected by the controller")
	_expect(view.call("get_selected_node", scene_root) == sprite, "the selected node can be resolved back to the scene")
	tree.item_selected.emit()
	_expect(not selected_paths.is_empty() and selected_paths[-1] == NodePath("Sprite"), "selection is forwarded as a scene-relative path")
	view.call("request_rename", NodePath("Sprite"), "SpriteRenamed")
	_expect(renamed_nodes.size() == 1 and renamed_nodes[0].get("new_name") == "SpriteRenamed", "inline rename requests are forwarded with their scene path")

	var outside_node := Sprite2D.new()
	_expect(not bool(view.call("select_node", scene_root, outside_node)), "nodes outside the edited scene cannot be selected")
	outside_node.free()

	var toolbar := view.get_child(1) as HBoxContainer
	(toolbar.get_child(0) as Button).pressed.emit()
	(toolbar.get_child(1) as Button).pressed.emit()
	(toolbar.get_child(2) as Button).pressed.emit()
	(toolbar.get_child(3) as Button).pressed.emit()
	_expect(add_requests == 1, "add action is forwarded to the controller")
	_expect(duplicate_requests == 1, "duplicate action is forwarded to the controller")
	_expect(remove_requests == 1, "remove action is forwarded to the controller")
	_expect(refresh_requests == 1, "refresh action is forwarded to the controller")

	view.call("set_scene_root", null)
	_expect(tree.get_root() != null and tree.get_root().get_text(0) == "Сцена объекта не открыта", "missing scenes show a non-selectable empty state")
	_expect(view.call("get_selected_node", scene_root) == null, "empty state does not expose a stale selection")

	root.remove_child(view)
	view.free()
	root.remove_child(scene_root)
	scene_root.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder scene tree view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_node_selected(path: NodePath) -> void:
	selected_paths.append(path)


func _on_add_requested() -> void:
	add_requests += 1


func _on_duplicate_requested() -> void:
	duplicate_requests += 1


func _on_node_rename_requested(path: NodePath, new_name: String) -> void:
	renamed_nodes.append({"path": path, "new_name": new_name})


func _on_remove_requested() -> void:
	remove_requests += 1


func _on_refresh_requested() -> void:
	refresh_requests += 1


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
