@tool
extends RefCounted
const CATEGORY_ID := "combat"
const CATEGORY_NAME := "Бой"
const STATE_NOTE := "Готовый компонент с публичными методами. Игровой код вызывает метод в соответствующий момент: при блоке, парировании, уклонении, атаке или выборе цели."
const RULE = preload("res://addons/web_object_builder/mechanics/combat/components/combat_rule.gd")
const DEFINITIONS := [
	{"id":"can_block","name":"Блокирование","description":"Уменьшает входящий урон при активном блоке.","defaults":{"rule_type":"block","enabled":true,"damage_reduction":0.75},"settings":[{"key":"damage_reduction","display_name":"Снижение урона","value_type":"Float","default_value":0.75,"group_name":"Блок","has_range":true,"minimum":0.0,"maximum":1.0}]},
	{"id":"can_parry","name":"Парирование","description":"Проверяет окно парирования и возвращает множитель контратаки.","defaults":{"rule_type":"parry","enabled":true,"parry_window":0.25,"counter_multiplier":1.5},"settings":[{"key":"parry_window","display_name":"Окно парирования","value_type":"Float","default_value":0.25,"group_name":"Парирование","has_range":true,"minimum":0.0,"maximum":2.0},{"key":"counter_multiplier","display_name":"Множитель контратаки","value_type":"Float","default_value":1.5,"group_name":"Парирование","has_range":true,"minimum":1.0,"maximum":20.0}]},
	{"id":"can_dodge","name":"Уклонение","description":"Возвращает длительность уклонения и признак временной неуязвимости.","defaults":{"rule_type":"dodge","enabled":true,"dodge_duration":0.35,"invulnerability":true},"settings":[{"key":"dodge_duration","display_name":"Длительность","value_type":"Float","default_value":0.35,"group_name":"Уклонение","has_range":true,"minimum":0.01,"maximum":10.0},{"key":"invulnerability","display_name":"Неуязвимость во время уклонения","value_type":"Boolean","default_value":true,"group_name":"Уклонение"}]},
	{"id":"can_aim","name":"Прицеливание","description":"Нормализует направление прицеливания.","defaults":{"rule_type":"aim","enabled":true,"aim_cone_degrees":8.0},"settings":[{"key":"aim_cone_degrees","display_name":"Угол помощи прицеливания","value_type":"Float","default_value":8.0,"group_name":"Прицеливание","has_range":true,"minimum":0.0,"maximum":90.0}]},
	{"id":"can_charge_attack","name":"Заряженная атака","description":"Усиливает атаку в зависимости от времени удержания.","defaults":{"rule_type":"charge","enabled":true,"charge_time":1.0,"maximum_multiplier":2.5},"settings":[{"key":"charge_time","display_name":"Время полного заряда","value_type":"Float","default_value":1.0,"group_name":"Заряд","has_range":true,"minimum":0.01,"maximum":60.0},{"key":"maximum_multiplier","display_name":"Максимальный множитель","value_type":"Float","default_value":2.5,"group_name":"Заряд","has_range":true,"minimum":1.0,"maximum":100.0}]},
	{"id":"can_critical_hit","name":"Критический удар","description":"Усиливает удар по заданной вероятности.","defaults":{"rule_type":"critical","enabled":true,"critical_chance":0.1,"critical_multiplier":2.0},"settings":[{"key":"critical_chance","display_name":"Шанс критического удара","value_type":"Float","default_value":0.1,"group_name":"Критический удар","has_range":true,"minimum":0.0,"maximum":1.0},{"key":"critical_multiplier","display_name":"Множитель урона","value_type":"Float","default_value":2.0,"group_name":"Критический удар","has_range":true,"minimum":1.0,"maximum":100.0}]},
	{"id":"can_combo_attack","name":"Комбинация атак","description":"Отслеживает последовательность ударов и множитель каждого шага.","defaults":{"rule_type":"combo","enabled":true,"combo_window":0.8,"combo_multipliers":"1.0,1.15,1.4"},"settings":[{"key":"combo_window","display_name":"Окно между ударами","value_type":"Float","default_value":0.8,"group_name":"Комбо","has_range":true,"minimum":0.0,"maximum":10.0},{"key":"combo_multipliers","display_name":"Множители шагов через запятую","value_type":"String","default_value":"1.0,1.15,1.4","group_name":"Комбо"}]},
	{"id":"can_target_enemy","name":"Выбор цели","description":"Хранит выбранную цель и проверяет дистанцию.","defaults":{"rule_type":"target","enabled":true,"maximum_distance":600.0},"settings":[{"key":"maximum_distance","display_name":"Дальность выбора цели","value_type":"Float","default_value":600.0,"group_name":"Цель","has_range":true,"minimum":0.0,"maximum":100000.0}]}
]
func _settings_for(item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for descriptor in item.settings:
		if descriptor is Dictionary:
			result.append(descriptor.duplicate(true))
	return result

func build_component_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for item in DEFINITIONS:
		var d := ObjectComponentDefinition.new()
		d.component_id = str(item.id)
		d.display_name = str(item.name)
		d.description = str(item.description)
		d.category = "Combat"
		d.category_id = "Combat"
		d.category_display_name = CATEGORY_NAME
		d.component_version = 1
		d.component_script = RULE
		d.setting_definitions = _settings_for(item)
		d.settings = item.defaults.duplicate(true)
		result.append(d)
	return result
func build_capability_definitions() -> Array[ObjectCapabilityDefinition]:
	var result: Array[ObjectCapabilityDefinition] = []
	for item in DEFINITIONS:
		var d := ObjectCapabilityDefinition.new()
		d.capability_id = str(item.id)
		d.display_name = str(item.name)
		d.description = str(item.description)
		d.category_id = CATEGORY_ID
		d.category_name = CATEGORY_NAME
		d.icon = "swords"
		d.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME])
		d.component_ids = PackedStringArray([str(item.id)])
		d.available_in_simple_mode = true
		d.runtime_status = "Implemented"
		d.implementation_note = STATE_NOTE
		d.version = 1
		result.append(d)
	return result
