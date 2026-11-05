@tool
extends Resource
class_name ObjectComponentDefinition

@export var component_id: String = ""
@export var display_name: String = ""
@export_enum("Appearance", "Physics", "Stats", "Combat", "Interaction", "Destruction", "Audio", "Procedural") var category: String = "Stats"
@export_range(1, 1000, 1) var component_version: int = 1
@export var enabled: bool = true
@export var component_script: Script
@export var settings: Dictionary = {}
