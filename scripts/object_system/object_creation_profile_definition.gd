@tool
extends Resource
class_name ObjectCreationProfileDefinition

## Optional starting suggestions. A profile must never restrict later object capabilities.

@export var profile_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var suggested_category: String = "Other"
@export var suggested_root_type: String = "Node2D"
@export var icon: String = "shapes"
@export var suggested_properties: Array[ObjectPropertyDefinition] = []
@export var suggested_capability_ids: PackedStringArray = PackedStringArray()
@export var version: int = 1
