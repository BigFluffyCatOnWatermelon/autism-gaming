@tool
extends Resource
class_name ObjectCapabilityDefinition

## User-facing capability card. Technical components remain an implementation detail.

@export var capability_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category_id: String = "general"
@export var category_name: String = "Основное"
@export var icon: String = "sparkles"
@export var keywords: PackedStringArray = PackedStringArray()
@export var required_capability_ids: PackedStringArray = PackedStringArray()
@export var component_ids: PackedStringArray = PackedStringArray()
@export var available_in_simple_mode: bool = true
@export var version: int = 1
