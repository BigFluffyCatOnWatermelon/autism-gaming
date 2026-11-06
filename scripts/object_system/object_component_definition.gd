@tool
extends Resource
class_name ObjectComponentDefinition

@export var component_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("Appearance", "Physics", "Stats", "Combat", "Interaction", "Destruction", "Audio", "Procedural") var category: String = "Stats"
## Optional custom category metadata. Empty values use the built-in category enum above.
@export var category_id: String = ""
@export var category_display_name: String = ""
@export var supported_node_types: PackedStringArray = PackedStringArray()
@export var required_component_ids: PackedStringArray = PackedStringArray()
@export var incompatible_component_ids: PackedStringArray = PackedStringArray()
@export_range(1, 1000, 1) var component_version: int = 1
@export var enabled: bool = true
@export var component_script: Script
@export_storage var setting_definitions: Array[Dictionary] = []
@export_storage var settings: Dictionary = {}


static func get_builtin_setting_definitions(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var normalized_id := id.strip_edges().to_lower()
	if normalized_id == "damageable":
		result.append({
			"key": "can_receive_damage",
			"display_name": "Принимать урон",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "Защита"
		})
		result.append({
			"key": "damage_multiplier",
			"display_name": "Множитель входящего урона",
			"value_type": "Float",
			"default_value": 1.0,
			"group_name": "Сопротивление",
			"has_range": true,
			"minimum": 0.0,
			"maximum": 10.0
		})
		result.append({
			"key": "flat_reduction",
			"display_name": "Плоское снижение урона",
			"value_type": "Float",
			"default_value": 0.0,
			"group_name": "Сопротивление",
			"has_range": true,
			"minimum": 0.0,
			"maximum": 1000000.0
		})
		return result
	if normalized_id == "attack":
		result.append({
			"key": "attack_damage",
			"display_name": "Урон атаки",
			"value_type": "Float",
			"default_value": 12.0,
			"group_name": "Атака",
			"has_range": true,
			"minimum": 0.0,
			"maximum": 1000000.0
		})
		result.append({
			"key": "attack_range",
			"display_name": "Дистанция атаки",
			"value_type": "Float",
			"default_value": 220.0,
			"group_name": "Атака",
			"has_range": true,
			"minimum": 0.0,
			"maximum": 100000.0
		})
		result.append({
			"key": "cooldown",
			"display_name": "Перезарядка",
			"value_type": "Float",
			"default_value": 0.4,
			"group_name": "Атака",
			"has_range": true,
			"minimum": 0.0,
			"maximum": 60.0
		})
		result.append({
			"key": "require_range",
			"display_name": "Проверять дистанцию",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "Ограничения"
		})
		result.append({
			"key": "can_attack",
			"display_name": "Разрешить атаку",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "Ограничения"
		})
		return result
	if normalized_id == "destructible":
		result.append({
			"key": "destroy_on_zero_health",
			"display_name": "Разрушать при нулевом здоровье",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "Условия"
		})
		result.append({
			"key": "disable_collision_on_destroy",
			"display_name": "Отключать коллизии",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "После разрушения"
		})
		result.append({
			"key": "disable_damage_on_destroy",
			"display_name": "Отключать получение урона",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "После разрушения"
		})
		result.append({
			"key": "hide_on_destroy",
			"display_name": "Скрывать объект",
			"value_type": "Boolean",
			"default_value": false,
			"group_name": "После разрушения"
		})
		result.append({
			"key": "remove_on_destroy",
			"display_name": "Удалять объект",
			"value_type": "Boolean",
			"default_value": false,
			"group_name": "После разрушения"
		})
		result.append({
			"key": "destroy_delay",
			"display_name": "Задержка удаления",
			"value_type": "Float",
			"default_value": 0.0,
			"group_name": "После разрушения",
			"has_range": true,
			"minimum": 0.0,
			"maximum": 300.0
		})
		result.append({
			"key": "restore_health_on_repair",
			"display_name": "Восстанавливать здоровье при починке",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "Восстановление"
		})
		return result
	if normalized_id == "pickup":
		result.append({
			"key": "item_id",
			"display_name": "ID предмета",
			"value_type": "String",
			"default_value": "",
			"group_name": "Предмет"
		})
		result.append({
			"key": "quantity",
			"display_name": "Количество",
			"value_type": "Integer",
			"default_value": 1,
			"group_name": "Предмет",
			"has_range": true,
			"minimum": 1,
			"maximum": 99999
		})
		result.append({
			"key": "can_be_picked_up",
			"display_name": "Разрешить подбор",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "Доступность"
		})
		result.append({
			"key": "remove_object_when_empty",
			"display_name": "Удалить объект после подбора",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "После подбора"
		})
		return result
	if normalized_id != "health":
		return result

	result.append({
		"key": "max_health",
		"display_name": "Максимальное здоровье",
		"value_type": "Float",
		"default_value": 100.0,
		"group_name": "Здоровье",
		"has_range": true,
		"minimum": 1.0,
		"maximum": 1000000.0
	})
	result.append({
		"key": "starting_health",
		"display_name": "Начальное здоровье",
		"value_type": "Float",
		"default_value": 100.0,
		"group_name": "Здоровье",
		"has_range": true,
		"minimum": 0.0,
		"maximum": 1000000.0
	})
	result.append({
		"key": "invulnerable",
		"display_name": "Неуязвимость",
		"value_type": "Boolean",
		"default_value": false,
		"group_name": "Защита"
	})
	result.append({
		"key": "can_heal",
		"display_name": "Разрешить лечение",
		"value_type": "Boolean",
		"default_value": true,
		"group_name": "Восстановление"
	})
	return result


func get_setting_definitions() -> Array[Dictionary]:
	var source := setting_definitions
	if source.is_empty():
		source = get_builtin_setting_definitions(component_id)
	var result: Array[Dictionary] = []
	for descriptor in source:
		result.append(descriptor.duplicate(true))
	return result


func get_inspector_property_name_for_setting(key: String) -> String:
	var descriptor := _find_setting_definition(key)
	if descriptor.is_empty():
		return ""
	return _inspector_property_name(descriptor)


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func get_settings() -> Dictionary:
	return settings.duplicate(true)


func set_setting(key: String, value: Variant) -> bool:
	var descriptor := _find_setting_definition(key)
	if descriptor.is_empty():
		settings[key] = value
		return true

	var value_type := str(descriptor.get("value_type", ""))
	var normalized: Variant = value
	match value_type:
		"String":
			if typeof(value) != TYPE_STRING:
				return false
		"Integer":
			if typeof(value) == TYPE_INT:
				normalized = int(value)
			elif typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
				normalized = int(roundf(float(value)))
			else:
				return false
		"Float":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return false
			if is_nan(float(value)) or is_inf(float(value)):
				return false
			normalized = float(value)
		"Boolean":
			if typeof(value) != TYPE_BOOL:
				return false
		"Vector2":
			if typeof(value) != TYPE_VECTOR2:
				return false
		_:
			return false

	if bool(descriptor.get("has_range", false)):
		var minimum := float(descriptor.get("minimum", -1000000.0))
		var maximum := float(descriptor.get("maximum", 1000000.0))
		if minimum > maximum:
			return false
		if value_type == "Integer":
			var lower := int(ceil(minimum))
			var upper := int(floor(maximum))
			if lower > upper:
				return false
			normalized = clampi(int(normalized), lower, upper)
		elif value_type == "Float":
			normalized = clampf(float(normalized), minimum, maximum)

	settings[key] = normalized
	notify_property_list_changed()
	return true


func _find_setting_definition(key: String) -> Dictionary:
	for descriptor in get_setting_definitions():
		if str(descriptor.get("key", "")) == key:
			return descriptor
	return {}


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	for descriptor in get_setting_definitions():
		var property_name := _inspector_property_name(descriptor)
		var property_type := _variant_type_for_setting(str(descriptor.get("value_type", "")))
		if property_name.is_empty() or property_type == TYPE_NIL:
			continue
		var hints := PROPERTY_HINT_NONE
		var hint_string := ""
		if bool(descriptor.get("has_range", false)) and (
			str(descriptor.get("value_type", "")) == "Integer"
			or str(descriptor.get("value_type", "")) == "Float"
		):
			hints = PROPERTY_HINT_RANGE
			hint_string = "%s,%s" % [
				str(descriptor.get("minimum", 0.0)),
				str(descriptor.get("maximum", 1000000.0))
			]
		properties.append({
			"name": property_name,
			"type": property_type,
			"hint": hints,
			"hint_string": hint_string,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	return properties


func _get(property: StringName) -> Variant:
	var key := _setting_key_from_inspector_property(str(property))
	if key.is_empty():
		return null
	var descriptor := _find_setting_definition(key)
	return settings.get(key, descriptor.get("default_value"))


func _set(property: StringName, value: Variant) -> bool:
	var key := _setting_key_from_inspector_property(str(property))
	if key.is_empty():
		return false
	return set_setting(key, value)


func _property_can_revert(property: StringName) -> bool:
	var key := _setting_key_from_inspector_property(str(property))
	if key.is_empty():
		return false
	return true


func _property_get_revert(property: StringName) -> Variant:
	var key := _setting_key_from_inspector_property(str(property))
	if key.is_empty():
		return null
	var descriptor := _find_setting_definition(key)
	return descriptor.get("default_value")


func _inspector_property_name(descriptor: Dictionary) -> String:
	var key := str(descriptor.get("key", ""))
	var prefix := _sanitize_identifier(component_id)
	if key.is_empty() or prefix.is_empty():
		return ""
	return "%s_%s" % [prefix, key]


func _setting_key_from_inspector_property(property_name: String) -> String:
	var prefix := _sanitize_identifier(component_id) + "_"
	if not property_name.begins_with(prefix):
		return ""
	return property_name.trim_prefix(prefix)


func _sanitize_identifier(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.strip_edges().trim_prefix("_").trim_suffix("_")


func _variant_type_for_setting(value_type: String) -> int:
	match value_type:
		"String":
			return TYPE_STRING
		"Integer":
			return TYPE_INT
		"Float":
			return TYPE_FLOAT
		"Boolean":
			return TYPE_BOOL
		"Vector2":
			return TYPE_VECTOR2
		_:
			return TYPE_NIL
