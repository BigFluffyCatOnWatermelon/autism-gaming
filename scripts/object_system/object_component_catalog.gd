extends RefCounted
class_name ObjectComponentCatalog

const HEALTH_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/health_component.gd")
const DAMAGEABLE_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/damageable_component.gd")
const ATTACK_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/attack_component.gd")

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
	if category_id.is_empty():
		return PackedStringArray(["health", "damageable", "attack"])
	if category_id == "Stats":
		return PackedStringArray(["health"])
	if category_id == "Combat":
		return PackedStringArray(["damageable", "attack"])
	return PackedStringArray()


static func get_component_display_name(component_id: String) -> String:
	match component_id.strip_edges().to_lower():
		"health":
			return "Здоровье"
		"damageable":
			return "Приём урона"
		"attack":
			return "Атака"
		_:
			return component_id


static func get_component_description(component_id: String) -> String:
	match component_id.strip_edges().to_lower():
		"health":
			return "Запас здоровья, получение урона, лечение и сигнал смерти."
		"damageable":
			return "Принимает урон, применяет множитель и плоское снижение, передаёт результат компоненту Health."
		"attack":
			return "Наносит урон цели с Damageable, проверяет расстояние и перезарядку."
		_:
			return "Компонент без описания."


static func has_component(component_id: String) -> bool:
	return component_id.strip_edges().to_lower() in ["health", "damageable", "attack"]


static func create_definition(component_id: String) -> ObjectComponentDefinition:
	var normalized_id := component_id.strip_edges().to_lower()
	if normalized_id not in ["health", "damageable", "attack"]:
		return null

	var definition := ObjectComponentDefinition.new()
	definition.component_id = normalized_id
	definition.display_name = get_component_display_name(normalized_id)
	definition.category = "Stats" if normalized_id == "health" else "Combat"
	definition.component_version = 1
	match normalized_id:
		"health":
			definition.component_script = HEALTH_COMPONENT_SCRIPT
		"damageable":
			definition.component_script = DAMAGEABLE_COMPONENT_SCRIPT
		"attack":
			definition.component_script = ATTACK_COMPONENT_SCRIPT
	definition.setting_definitions = ObjectComponentDefinition.get_builtin_setting_definitions(normalized_id)
	for setting_definition in definition.setting_definitions:
		var setting_key := str(setting_definition.get("key", ""))
		if not setting_key.is_empty():
			definition.settings[setting_key] = setting_definition.get("default_value")
	return definition


static func create_all_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for component_id in get_component_ids():
		var definition := create_definition(component_id)
		if definition != null:
			result.append(definition)
	return result
