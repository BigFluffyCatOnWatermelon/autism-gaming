@tool
extends RefCounted

const CATEGORY_ID := "destruction"
const CATEGORY_NAME := "Разрушение"
const STATE_NOTE := "Компонент последовательности разрушения: стадии, обломки, добыча, анимация падения, остатки, ремонт, восстановление и взрыв."
const SCRIPT = preload("res://addons/web_object_builder/mechanics/destruction/destruction_rule.gd")

const DEFINITION_DATA := [
	{"id":"can_break_into_parts","name":"Разрушение на части","description":"Создаёт отдельные сцены частей по списку путей и смещений.","requires":["breaks_when_health_empty"],"fields":[["parts_json","Список частей (JSON)","String","[]","Части"]]},
	{"id":"has_destruction_stages","name":"Стадии разрушения","description":"Определяет номер стадии по доле оставшейся прочности.","requires":["breaks_when_health_empty"],"fields":[["stage_thresholds","Пороги стадий через запятую","String","0.75,0.5,0.25","Стадии"]]},
	{"id":"spawns_debris","name":"Создаёт обломки","description":"Создаёт заданное число экземпляров сцены обломка.","requires":["breaks_when_health_empty"],"fields":[["debris_scene_path","Сцена обломка","String","","Обломки"],["debris_count","Количество","Integer",4,"Обломки",0,256]]},
	{"id":"drops_loot_on_destroy","name":"Добыча при разрушении","description":"Бросает таблицу добычи с шансом и диапазоном количества для каждой записи.","requires":["breaks_when_health_empty"],"fields":[["loot_table_path","Путь к ресурсу таблицы добычи","String","","Добыча"],["loot_table_json","Старая таблица добычи JSON (резерв)","String","[]","Добыча"]]},
	{"id":"plays_destroy_animation","name":"Анимация разрушения","description":"Проигрывает указанную анимацию AnimationPlayer.","requires":["breaks_when_health_empty"],"fields":[["animation_player_path","Путь к AnimationPlayer","String","AnimationPlayer","Анимация"],["destroy_animation","Название анимации","String","destroy","Анимация"]]},
	{"id":"leaves_remains","name":"Оставляет остатки","description":"Показывает встроенные части родительского объекта или создаёт указанную сцену остатков на месте разрушения.","requires":["breaks_when_health_empty"],"fields":[["remains_scene_path","Сцена остатков (если не встроена)","String","","Остатки"]]},
	{"id":"falls_when_destroyed","name":"Падает при разрушении","description":"Перед исчезновением или появлением остатков наклоняет объект вокруг его опорной точки.","requires":["breaks_when_health_empty"],"fields":[["fall_angle_degrees","Угол падения","Float",78.0,"Падение",1.0,120.0],["fall_duration","Длительность падения","Float",0.48,"Падение",0.05,5.0]]},
	{"id":"can_be_repaired","name":"Можно починить","description":"Восстанавливает здоровье через Health.heal().","requires":["has_health"],"fields":[["repair_amount","Здоровье за ремонт","Float",25.0,"Ремонт",0.0,1000000.0]]},
	{"id":"can_regrow","name":"Может восстановиться","description":"Отсчитывает время до повторного восстановления объекта или ресурса.","fields":[["regrowth_seconds","Время восстановления","Float",30.0,"Восстановление",0.0,86400.0]]},
	{"id":"can_explode_on_destroy","name":"Взрывается при уничтожении","description":"Возвращает радиус и урон для взрыва, который обрабатывает игровая сцена.","requires":["breaks_when_health_empty"],"fields":[["explosion_radius","Радиус взрыва","Float",96.0,"Взрыв",0.0,100000.0],["explosion_damage","Урон взрыва","Float",25.0,"Взрыв",0.0,1000000.0]]}
]


func _settings_for(item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for field in item.fields:
		var descriptor := {
			"key": str(field[0]),
			"display_name": str(field[1]),
			"value_type": str(field[2]),
			"default_value": field[3],
			"group_name": str(field[4])
		}
		if field.size() >= 7:
			descriptor["has_range"] = true
			descriptor["minimum"] = float(field[5])
			descriptor["maximum"] = float(field[6])
		if str(field[0]) == "loot_table_json":
			descriptor["display_name"] = "Резервная таблица добычи"
			descriptor["editor"] = "structured_list"
			descriptor["editor_config"] = {
				"structure_type": "loot_table",
				"reference_type": "item"
			}
		result.append(descriptor)
	return result


func _defaults_for(item: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in item.fields:
		result[str(field[0])] = field[3]
	return result


func build_component_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for item in DEFINITION_DATA:
		var definition := ObjectComponentDefinition.new()
		definition.component_id = str(item.id)
		definition.display_name = str(item.name)
		definition.description = str(item.description)
		definition.category = "Destruction"
		definition.category_id = "Destruction"
		definition.category_display_name = CATEGORY_NAME
		definition.component_version = 1
		definition.component_script = SCRIPT
		definition.setting_definitions = _settings_for(item)
		definition.settings = _defaults_for(item)
		if str(item.id) not in ["can_be_repaired", "can_regrow"]:
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
	for item in DEFINITION_DATA:
		var definition := ObjectCapabilityDefinition.new()
		definition.capability_id = str(item.id)
		definition.display_name = str(item.name)
		definition.description = str(item.description)
		definition.category_id = CATEGORY_ID
		definition.category_name = CATEGORY_NAME
		definition.icon = "hammer"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.required_capability_ids = PackedStringArray(item.get("requires", []))
		if str(item.id) not in ["can_be_repaired", "can_regrow"]:
			definition.merged_into_capability_id = "breaks_when_health_empty"
			definition.merged_enable_setting_key = "enabled"
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
