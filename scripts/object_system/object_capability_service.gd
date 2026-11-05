extends RefCounted
class_name ObjectCapabilityService

## Converts friendly capability choices into validated, dependency-complete component bindings.

## Builds a complete selection change before the editor mutates the ObjectDefinition.
## Required capabilities are added automatically; orphaned automatic dependencies are disabled.
static func plan_selection_change(
	current_selections: Array[ObjectCapabilitySelection],
	capability_id: String,
	enable: bool
) -> Dictionary:
	var normalized_id := capability_id.strip_edges().to_lower()
	var target_definition := ObjectCapabilityCatalog.get_definition(normalized_id)
	if target_definition == null:
		return _failed_selection_plan(["Неизвестная возможность: " + normalized_id])

	var next_values: Array[ObjectCapabilitySelection] = []
	for selection in current_selections:
		if selection == null:
			continue
		next_values.append(selection.duplicate(true) as ObjectCapabilitySelection)

	var target_index := _find_selection_index(next_values, normalized_id)
	var added_ids := PackedStringArray()
	var disabled_ids := PackedStringArray()

	if enable:
		if target_index < 0:
			var new_selection := ObjectCapabilityCatalog.create_selection(normalized_id)
			if new_selection == null:
				return _failed_selection_plan(["Не удалось создать выбранную возможность: " + normalized_id])
			new_selection.automatically_added = false
			next_values.append(new_selection)
			added_ids.append(normalized_id)
		else:
			var target_selection := next_values[target_index]
			target_selection.enabled = true
			target_selection.automatically_added = false

		var dependency_errors := PackedStringArray()
		var dependency_states: Dictionary = {}
		if not _ensure_required_selections(normalized_id, next_values, dependency_states, added_ids, dependency_errors):
			return _failed_selection_plan(dependency_errors)
	else:
		if target_index < 0 or not next_values[target_index].enabled:
			return {
				"ok": true,
				"selections": next_values,
				"added_capability_ids": added_ids,
				"disabled_capability_ids": disabled_ids,
				"errors": PackedStringArray()
			}

		var blocking_names := PackedStringArray()
		for selection in next_values:
			if selection == null or not selection.enabled or selection.capability_id == normalized_id:
				continue
			if _capability_requires(selection.capability_id, normalized_id, {}):
				var dependent := ObjectCapabilityCatalog.get_definition(selection.capability_id)
				blocking_names.append(dependent.display_name if dependent != null else selection.capability_id)

		if not blocking_names.is_empty():
			return _failed_selection_plan([
				"Нельзя отключить «%s»: от неё зависят %s. Сначала отключи эти возможности."
				% [target_definition.display_name, ", ".join(blocking_names)]
			])

		next_values[target_index].enabled = false
		next_values[target_index].automatically_added = false
		disabled_ids.append(normalized_id)

		for selection in next_values:
			if selection == null or not selection.enabled or not selection.automatically_added:
				continue
			if not _is_required_by_active_selection(selection.capability_id, next_values):
				selection.enabled = false
				disabled_ids.append(selection.capability_id)

	var validation_errors := validate_selections(next_values)
	if not validation_errors.is_empty():
		return _failed_selection_plan(validation_errors)

	return {
		"ok": true,
		"selections": next_values,
		"added_capability_ids": added_ids,
		"disabled_capability_ids": disabled_ids,
		"errors": PackedStringArray()
	}


