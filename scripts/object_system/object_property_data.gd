@tool
extends Node
class_name ObjectPropertyData

@export_storage var property_definitions: Array[ObjectPropertyDefinition] = []
@export_storage var stored_values: Dictionary = {}


func configure(
	definitions: Array[ObjectPropertyDefinition],
	overrides: Dictionary = {},
	preserve_existing: bool = true
) -> void:
	var previous_values := stored_values.duplicate(true)
	property_definitions.clear()
	var next_values: Dictionary = {}
	for source_definition in definitions:
		if source_definition == null or source_definition.property_id.strip_edges().is_empty():
			continue
		var definition := source_definition.duplicate(true) as ObjectPropertyDefinition
		if definition == null:
			continue
		property_definitions.append(definition)

		var candidate: Variant = definition.default_value
		if preserve_existing and previous_values.has(definition.property_id):
			candidate = previous_values[definition.property_id]
		if overrides.has(definition.property_id):
			candidate = overrides[definition.property_id]

		var normalized := normalize_value(definition, candidate)
		if not normalized.ok:
			push_warning(
				"ObjectPropertyData: неверное значение '%s': %s. Используется default."
				% [definition.property_id, normalized.error]
			)
			normalized = normalize_value(definition, definition.default_value)
		if normalized.ok:
			next_values[definition.property_id] = normalized.value
		else:
			next_values[definition.property_id] = _type_default(definition.value_type)

	stored_values = next_values
	notify_property_list_changed()


func get_custom_property(property_id: String, fallback: Variant = null) -> Variant:
	return stored_values.get(property_id, fallback)


func get_custom_property_definition(property_id: String) -> ObjectPropertyDefinition:
	for definition in property_definitions:
		if definition != null and definition.property_id == property_id:
			return definition
	return null


func set_custom_property(property_id: String, value: Variant) -> bool:
	var definition := get_custom_property_definition(property_id)
	if definition == null:
		return false
	var normalized := normalize_value(definition, value)
	if not normalized.ok:
		push_warning(
			"ObjectPropertyData: значение свойства '%s' отклонено: %s"
			% [property_id, normalized.error]
		)
		return false
	stored_values[property_id] = normalized.value
	return true


func get_values() -> Dictionary:
	return stored_values.duplicate(true)


func _get_property_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var previous_group := ""
	var used_names := {}
	for definition in property_definitions:
		if definition == null:
			continue
		var property_name := _inspector_property_name(definition)
		if property_name.is_empty() or used_names.has(property_name):
			continue

		var group_name := definition.group_name.strip_edges()
		if not group_name.is_empty() and group_name != previous_group:
			result.append({
				"name": group_name,
				"type": TYPE_NIL,
				"hint_string": _group_prefix(group_name),
				"usage": PROPERTY_USAGE_GROUP
			})
		previous_group = group_name

		var property_info: Dictionary = {
			"name": property_name,
			"type": _variant_type(definition.value_type),
			"usage": PROPERTY_USAGE_DEFAULT
		}
		if definition.has_range and definition.value_type in ["Integer", "Float"]:
			property_info["hint"] = PROPERTY_HINT_RANGE
			var step_value := "1" if definition.value_type == "Integer" else "0.01"
			property_info["hint_string"] = "%s,%s,%s" % [
				str(definition.minimum),
				str(definition.maximum),
				step_value
			]
		result.append(property_info)
		used_names[property_name] = true
	return result


func _get(property: StringName) -> Variant:
	var definition := _find_definition_by_inspector_name(str(property))
	if definition == null:
		return null
	return stored_values.get(definition.property_id, definition.default_value)


func _set(property: StringName, value: Variant) -> bool:
	var definition := _find_definition_by_inspector_name(str(property))
	if definition == null:
		return false
	var normalized := normalize_value(definition, value)
	if not normalized.ok:
		return false
	stored_values[definition.property_id] = normalized.value
	return true


func _property_can_revert(property: StringName) -> bool:
	return _find_definition_by_inspector_name(str(property)) != null


func _property_get_revert(property: StringName) -> Variant:
	var definition := _find_definition_by_inspector_name(str(property))
	if definition == null:
		return null
	return definition.default_value


func _find_definition_by_inspector_name(property_name: String) -> ObjectPropertyDefinition:
	for definition in property_definitions:
		if definition == null:
			continue
		if _inspector_property_name(definition) == property_name:
			return definition
	return null


func _inspector_property_name(definition: ObjectPropertyDefinition) -> String:
	var property_id := definition.property_id.strip_edges()
	var group_name := definition.group_name.strip_edges()
	if group_name.is_empty():
		return property_id
	return _group_prefix(group_name) + property_id


func _group_prefix(group_name: String) -> String:
	var prefix := group_name.to_snake_case()
	if prefix.is_empty():
		prefix = "group"
	return prefix + "_"


static func normalize_value(
	definition: ObjectPropertyDefinition,
	value: Variant
) -> Dictionary:
	if definition == null:
		return {"ok": false, "value": null, "error": "определение свойства отсутствует"}

	var normalized_value: Variant = value
	match definition.value_type:
		"String":
			if typeof(value) != TYPE_STRING:
				return {"ok": false, "value": null, "error": "ожидалась строка"}
		"Integer":
			if typeof(value) == TYPE_INT:
				normalized_value = int(value)
			elif typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
				normalized_value = int(roundf(float(value)))
			else:
				return {"ok": false, "value": null, "error": "ожидалось целое число"}
		"Float":
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				normalized_value = float(value)
			else:
				return {"ok": false, "value": null, "error": "ожидалось число"}
		"Boolean":
			if typeof(value) != TYPE_BOOL:
				return {"ok": false, "value": null, "error": "ожидалось логическое значение"}
		"Vector2":
			if typeof(value) != TYPE_VECTOR2:
				return {"ok": false, "value": null, "error": "ожидался Vector2"}
		_:
			return {"ok": false, "value": null, "error": "неизвестный тип свойства"}

	if definition.has_range:
		if definition.value_type == "Integer":
			var lower_bound := int(ceil(definition.minimum))
			var upper_bound := int(floor(definition.maximum))
			if lower_bound > upper_bound:
				return {"ok": false, "value": null, "error": "целочисленный диапазон пуст"}
			normalized_value = clampi(int(normalized_value), lower_bound, upper_bound)
		elif definition.value_type == "Float":
			if definition.minimum > definition.maximum:
				return {"ok": false, "value": null, "error": "минимум больше максимума"}
			normalized_value = clampf(
				float(normalized_value),
				definition.minimum,
				definition.maximum
			)

	return {"ok": true, "value": normalized_value, "error": ""}


static func _variant_type(type_name: String) -> int:
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


static func _type_default(type_name: String) -> Variant:
	match type_name:
		"String":
			return ""
		"Integer":
			return 0
		"Float":
			return 0.0
		"Boolean":
			return false
		"Vector2":
			return Vector2.ZERO
		_:
			return null
