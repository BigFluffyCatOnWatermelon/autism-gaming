@tool
extends RefCounted

const SCRIPT = preload("res://addons/object_builder/mechanics/world_time/component.gd")
const CATEGORY_ID := "world_time"
const CATEGORY_NAME := "Время и события"
const STATE_NOTE := "World-time runtime API: расписание дня/ночи, сезонные данные, таймеры активации, cooldown, respawn, lifespan, погодные эффекты, периодический output, signal triggers и event schedule."

const DEFINITIONS := [
	{"id":"has_day_night_schedule","name":"Расписание дня и ночи","description":"Возвращает фазу суток по игровому часу и расписанию.","defaults":{"schedule_json":"[{\"start\":6,\"end\":18,\"phase\":\"day\"},{\"start\":18,\"end\":6,\"phase\":\"night\"}]","default_phase":"day"},"settings":[{"key":"schedule_json","display_name":"Фазы суток JSON","value_type":"String","default_value":"[{\"start\":6,\"end\":18,\"phase\":\"day\"},{\"start\":18,\"end\":6,\"phase\":\"night\"}]","group_name":"Сутки"},{"key":"default_phase","display_name":"Фаза по умолчанию","value_type":"String","default_value":"day","group_name":"Сутки"}]},
	{"id":"changes_by_season","name":"Зависит от сезона","description":"Возвращает сезонный набор параметров по ID сезона.","defaults":{"seasonal_values_json":"{}"},"settings":[{"key":"seasonal_values_json","display_name":"Значения сезонов JSON","value_type":"String","default_value":"{}","group_name":"Сезоны"}]},
	{"id":"has_timed_activation","name":"Активация по таймеру","description":"Активирует объект после заданной задержки.","defaults":{"delay_seconds":2.0},"settings":[{"key":"delay_seconds","display_name":"Задержка активации","value_type":"Float","default_value":2.0,"group_name":"Таймер","has_range":true,"minimum":0.0,"maximum":31536000.0}]},
	{"id":"has_cooldown","name":"Перезарядка","description":"Запускает и отсчитывает cooldown до готовности следующего действия.","defaults":{"cooldown_seconds":3.0},"settings":[{"key":"cooldown_seconds","display_name":"Длительность перезарядки","value_type":"Float","default_value":3.0,"group_name":"Перезарядка","has_range":true,"minimum":0.0,"maximum":31536000.0}]},
	{"id":"supports_timed_respawn","name":"Возрождение по времени","description":"Переводит объект в неактивное состояние и возвращает его после задержки.","defaults":{"respawn_delay":30.0},"settings":[{"key":"respawn_delay","display_name":"Задержка возрождения","value_type":"Float","default_value":30.0,"group_name":"Возрождение","has_range":true,"minimum":0.0,"maximum":31536000.0}]},
	{"id":"has_lifespan","name":"Время жизни","description":"Отсчитывает срок жизни и выдаёт событие истечения.","defaults":{"lifespan_seconds":60.0},"settings":[{"key":"lifespan_seconds","display_name":"Время жизни","value_type":"Float","default_value":60.0,"group_name":"Срок жизни","has_range":true,"minimum":0.0,"maximum":31536000.0}]},
	{"id":"reacts_to_weather","name":"Реакция на погоду","description":"Возвращает погодные модификаторы или запрещает неподдерживаемую погоду.","defaults":{"allowed_weather_csv":"","weather_effects_json":"{}"},"settings":[{"key":"allowed_weather_csv","display_name":"Допустимая погода","value_type":"String","default_value":"","group_name":"Погода"},{"key":"weather_effects_json","display_name":"Эффекты погоды JSON","value_type":"String","default_value":"{}","group_name":"Погода"}]},
	{"id":"has_periodic_output","name":"Периодическое производство","description":"Выдаёт заданное количество ресурса через равные интервалы.","defaults":{"output_item_id":"resource","output_interval":60.0,"amount_per_cycle":1},"settings":[{"key":"output_item_id","display_name":"ID ресурса","value_type":"String","default_value":"resource","group_name":"Производство"},{"key":"output_interval","display_name":"Интервал","value_type":"Float","default_value":60.0,"group_name":"Производство","has_range":true,"minimum":0.1,"maximum":31536000.0},{"key":"amount_per_cycle","display_name":"Количество за цикл","value_type":"Integer","default_value":1,"group_name":"Производство","has_range":true,"minimum":1,"maximum":999999}]},
	{"id":"supports_signal_triggers","name":"Запуск по сигналу","description":"Сопоставляет входящий ID события с действием и payload.","defaults":{"event_rules_json":"{}"},"settings":[{"key":"event_rules_json","display_name":"Правила событий JSON","value_type":"String","default_value":"{}","group_name":"Сигналы"}]},
	{"id":"supports_event_schedule","name":"Расписание событий","description":"Возвращает события, назначенные на игровой день и час.","defaults":{"events_json":"[]","hour_tolerance":0.25},"settings":[{"key":"events_json","display_name":"События JSON","value_type":"String","default_value":"[]","group_name":"Расписание"},{"key":"hour_tolerance","display_name":"Допуск по времени","value_type":"Float","default_value":0.25,"group_name":"Расписание","has_range":true,"minimum":0.0,"maximum":12.0}]}
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
		definition.category = "WorldTime"
		definition.category_id = "WorldTime"
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
		definition.icon = "clock"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "время", "событие"])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
