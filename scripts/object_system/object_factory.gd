extends RefCounted
class_name ObjectFactory

const MECHANIC_MODULE_LOADER = preload("res://scripts/object_system/mechanic_module_loader.gd")
const OBJECT_SCENE_STRUCTURE_SERVICE = preload("res://scripts/object_system/object_scene_structure_service.gd")
static var _mechanic_modules_attempted := false


static func instantiate(definition: ObjectDefinition, property_overrides: Dictionary = {}) -> Node:
	if definition == null:
		push_error("ObjectFactory: передано пустое определение.")
		return null

	if not _mechanic_modules_attempted:
		_mechanic_modules_attempted = true
		var module_errors := MECHANIC_MODULE_LOADER.register_modules_in_directory()
		for error_message in module_errors:
			push_error("ObjectFactory: " + error_message)

	var instance: Node = null
	if not definition.scene_path.strip_edges().is_empty() and ResourceLoader.exists(definition.scene_path):
		var saved_scene := ResourceLoader.load(
			definition.scene_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		) as PackedScene
		if saved_scene != null:
			instance = saved_scene.instantiate()
	if instance == null and definition.scene != null:
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
		property_data.name = "Свойства объекта"
		instance.add_child(property_data)
		property_data.owner = instance
	property_data.configure(definition.custom_properties, property_overrides, true)

	# Build and validate the declarative node tree before attaching mechanic components.
	var structure_result := OBJECT_SCENE_STRUCTURE_SERVICE.apply_structure(definition, instance)
	if not bool(structure_result.get("ok", false)):
		var structure_errors: PackedStringArray = structure_result.get("errors", PackedStringArray())
		for error_message in structure_errors:
			push_error("ObjectFactory: " + error_message)
		instance.free()
		return null

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

	# Fold deprecated standalone selections into their visible parent before runtime binding.
	var merge_result := ObjectCapabilityService.migrate_merged_selections(definition.capabilities)
	var runtime_capabilities: Array[ObjectCapabilitySelection] = merge_result.get("selections", [])
	# Validate friendly capability choices before building the component plan.
	var capability_errors := ObjectCapabilityService.validate_selections(
		runtime_capabilities,
		instance
	)
	if not capability_errors.is_empty():
		for error_message in capability_errors:
			push_error("ObjectFactory: " + error_message)
		instance.free()
		return null

	# Normalize the legacy root-level component array into the same binding model.
	var all_bindings: Array[ObjectComponentBinding] = []
	var attached_legacy_component_ids: Dictionary = {}
	var legacy_component_definitions_by_id: Dictionary = {}
	for component_definition in definition.components:
		if component_definition == null:
			continue
		var component_id := component_definition.component_id.strip_edges().to_lower()
		if component_id.is_empty():
			if component_definition.enabled:
				push_error("ObjectFactory: у legacy-компонента отсутствует ID.")
				instance.free()
				return null
			continue
		if not legacy_component_definitions_by_id.has(component_id) or component_definition.enabled:
			legacy_component_definitions_by_id[component_id] = component_definition
		if not component_definition.enabled:
			continue
		if attached_legacy_component_ids.has(component_id):
			push_warning("ObjectFactory: повторный legacy-компонент '%s' пропущен." % component_id)
			continue
		attached_legacy_component_ids[component_id] = true

		var legacy_binding := ObjectComponentBinding.new()
		legacy_binding.binding_id = "legacy:" + component_id
		legacy_binding.component_definition = component_definition.duplicate(true) as ObjectComponentDefinition
		legacy_binding.target_node_path = NodePath(".")
		all_bindings.append(legacy_binding)

	# Explicit advanced bindings plus automatically resolved simple capabilities.
	for binding in definition.component_bindings:
		all_bindings.append(binding)
	for generated_binding in ObjectCapabilityService.build_component_bindings(runtime_capabilities):
		all_bindings.append(generated_binding)

	# Older definitions stored inventory and container components in the legacy
	# root array. They used has_container_capacity.max_weight for both systems.
	# Add the new inventory-only component without mutating the saved definition.
	var legacy_inventory := legacy_component_definitions_by_id.get("has_inventory") as ObjectComponentDefinition
	var legacy_container_capacity := legacy_component_definitions_by_id.get("has_container_capacity") as ObjectComponentDefinition
	var legacy_weight_capacity := legacy_component_definitions_by_id.get("has_weight_capacity") as ObjectComponentDefinition
	if (
		legacy_inventory != null
		and legacy_inventory.enabled
		and legacy_container_capacity != null
		and legacy_container_capacity.enabled
		and legacy_weight_capacity == null
	):
		var has_explicit_weight_setting := false
		for selection in runtime_capabilities:
			if selection != null and str(selection.target_node_path) == "." and selection.settings_by_component.has("has_weight_capacity"):
				has_explicit_weight_setting = true
				break
		var explicit_weight_binding := false
		var generated_weight_binding: ObjectComponentBinding = null
		for binding in all_bindings:
			if binding == null or binding.component_definition == null:
				continue
			if binding.component_definition.component_id.strip_edges().to_lower() != "has_weight_capacity" or binding.target_node_path != NodePath("."):
				continue
			if str(binding.binding_id).begins_with("capability_"):
				generated_weight_binding = binding
			else:
				explicit_weight_binding = true
				break
		if not has_explicit_weight_setting and not explicit_weight_binding:
			if generated_weight_binding == null:
				generated_weight_binding = ObjectComponentCatalog.create_binding(
					"has_weight_capacity",
					NodePath(".")
				)
				if generated_weight_binding != null:
					generated_weight_binding.binding_id = "legacy_migrated:has_weight_capacity"
					all_bindings.append(generated_weight_binding)
			if generated_weight_binding != null:
				var legacy_capacity_settings := legacy_container_capacity.get_settings()
				generated_weight_binding.component_definition.set_setting("enabled", true)
				generated_weight_binding.component_definition.set_setting(
					"max_weight",
					float(legacy_capacity_settings.get("max_weight", 0.0))
				)

	# Resolve every target, supported node type, dependency and conflict before attaching
	# the first component. A failed plan never returns a partially assembled object.
	var binding_plan := ObjectComponentCatalog.resolve_bindings(all_bindings, instance)
	if not bool(binding_plan.get("ok", false)):
		var binding_errors: PackedStringArray = binding_plan.get("errors", PackedStringArray())
		for error_message in binding_errors:
			push_error("ObjectFactory: " + error_message)
		instance.free()
		return null

	var resolved_bindings: Array[ObjectComponentBinding] = []
	var planned_bindings: Variant = binding_plan.get("bindings", [])
	if planned_bindings is Array:
		for value in planned_bindings:
			if value is ObjectComponentBinding:
				resolved_bindings.append(value as ObjectComponentBinding)

	for binding in resolved_bindings:
		var target_node := binding.get_target_node(instance)
		if target_node == null:
			push_error(
				"ObjectFactory: целевой узел привязки '%s' исчез после проверки."
				% binding.binding_id
			)
			instance.free()
			return null
		if not _attach_component(
			target_node,
			instance,
			binding.component_definition,
			binding.binding_id,
			binding.target_node_path
		):
			instance.free()
			return null

	instance.set_meta("object_builder_runtime_components_ready", true)
	return instance


