@tool
extends RefCounted

const SCRIPT = preload("res://addons/web_object_builder/mechanics/containers/component.gd")
const CATEGORY_ID := "containers"
const CATEGORY_NAME := "Хранилища"
const STATE_NOTE := "Контейнерный runtime API: хранение, вместимость, замки/ключи, доступ по владельцу и фракции, добыча содержимого, общие хранилища, связи, сортировка и сериализация."

const DEFINITIONS := [
	{"id":"stores_items","name":"Имеет хранилище","description":"Создаёт содержимое контейнера и предоставляет операции добавления и изъятия.","defaults":{"initial_contents_json":"[]"},"settings":[{"key":"initial_contents_json","display_name":"Начальное содержимое JSON","value_type":"String","default_value":"[]","group_name":"Содержимое"}]},
	{"id":"has_container_capacity","name":"Вместимость контейнера","description":"Ограничивает число стопок и суммарный вес содержимого.","defaults":{"max_slots":24,"max_weight":0.0},"settings":[{"key":"max_slots","display_name":"Максимум стопок","value_type":"Integer","default_value":24,"group_name":"Вместимость контейнера","has_range":true,"minimum":1,"maximum":10000},{"key":"max_weight","display_name":"Максимальный вес контейнера (0 — без лимита)","value_type":"Float","default_value":0.0,"group_name":"Вместимость контейнера","has_range":true,"minimum":0.0,"maximum":100000000.0}]},
	{"id":"can_be_locked","name":"Замок","description":"Управляет общим состоянием замка: начальная блокировка, ключ для запирания и отдельные правила отпирания.","defaults":{"initially_locked":false,"lock_key_id":"","unlock_enabled":false,"unlock_requires_key":false,"unlock_key_id":""},"settings":[{"key":"initially_locked","display_name":"Заперт изначально","value_type":"Boolean","default_value":false,"group_name":"Замок"},{"key":"lock_key_id","display_name":"ID ключа для запирания","value_type":"String","default_value":"","group_name":"Запирание"},{"key":"unlock_enabled","display_name":"Разрешить отпирание","value_type":"Boolean","default_value":false,"group_name":"Отпирание"},{"key":"unlock_requires_key","display_name":"Требовать ключ для отпирания","value_type":"Boolean","default_value":false,"group_name":"Отпирание"},{"key":"unlock_key_id","display_name":"ID ключа для отпирания","value_type":"String","default_value":"","group_name":"Отпирание"}]},
	{"id":"can_be_unlocked","name":"Можно отпереть","description":"Снимает блокировку после проверки обязательного ключа.","defaults":{"requires_key":false,"unlock_key_id":""},"settings":[{"key":"requires_key","display_name":"Требовать ключ","value_type":"Boolean","default_value":false,"group_name":"Замок"},{"key":"unlock_key_id","display_name":"ID ключа","value_type":"String","default_value":"","group_name":"Замок"}]},
	{"id":"can_be_looted","name":"Можно обыскать","description":"Разрешает просмотр и изъятие содержимого через loot/remove_item.","defaults":{"loot_enabled":true},"settings":[{"key":"loot_enabled","display_name":"Разрешить обыск","value_type":"Boolean","default_value":true,"group_name":"Доступ"}]},
	{"id":"has_shared_storage","name":"Общее хранилище","description":"Подключает содержимое к общей группе хранилища; по желанию разрешает связывание контейнеров.","defaults":{"shared_group_id":"","allow_links":false},"settings":[{"key":"shared_group_id","display_name":"ID общего хранилища","value_type":"String","default_value":"","group_name":"Общее хранилище"},{"key":"allow_links","display_name":"Разрешить связывание контейнеров","value_type":"Boolean","default_value":false,"group_name":"Связи"}]},
	{"id":"supports_container_links","name":"Связанные контейнеры","description":"Объединяет состояние двух контейнеров в одну группу общего хранения.","defaults":{"allow_links":true},"settings":[{"key":"allow_links","display_name":"Разрешить связывание","value_type":"Boolean","default_value":true,"group_name":"Связи"}]},
	{"id":"has_container_permissions","name":"Права доступа","description":"Ограничивает доступ владельцем, фракциями или публичным режимом.","defaults":{"owner_id":"","allowed_factions_csv":"","public_access":true},"settings":[{"key":"owner_id","display_name":"ID владельца","value_type":"String","default_value":"","group_name":"Права"},{"key":"allowed_factions_csv","display_name":"Разрешённые фракции","value_type":"String","default_value":"","group_name":"Права"},{"key":"public_access","display_name":"Публичный доступ","value_type":"Boolean","default_value":true,"group_name":"Права"}]},
	{"id":"supports_auto_sort","name":"Автосортировка содержимого","description":"Сортирует содержимое контейнера по имени, весу или количеству.","defaults":{"default_sort":"name"},"settings":[{"key":"default_sort","display_name":"Режим сортировки","value_type":"String","default_value":"name","group_name":"Сортировка"}]},
	{"id":"has_container_persistence","name":"Сохранение содержимого","description":"Объявляет контейнер сохраняемым и поддерживает экспорт/восстановление runtime-состояния.","defaults":{"persistent":true},"settings":[{"key":"persistent","display_name":"Сохранять содержимое","value_type":"Boolean","default_value":true,"group_name":"Сохранение"}]}
]


