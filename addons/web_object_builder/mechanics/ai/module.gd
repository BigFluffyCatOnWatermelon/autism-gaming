@tool
extends RefCounted

const SCRIPT = preload("res://addons/web_object_builder/mechanics/ai/component.gd")
const CATEGORY_ID := "ai"
const CATEGORY_NAME := "Поведение и AI"
const STATE_NOTE := "AI intent API: выбор цели, follow/chase/flee/guard, патруль, блуждание, помощь союзникам, сигнал тревоги и диалоги. Возвращает intent для игрового контроллера; сам не подменяет систему движения."

const DEFINITIONS := [
	{"id":"has_ai","name":"Управляется AI","description":"Включает вычисление поведения и выдачу intent для внешнего контроллера.","defaults":{"ai_enabled":true},"settings":[{"key":"ai_enabled","display_name":"AI активен","value_type":"Boolean","default_value":true,"group_name":"AI"}]},
	{"id":"can_follow_target","name":"Следует за целью","description":"Возвращает направление сопровождения назначенной цели.","defaults":{"follow_distance":48.0},"settings":[{"key":"follow_distance","display_name":"Дистанция следования","value_type":"Float","default_value":48.0,"group_name":"Следование","has_range":true,"minimum":0.0,"maximum":100000.0}]},
	{"id":"can_patrol","name":"Патрулирует","description":"Следует по заданному маршруту с настройкой скорости, радиуса прибытия и зацикливания.","defaults":{"patrol_points_json":"[[0,0],[128,0]]","arrival_distance":8.0,"patrol_speed":60.0,"loop_route":true},"settings":[{"key":"patrol_points_json","display_name":"Точки маршрута JSON","value_type":"String","default_value":"[[0,0],[128,0]]","group_name":"Патруль"},{"key":"patrol_speed","display_name":"Скорость патруля","value_type":"Float","default_value":60.0,"group_name":"Патруль","has_range":true,"minimum":0.0,"maximum":2000.0},{"key":"arrival_distance","display_name":"Радиус прибытия","value_type":"Float","default_value":8.0,"group_name":"Патруль","has_range":true,"minimum":1.0,"maximum":10000.0},{"key":"loop_route","display_name":"Зацикливать маршрут","value_type":"Boolean","default_value":true,"group_name":"Патруль"}]},
	{"id":"can_chase","name":"Преследует","description":"Обнаруживает цель в радиусе и выдаёт позицию для преследования.","defaults":{"detection_radius":160.0},"settings":[{"key":"detection_radius","display_name":"Радиус обнаружения","value_type":"Float","default_value":160.0,"group_name":"Преследование","has_range":true,"minimum":0.0,"maximum":100000.0}]},
	{"id":"can_flee","name":"Убегает","description":"При низком здоровье выбирает направление от цели.","defaults":{"health_threshold":0.25,"flee_distance":128.0},"settings":[{"key":"health_threshold","display_name":"Порог здоровья","value_type":"Float","default_value":0.25,"group_name":"Отступление","has_range":true,"minimum":0.0,"maximum":1.0},{"key":"flee_distance","display_name":"Дистанция отступления","value_type":"Float","default_value":128.0,"group_name":"Отступление","has_range":true,"minimum":0.0,"maximum":100000.0}]},
	{"id":"can_guard_area","name":"Охраняет область","description":"Удерживает заданную зону и реагирует на цель внутри неё.","defaults":{"guard_center":Vector2.ZERO,"guard_radius":128.0},"settings":[{"key":"guard_center","display_name":"Центр охраны","value_type":"Vector2","default_value":Vector2.ZERO,"group_name":"Охрана"},{"key":"guard_radius","display_name":"Радиус охраны","value_type":"Float","default_value":128.0,"group_name":"Охрана","has_range":true,"minimum":0.0,"maximum":100000.0}]},
	{"id":"can_wander","name":"Бродит","description":"Периодически выбирает случайную точку вокруг текущего положения.","defaults":{"wander_radius":96.0,"target_duration":3.0},"settings":[{"key":"wander_radius","display_name":"Радиус блуждания","value_type":"Float","default_value":96.0,"group_name":"Блуждание","has_range":true,"minimum":0.0,"maximum":100000.0},{"key":"target_duration","display_name":"Время цели","value_type":"Float","default_value":3.0,"group_name":"Блуждание","has_range":true,"minimum":0.1,"maximum":3600.0}]},
	{"id":"can_assist","name":"Помогает союзникам","description":"Выбирает ближайшего союзника с флагом needs_assistance или низким здоровьем.","defaults":{"assist_radius":128.0,"ally_health_threshold":0.35},"settings":[{"key":"assist_radius","display_name":"Радиус помощи","value_type":"Float","default_value":128.0,"group_name":"Помощь","has_range":true,"minimum":0.0,"maximum":100000.0},{"key":"ally_health_threshold","display_name":"Порог здоровья союзника","value_type":"Float","default_value":0.35,"group_name":"Помощь","has_range":true,"minimum":0.0,"maximum":1.0}]},
	{"id":"can_call_for_help","name":"Зовёт на помощь","description":"Отправляет сигнал с позицией и радиусом поиска союзников.","defaults":{"help_radius":256.0},"settings":[{"key":"help_radius","display_name":"Радиус сигнала","value_type":"Float","default_value":256.0,"group_name":"Сигнал","has_range":true,"minimum":0.0,"maximum":100000.0}]},
	{"id":"supports_dialogue","name":"Диалоги","description":"Хранит реплики по темам и отправляет событие начала диалога.","defaults":{"dialogue_json":"{\"greeting\":[\"Привет!\"]}"},"settings":[{"key":"dialogue_json","display_name":"Реплики JSON","value_type":"String","default_value":"{\"greeting\":[\"Привет!\"]}","group_name":"Диалог"}]}
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
		definition.category = "AI"
		definition.category_id = "AI"
		definition.category_display_name = CATEGORY_NAME
		definition.component_version = 1
		definition.component_script = SCRIPT
		definition.setting_definitions = _settings_for(item)
		definition.settings = item.defaults.duplicate(true)
		if str(item.id) not in ["has_ai", "supports_dialogue"]:
			definition.settings["enabled"] = false
			definition.setting_definitions.push_front({
				"key": "enabled",
				"display_name": "Поведение включено",
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
		definition.display_name = "Поведение AI" if str(item.id) == "has_ai" else str(item.name)
		definition.description = "Управляет поведением объекта. Следование, преследование, патруль и другие режимы включаются внутри настроек." if str(item.id) == "has_ai" else str(item.description)
		definition.category_id = CATEGORY_ID
		definition.category_name = CATEGORY_NAME
		definition.icon = "brain"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "поведение", "цель"])
		definition.component_ids = PackedStringArray([str(item.id)])
		if str(item.id) in ["can_follow_target", "can_patrol", "can_chase", "can_flee", "can_guard_area", "can_wander", "can_assist", "can_call_for_help"]:
			definition.merged_into_capability_id = "has_ai"
			definition.merged_enable_setting_key = "enabled"
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
