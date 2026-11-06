@tool
extends Resource
class_name ObjectNodeDefinition

## One generated node in a reusable ObjectDefinition structure.
## IDs are stable within the object and are not derived from display names.

@export var node_id: String = ""
@export var parent_node_id: String = "root"
## Optional path to an existing node in the base PackedScene. When set, parent_node_id must be root.
@export var parent_node_path: NodePath = NodePath("")
@export var node_type: String = "Node2D"
@export var node_name: String = "Node"
@export var enabled: bool = true
@export var properties: Dictionary = {}
@export var groups: PackedStringArray = PackedStringArray()
@export var metadata: Dictionary = {}
