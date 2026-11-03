extends Resource
class_name ItemDefinition

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("tools", "weapons", "food", "materials", "ammunition") var category: String = "materials"
@export var stack_limit: int = 99
@export var icon: Texture2D
@export var properties: Dictionary = {}
@export var combat_stats: Dictionary = {}