static func _ensure_required_selections(
	capability_id: String,
	selections: Array[ObjectCapabilitySelection],
	states: Dictionary,
	added_ids: PackedStringArray,
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
	for dependency_id_value in definition.required_capability_ids:
		var dependency_id := str(dependency_id_value).strip_edges().to_lower()
		var dependency_index := _find_selection_index(selections, dependency_id)
		if dependency_index < 0:
			var dependency_selection := ObjectCapabilityCatalog.create_selection(dependency_id)
			if dependency_selection == null:
				errors.append("Невозможно автоматически добавить зависимость: " + dependency_id)
				return false
			dependency_selection.automatically_added = true
			selections.append(dependency_selection)
			added_ids.append(dependency_id)
		else:
			var dependency_selection := selections[dependency_index]
			if not dependency_selection.enabled:
				dependency_selection.enabled = true
				dependency_selection.automatically_added = true
				added_ids.append(dependency_id)

		if not _ensure_required_selections(dependency_id, selections, states, added_ids, errors):
			return false

	states[capability_id] = 2
	return true


static func _capability_requires(
	capability_id: String,
	required_id: String,
	visited: Dictionary
) -> bool:
	if visited.has(capability_id):
		return false
	visited[capability_id] = true
	var definition := ObjectCapabilityCatalog.get_definition(capability_id)
	if definition == null:
		return false
	for dependency_id_value in definition.required_capability_ids:
		var dependency_id := str(dependency_id_value).strip_edges().to_lower()
		if dependency_id == required_id:
			return true
		if _capability_requires(dependency_id, required_id, visited):
			return true
	return false


static func _is_required_by_active_selection(
	capability_id: String,
	selections: Array[ObjectCapabilitySelection]
) -> bool:
	for selection in selections:
		if selection == null or not selection.enabled or selection.capability_id == capability_id:
			continue
		if _capability_requires(selection.capability_id, capability_id, {}):
			return true
	return false


static func _find_selection_index(
	selections: Array[ObjectCapabilitySelection],
	capability_id: String
) -> int:
	for index in range(selections.size()):
		var selection := selections[index]
		if selection != null and selection.capability_id.strip_edges().to_lower() == capability_id:
			return index
	return -1


static func _failed_selection_plan(errors: PackedStringArray) -> Dictionary:
	return {
		"ok": false,
		"selections": [],
		"added_capability_ids": PackedStringArray(),
		"disabled_capability_ids": PackedStringArray(),
		"errors": errors
	}


## Describes the complete component delta before the editor changes the working object.
## The returned plan is data only: callers may show it for confirmation before committing.
static func build_application_plan(
	current_selections: Array[ObjectCapabilitySelection],
	next_selections: Array[ObjectCapabilitySelection],
	scene_root: Node = null
) -> Dictionary:
	var validation_errors := validate_selections(next_selections, scene_root)
	if not validation_errors.is_empty():
		return {
			"ok": false,
			"changed": false,
			"errors": validation_errors,
			"added_capability_ids": PackedStringArray(),
			"removed_capability_ids": PackedStringArray(),
			"added_components": [],
			"removed_components": [],
			"updated_components": [],
			"summary_lines": PackedStringArray()
		}

	var current_bindings := build_component_bindings(current_selections)
	var next_bindings := build_component_bindings(next_selections)
	var current_by_key: Dictionary = {}
	var next_by_key: Dictionary = {}
	for binding in current_bindings:
		var key := _component_binding_key(binding)
		if not key.is_empty():
			current_by_key[key] = binding
	for binding in next_bindings:
		var key := _component_binding_key(binding)
		if not key.is_empty():
			next_by_key[key] = binding

	var added_components: Array[Dictionary] = []
	var removed_components: Array[Dictionary] = []
	var updated_components: Array[Dictionary] = []
	for key in next_by_key:
		var next_binding := next_by_key[key] as ObjectComponentBinding
		var component_id := next_binding.get_component_id()
		if not current_by_key.has(key):
			added_components.append(_component_plan_entry(next_binding))
			continue
		var current_binding := current_by_key[key] as ObjectComponentBinding
		var before_settings := current_binding.component_definition.get_settings()
		var after_settings := next_binding.component_definition.get_settings()
		if before_settings != after_settings:
			updated_components.append({
				"component_id": component_id,
				"display_name": ObjectComponentCatalog.get_component_display_name(component_id),
				"target_node_path": str(next_binding.target_node_path),
				"before": before_settings,
				"after": after_settings
			})
	for key in current_by_key:
		if not next_by_key.has(key):
			removed_components.append(_component_plan_entry(current_by_key[key] as ObjectComponentBinding))

	var current_capabilities := _enabled_capability_ids(current_selections)
	var next_capabilities := _enabled_capability_ids(next_selections)
	var added_capabilities := PackedStringArray()
	var removed_capabilities := PackedStringArray()
	for capability_id in next_capabilities:
		if not current_capabilities.has(capability_id):
			added_capabilities.append(capability_id)
	for capability_id in current_capabilities:
		if not next_capabilities.has(capability_id):
			removed_capabilities.append(capability_id)

	var summary := PackedStringArray()
	_append_capability_summary(summary, "Добавляются возможности", added_capabilities)
	_append_capability_summary(summary, "Отключаются возможности", removed_capabilities)
	_append_component_summary(summary, "Добавляются игровые модули", added_components)
	_append_component_summary(summary, "Удаляются игровые модули", removed_components)
	_append_component_summary(summary, "Меняются настройки модулей", updated_components)
	var changed := (
		not added_capabilities.is_empty()
		or not removed_capabilities.is_empty()
		or not added_components.is_empty()
		or not removed_components.is_empty()
		or not updated_components.is_empty()
	)
	if not changed:
		summary.append("Состав объекта не изменится.")
	else:
		summary.push_front("Будет применён следующий план:")

	return {
		"ok": true,
		"changed": changed,
		"errors": PackedStringArray(),
		"added_capability_ids": added_capabilities,
		"removed_capability_ids": removed_capabilities,
		"added_components": added_components,
		"removed_components": removed_components,
		"updated_components": updated_components,
		"summary_lines": summary
	}


static func _enabled_capability_ids(
	selections: Array[ObjectCapabilitySelection]
) -> PackedStringArray:
	var result := PackedStringArray()
	for selection in selections:
		if selection == null or not selection.enabled:
			continue
		var capability_id := selection.capability_id.strip_edges().to_lower()
		if not capability_id.is_empty() and not result.has(capability_id):
			result.append(capability_id)
	return result


static func _component_binding_key(binding: ObjectComponentBinding) -> String:
	if binding == null or binding.component_definition == null:
		return ""
	return "%s@%s" % [
		binding.get_component_id().strip_edges().to_lower(),
		str(binding.target_node_path)
	]


static func _component_plan_entry(binding: ObjectComponentBinding) -> Dictionary:
	if binding == null or binding.component_definition == null:
		return {}
	var component_id := binding.get_component_id()
	return {
		"component_id": component_id,
		"display_name": ObjectComponentCatalog.get_component_display_name(component_id),
		"target_node_path": str(binding.target_node_path)
	}


static func _append_capability_summary(
	output: PackedStringArray,
	label: String,
	capability_ids: PackedStringArray
) -> void:
	if capability_ids.is_empty():
		return
	var names := PackedStringArray()
	for capability_id in capability_ids:
		var definition := ObjectCapabilityCatalog.get_definition(capability_id)
		names.append(definition.display_name if definition != null else capability_id)
	output.append("%s: %s." % [label, ", ".join(names)])


static func _append_component_summary(
	output: PackedStringArray,
	label: String,
	entries: Array[Dictionary]
) -> void:
	if entries.is_empty():
		return
	var descriptions := PackedStringArray()
	for entry in entries:
		var node_path := str(entry.get("target_node_path", "."))
		var target_text := "корневой узел" if node_path.is_empty() or node_path == "." else node_path
		descriptions.append("%s (%s)" % [str(entry.get("display_name", entry.get("component_id", "компонент"))), target_text])
	output.append("%s: %s." % [label, ", ".join(descriptions)])


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
		if not selection.enabled:
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
		if capability.runtime_status != "Implemented":
			errors.append(
				"Механика «%s» пока находится в разработке и не может быть включена."
				% capability.display_name
			)
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
