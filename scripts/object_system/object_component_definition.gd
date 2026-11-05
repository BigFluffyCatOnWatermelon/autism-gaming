@tool
extends Resource
class_name ObjectComponentDefinition

@export var component_id: String = ""
@export var display_name: String = ""
@export var enabled: bool = true
@export var component_script: Script
@export var settings: Dictionary = {}
