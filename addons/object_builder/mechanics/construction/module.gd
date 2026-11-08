@tool
extends RefCounted

const SCRIPT = preload("res://addons/object_builder/mechanics/construction/component.gd")
const CATEGORY_ID := "construction"
const CATEGORY_NAME := "Строительство"
const STATE_NOTE := "Строительный runtime API: проверка размещения, grid snap, поворот, стоимость и списание материалов, улучшения, разбор с возвратом, preview, стадии и blueprint."

const DEFINITIONS := [
	{"id":"can_be_placed","name":"Можно разместить","description":"Проверяет доступность позиции, границы мира, поверхность и блокирующие объекты.","defaults":{"placement_enabled":true,"world_bounds_json":"{}","allowed_terrain_csv":"","placement_clearance":0.0},"settings":[{"key":"placement_enabled","display_name":"Разрешить размещение","value_type":"Boolean","default_value":true,"group_name":"Размещение"},{"key":"world_bounds_json","display_name":"Границы мира JSON","value_type":"String","default_value":"{}","group_name":"Размещение"},{"key":"allowed_terrain_csv","display_name":"Допустимые поверхности","value_type":"String","default_value":"","group_name":"Размещение"},{"key":"placement_clearance","display_name":"Минимальная дистанция","value_type":"Float","default_value":0.0,"group_name":"Размещение","has_range":true,"minimum":0.0,"maximum":100000.0}]},
	{"id":"snaps_to_grid","name":"Привязка к сетке","description":"Округляет координаты до ближайшей ячейки строительной сетки.","defaults":{"grid_size":Vector2(16.0,16.0),"grid_origin":Vector2.ZERO},"settings":[{"key":"grid_size","display_name":"Размер ячейки","value_type":"Vector2","default_value":Vector2(16.0,16.0),"group_name":"Сетка"},{"key":"grid_origin","display_name":"Начало сетки","value_type":"Vector2","default_value":Vector2.ZERO,"group_name":"Сетка"}]},
	{"id":"supports_rotation_placement","name":"Поворот при размещении","description":"Поворачивает предпросмотр на заданный угловой шаг.","defaults":{"rotation_step_degrees":90.0},"settings":[{"key":"rotation_step_degrees","display_name":"Шаг поворота","value_type":"Float","default_value":90.0,"group_name":"Поворот","has_range":true,"minimum":1.0,"maximum":360.0}]},
	{"id":"has_build_cost","name":"Стоимость постройки","description":"Хранит таблицу ресурсов, требуемых для размещения.","defaults":{"build_cost_json":"{}"},"settings":[{"key":"build_cost_json","display_name":"Стоимость JSON","value_type":"String","default_value":"{}","group_name":"Стоимость"}]},
	{"id":"requires_build_materials","name":"Требует материалы","description":"Проверяет и списывает материалы из инвентаря с откатом при ошибке.","defaults":{"material_costs_json":"{}"},"settings":[{"key":"material_costs_json","display_name":"Материалы JSON (пусто — стоимость постройки)","value_type":"String","default_value":"{}","group_name":"Материалы"}]},
	{"id":"can_be_upgraded","name":"Можно улучшить","description":"Хранит уровень улучшения, предел и стоимость следующего уровня.","defaults":{"max_upgrade_level":3,"upgrade_costs_json":"{}"},"settings":[{"key":"max_upgrade_level","display_name":"Максимальный уровень","value_type":"Integer","default_value":3,"group_name":"Улучшение","has_range":true,"minimum":0,"maximum":100},{"key":"upgrade_costs_json","display_name":"Стоимость уровней JSON","value_type":"String","default_value":"{}","group_name":"Улучшение"}]},
	{"id":"can_be_dismantled","name":"Можно разобрать","description":"Помечает объект разобранным и рассчитывает возврат части строительных материалов.","defaults":{"refund_ratio":0.5},"settings":[{"key":"refund_ratio","display_name":"Доля возврата","value_type":"Float","default_value":0.5,"group_name":"Разбор","has_range":true,"minimum":0.0,"maximum":1.0}]},
	{"id":"supports_build_preview","name":"Предпросмотр постройки","description":"Возвращает параметры ghost-preview и признак допустимости размещения.","defaults":{"preview_alpha":0.45,"valid_color":"#66dd88","invalid_color":"#ee6677"},"settings":[{"key":"preview_alpha","display_name":"Прозрачность предпросмотра","value_type":"Float","default_value":0.45,"group_name":"Предпросмотр","has_range":true,"minimum":0.0,"maximum":1.0},{"key":"valid_color","display_name":"Цвет допустимого размещения","value_type":"String","default_value":"#66dd88","group_name":"Предпросмотр"},{"key":"invalid_color","display_name":"Цвет недопустимого размещения","value_type":"String","default_value":"#ee6677","group_name":"Предпросмотр"}]},
	{"id":"has_build_stages","name":"Этапы строительства","description":"Накопляет прогресс и определяет этап по порогам завершения.","defaults":{"build_duration":10.0,"stage_thresholds_json":"[0.25,0.5,0.75,1.0]"},"settings":[{"key":"build_duration","display_name":"Время строительства","value_type":"Float","default_value":10.0,"group_name":"Этапы","has_range":true,"minimum":0.01,"maximum":604800.0},{"key":"stage_thresholds_json","display_name":"Пороги этапов JSON","value_type":"String","default_value":"[0.25,0.5,0.75,1.0]","group_name":"Этапы"}]},
	{"id":"supports_blueprint","name":"Чертёж постройки","description":"Экспортирует и применяет схему размещения, поворота, уровня и этапа.","defaults":{"include_placement_data":true},"settings":[{"key":"include_placement_data","display_name":"Сохранять размещение","value_type":"Boolean","default_value":true,"group_name":"Чертёж"}]}
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
		definition.category = "Construction"
		definition.category_id = "Construction"
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
		definition.icon = "hammer"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "стройка", "постройка"])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
