@tool
extends RefCounted

const SCRIPT = preload("res://addons/object_builder/mechanics/harvesting/component.gd")
const CATEGORY_ID := "harvesting"
const CATEGORY_NAME := "Добыча и сбор"
const STATE_NOTE := "Рабочий компонент добычи: проверка инструментов/сезона, прогресс, этапы, таблица ресурсов, качество, эффективность инструмента и повторное отрастание. Игровой цикл вызывает begin_harvest()/advance_harvest()."

const DEFINITIONS := [
	{"id":"can_be_harvested","name":"Можно добывать","description":"Проверяет доступность ресурса и задаёт базовую длительность добычи.","defaults":{"enabled":true,"harvest_time_seconds":2.0},"settings":[{"key":"enabled","display_name":"Доступна добыча","value_type":"Boolean","default_value":true,"group_name":"Добыча"},{"key":"harvest_time_seconds","display_name":"Время добычи","value_type":"Float","default_value":2.0,"group_name":"Добыча","has_range":true,"minimum":0.05,"maximum":3600.0}]},
	{"id":"requires_tool","name":"Требует инструмент","description":"Ограничивает добычу ID инструмента и минимальным уровнем.","defaults":{"required_tool_id":"axe","minimum_tool_level":0,"tool_requirements_json":"{}"},"settings":[{"key":"required_tool_id","display_name":"ID инструмента","value_type":"String","default_value":"axe","group_name":"Инструмент"},{"key":"minimum_tool_level","display_name":"Минимальный уровень","value_type":"Integer","default_value":0,"group_name":"Инструмент","has_range":true,"minimum":0,"maximum":999},{"key":"tool_requirements_json","display_name":"Уровни инструментов JSON","value_type":"String","default_value":"{}","group_name":"Инструмент"}]},
	{"id":"has_harvest_progress","name":"Прогресс добычи","description":"Хранит текущий прогресс и выдаёт событие обновления шкалы.","defaults":{"harvest_duration":2.0},"settings":[{"key":"harvest_duration","display_name":"Длительность шкалы","value_type":"Float","default_value":2.0,"group_name":"Прогресс","has_range":true,"minimum":0.05,"maximum":3600.0}]},
	{"id":"yields_resources","name":"Даёт ресурсы","description":"Рассчитывает выпадение ресурсов по шансам и диапазонам количества.","defaults":{"resource_table_json":"[{\"item_id\":\"wood\",\"min\":1,\"max\":2,\"chance\":1.0}]"},"settings":[{"key":"resource_table_json","display_name":"Таблица ресурсов JSON","value_type":"String","default_value":"[{\"item_id\":\"wood\",\"min\":1,\"max\":2,\"chance\":1.0}]","group_name":"Ресурсы"}]},
	{"id":"has_regrowth","name":"Повторное отрастание","description":"Отсчитывает время восстановления и выдаёт событие regrown.","defaults":{"regrowth_seconds":60.0},"settings":[{"key":"regrowth_seconds","display_name":"Время отрастания","value_type":"Float","default_value":60.0,"group_name":"Восстановление","has_range":true,"minimum":0.0,"maximum":604800.0}]},
	{"id":"has_seasonal_yield","name":"Сезонная добыча","description":"Разрешает добычу только в перечисленные сезоны и применяет сезонный множитель количества.","defaults":{"seasonal_yields_json":"{\"spring\":1.0,\"summer\":1.0,\"autumn\":1.0,\"winter\":0.5}"},"settings":[{"key":"seasonal_yields_json","display_name":"Множители сезонов JSON","value_type":"String","default_value":"{\"spring\":1.0,\"summer\":1.0,\"autumn\":1.0,\"winter\":0.5}","group_name":"Сезоны"}]},
	{"id":"has_quality_variants","name":"Качество добычи","description":"Выбирает качество результата по весовой таблице вероятностей.","defaults":{"quality_chances_json":"{\"normal\":0.7,\"fine\":0.2,\"rare\":0.1}"},"settings":[{"key":"quality_chances_json","display_name":"Шансы качества JSON","value_type":"String","default_value":"{\"normal\":0.7,\"fine\":0.2,\"rare\":0.1}","group_name":"Качество"}]},
	{"id":"has_tool_efficiency","name":"Эффективность инструмента","description":"Умножает скорость добычи на коэффициент выбранного инструмента.","defaults":{"tool_efficiency_json":"{\"axe\":1.0,\"pickaxe\":1.0}"},"settings":[{"key":"tool_efficiency_json","display_name":"Эффективность инструментов JSON","value_type":"String","default_value":"{\"axe\":1.0,\"pickaxe\":1.0}","group_name":"Инструменты"}]},
	{"id":"has_multi_stage_harvest","name":"Несколько этапов добычи","description":"Преобразует долю прогресса в последовательные этапы и выдаёт stage_changed.","defaults":{"harvest_stages_json":"[0.33,0.66,1.0]"},"settings":[{"key":"harvest_stages_json","display_name":"Пороги этапов JSON","value_type":"String","default_value":"[0.33,0.66,1.0]","group_name":"Этапы"}]},
	{"id":"can_be_mined","name":"Можно добывать киркой","description":"Требует инструмент с заданным ID и минимальной мощностью добычи.","defaults":{"required_tool_id":"pickaxe","minimum_mining_power":1.0,"tool_power_json":"{\"pickaxe\":{\"power\":1.0}}"},"settings":[{"key":"required_tool_id","display_name":"ID инструмента","value_type":"String","default_value":"pickaxe","group_name":"Добыча"},{"key":"minimum_mining_power","display_name":"Минимальная мощность","value_type":"Float","default_value":1.0,"group_name":"Добыча","has_range":true,"minimum":0.0,"maximum":100000.0},{"key":"tool_power_json","display_name":"Мощность инструментов JSON","value_type":"String","default_value":"{\"pickaxe\":{\"power\":1.0}}","group_name":"Добыча"}]}
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
		definition.category = "Harvesting"
		definition.category_id = "Harvesting"
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
		definition.icon = "pickaxe"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "сбор", "ресурсы"])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.available_in_simple_mode = true
		definition.runtime_status = "Planned"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
