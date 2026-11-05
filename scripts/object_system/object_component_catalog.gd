extends RefCounted
class_name ObjectComponentCatalog

const HEALTH_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/health_component.gd")

const CATEGORY_DEFINITIONS := [
	{"id": "Appearance", "display_name": "Внешний вид"},
	{"id": "Physics", "display_name": "Физика"},
	{"id": "Stats", "display_name": "Характеристики"},
	{"id": "Combat", "display_name": "Бой"},
	{"id": "Interaction", "display_name": "Взаимодействие"},
	{"id": "Destruction", "display_name": "Разрушение"},
	{"id": "Audio", "display_name": "Звук"},
	{"id": "Procedural", "display_name": "Процедурная генерация"}
]


static func get_categories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category in CATEGORY_DEFINITIONS:
		result.append(category.duplicate(true))
	return result


static func get_category_display_name(category_id: String) -> String:
	for category in CATEGORY_DEFINITIONS:
		if str(category.get("id", "")) == category_id:
			return str(category.get("display_name", category_id))
	return category_id


static func get_component_ids(category_id: String = "") -> PackedStringArray:
	if category_id.is_empty() or category_id == "Stats":
		return PackedStringArray(["health"])
	return PackedStringArray()


static func has_component(component_id: String) -> bool:
	return component_id.strip_edges().to_lower() == "health"


static func create_definition(component_id: String) -> ObjectComponentDefinition:
	if component_id.strip_edges().to_lower() != "health":
		return null

	var definition := ObjectComponentDefinition.new()
	definition.component_id = "health"
	definition.display_name = "Здоровье"
	definition.category = "Stats"
	definition.component_version = 1
	definition.component_script = HEALTH_COMPONENT_SCRIPT
	definition.settings = {
		"max_health": 100.0,
		"starting_health": 100.0,
		"invulnerable": false,
		"can_heal": true
	}
	return definition


static func create_all_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for component_id in get_component_ids():
		var definition := create_definition(component_id)
		if definition != null:
			result.append(definition)
	return result
