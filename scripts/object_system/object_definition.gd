@tool
extends Resource
class_name ObjectDefinition

const CURRENT_SCHEMA_VERSION := 3

@export var schema_version: int = CURRENT_SCHEMA_VERSION
@export var object_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: String = "Nature"
@export var object_type: String = "other"
@export var tags: PackedStringArray = PackedStringArray()
@export var root_type: String = "Node2D"
@export var scene: PackedScene
@export var scene_path: String = ""
@export var preview_texture: Texture2D
@export var is_template: bool = false
@export var template_id: String = ""
@export var custom_properties: Array[ObjectPropertyDefinition] = []

## Legacy root-level component definitions. Kept for existing library data and API users.
@export var components: Array[ObjectComponentDefinition] = []

## New component placements. Each binding can target any node in the object scene.
@export var component_bindings: Array[ObjectComponentBinding] = []
