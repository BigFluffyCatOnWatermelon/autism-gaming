@tool
extends VBoxContainer
## Displays an object's scene tree and forwards user actions to the editor controller.

signal add_node_requested
signal remove_node_requested
signal refresh_requested
signal node_selected(path: NodePath)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

var tree: Tree
var status_label: Label


func build() -> void:
	if tree != null:
		return
	add_theme_constant_override("separation", 7)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIFactory.create_section_title(self, "ДЕРЕВО СЦЕНЫ")

	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	UIFactory.add_action_button(
		toolbar,
		"+ Дочерний узел",
		_on_add_pressed,
		"Добавить дочерний узел",
		true
	)
	UIFactory.add_action_button(
		toolbar,
		"Удалить",
		_on_remove_pressed,
		"Удаляет выбранный дочерний узел через Undo/Redo."
	)
	UIFactory.add_action_button(
		toolbar,
		"↻",
		_on_refresh_pressed,
		"Обновить дерево открытой сцены объекта."
	)

	tree = Tree.new()
	tree.custom_minimum_size = Vector2(0, 190)
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = false
	tree.select_mode = Tree.SELECT_SINGLE
	tree.item_selected.connect(_on_item_selected)
	add_child(tree)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)


func set_scene_root(scene_root: Node) -> void:
	if tree == null:
		return
	tree.clear()
	if scene_root == null:
		status_label.text = "Открой сцену выбранного объекта, чтобы редактировать её структуру."
		var placeholder := tree.create_item()
		placeholder.set_text(0, "Сцена объекта не открыта")
		placeholder.set_selectable(0, false)
		return

	var root_item := tree.create_item()
	root_item.set_text(0, "%s  <%s>" % [scene_root.name, scene_root.get_class()])
	root_item.set_metadata(0, NodePath("."))
	root_item.set_tooltip_text(0, scene_root.get_path())
	for child in scene_root.get_children():
		_add_node_item(child, root_item, scene_root)
	status_label.text = "Дерево синхронизируется со штатными Scene dock и Inspector. Ctrl+S сохраняет сцену."


func select_node(scene_root: Node, node: Node) -> bool:
	if tree == null or scene_root == null or node == null:
		return false
	if not is_instance_valid(scene_root) or not is_instance_valid(node):
		return false
	if node != scene_root and not scene_root.is_ancestor_of(node):
		return false
	var target_path := scene_root.get_path_to(node)
	var item := _find_item(tree.get_root(), target_path)
	if item == null:
		return false
	item.select(0)
	tree.scroll_to_item(item)
	return true


func get_selected_node(scene_root: Node) -> Node:
	if tree == null or scene_root == null or not is_instance_valid(scene_root):
		return null
	var selected_item := tree.get_selected()
	if selected_item == null:
		return null
	var path_value: Variant = selected_item.get_metadata(0)
	if not (path_value is NodePath):
		return null
	return scene_root.get_node_or_null(NodePath(str(path_value)))


func _add_node_item(node: Node, parent_item: TreeItem, scene_root: Node) -> void:
	var item := tree.create_item(parent_item)
	var display_name := "Параметры объекта" if node is ObjectPropertyData else node.name
	item.set_text(0, "%s  <%s>" % [display_name, node.get_class()])
	item.set_metadata(0, scene_root.get_path_to(node))
	item.set_tooltip_text(0, str(node.get_path()))
	for child in node.get_children():
		_add_node_item(child, item, scene_root)


func _find_item(parent_item: TreeItem, target_path: NodePath) -> TreeItem:
	if parent_item == null:
		return null
	if parent_item.get_metadata(0) == target_path:
		return parent_item
	for child_item in parent_item.get_children():
		var found_item := _find_item(child_item, target_path)
		if found_item != null:
			return found_item
	return null


func _on_item_selected() -> void:
	if tree == null:
		return
	var selected_item := tree.get_selected()
	if selected_item == null:
		return
	var path_value: Variant = selected_item.get_metadata(0)
	if path_value is NodePath:
		node_selected.emit(NodePath(str(path_value)))


func _on_add_pressed() -> void:
	add_node_requested.emit()


func _on_remove_pressed() -> void:
	remove_node_requested.emit()


func _on_refresh_pressed() -> void:
	refresh_requested.emit()
