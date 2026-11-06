@tool
extends RefCounted

const CATEGORY_ID := "defense"
const CATEGORY_NAME := "Защита"
const STATE_NOTE := "Готовый защитный компонент с публичными методами. Игровой код вызывает нужное правило при обработке урона, снаряда или эффекта."
const SCRIPT = preload("res://addons/object_builder/mechanics/defense/defense_rule.gd")

const DEFINITIONS := [
	{"id":"has_armor","name":"Броня","description":"Уменьшает входящий урон на процент и фиксированное значение.","fields":[["armor_percent_reduction","Процент снижения","Float",0.2,"Броня",0.0,1.0],["armor_flat_reduction","Плоское снижение","Float",5.0,"Броня",0.0,100000.0]]},
	{"id":"has_damage_resistance","name":"Сопротивление урону","description":"Применяет разные проценты сопротивления по типам урона из JSON-карты.","fields":[["damage_resistances_json","Сопротивления по типам (JSON)","String","{}","Сопротивления"]]},
	{"id":"has_immunity","name":"Иммунитет","description":"Игнорирует перечисленные типы эффектов; звёздочка означает все эффекты.","fields":[["immune_effects_csv","Иммунитеты через запятую","String","","Иммунитет"]]},
	{"id":"has_shield","name":"Щит","description":"Поглощает входящий урон отдельным запасом очков щита.","fields":[["shield_current","Текущий заряд щита","Float",50.0,"Щит",0.0,1000000.0],["shield_maximum","Максимальный заряд","Float",50.0,"Щит",0.0,1000000.0]]},
	{"id":"reduces_projectile_damage","name":"Защита от снарядов","description":"Уменьшает урон, получаемый от снарядов.","fields":[["projectile_reduction","Снижение урона снарядов","Float",0.5,"Снаряды",0.0,1.0]]},
	{"id":"reflects_projectiles","name":"Отражение снарядов","description":"Возвращает отражённое направление снаряда относительно нормали поверхности.","fields":[["projectile_reflection_enabled","Отражать снаряды","Boolean",true,"Отражение"]]},
	{"id":"has_invulnerability_window","name":"Окно неуязвимости","description":"Даёт кратковременную неуязвимость после вызова begin_invulnerability_window().","fields":[["invulnerability_duration","Длительность окна","Float",0.5,"Неуязвимость",0.0,10.0]]},
	{"id":"has_weak_points","name":"Уязвимые места","description":"Возвращает множитель урона для ID точки попадания из JSON-карты.","fields":[["weak_points_json","Множители точек попадания (JSON)","String","{}","Уязвимые места"]]},
	{"id":"resists_status_effects","name":"Сопротивление эффектам","description":"Уменьшает силу эффектов по ID из JSON-карты сопротивлений.","fields":[["status_resistances_json","Сопротивления эффектам (JSON)","String","{}","Сопротивления"]]},
	{"id":"regenerates_health","name":"Регенерация здоровья","description":"Восстанавливает здоровье через Health.heal() с заданной скоростью.","requires":["has_health"],"fields":[["health_regeneration_per_second","Здоровье в секунду","Float",1.0,"Регенерация",0.0,100000.0]]}
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
		result.append(descriptor)
	return result


func _defaults_for(item: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in item.fields:
		result[str(field[0])] = field[3]
	return result


func build_component_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for item in DEFINITIONS:
		var definition := ObjectComponentDefinition.new()
		definition.component_id = str(item.id)
		definition.display_name = str(item.name)
		definition.description = str(item.description)
		definition.category = "Combat"
		definition.category_id = "Combat"
		definition.category_display_name = CATEGORY_NAME
		definition.component_version = 1
		definition.component_script = SCRIPT
		definition.setting_definitions = _settings_for(item)
		definition.settings = _defaults_for(item)
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
		definition.icon = "shield"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.required_capability_ids = PackedStringArray(item.get("requires", []))
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