## Attaches the definition's runtime components to an existing scene instance.
## Object Builder scenes are often dragged directly into the Godot editor and
## therefore do not pass through instantiate() at runtime. The reference node
## uses this bridge to keep both creation paths behaviorally identical.
static func initialize_existing_instance(
	definition: ObjectDefinition,
	existing_root: Node
) -> bool:
	if definition == null or existing_root == null or not is_instance_valid(existing_root):
		return false
	if bool(existing_root.get_meta("object_builder_runtime_components_ready", false)):
		return true

	# Build a temporary Factory instance so the normal validation and component
	# configuration path remains the single source of truth.
	var prototype := instantiate(definition)
	if prototype == null:
		return false

	existing_root.set_meta("object_definition_id", definition.object_id)
	existing_root.set_meta("object_definition_version", definition.schema_version)
	existing_root.set_meta("object_builder_id", definition.object_id)
	existing_root.set_meta(
		"object_builder_uri",
		"objectbuilder://object/" + definition.object_id.uri_encode()
	)
	existing_root.set_meta("object_builder_name", definition.display_name)
	existing_root.set_meta("object_category", definition.category)
	existing_root.set_meta("object_builder_relations", definition.relations.duplicate(true))
	var definition_resource_path := ObjectLibraryService.get_definition_path_for_definition(definition)
	if not definition_resource_path.is_empty():
		existing_root.set_meta("object_builder_resource_path", definition_resource_path)

	var structure_result := OBJECT_SCENE_STRUCTURE_SERVICE.apply_structure(definition, existing_root)
	if not bool(structure_result.get("ok", false)):
		var structure_errors: PackedStringArray = structure_result.get("errors", PackedStringArray())
		for error_message in structure_errors:
			push_error("ObjectFactory: " + error_message)
		prototype.free()
		return false

	var property_data := _get_property_data(existing_root)
	if property_data == null:
		property_data = ObjectPropertyData.new()
		property_data.name = "Свойства объекта"
		existing_root.add_child(property_data)
		property_data.owner = existing_root
	property_data.configure(definition.custom_properties, {}, true)
	var property_definitions: Dictionary = {}
	for property_definition in property_data.property_definitions:
		if property_definition == null or property_definition.property_id.is_empty():
			continue
		property_definitions[property_definition.property_id] = property_definition
	existing_root.set_meta("object_custom_properties", property_data.get_values())
	existing_root.set_meta("object_custom_property_definitions", property_definitions)

	var existing_bindings: Dictionary = {}
	for existing_component in get_components(existing_root):
		existing_bindings[
			"%s@%s@%s" % [
				existing_component.component_id,
				existing_component.binding_id,
				str(existing_component.target_node_path)
			]
		] = true

	var transfer_plan: Array[Dictionary] = []
	for component in get_components(prototype):
		var binding_key := "%s@%s@%s" % [
			component.component_id,
			component.binding_id,
			str(component.target_node_path)
		]
		if existing_bindings.has(binding_key):
			continue
		var target_path: NodePath = component.target_node_path
		var target_node: Node
		if target_path.is_empty() or str(target_path) == ".":
			target_node = existing_root
		else:
			target_node = existing_root.get_node_or_null(target_path)
		if target_node == null:
			push_error(
				"ObjectFactory: для прямого экземпляра не найден узел привязки '%s'."
				% str(target_path)
			)
			prototype.free()
			return false
		if component.has_method("bind_animation_player") and _find_animation_player(target_node) == null:
			push_error("ObjectFactory: для компонента '%s' не найден AnimationPlayer." % component.component_id)
			prototype.free()
			return false
		if component.has_method("bind_animated_sprite") and _find_animated_sprite(target_node) == null:
			push_error("ObjectFactory: для компонента '%s' не найден AnimatedSprite2D." % component.component_id)
			prototype.free()
			return false
		transfer_plan.append({"component": component, "target": target_node})

	var transferred: Array[ObjectComponent] = []
	for entry in transfer_plan:
		var component := entry.get("component") as ObjectComponent
		var target_node := entry.get("target") as Node
		var old_parent := component.get_parent()
		if old_parent != null:
			old_parent.remove_child(component)
		component.configure_context(existing_root, component.binding_id, component.target_node_path)

		if component.has_method("bind_target"):
			var bind_result: Variant = component.call("bind_target", target_node)
			if typeof(bind_result) == TYPE_BOOL and not bool(bind_result):
				component.free()
				for attached_component in transferred:
					var attached_parent := attached_component.get_parent()
					if attached_parent != null:
						attached_parent.remove_child(attached_component)
					attached_component.free()
				prototype.free()
				return false
		if component.has_method("bind_animation_player"):
			var animation_bind_result: Variant = component.call(
				"bind_animation_player",
				_find_animation_player(target_node)
			)
			if typeof(animation_bind_result) == TYPE_BOOL and not bool(animation_bind_result):
				component.free()
				for attached_component in transferred:
					var attached_parent := attached_component.get_parent()
					if attached_parent != null:
						attached_parent.remove_child(attached_component)
					attached_component.free()
				prototype.free()
				return false
		if component.has_method("bind_animated_sprite"):
			var sprite_bind_result: Variant = component.call(
				"bind_animated_sprite",
				_find_animated_sprite(target_node)
			)
			if typeof(sprite_bind_result) == TYPE_BOOL and not bool(sprite_bind_result):
				component.free()
				for attached_component in transferred:
					var attached_parent := attached_component.get_parent()
					if attached_parent != null:
						attached_parent.remove_child(attached_component)
					attached_component.free()
				prototype.free()
				return false

		target_node.add_child(component)
		transferred.append(component)

	prototype.free()
	existing_root.set_meta("object_builder_runtime_components_ready", true)
	return true


