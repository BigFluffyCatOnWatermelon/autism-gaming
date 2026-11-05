@tool
extends Resource
class_name ObjectPropertyDefinition

@export var property_id: String = ""
@export var display_name: String = ""
@export_enum("String", "Integer", "Float", "Boolean", "Vector2") var value_type: String = "String"
@export var default_value: Variant = ""
@export var group_name: String = "Основное"
@export_multiline var description: String = ""
@export var advanced: bool = false
@export var has_range: bool = false
@export var minimum: float = 0.0
@export var maximum: float = 100.0
