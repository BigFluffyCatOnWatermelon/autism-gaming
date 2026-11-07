@tool
extends RefCounted
class_name CapabilityPresetRegistry
## Curated, editable bundles of ready capabilities. Presets never create mechanics.

const PRESETS := [
	{
		"id": "breakable_resource",
		"display_name": "Разрушаемый ресурс",
		"description": "Прочный объект, который принимает урон, разрушается и оставляет результат.",
		"icon": "pickaxe",
		"capability_ids": [
			"has_health",
			"can_receive_damage",
			"breaks_when_health_empty",
			"spawns_debris",
			"drops_loot_on_destroy",
			"can_regrow"
		]
	},
	{
		"id": "armored_enemy",
		"display_name": "Бронированный противник",
		"description": "Существо с атакой, здоровьем и несколькими уровнями защиты.",
		"icon": "shield",
		"capability_ids": [
			"has_health",
			"can_receive_damage",
			"can_attack",
			"has_armor",
			"has_damage_resistance",
			"has_invulnerability_window"
		]
	},
	{
		"id": "durable_building",
		"display_name": "Прочная постройка",
		"description": "Постройка выдерживает повреждения, может разрушаться и ремонтироваться.",
		"icon": "house",
		"capability_ids": [
			"has_health",
			"can_receive_damage",
			"has_armor",
			"has_damage_resistance",
			"breaks_when_health_empty",
			"has_destruction_stages",
			"can_be_repaired"
		]
	},
	{
		"id": "shielded_guard",
		"display_name": "Защищённый страж",
		"description": "Персонаж атакует, защищается щитом и восстанавливает здоровье.",
		"icon": "shield-check",
		"capability_ids": [
			"has_health",
			"can_receive_damage",
			"can_attack",
			"has_shield",
			"has_invulnerability_window",
			"regenerates_health"
		]
	},
	{
		"id": "interactive_object",
		"display_name": "Интерактивный объект",
		"description": "Объект реагирует на действие игрока и при необходимости может быть повреждён.",
		"icon": "hand",
		"capability_ids": [
			"can_interact",
			"has_health",
			"can_receive_damage",
			"breaks_when_health_empty",
			"drops_loot_on_destroy"
		]
	},
	{
		"id": "pickup_item",
		"display_name": "Подбираемый предмет",
		"description": "Базовая возможность подбора предмета в существующий инвентарь.",
		"icon": "package",
		"capability_ids": [
			"is_pickup_item"
		]
	}
]


static func get_presets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for preset in PRESETS:
		result.append(preset.duplicate(true))
	return result


static func get_preset(preset_id: String) -> Dictionary:
	var normalized_id := preset_id.strip_edges().to_lower()
	for preset in PRESETS:
		if str(preset.get("id", "")) == normalized_id:
			return preset.duplicate(true)
	return {}


static func validate_registry() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_preset_ids: Dictionary = {}
	for preset in PRESETS:
		var preset_id := str(preset.get("id", "")).strip_edges().to_lower()
		if preset_id.is_empty():
			errors.append("У набора возможностей должен быть ID.")
		elif seen_preset_ids.has(preset_id):
			errors.append("Повторяется ID набора возможностей: " + preset_id)
		else:
			seen_preset_ids[preset_id] = true

		var seen_capabilities: Dictionary = {}
		var capability_ids: Variant = preset.get("capability_ids", [])
		if not capability_ids is Array:
			errors.append("У набора '%s' список возможностей должен быть массивом." % preset_id)
			continue
		for capability_id_value in capability_ids:
			var capability_id := str(capability_id_value).strip_edges().to_lower()
			if capability_id.is_empty():
				errors.append("У набора '%s' есть пустой ID возможности." % preset_id)
				continue
			if seen_capabilities.has(capability_id):
				errors.append("В наборе '%s' повторяется возможность '%s'." % [preset_id, capability_id])
				continue
			seen_capabilities[capability_id] = true
			var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
			if definition == null:
				errors.append("Набор '%s' ссылается на неизвестную возможность '%s'." % [preset_id, capability_id])
			elif not definition.is_ready():
				errors.append("Набор '%s' содержит неготовую возможность '%s'." % [preset_id, capability_id])
	return errors