static func _attach_component(
	target_node: Node,
	object_root: Node,
	component_definition: ObjectComponentDefinition,
	binding_id: String,
	target_node_path: NodePath
) -> bool:
	if target_node == null or object_root == null or component_definition == null:
		push_error("ObjectFactory: невозможно подключить пустую привязку компонента.")
		return false

	var component_id := component_definition.component_id.strip_edges().to_lower()
	var catalog_definition := ObjectComponentCatalog.create_definition(component_id)
	var component_script := component_definition.component_script
	var component_settings: Dictionary = {}
	if catalog_definition != null:
		if component_script == null:
			component_script = catalog_definition.component_script
		component_settings = catalog_definition.settings.duplicate(true)
	for setting_key in component_definition.settings:
		component_settings[setting_key] = component_definition.settings[setting_key]

	if component_script == null:
		push_error(
			"ObjectFactory: скрипт компонента '%s' не назначен и отсутствует в реестре."
			% component_id
		)
		return false

	var component_instance: Object = component_script.new()
	if not component_instance is ObjectComponent:
		if component_instance is Node:
			(component_instance as Node).free()
		push_error(
			"ObjectFactory: компонент '%s' должен наследовать ObjectComponent."
			% component_id
		)
		return false

	var component_node := component_instance as ObjectComponent
	var node_name := component_definition.display_name.strip_edges()
	if node_name.is_empty():
		node_name = component_id
	if node_name.is_empty():
		node_name = "Component"
	component_node.name = _make_unique_child_name(target_node, node_name.validate_node_name())
	component_node.component_id = component_id
	component_node.configure_context(object_root, binding_id, target_node_path)
	component_node.configure(component_settings)
	# Mechanic packages expose explicit bind_target() contracts. Resolve the binding
	# before the component enters the scene tree so it never operates on an implicit root.
	if component_node.has_method("bind_target"):
		var bind_result: Variant = component_node.call("bind_target", target_node)
		if typeof(bind_result) == TYPE_BOOL and not bool(bind_result):
			push_error(
				"ObjectFactory: компонент '%s' отклонил целевой узел '%s'."
				% [component_id, str(target_node_path)]
			)
			component_node.free()
			return false
	if component_node.has_method("bind_animation_player"):
		var animation_player := _find_animation_player(target_node)
		if animation_player == null:
			push_error(
				"ObjectFactory: для компонента '%s' в узле '%s' не найден AnimationPlayer."
				% [component_id, str(target_node_path)]
			)
			component_node.free()
			return false
		var animation_bind_result: Variant = component_node.call(
			"bind_animation_player",
			animation_player
		)
		if typeof(animation_bind_result) == TYPE_BOOL and not bool(animation_bind_result):
			push_error("ObjectFactory: компонент '%s' не принял AnimationPlayer." % component_id)
			component_node.free()
			return false
	if component_node.has_method("bind_animated_sprite"):
		var animated_sprite := _find_animated_sprite(target_node)
		if animated_sprite == null:
			push_error(
				"ObjectFactory: для компонента '%s' в узле '%s' не найден AnimatedSprite2D."
				% [component_id, str(target_node_path)]
			)
			component_node.free()
			return false
		var sprite_bind_result: Variant = component_node.call(
			"bind_animated_sprite",
			animated_sprite
		)
		if typeof(sprite_bind_result) == TYPE_BOOL and not bool(sprite_bind_result):
			push_error("ObjectFactory: компонент '%s' не принял AnimatedSprite2D." % component_id)
			component_node.free()
			return false
	target_node.add_child(component_node)
	return true


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		if child is Node:
			var found := _find_animation_player(child as Node)
			if found != null:
				return found
	return null


