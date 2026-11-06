@tool
extends Resource
class_name ObjectSignalConnectionDefinition

## Declarative signal connection between nodes in one ObjectDefinition.
## Use "root" for the root node; other endpoints reference ObjectNodeDefinition.node_id.

@export var connection_id: String = ""
@export var source_node_id: String = "root"
@export var signal_name: String = ""
@export var target_node_id: String = "root"
@export var method_name: String = ""
@export_flags("Deferred", "Persist", "One Shot", "Reference Counted") var flags: int = 0
@export var enabled: bool = true
