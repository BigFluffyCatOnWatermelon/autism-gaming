extends Resource
class_name ItemCatalog

@export_enum("tools", "weapons", "food", "materials", "ammunition") var category: String = "materials"
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var items: Array[ItemDefinition] = []