static func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node == null:
		return null
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D
	for child in node.get_children():
		if child is Node:
			var found := _find_animated_sprite(child as Node)
			if found != null:
				return found
	return null


static func _make_unique_child_name(parent: Node, requested_name: String) -> String:
	var base_name := requested_name if not requested_name.is_empty() else "Component"
	var candidate := base_name
	var suffix := 2
	while parent.has_node(NodePath(candidate)):
		candidate = "%s_%d" % [base_name, suffix]
		suffix += 1
	return candidate


static func get_object_root(node: Node) -> Node:
	if node == null:
		return null
	var current: Node = node
	while current != null:
		if current.has_meta("object_definition_id"):
			return current
		current = current.get_parent()
	return node


static func get_component(instance: Node, component_id: String) -> ObjectComponent:
	if instance == null or component_id.strip_edges().is_empty():
		return null
	var matches := get_components(instance, component_id)
	return matches[0] if not matches.is_empty() else null


static func get_components(instance: Node, component_id: String = "") -> Array[ObjectComponent]:
	var result: Array[ObjectComponent] = []
	if instance == null:
		return result
	var object_root := get_object_root(instance)
	if object_root == null:
		return result
	var normalized_id := component_id.strip_edges().to_lower()
	_collect_components(object_root, object_root, normalized_id, result)
	return result


