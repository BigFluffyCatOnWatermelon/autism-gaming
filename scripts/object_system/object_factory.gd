extends RefCounted
class_name ObjectFactory


static func instantiate(definition: ObjectDefinition, property_overrides: Dictionary = {}) -> Node:
	if definition == null:
		push_error("ObjectFactory: передано пустое определение.")
		return null

	var instance: Node = null
	if definition.scene != null:
		instance = definition.scene.instantiate()
	if instance == null:
		var created: Object = ClassDB.instantiate(definition.root_type)
		if created is Node:
			instance = created as Node
		else:
			push_error("ObjectFactory: неизвестный тип корневого узла: " + definition.root_type)
			return null

	if not definition.display_name.strip_edges().is_empty():
		instance.name = definition.display_name.validate_node_name()

	instance.set_meta("object_definition_id", definition.object_id)
	instance.set_meta("object_definition_version", definition.schema_version)

	var property_data := _get_property_data(instance)
	if property_data == null:
		property_data = ObjectPropertyData.new()
		property_data.name = "ObjectProperties"
		instance.add_child(property_data)
		property_data.owner = instance
	property_data.configure(definition.custom_properties, property_overrides, true)

	var values := property_data.get_values()
	var property_definitions: Dictionary = {}
	for property_definition in property_data.property_definitions:
		if property_definition == null or property_definition.property_id.is_empty():
			continue
		property_definitions[property_definition.property_id] = property_definition
	for override_id in property_overrides:
		if not property_definitions.has(str(override_id)):
			push_warning(
				"ObjectFactory: override для неизвестного свойства '%s' проигнорирован."
				% str(override_id)
			)

	instance.set_meta("object_custom_properties", values)
	instance.set_meta("object_custom_property_definitions", property_definitions)

	for component_definition in definition.components:
		if component_definition == null or not component_definition.enabled:
			continue
		if component_definition.component_script == null:
			continue
		var component_instance: Object = component_definition.component_script.new()
		if component_instance is ObjectComponent:
			var component_node := component_instance as ObjectComponent
			component_node.name = component_definition.display_name.validate_node_name()
			component_node.configure(component_definition.settings)
			instance.add_child(component_node)
		elif component_instance is Node:
			push_warning(
				"ObjectFactory: компонент '%s' не наследует ObjectComponent и пропущен."
				% component_definition.component_id
			)
			(component_instance as Node).free()
		else:
			push_warning("ObjectFactory: скрипт компонента не создал Node.")
	return instance


static func get_custom_property(
	instance: Node,
	property_id: String,
	fallback: Variant = null
) -> Variant:
	if instance == null:
		return fallback
	var property_data := _get_property_data(instance)
	if property_data != null:
		return property_data.get_custom_property(property_id, fallback)
	if not instance.has_meta("object_custom_properties"):
		return fallback
	var values: Dictionary = instance.get_meta("object_custom_properties", {})
	return values.get(property_id, fallback)


static func get_custom_property_definition(
	instance: Node,
	property_id: String
) -> ObjectPropertyDefinition:
	if instance == null:
		return null
	var property_data := _get_property_data(instance)
	if property_data != null:
		return property_data.get_custom_property_definition(property_id)
	if not instance.has_meta("object_custom_property_definitions"):
		return null
	var definitions: Dictionary = instance.get_meta("object_custom_property_definitions", {})
	return definitions.get(property_id) as ObjectPropertyDefinition


static func set_custom_property(instance: Node, property_id: String, value: Variant) -> bool:
	if instance == null:
		return false
	var property_data := _get_property_data(instance)
	if property_data != null:
		if not property_data.set_custom_property(property_id, value):
			return false
		instance.set_meta("object_custom_properties", property_data.get_values())
		return true

	var property_definition := get_custom_property_definition(instance, property_id)
	if property_definition == null:
		push_warning("ObjectFactory: свойство не найдено: " + property_id)
		return false

	var normalized := normalize_custom_property_value(property_definition, value)
	if not normalized.ok:
		push_warning(
			"ObjectFactory: значение свойства '%s' отклонено: %s"
			% [property_id, normalized.error]
		)
		return false

	var values: Dictionary = instance.get_meta("object_custom_properties", {})
	values[property_id] = normalized.value
	instance.set_meta("object_custom_properties", values)
	return true


static func _get_property_data(instance: Node) -> ObjectPropertyData:
	if instance == null:
		return null
	return instance.get_node_or_null("ObjectProperties") as ObjectPropertyData


static func normalize_custom_property_value(
	property_definition: ObjectPropertyDefinition,
	value: Variant
) -> Dictionary:
	return ObjectPropertyData.normalize_value(property_definition, value)


static func _get_type_default(type_name: String) -> Variant:
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
