@tool
extends Resource
class_name GameplayTableDefinition

## Editable external table. Different table types keep their own entry semantics.
@export var table_id: String = ""
@export_enum("yield", "recipe", "production", "loot") var table_type: String = "yield"
@export_multiline var description: String = ""
@export var entries: Array[Dictionary] = []
