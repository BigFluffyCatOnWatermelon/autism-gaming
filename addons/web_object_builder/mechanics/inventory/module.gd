@tool
extends RefCounted

const SCRIPT = preload("res://addons/web_object_builder/mechanics/inventory/component.gd")
const CATEGORY_ID := "inventory"
const CATEGORY_NAME := "Инвентарь"
const STATE_NOTE := "Инвентарь с реальными слотами и общим состоянием: добавление/удаление, фильтры, сортировка, разделение, быстрый перенос, лимит веса, экипировка, hotbar, рецепты и закрепление предметов. Runtime-состояние экспортируется и восстанавливается."

const DEFINITIONS := [
	{"id":"has_inventory","name":"Имеет инвентарь","description":"Создаёт слоты и хранит содержимое предмета в состоянии экземпляра.","defaults":{"slot_capacity":24,"initial_items_json":"[]"},"settings":[{"key":"slot_capacity","display_name":"Количество слотов","value_type":"Integer","default_value":24,"group_name":"Инвентарь","has_range":true,"minimum":1,"maximum":10000},{"key":"initial_items_json","display_name":"Начальное содержимое JSON","value_type":"String","default_value":"[]","group_name":"Инвентарь"}]},
	{"id":"has_equipment_slots","name":"Слоты экипировки","description":"Хранит экипированные предметы по именованным слотам.","defaults":{"equipment_slots_csv":"head,chest,legs,feet,hand,offhand,accessory"},"settings":[{"key":"equipment_slots_csv","display_name":"Слоты через запятую","value_type":"String","default_value":"head,chest,legs,feet,hand,offhand,accessory","group_name":"Экипировка"}]},
	{"id":"supports_hotbar","name":"Панель быстрого доступа","description":"Назначает слоты инвентаря на быстрые клавиши и хранит выбранный слот.","defaults":{"hotbar_slots":9},"settings":[{"key":"hotbar_slots","display_name":"Количество быстрых слотов","value_type":"Integer","default_value":9,"group_name":"Панель","has_range":true,"minimum":1,"maximum":32}]},
	{"id":"supports_item_filters","name":"Фильтры предметов","description":"Применяет разрешающие и запрещающие правила по ID и тегам.","defaults":{"filter_rules_json":"{}"},"settings":[{"key":"filter_rules_json","display_name":"Правила фильтрации JSON","value_type":"String","default_value":"{}","group_name":"Фильтры"}]},
	{"id":"supports_item_sorting","name":"Сортировка предметов","description":"Сортирует содержимое по имени, весу, редкости или типу.","defaults":{"default_sort":"name"},"settings":[{"key":"default_sort","display_name":"Сортировка по умолчанию","value_type":"String","default_value":"name","group_name":"Сортировка"}]},
	{"id":"supports_stack_splitting","name":"Разделение стопки","description":"Разделяет количество предмета в отдельный свободный слот.","defaults":{"allow_split":true},"settings":[{"key":"allow_split","display_name":"Разрешить разделение","value_type":"Boolean","default_value":true,"group_name":"Стопки"}]},
	{"id":"supports_quick_transfer","name":"Быстрое перемещение","description":"Переносит предметы между двумя совместимыми инвентарями без потери остатка.","defaults":{"transfer_mode":"all"},"settings":[{"key":"transfer_mode","display_name":"Режим переноса","value_type":"String","default_value":"all","group_name":"Перемещение"}]},
	{"id":"has_weight_capacity","name":"Лимит переносимого веса","description":"Ограничивает суммарный вес предметов и экипировки в инвентаре. Не влияет на вместимость контейнера.","defaults":{"max_weight":100.0},"settings":[{"key":"max_weight","display_name":"Максимальный переносимый вес (0 — без лимита)","value_type":"Float","default_value":100.0,"group_name":"Вес инвентаря","has_range":true,"minimum":0.0,"maximum":1000000.0}]},
	{"id":"supports_item_crafting","name":"Создание предметов","description":"Проверяет рецепт, списывает ингредиенты и выдаёт результат с откатом при ошибке. Поддерживает внешний GameplayTableDefinition и старую JSON-таблицу.","defaults":{"recipes_table_path":"","recipes_json":"{}"},"settings":[{"key":"recipes_table_path","display_name":"Путь к ресурсу рецептов","value_type":"String","default_value":"","group_name":"Рецепты"},{"key":"recipes_json","display_name":"Старая таблица рецептов JSON (резерв)","value_type":"String","default_value":"{}","group_name":"Рецепты"}]},
	{"id":"supports_item_binding","name":"Закреплённые предметы","description":"Помечает слот закреплённым и запрещает обычное удаление/перенос закреплённого предмета.","defaults":{"allow_binding":true},"settings":[{"key":"allow_binding","display_name":"Разрешить закрепление","value_type":"Boolean","default_value":true,"group_name":"Закрепление"}]}
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
		definition.category = "Inventory"
		definition.category_id = "Inventory"
		definition.category_display_name = CATEGORY_NAME
		definition.component_version = 1
		definition.component_script = SCRIPT
		definition.setting_definitions = _settings_for(item)
		definition.settings = item.defaults.duplicate(true)
		definition.settings["enabled"] = false
		definition.setting_definitions.push_front({
			"key": "enabled",
			"display_name": "Включено",
			"value_type": "Boolean",
			"default_value": false,
			"group_name": "Дополнительные функции хранилища"
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
		definition.icon = "backpack"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "слоты", "хранение"])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.merged_into_capability_id = "stores_items"
		# Keep carry-weight limits separate from container slot/weight capacity.
		# Both remain nested under the common storage capability, but affect different state.
		definition.merged_enable_setting_key = "enabled"
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