static func _collect_components(
	current: Node,
	object_root: Node,
	component_id: String,
	output: Array[ObjectComponent]
) -> void:
	if current == null:
		return
	if current != object_root and current.has_meta("object_definition_id"):
		return
	if current is ObjectComponent:
		var component := current as ObjectComponent
		if component_id.is_empty() or component.component_id.strip_edges().to_lower() == component_id:
			output.append(component)
	for child in current.get_children():
		if child is Node:
			_collect_components(child as Node, object_root, component_id, output)


static func get_component_on(target_node: Node, component_id: String) -> ObjectComponent:
	if target_node == null or component_id.strip_edges().is_empty():
		return null
	var normalized_id := component_id.strip_edges().to_lower()
	for child in target_node.get_children():
		if child is ObjectComponent:
			var component := child as ObjectComponent
			if component.component_id.strip_edges().to_lower() == normalized_id:
				return component
	return null


static func get_component_by_binding_id(instance: Node, binding_id: String) -> ObjectComponent:
	if binding_id.strip_edges().is_empty():
		return null
	for component in get_components(instance):
		if component.binding_id == binding_id:
			return component
	return null


static func has_component(instance: Node, component_id: String) -> bool:
	return get_component(instance, component_id) != null


static func get_custom_property(
	instance: Node,
	property_id: String,
	fallback: Variant = null
) -> Variant:
	if instance == null:
		return fallback
	var object_root := get_object_root(instance)
	var property_data := _get_property_data(object_root)
	if property_data != null:
		return property_data.get_custom_property(property_id, fallback)
	if not object_root.has_meta("object_custom_properties"):
		return fallback
	var values: Dictionary = object_root.get_meta("object_custom_properties", {})
	return values.get(property_id, fallback)


static func get_custom_property_definition(
	instance: Node,
	property_id: String
) -> ObjectPropertyDefinition:
	if instance == null:
		return null
	var object_root := get_object_root(instance)
	var property_data := _get_property_data(object_root)
	if property_data != null:
		return property_data.get_custom_property_definition(property_id)
	if not object_root.has_meta("object_custom_property_definitions"):
		return null
	var definitions: Dictionary = object_root.get_meta("object_custom_property_definitions", {})
	return definitions.get(property_id) as ObjectPropertyDefinition


static func set_custom_property(instance: Node, property_id: String, value: Variant) -> bool:
	if instance == null:
		return false
	var object_root := get_object_root(instance)
	var property_data := _get_property_data(object_root)
	if property_data != null:
		if not property_data.set_custom_property(property_id, value):
			return false
		object_root.set_meta("object_custom_properties", property_data.get_values())
		return true

	var property_definition := get_custom_property_definition(object_root, property_id)
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

	var values: Dictionary = object_root.get_meta("object_custom_properties", {})
	values[property_id] = normalized.value
	object_root.set_meta("object_custom_properties", values)
	return true


static func _get_property_data(instance: Node) -> ObjectPropertyData:
	if instance == null:
		return null
	var property_data := _find_property_data_recursive(instance)
	if property_data != null:
		property_data.name = "Свойства объекта"
	return property_data


static func _find_property_data_recursive(node: Node) -> ObjectPropertyData:
	if node == null:
		return null
	if node is ObjectPropertyData:
		return node as ObjectPropertyData
	for child in node.get_children():
		if child is Node:
			var found := _find_property_data_recursive(child as Node)
			if found != null:
				return found
	return null


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
