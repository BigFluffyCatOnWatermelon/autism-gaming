extends RefCounted
class_name ObjectCapabilityService

## Converts friendly capability choices into validated, dependency-complete component bindings.

static func build_component_bindings(
	selections: Array[ObjectCapabilitySelection]
) -> Array[ObjectComponentBinding]:
	var result: Array[ObjectComponentBinding] = []
	var validation_errors := validate_selections(selections)
	if not validation_errors.is_empty():
		return result

	var selections_by_id: Dictionary = {}
	for selection in selections:
		if selection == null or not selection.enabled:
			continue
		var capability_id := selection.capability_id.strip_edges().to_lower()
		if not selections_by_id.has(capability_id):
			selections_by_id[capability_id] = selection

	var resolved_ids: Array[String] = []
	var states: Dictionary = {}
	var resolution_errors := PackedStringArray()
	for selection in selections:
		if selection == null or not selection.enabled:
			continue
		_append_with_dependencies(
			selection.capability_id.strip_edges().to_lower(),
			states,
			resolved_ids,
			resolution_errors
		)
	if not resolution_errors.is_empty():
		return result

	var binding_indexes: Dictionary = {}
	for capability_id in resolved_ids:
		var capability := ObjectCapabilityCatalog.get_definition(capability_id)
		if capability == null:
			continue
		var selection := selections_by_id.get(capability_id) as ObjectCapabilitySelection
		var target_path := selection.target_node_path if selection != null else NodePath(".")
		for component_id in capability.component_ids:
			var normalized_component_id := str(component_id).strip_edges().to_lower()
			var binding_key := "%s@%s" % [normalized_component_id, str(target_path)]
			if binding_indexes.has(binding_key):
				var existing_binding := result[int(binding_indexes[binding_key])]
				_apply_selection_settings(existing_binding, selection, normalized_component_id)
				continue

			var binding := ObjectComponentCatalog.create_binding(
				normalized_component_id,
				target_path
			)
			if binding == null:
				push_error(
					"ObjectCapabilityService: возможность '%s' не смогла создать компонент '%s'."
					% [capability_id, normalized_component_id]
				)
				return []
			binding.binding_id = "capability_%s_%s" % [capability_id, normalized_component_id]
			_apply_selection_settings(binding, selection, normalized_component_id)
			binding_indexes[binding_key] = result.size()
			result.append(binding)
	return result


static func _apply_selection_settings(
	binding: ObjectComponentBinding,
	selection: ObjectCapabilitySelection,
	component_id: String
) -> void:
	if binding == null or selection == null:
		return
	var component_settings := selection.get_component_settings(component_id)
	for setting_key in component_settings:
		if not binding.component_definition.set_setting(str(setting_key), component_settings[setting_key]):
			push_warning(
				"ObjectCapabilityService: некорректная настройка '%s' компонента '%s' пропущена."
				% [str(setting_key), component_id]
			)


static func validate_selections(
	selections: Array[ObjectCapabilitySelection],
	scene_root: Node = null
) -> PackedStringArray:
	var errors := PackedStringArray()
	var selected_ids: Dictionary = {}
	for selection in selections:
		if selection == null:
			errors.append("В списке возможностей есть пустая запись.")
			continue
		var capability_id := selection.capability_id.strip_edges().to_lower()
		if capability_id.is_empty():
			errors.append("У выбранной возможности отсутствует ID.")
			continue
		if selected_ids.has(capability_id):
			errors.append("Возможность выбрана несколько раз: " + capability_id)
			continue
		selected_ids[capability_id] = selection

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
			var normalized_component_id := str(component_id).strip_edges().to_lower()
			if not capability.component_ids.has(normalized_component_id):
				errors.append(
					"Возможность «%s» не управляет настройками компонента «%s»."
					% [capability.display_name, normalized_component_id]
				)
				continue
			var component_definition := ObjectComponentCatalog.create_definition(normalized_component_id)
			if component_definition == null:
				errors.append(
					"Для возможности '%s' не найден компонент '%s'."
					% [capability_id, normalized_component_id]
				)
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
	var resolved_ids: Array[String] = []
	for capability_id in selected_ids:
		if not _append_with_dependencies(str(capability_id), dependency_states, resolved_ids, errors):
			continue

	for capability_id in resolved_ids:
		var capability := ObjectCapabilityCatalog.get_definition(capability_id)
		if capability == null:
			continue
		for incompatible_id in capability.incompatible_capability_ids:
			var normalized_incompatible_id := str(incompatible_id).strip_edges().to_lower()
			if resolved_ids.has(normalized_incompatible_id):
				var incompatible_capability := ObjectCapabilityCatalog.get_definition(normalized_incompatible_id)
				if incompatible_capability != null:
					errors.append(
						"Возможности «%s» и «%s» нельзя использовать вместе."
						% [capability.display_name, incompatible_capability.display_name]
					)
				else:
					errors.append(
						"Возможность «%s» несовместима с отсутствующей возможностью «%s»."
						% [capability.display_name, normalized_incompatible_id]
					)

	var emitted_components: Dictionary = {}
	for capability_id in resolved_ids:
		var capability := ObjectCapabilityCatalog.get_definition(capability_id)
		if capability == null:
			continue
		for component_id in capability.component_ids:
			if not ObjectComponentCatalog.has_component(str(component_id)):
				errors.append(
					"Возможность «%s» требует отсутствующий игровой модуль «%s»."
					% [capability.display_name, str(component_id)]
				)
			var component_key := str(component_id).strip_edges().to_lower()
			if emitted_components.has(component_key):
				continue
			emitted_components[component_key] = true
	return errors


static func _append_with_dependencies(
	capability_id: String,
	states: Dictionary,
	output: Array[String],
	errors: PackedStringArray
) -> bool:
	if states.get(capability_id, 0) == 2:
		return true
	if states.get(capability_id, 0) == 1:
		errors.append("Обнаружен цикл зависимостей возможностей: " + capability_id)
		return false

	var definition := ObjectCapabilityCatalog.get_definition(capability_id)
	if definition == null:
		errors.append("Неизвестная зависимость возможности: " + capability_id)
		return false

	states[capability_id] = 1
	for dependency_id in definition.required_capability_ids:
		if not _append_with_dependencies(str(dependency_id).strip_edges().to_lower(), states, output, errors):
			return false
	states[capability_id] = 2
	if not output.has(capability_id):
		output.append(capability_id)
	return true
