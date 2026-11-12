@tool
extends RefCounted

const SCRIPT = preload("res://addons/web_object_builder/mechanics/world_generation/component.gd")
const CATEGORY_ID := "world_generation"
const CATEGORY_NAME := "Генерация мира"
const STATE_NOTE := "World-generation runtime API: фильтры биомов/условий/регионов, weighted variants, детерминированные layouts и spread по seed, density limits, рост по стадиям и адаптация к среде."

const DEFINITIONS := [
	{"id":"spawns_by_biome","name":"Появляется в биомах","description":"Ограничивает появление выбранными биомами.","defaults":{"allowed_biomes_csv":"plains,forest"},"settings":[{"key":"allowed_biomes_csv","display_name":"Разрешённые биомы","value_type":"String","default_value":"plains,forest","group_name":"Биомы"}]},
	{"id":"has_spawn_conditions","name":"Условия появления","description":"Проверяет температуру, высоту, сезон и обязательные теги.","defaults":{"conditions_json":"{}"},"settings":[{"key":"conditions_json","display_name":"Условия появления JSON","value_type":"String","default_value":"{}","group_name":"Условия"}]},
	{"id":"has_random_variants","name":"Случайные варианты","description":"Выбирает вариант по весам с детерминированным seed.","defaults":{"variants_json":"[{\"id\":\"default\",\"weight\":1.0}]"},"settings":[{"key":"variants_json","display_name":"Варианты JSON","value_type":"String","default_value":"[{\"id\":\"default\",\"weight\":1.0}]","group_name":"Варианты"}]},
	{"id":"has_procedural_layout","name":"Процедурная структура","description":"Генерирует точки по шаблону scatter/grid/ring/cluster.","defaults":{"pattern":"scatter","object_count":12,"spacing":32.0},"settings":[{"key":"pattern","display_name":"Шаблон","value_type":"String","default_value":"scatter","group_name":"Структура"},{"key":"object_count","display_name":"Количество объектов","value_type":"Integer","default_value":12,"group_name":"Структура","has_range":true,"minimum":0,"maximum":100000},{"key":"spacing","display_name":"Шаг/радиус","value_type":"Float","default_value":32.0,"group_name":"Структура","has_range":true,"minimum":1.0,"maximum":100000.0}]},
	{"id":"supports_world_seed","name":"Зависимость от seed мира","description":"Хранит начальное значение для повторяемой генерации.","defaults":{"default_seed":1},"settings":[{"key":"default_seed","display_name":"Seed мира","value_type":"Integer","default_value":1,"group_name":"Seed"}]},
	{"id":"has_density_rules","name":"Правила плотности","description":"Ограничивает число экземпляров в регионе и задаёт региональные лимиты.","defaults":{"max_per_region":20,"density_by_region_json":"{}"},"settings":[{"key":"max_per_region","display_name":"Максимум на регион","value_type":"Integer","default_value":20,"group_name":"Плотность","has_range":true,"minimum":0,"maximum":1000000},{"key":"density_by_region_json","display_name":"Лимиты регионов JSON","value_type":"String","default_value":"{}","group_name":"Плотность"}]},
	{"id":"can_spread","name":"Распространяется","description":"Выбирает свободные соседние клетки в заданном радиусе.","defaults":{"spread_radius":1,"max_spread_cells":4,"allow_diagonal":false},"settings":[{"key":"spread_radius","display_name":"Радиус распространения","value_type":"Integer","default_value":1,"group_name":"Распространение","has_range":true,"minimum":1,"maximum":32},{"key":"max_spread_cells","display_name":"Максимум новых клеток","value_type":"Integer","default_value":4,"group_name":"Распространение","has_range":true,"minimum":1,"maximum":10000},{"key":"allow_diagonal","display_name":"Диагональные клетки","value_type":"Boolean","default_value":false,"group_name":"Распространение"}]},
	{"id":"can_grow","name":"Растёт","description":"Увеличивает прогресс и переключает стадии роста.","defaults":{"growth_duration":60.0,"growth_stages_json":"[0.25,0.5,0.75,1.0]"},"settings":[{"key":"growth_duration","display_name":"Время полного роста","value_type":"Float","default_value":60.0,"group_name":"Рост","has_range":true,"minimum":0.01,"maximum":31536000.0},{"key":"growth_stages_json","display_name":"Пороги стадий JSON","value_type":"String","default_value":"[0.25,0.5,0.75,1.0]","group_name":"Рост"}]},
	{"id":"adapts_to_environment","name":"Адаптация к окружению","description":"Возвращает составные модификаторы по условиям среды.","defaults":{"adaptation_rules_json":"{}"},"settings":[{"key":"adaptation_rules_json","display_name":"Правила адаптации JSON","value_type":"String","default_value":"{}","group_name":"Адаптация"}]},
	{"id":"supports_region_rules","name":"Правила региона","description":"Разрешает/запрещает регионы и задаёт дополнительные правила.","defaults":{"allowed_regions_csv":"","blocked_regions_csv":"","region_rules_json":"{}"},"settings":[{"key":"allowed_regions_csv","display_name":"Разрешённые регионы","value_type":"String","default_value":"","group_name":"Регионы"},{"key":"blocked_regions_csv","display_name":"Запрещённые регионы","value_type":"String","default_value":"","group_name":"Регионы"},{"key":"region_rules_json","display_name":"Правила регионов JSON","value_type":"String","default_value":"{}","group_name":"Регионы"}]}
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
		definition.category = "WorldGeneration"
		definition.category_id = "WorldGeneration"
		definition.category_display_name = CATEGORY_NAME
		definition.component_version = 1
		definition.component_script = SCRIPT
		definition.setting_definitions = _settings_for(item)
		definition.settings = item.defaults.duplicate(true)
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
		definition.icon = "sprout"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "процедурная", "генерация"])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
