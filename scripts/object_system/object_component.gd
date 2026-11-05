@tool
extends Node
class_name ObjectComponent

var component_id: String = ""
var binding_id: String = ""
var target_node_path: NodePath = NodePath(".")
var object_root: Node
var settings: Dictionary = {}


func configure_context(root: Node, stable_binding_id: String, node_path: NodePath) -> void:
	object_root = root
	binding_id = stable_binding_id
	target_node_path = node_path


func configure(values: Dictionary) -> void:
	settings = values.duplicate(true)
	_on_configured()


func get_object_root() -> Node:
	if is_instance_valid(object_root):
		return object_root
	return ObjectFactory.get_object_root(self)


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func get_settings() -> Dictionary:
	return settings.duplicate(true)


func _on_configured() -> void:
	pass
