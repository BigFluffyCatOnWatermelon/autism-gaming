extends RefCounted
class_name ObjectCapabilityCatalog

## The friendly catalogue presented by the Simple mode. It maps to internal components.

static func get_categories() -> Array[Dictionary]:
	return [
		{"id": "general", "display_name": "Основное"},
		{"id": "stats", "display_name": "Характеристики"},
		{"id": "interaction", "display_name": "Взаимодействие"},
		{"id": "combat", "display_name": "Бой"},
		{"id": "destruction", "display_name": "Разрушение"}
	]


static func get_capability_ids(category_id: String = "") -> PackedStringArray:
	var all_ids := PackedStringArray([
		"has_health",
		"can_receive_damage",
		"can_attack",
		"breaks_when_health_empty"
	])
	if category_id.is_empty():
		return all_ids
	var result := PackedStringArray()
	for capability_id in all_ids:
		var definition := get_definition(capability_id)
		if definition != null and definition.category_id == category_id:
			result.append(capability_id)
	return result


static func get_definition(capability_id: String) -> ObjectCapabilityDefinition:
	var normalized_id := capability_id.strip_edges().to_lower()
	var definition := ObjectCapabilityDefinition.new()
	definition.capability_id = normalized_id
	match normalized_id:
		"has_health":
			definition.display_name = "Есть здоровье"
			definition.description = "У объекта есть запас здоровья. Его можно уменьшать и восстанавливать."
			definition.category_id = "stats"
			definition.category_name = "Характеристики"
			definition.icon = "heart"
			definition.keywords = PackedStringArray(["здоровье", "прочность", "жизнь", "hp"])
			definition.component_ids = PackedStringArray(["health"])
		"can_receive_damage":
			definition.display_name = "Можно повредить"
			definition.description = "Объект принимает урон. Здоровье будет добавлено автоматически."
			definition.category_id = "combat"
			definition.category_name = "Бой"
			definition.icon = "shield"
			definition.keywords = PackedStringArray(["урон", "повреждение", "атака", "здоровье"])
			definition.required_capability_ids = PackedStringArray(["has_health"])
			definition.component_ids = PackedStringArray(["damageable"])
		"can_attack":
			definition.display_name = "Может атаковать"
			definition.description = "Объект может наносить урон другим объектам, которые умеют его получать."
			definition.category_id = "combat"
			definition.category_name = "Бой"
			definition.icon = "swords"
			definition.keywords = PackedStringArray(["атака", "урон", "нападение"])
			definition.component_ids = PackedStringArray(["attack"])
		"breaks_when_health_empty":
			definition.display_name = "Разрушается при потере здоровья"
			definition.description = "Когда здоровье закончится, объект перейдёт в разрушенное состояние. Здоровье добавится автоматически."
			definition.category_id = "destruction"
			definition.category_name = "Разрушение"
			definition.icon = "hammer"
			definition.keywords = PackedStringArray(["разрушение", "сломать", "ломается", "прочность"])
			definition.required_capability_ids = PackedStringArray(["has_health"])
			definition.component_ids = PackedStringArray(["destructible"])
		_:
			return null
	return definition


static func has_capability(capability_id: String) -> bool:
	return get_definition(capability_id) != null


static func create_selection(capability_id: String) -> ObjectCapabilitySelection:
	if not has_capability(capability_id):
		return null
	var selection := ObjectCapabilitySelection.new()
	selection.capability_id = capability_id.strip_edges().to_lower()
	return selection
