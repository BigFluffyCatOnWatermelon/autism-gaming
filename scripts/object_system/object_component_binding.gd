@tool
extends Resource
class_name ObjectComponentBinding

## Placement of one component on one node inside an ObjectDefinition scene.
## An empty path or "." means the root object. Explicit paths never fall back to root.

@export var binding_id: String = ""
@export var component_definition: ObjectComponentDefinition
@export var target_node_path: NodePath = NodePath(".")
@export var enabled: bool = true


func get_component_id() -> String:
	if component_definition == null:
		return ""
	return component_definition.component_id.strip_edges().to_lower()


func get_target_node(object_root: Node) -> Node:
	if object_root == null:
		return null
	if target_node_path.is_empty() or str(target_node_path) == ".":
		return object_root
	return object_root.get_node_or_null(target_node_path)


func ensure_binding_id() -> String:
	if binding_id.strip_edges().is_empty():
		binding_id = "binding_%s_%s" % [str(Time.get_ticks_usec()), str(randi())]
	return binding_id
