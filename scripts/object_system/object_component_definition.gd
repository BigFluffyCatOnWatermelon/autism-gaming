@tool
extends Resource
class_name ObjectComponentDefinition

@export var component_id: String = ""
@export var display_name: String = ""
@export_enum("Appearance", "Physics", "Stats", "Combat", "Interaction", "Destruction", "Audio", "Procedural") var category: String = "Stats"
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
	return true


func _get_property_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var previous_group := ""
	var used_names := {}
	for descriptor in get_setting_definitions():
		var key := str(descriptor.get("key", "")).strip_edges()
		if key.is_empty():
			continue
		var property_name := _inspector_property_name(descriptor)
		if property_name.is_empty() or used_names.has(property_name):
			continue

		var group_name := str(descriptor.get("group_name", "")).strip_edges()
		if not group_name.is_empty() and group_name != previous_group:
			result.append({
				"name": group_name,
				"type": TYPE_NIL,
				"hint_string": _group_prefix(group_name),
				"usage": PROPERTY_USAGE_GROUP
			})
		previous_group = group_name

		var value_type := str(descriptor.get("value_type", ""))
		var property_info: Dictionary = {
			"name": property_name,
			"type": _variant_type(value_type),
			"usage": PROPERTY_USAGE_DEFAULT
		}
		if bool(descriptor.get("has_range", false)) and value_type in ["Integer", "Float"]:
			var step_value := "1" if value_type == "Integer" else "0.01"
			property_info["hint"] = PROPERTY_HINT_RANGE
			property_info["hint_string"] = "%s,%s,%s" % [
				str(descriptor.get("minimum", 0.0)),
				str(descriptor.get("maximum", 100.0)),
				step_value
			]
		result.append(property_info)
		used_names[property_name] = true
	return result


func _get(property: StringName) -> Variant:
	var descriptor := _find_setting_by_inspector_name(str(property))
	if descriptor.is_empty():
		return null
	var key := str(descriptor.get("key", ""))
	return settings.get(key, descriptor.get("default_value"))


func _set(property: StringName, value: Variant) -> bool:
	var descriptor := _find_setting_by_inspector_name(str(property))
	if descriptor.is_empty():
		return false
	return set_setting(str(descriptor.get("key", "")), value)


func _property_can_revert(property: StringName) -> bool:
	return not _find_setting_by_inspector_name(str(property)).is_empty()


func _property_get_revert(property: StringName) -> Variant:
	var descriptor := _find_setting_by_inspector_name(str(property))
	if descriptor.is_empty():
		return null
	return descriptor.get("default_value")


func _find_setting_definition(key: String) -> Dictionary:
	for descriptor in get_setting_definitions():
		if str(descriptor.get("key", "")) == key:
			return descriptor
	return {}


func _find_setting_by_inspector_name(property_name: String) -> Dictionary:
	for descriptor in get_setting_definitions():
		if _inspector_property_name(descriptor) == property_name:
			return descriptor
	return {}


func _inspector_property_name(descriptor: Dictionary) -> String:
	var key := str(descriptor.get("key", "")).strip_edges()
	if key.is_empty():
		return ""
	var group_name := str(descriptor.get("group_name", "")).strip_edges()
	if group_name.is_empty():
		return key.to_snake_case()
	return _group_prefix(group_name) + key.to_snake_case()


func _group_prefix(group_name: String) -> String:
	var prefix := group_name.to_snake_case()
	if prefix.is_empty():
		prefix = "settings"
	return prefix + "_"


func _variant_type(type_name: String) -> int:
	match type_name:
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
