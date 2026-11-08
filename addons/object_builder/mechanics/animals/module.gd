@tool
extends RefCounted

const SCRIPT = preload("res://addons/object_builder/mechanics/animals/component.gd")
const CATEGORY_ID := "animals"
const CATEGORY_NAME := "Животные"
const STATE_NOTE := "Animal runtime API: кормление, приручение, счастье, контакт, среда обитания, расписание, размножение, периодические ресурсы, езда верхом и миграция."

const DEFINITIONS := [
	{"id":"can_be_tamed","name":"Можно приручить","description":"Накопление прогресса приручения через подходящий корм и назначение владельца.","defaults":{"taming_progress_required":3.0,"taming_progress_per_feed":1.0,"taming_foods_csv":""},"settings":[{"key":"taming_progress_required","display_name":"Требуемый прогресс","value_type":"Float","default_value":3.0,"group_name":"Приручение","has_range":true,"minimum":0.1,"maximum":10000.0},{"key":"taming_progress_per_feed","display_name":"Прогресс за кормление","value_type":"Float","default_value":1.0,"group_name":"Приручение","has_range":true,"minimum":0.0,"maximum":1000.0},{"key":"taming_foods_csv","display_name":"Подходящий корм","value_type":"String","default_value":"","group_name":"Приручение"}]},
	{"id":"can_be_fed","name":"Можно кормить","description":"Принимает заданные типы корма и увеличивает сытость.","defaults":{"accepted_foods_csv":"hay,apple","nutrition_per_feed":20.0},"settings":[{"key":"accepted_foods_csv","display_name":"Допустимый корм","value_type":"String","default_value":"hay,apple","group_name":"Кормление"},{"key":"nutrition_per_feed","display_name":"Питательность","value_type":"Float","default_value":20.0,"group_name":"Кормление","has_range":true,"minimum":0.1,"maximum":100.0}]},
	{"id":"can_breed","name":"Размножение","description":"Проверяет готовность двух животных и выдаёт данные потомства с периодом восстановления.","defaults":{"offspring_object_id":"animal_offspring","breeding_cooldown_seconds":86400.0},"settings":[{"key":"offspring_object_id","display_name":"ID потомства","value_type":"String","default_value":"animal_offspring","group_name":"Размножение"},{"key":"breeding_cooldown_seconds","display_name":"Период восстановления","value_type":"Float","default_value":86400.0,"group_name":"Размножение","has_range":true,"minimum":0.0,"maximum":31536000.0}]},
	{"id":"can_produce_resources","name":"Производит ресурсы","description":"Выдаёт ресурс через равные интервалы времени.","defaults":{"resource_item_id":"milk","production_interval":3600.0,"amount_per_cycle":1},"settings":[{"key":"resource_item_id","display_name":"ID ресурса","value_type":"String","default_value":"milk","group_name":"Производство"},{"key":"production_interval","display_name":"Интервал производства","value_type":"Float","default_value":3600.0,"group_name":"Производство","has_range":true,"minimum":0.1,"maximum":31536000.0},{"key":"amount_per_cycle","display_name":"Количество за цикл","value_type":"Integer","default_value":1,"group_name":"Производство","has_range":true,"minimum":1,"maximum":999999}]},
	{"id":"has_habitat","name":"Среда обитания","description":"Проверяет допустимый биом и температурный диапазон.","defaults":{"allowed_biomes_csv":"plains,forest","minimum_temperature":-10.0,"maximum_temperature":35.0},"settings":[{"key":"allowed_biomes_csv","display_name":"Допустимые биомы","value_type":"String","default_value":"plains,forest","group_name":"Среда"},{"key":"minimum_temperature","display_name":"Минимальная температура","value_type":"Float","default_value":-10.0,"group_name":"Среда","has_range":true,"minimum":-100.0,"maximum":100.0},{"key":"maximum_temperature","display_name":"Максимальная температура","value_type":"Float","default_value":35.0,"group_name":"Среда","has_range":true,"minimum":-100.0,"maximum":100.0}]},
	{"id":"has_happiness","name":"Настроение животного","description":"Хранит настроение и меняет его от ухода и контакта.","defaults":{"starting_happiness":50.0,"feed_bonus":5.0,"pet_bonus":10.0},"settings":[{"key":"starting_happiness","display_name":"Начальное настроение","value_type":"Float","default_value":50.0,"group_name":"Настроение","has_range":true,"minimum":0.0,"maximum":100.0},{"key":"feed_bonus","display_name":"Бонус за кормление","value_type":"Float","default_value":5.0,"group_name":"Настроение","has_range":true,"minimum":0.0,"maximum":100.0},{"key":"pet_bonus","display_name":"Бонус за поглаживание","value_type":"Float","default_value":10.0,"group_name":"Настроение","has_range":true,"minimum":0.0,"maximum":100.0}]},
	{"id":"has_daily_routine","name":"Распорядок дня","description":"Возвращает действие по расписанию игрового часа.","defaults":{"schedule_json":"[{\"start\":6,\"end\":12,\"action\":\"graze\"}]","default_action":"idle"},"settings":[{"key":"schedule_json","display_name":"Расписание JSON","value_type":"String","default_value":"[{\"start\":6,\"end\":12,\"action\":\"graze\"}]","group_name":"Распорядок"},{"key":"default_action","display_name":"Действие по умолчанию","value_type":"String","default_value":"idle","group_name":"Распорядок"}]},
	{"id":"can_be_mounted","name":"Можно оседлать","description":"Позволяет назначить всадника и возвращает скорость передвижения.","defaults":{"mount_speed":120.0},"settings":[{"key":"mount_speed","display_name":"Скорость верхом","value_type":"Float","default_value":120.0,"group_name":"Верховая езда","has_range":true,"minimum":0.0,"maximum":10000.0}]},
	{"id":"can_migrate","name":"Мигрирует","description":"Выбирает регион назначения по текущему сезону.","defaults":{"migration_by_season_json":"{}"},"settings":[{"key":"migration_by_season_json","display_name":"Маршруты миграции JSON","value_type":"String","default_value":"{}","group_name":"Миграция"}]},
	{"id":"can_be_petted","name":"Можно погладить","description":"Увеличивает привязанность и настроение с периодом повторного контакта.","defaults":{"affection_gain":5.0,"pet_cooldown_seconds":30.0},"settings":[{"key":"affection_gain","display_name":"Привязанность за контакт","value_type":"Float","default_value":5.0,"group_name":"Контакт","has_range":true,"minimum":0.0,"maximum":100.0},{"key":"pet_cooldown_seconds","display_name":"Задержка контакта","value_type":"Float","default_value":30.0,"group_name":"Контакт","has_range":true,"minimum":0.0,"maximum":86400.0}]}
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
		definition.category = "Animals"
		definition.category_id = "Animals"
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
		definition.icon = "paw-print"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "животное", "уход"])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
