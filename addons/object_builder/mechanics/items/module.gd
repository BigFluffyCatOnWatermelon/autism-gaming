@tool
extends RefCounted

const SCRIPT = preload("res://addons/object_builder/mechanics/items/component.gd")
const CATEGORY_ID := "items"
const CATEGORY_NAME := "Предметы"
const STATE_NOTE := "Компонентный API предмета: подбор, стопки, вес, стоимость, расходование, экипировка, выбрасывание, обмен, прочность и лимит применений. Состояние экземпляра экспортируется и восстанавливается."

const DEFINITIONS := [
	{"id":"is_pickup_item","name":"Подбираемый предмет","description":"Разрешает подбор предмета и сохраняет состояние получения.","defaults":{"pickup_enabled":true,"pickup_radius":48.0},"settings":[{"key":"pickup_enabled","display_name":"Разрешить подбор","value_type":"Boolean","default_value":true,"group_name":"Подбор"},{"key":"pickup_radius","display_name":"Радиус подбора","value_type":"Float","default_value":48.0,"group_name":"Подбор","has_range":true,"minimum":0.0,"maximum":10000.0}]},
	{"id":"is_stackable","name":"Складывается в стопку","description":"Объединяет одинаковые предметы и ограничивает размер стопки.","defaults":{"max_stack_size":99,"initial_count":1},"settings":[{"key":"max_stack_size","display_name":"Максимум в стопке","value_type":"Integer","default_value":99,"group_name":"Стопка","has_range":true,"minimum":1,"maximum":999999},{"key":"initial_count","display_name":"Начальное количество","value_type":"Integer","default_value":1,"group_name":"Стопка","has_range":true,"minimum":1,"maximum":999999}]},
	{"id":"has_item_weight","name":"Вес предмета","description":"Возвращает вес единицы и суммарный вес с учётом количества.","defaults":{"weight_per_unit":1.0},"settings":[{"key":"weight_per_unit","display_name":"Вес единицы","value_type":"Float","default_value":1.0,"group_name":"Вес","has_range":true,"minimum":0.0,"maximum":1000000.0}]},
	{"id":"has_item_value","name":"Стоимость предмета","description":"Рассчитывает базовую стоимость предмета.","defaults":{"base_value":0.0,"currency_id":"coins"},"settings":[{"key":"base_value","display_name":"Базовая стоимость","value_type":"Float","default_value":0.0,"group_name":"Стоимость","has_range":true,"minimum":0.0,"maximum":1000000000.0},{"key":"currency_id","display_name":"ID валюты","value_type":"String","default_value":"coins","group_name":"Стоимость"}]},
	{"id":"is_consumable","name":"Расходуемый предмет","description":"Уменьшает количество предмета после подтверждённого использования.","defaults":{"consume_amount":1},"settings":[{"key":"consume_amount","display_name":"Количество за применение","value_type":"Integer","default_value":1,"group_name":"Использование","has_range":true,"minimum":1,"maximum":999999}]},
	{"id":"can_be_equipped","name":"Можно экипировать","description":"Проверяет допустимый слот и сохраняет текущий слот экипировки.","defaults":{"equipment_slot":"hand","allowed_slots_csv":"hand"},"settings":[{"key":"equipment_slot","display_name":"Основной слот","value_type":"String","default_value":"hand","group_name":"Экипировка"},{"key":"allowed_slots_csv","display_name":"Разрешённые слоты через запятую","value_type":"String","default_value":"hand","group_name":"Экипировка"}]},
	{"id":"can_be_dropped","name":"Можно выбросить","description":"Снимает количество со стопки и формирует проверяемый payload выброса.","defaults":{"drop_enabled":true},"settings":[{"key":"drop_enabled","display_name":"Разрешить выбрасывание","value_type":"Boolean","default_value":true,"group_name":"Выброс"}]},
	{"id":"can_be_traded","name":"Можно обменять","description":"Проверяет возможность обмена и рассчитывает итоговую стоимость перед списанием количества.","defaults":{"trade_enabled":true,"trade_price_multiplier":1.0},"settings":[{"key":"trade_enabled","display_name":"Разрешить обмен","value_type":"Boolean","default_value":true,"group_name":"Обмен"},{"key":"trade_price_multiplier","display_name":"Множитель цены","value_type":"Float","default_value":1.0,"group_name":"Обмен","has_range":true,"minimum":0.0,"maximum":100000.0}]},
	{"id":"has_item_durability","name":"Прочность предмета","description":"Уменьшает прочность и сообщает о достижении нуля.","defaults":{"maximum_durability":100.0,"starting_durability":100.0},"settings":[{"key":"maximum_durability","display_name":"Максимальная прочность","value_type":"Float","default_value":100.0,"group_name":"Прочность","has_range":true,"minimum":0.0,"maximum":1000000.0},{"key":"starting_durability","display_name":"Начальная прочность","value_type":"Float","default_value":100.0,"group_name":"Прочность","has_range":true,"minimum":0.0,"maximum":1000000.0}]},
	{"id":"has_item_uses","name":"Ограниченное число применений","description":"Хранит остаток применений и отклоняет использование при нуле.","defaults":{"maximum_uses":10,"starting_uses":10},"settings":[{"key":"maximum_uses","display_name":"Максимум применений","value_type":"Integer","default_value":10,"group_name":"Применения","has_range":true,"minimum":0,"maximum":999999},{"key":"starting_uses","display_name":"Начальные применения","value_type":"Integer","default_value":10,"group_name":"Применения","has_range":true,"minimum":0,"maximum":999999}]}
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
		definition.category = "Items"
		definition.category_id = "Items"
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
		# is_pickup_item is a reserved built-in capability backed by the core Pickup component.
		# Keep the package component definition, but never attempt to replace the built-in card.
		if str(item.id) == "is_pickup_item":
			continue
		var definition := ObjectCapabilityDefinition.new()
		definition.capability_id = str(item.id)
		definition.display_name = str(item.name)
		definition.description = str(item.description)
		definition.category_id = CATEGORY_ID
		definition.category_name = CATEGORY_NAME
		definition.icon = "package"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "предмет", "вещь"])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
