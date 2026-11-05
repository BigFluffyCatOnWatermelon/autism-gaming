extends RefCounted
class_name ObjectCapabilityService

## Resolves friendly capability choices into dependency-complete component bindings.

static func build_component_bindings(
	selections: Array[ObjectCapabilitySelection]
) -> Array[ObjectComponentBinding]:
	var result: Array[ObjectComponentBinding] = []
	var selections_by_id: Dictionary = {}
	for selection in selections:
		if selection == null or not selection.enabled:
			continue
		var capability_id := selection.capability_id.strip_edges().to_lower()
		if capability_id.is_empty() or selections_by_id.has(capability_id):
			continue
		selections_by_id[capability_id] = selection

	var resolved_ids: Array[String] = []
	var states: Dictionary = {}
	for selection in selections:
		if selection == null or not selection.enabled:
			continue
		_append_with_dependencies(
			selection.capability_id.strip_edges().to_lower(),
			states,
			resolved_ids
		)

	for capability_id in resolved_ids:
		var capability := ObjectCapabilityCatalog.get_definition(capability_id)
		if capability == null:
			continue
		var selection := selections_by_id.get(capability_id) as ObjectCapabilitySelection
		for component_id in capability.component_ids:
			var binding := ObjectComponentCatalog.create_binding(
				component_id,
				selection.target_node_path if selection != null else NodePath(".")
			)
			if binding == null:
				continue
			binding.binding_id = "capability_%s_%s" % [capability_id, component_id]
			if selection != null:
				var component_settings := selection.get_component_settings(component_id)
				for setting_key in component_settings:
					binding.component_definition.set_setting(
						str(setting_key),
						component_settings[setting_key]
					)
			result.append(binding)
	return result


static func validate_selections(
	selections: Array[ObjectCapabilitySelection],
	scene_root: Node = null
) -> PackedStringArray:
	var errors := PackedStringArray()
	var used_ids: Dictionary = {}
	for selection in selections:
		if selection == null:
			errors.append("В списке возможностей есть пустая запись.")
			continue
		var capability_id := selection.capability_id.strip_edges().to_lower()
		if capability_id.is_empty():
			errors.append("У выбранной возможности отсутствует ID.")
			continue
		if used_ids.has(capability_id):
			errors.append("Возможность выбрана несколько раз: " + capability_id)
			continue
		used_ids[capability_id] = true

		var capability := ObjectCapabilityCatalog.get_definition(capability_id)
		if capability == null:
			errors.append("Неизвестная возможность: " + capability_id)
			continue
		var target_path := str(selection.target_node_path)
		if not target_path.is_empty() and target_path != ".":
			if scene_root == null:
				errors.append(
					"Возможность «%s» указывает на узел «%s», но у объекта нет сцены."
					% [capability.display_name, target_path]
				)
			elif scene_root.get_node_or_null(selection.target_node_path) == null:
				errors.append(
					"Для возможности «%s» не найден выбранный узел «%s»."
					% [capability.display_name, target_path]
				)

		for component_id in selection.settings_by_component:
			if not capability.component_ids.has(str(component_id)):
				errors.append(
					"Возможность «%s» не управляет настройками компонента «%s»."
					% [capability.display_name, str(component_id)]
				)
				continue
			var component_definition := ObjectComponentCatalog.create_definition(str(component_id))
			if component_definition == null:
				errors.append("Для возможности '%s' не найден компонент '%s'." % [capability_id, str(component_id)])
				continue
			var settings: Variant = selection.settings_by_component[component_id]
			if not settings is Dictionary:
				errors.append("Настройки возможности «%s» имеют неверный формат." % capability.display_name)
				continue
			for setting_key in settings:
				if not component_definition.set_setting(str(setting_key), settings[setting_key]):
					errors.append(
						"Неверное значение настройки «%s» в возможности «%s»."
						% [str(setting_key), capability.display_name]
					)

	var dependency_states: Dictionary = {}
	var resolved: Array[String] = []
	for capability_id in used_ids:
		_append_with_dependencies(str(capability_id), dependency_states, resolved, errors)
	return errors


static func _append_with_dependencies(
	capability_id: String,
	states: Dictionary,
	output: Array[String],
	errors: PackedStringArray = PackedStringArray()
) -> bool:
	if states.get(capability_id, 0) == 2:
		return true
	if states.get(capability_id, 0) == 1:
		if errors != null:
			errors.append("Обнаружен цикл зависимостей возможностей: " + capability_id)
		return false

	var definition := ObjectCapabilityCatalog.get_definition(capability_id)
	if definition == null:
		if errors != null:
			errors.append("Неизвестная зависимость возможности: " + capability_id)
		return false

	states[capability_id] = 1
	for dependency_id in definition.required_capability_ids:
		if not _append_with_dependencies(str(dependency_id), states, output, errors):
			return false
	states[capability_id] = 2
	if not output.has(capability_id):
		output.append(capability_id)
	return true