func _settings_for(item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for setting in item.settings:
		result.append(setting.duplicate(true))
	return result


func build_component_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for item in DEFINITIONS:
		var definition := ObjectComponentDefinition.new()
		definition.component_id = str(item.id)
		definition.display_name = str(item.name)
		definition.description = str(item.description)
		definition.category = "Containers"
		definition.category_id = "Containers"
		definition.category_display_name = CATEGORY_NAME
		definition.component_version = 1
		definition.component_script = SCRIPT
		definition.setting_definitions = _settings_for(item)
		definition.settings = item.defaults.duplicate(true)
		if str(item.id) != "stores_items":
			# Child options share one visible storage capability. Each remains
			# independently switchable inside that capability's settings dialog.
			definition.settings["enabled"] = false
			definition.setting_definitions.push_front({
				"key": "enabled",
				"display_name": "Включено",
				"value_type": "Boolean",
				"default_value": false,
				"group_name": "Основное"
			})
		result.append(definition)
	return result


func build_capability_definitions() -> Array[ObjectCapabilityDefinition]:
	var result: Array[ObjectCapabilityDefinition] = []
	for item in DEFINITIONS:
		var definition := ObjectCapabilityDefinition.new()
		definition.capability_id = str(item.id)
		definition.display_name = str(item.name)
		definition.description = str(item.description)
		definition.category_id = CATEGORY_ID
		definition.category_name = CATEGORY_NAME
		definition.icon = "archive"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "хранилище", "сундук"])
		definition.component_ids = PackedStringArray([str(item.id)])
		match str(item.id):
			"has_container_capacity", "can_be_locked", "can_be_looted", "has_shared_storage", "has_container_permissions", "supports_auto_sort", "has_container_persistence":
				definition.merged_into_capability_id = "stores_items"
				definition.merged_enable_setting_key = "enabled"
			"can_be_unlocked":
				definition.merged_into_capability_id = "stores_items"
				definition.merged_component_id = "can_be_locked"
				definition.merged_setting_key_map = {
					"requires_key": "unlock_requires_key",
					"unlock_key_id": "unlock_key_id"
				}
				definition.merged_enable_setting_keys = PackedStringArray(["enabled", "unlock_enabled"])
			"supports_container_links":
				definition.merged_into_capability_id = "stores_items"
				definition.merged_component_id = "has_shared_storage"
				definition.merged_setting_key_map = {"allow_links": "allow_links"}
				definition.merged_enable_setting_key = "enabled"
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
