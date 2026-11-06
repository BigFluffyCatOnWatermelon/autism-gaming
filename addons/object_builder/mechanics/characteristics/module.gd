@tool
extends RefCounted
const CATEGORY_ID := "stats"
const CATEGORY_NAME := "Характеристики"
const STATE_NOTE := "Числовой ресурс: чтение, изменение, расход, процент заполнения и tick(delta, rate_per_second)."
const STAT = preload("res://addons/object_builder/mechanics/characteristics/components/resource_stat.gd")
const DEFINITIONS := [
	{"id":"has_stamina","name":"Выносливость","description":"Запас сил: расходуется и восстанавливается.","defaults":{"current_value":100.0,"maximum_value":100.0,"minimum_value":0.0}},
	{"id":"has_mana","name":"Мана","description":"Запас магической энергии для способностей.","defaults":{"current_value":100.0,"maximum_value":100.0,"minimum_value":0.0}},
	{"id":"has_energy","name":"Энергия","description":"Универсальный энергетический ресурс объекта.","defaults":{"current_value":100.0,"maximum_value":100.0,"minimum_value":0.0}},
	{"id":"has_hunger","name":"Голод","description":"Уровень сытости; для уменьшения вызывай tick() с отрицательной скоростью.","defaults":{"current_value":100.0,"maximum_value":100.0,"minimum_value":0.0}},
	{"id":"has_thirst","name":"Жажда","description":"Показатель насыщения водой; для уменьшения вызывай tick() с отрицательной скоростью.","defaults":{"current_value":100.0,"maximum_value":100.0,"minimum_value":0.0}},
	{"id":"has_temperature","name":"Температура","description":"Температура с настраиваемыми нижней и верхней границами.","defaults":{"current_value":37.0,"maximum_value":42.0,"minimum_value":30.0}},
	{"id":"has_weight_limit","name":"Ограничение веса","description":"Текущая нагрузка и максимально допустимый вес.","defaults":{"current_value":0.0,"maximum_value":50.0,"minimum_value":0.0}},
	{"id":"has_mood","name":"Настроение","description":"Настроение от -100 (плохое) до 100 (хорошее).","defaults":{"current_value":0.0,"maximum_value":100.0,"minimum_value":-100.0}},
	{"id":"has_reputation","name":"Репутация","description":"Отношение окружающих от отрицательного до положительного значения.","defaults":{"current_value":0.0,"maximum_value":100.0,"minimum_value":-100.0}}
]
func _settings_for(item: Dictionary) -> Array[Dictionary]:
	var defaults: Dictionary = item.defaults
	var low := float(defaults.get("minimum_value", 0.0))
	var high := float(defaults.get("maximum_value", 100.0))
	var result: Array[Dictionary] = [
		{"key":"current_value","display_name":"Текущее значение","value_type":"Float","default_value":defaults.current_value,"group_name":"Значение","has_range":true,"minimum":low,"maximum":high},
		{"key":"maximum_value","display_name":"Максимум","value_type":"Float","default_value":high,"group_name":"Границы","has_range":true,"minimum":low,"maximum":1000000.0}
	]
	if defaults.has("minimum_value"):
		result.append({"key":"minimum_value","display_name":"Минимум","value_type":"Float","default_value":low,"group_name":"Границы","has_range":true,"minimum":-1000000.0,"maximum":1000000.0})
	return result
func build_component_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for item in DEFINITIONS:
		var d := ObjectComponentDefinition.new()
		d.component_id = str(item.id)
		d.display_name = str(item.name)
		d.description = str(item.description)
		d.category = "Stats"
		d.category_id = "Stats"
		d.category_display_name = CATEGORY_NAME
		d.component_version = 1
		d.component_script = STAT
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
		d.icon = "gauge"
		d.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME])
		d.component_ids = PackedStringArray([str(item.id)])
		d.available_in_simple_mode = true
		d.runtime_status = "Implemented"
		d.implementation_note = STATE_NOTE
		d.version = 1
		result.append(d)
	return result
