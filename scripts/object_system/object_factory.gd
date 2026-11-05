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

	var values: Dictionary = {}
	for property_definition in definition.custom_properties:
		if property_definition == null or property_definition.property_id.is_empty():
			continue
		values[property_definition.property_id] = property_overrides.get(
			property_definition.property_id,
			property_definition.default_value
		)
	instance.set_meta("object_custom_properties", values)

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


static func get_custom_property(instance: Node, property_id: String, fallback: Variant = null) -> Variant:
	if instance == null or not instance.has_meta("object_custom_properties"):
		return fallback
	var values: Dictionary = instance.get_meta("object_custom_properties", {})
	return values.get(property_id, fallback)


static func set_custom_property(instance: Node, property_id: String, value: Variant) -> void:
	if instance == null:
		return
	var values: Dictionary = instance.get_meta("object_custom_properties", {})
	values[property_id] = value
	instance.set_meta("object_custom_properties", values)
