extends RefCounted
class_name ObjectComponentCatalog

const HEALTH_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/health_component.gd")
const DAMAGEABLE_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/damageable_component.gd")
const ATTACK_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/attack_component.gd")
const DESTRUCTIBLE_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/destructible_component.gd")
const PICKUP_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/pickup_component.gd")
const INTERACTABLE_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/interactable_component.gd")

const CATEGORY_DEFINITIONS := [
	{"id": "Appearance", "display_name": "Внешний вид"},
	{"id": "Physics", "display_name": "Физика"},
	{"id": "Stats", "display_name": "Характеристики"},
	{"id": "Combat", "display_name": "Бой"},
	{"id": "Interaction", "display_name": "Взаимодействие"},
	{"id": "Destruction", "display_name": "Разрушение"},
	{"id": "Audio", "display_name": "Звук"},
	{"id": "Procedural", "display_name": "Процедурная генерация"}
]

## One registry stores built-ins and extension components under the same data contract.
static var _definitions: Dictionary = {}
static var _sources: Dictionary = {}
static var _initialized: bool = false


## Registers one extension component. Built-in IDs are reserved.
static func register_definition(
	definition: ObjectComponentDefinition,
	source_id: String = "extension"
) -> bool:
	return register_definitions([definition], source_id).is_empty()


## Validates the whole batch first, then registers it atomically.
static func register_definitions(
	definitions: Array,
	source_id: String = "extension"
) -> PackedStringArray:
	_ensure_initialized()
	return _register_batch(definitions, source_id, false)


## Removes all definitions from one source only when no registered capability depends on them.
static func unregister_source(source_id: String) -> PackedStringArray:
	_ensure_initialized()
	var normalized_source := source_id.strip_edges()
	if normalized_source.is_empty():
		return PackedStringArray(["Для отключения компонентов нужен непустой source_id."])
	if normalized_source == "builtin":
		return PackedStringArray(["Встроенные компоненты нельзя отключить как расширение."])

	var remove_ids := PackedStringArray()
	for component_id in _sources:
		if str(_sources[component_id]) == normalized_source:
			remove_ids.append(str(component_id))
	if remove_ids.is_empty():
		return PackedStringArray()

	for capability_id in ObjectCapabilityCatalog.get_capability_ids("", false):
		var capability := ObjectCapabilityCatalog.get_definition(capability_id)
		if capability == null:
			continue
		for component_id in capability.component_ids:
			if remove_ids.has(_normalize_id(component_id)):
				return PackedStringArray([
					"Нельзя отключить источник '%s': возможность «%s» использует компонент '%s'."
					% [normalized_source, capability.display_name, component_id]
				])

	for component_id in remove_ids:
		_definitions.erase(component_id)
		_sources.erase(component_id)
	return PackedStringArray()


static func validate_registry() -> PackedStringArray:
	_ensure_initialized()
	var errors := PackedStringArray()
	for component_id in _definitions:
		var definition := _definitions[component_id] as ObjectComponentDefinition
		if definition == null:
			errors.append("В реестре есть пустое определение компонента: " + str(component_id))
			continue
		errors.append_array(_validate_definition(definition, _definitions))
	if errors.is_empty():
		errors.append_array(_validate_dependency_graph(_definitions))
	return errors


static func get_source_id(component_id: String) -> String:
	_ensure_initialized()
	return str(_sources.get(_normalize_id(component_id), ""))


static func get_categories() -> Array[Dictionary]:
	_ensure_initialized()
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for category in CATEGORY_DEFINITIONS:
		var copied: Dictionary = category.duplicate(true)
		result.append(copied)
		seen[str(copied.get("id", ""))] = true

	for component_id in get_component_ids():
		var definition := create_definition(component_id)
		if definition == null:
			continue
		var category_id := definition.category_id if not definition.category_id.is_empty() else definition.category
		if seen.has(category_id):
			continue
		seen[category_id] = true
		result.append({
			"id": category_id,
			"display_name": definition.category_display_name if not definition.category_display_name.is_empty() else category_id
		})
	return result


static func get_category_display_name(category_id: String) -> String:
	for category in get_categories():
		if str(category.get("id", "")) == category_id:
			return str(category.get("display_name", category_id))
	return category_id


static func get_component_ids(category_id: String = "") -> PackedStringArray:
	_ensure_initialized()
	var result := PackedStringArray()
	for component_id in _definitions:
		var definition := _definitions[component_id] as ObjectComponentDefinition
		if definition == null:
			continue
		var resolved_category := definition.category_id if not definition.category_id.is_empty() else definition.category
		if category_id.is_empty() or resolved_category == category_id:
			result.append(str(component_id))
	result.sort()
	return result


static func get_component_display_name(component_id: String) -> String:
	var definition := create_definition(component_id)
	return definition.display_name if definition != null else component_id


static func get_component_description(component_id: String) -> String:
	var definition := create_definition(component_id)
	return definition.description if definition != null else "Компонент без описания."


static func has_component(component_id: String) -> bool:
	_ensure_initialized()
	return _definitions.has(_normalize_id(component_id))


static func create_definition(component_id: String) -> ObjectComponentDefinition:
	_ensure_initialized()
	var definition := _definitions.get(_normalize_id(component_id)) as ObjectComponentDefinition
	if definition == null:
		return null
	return definition.duplicate(true) as ObjectComponentDefinition


static func create_binding(
	component_id: String,
	target_node_path: NodePath = NodePath(".")
) -> ObjectComponentBinding:
	var component_definition := create_definition(component_id)
	if component_definition == null:
		return null
	var binding := ObjectComponentBinding.new()
	binding.component_definition = component_definition
	binding.target_node_path = target_node_path
	binding.ensure_binding_id()
	return binding


static func create_all_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for component_id in get_component_ids():
		var definition := create_definition(component_id)
		if definition != null:
			result.append(definition)
	return result


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	var errors := _register_batch(_make_builtin_definitions(), "builtin", true)
	if not errors.is_empty():
		for error_message in errors:
			push_error("ObjectComponentCatalog: встроенный реестр компонентов повреждён: " + error_message)


## Shared registration pipeline used by built-in and extension definitions.
## Only the private initialization path may reserve built-in IDs.
static func _register_batch(
	definitions: Array,
	source_id: String,
	allow_builtin_ids: bool
) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized_source := source_id.strip_edges()
	if normalized_source.is_empty():
		errors.append("Для регистрации компонентов нужен непустой source_id.")
		return errors

	var incoming: Dictionary = {}
	for value in definitions:
		if not value is ObjectComponentDefinition:
			errors.append("Реестр компонентов принимает только ObjectComponentDefinition.")
			continue
		var definition := value as ObjectComponentDefinition
		var component_id := _normalize_id(definition.component_id)
		if not _is_valid_id(component_id):
			errors.append("Некорректный ID компонента: " + definition.component_id)
			continue
		if _is_builtin_id(component_id) and not allow_builtin_ids:
			errors.append("Нельзя переопределить встроенный компонент: " + component_id)
			continue
		if incoming.has(component_id):
			errors.append("В пакете повторяется ID компонента: " + component_id)
			continue
		if _definitions.has(component_id) and str(_sources.get(component_id, "")) != normalized_source:
			errors.append("ID компонента уже зарегистрирован другим источником: " + component_id)
			continue

		var existing := _definitions.get(component_id) as ObjectComponentDefinition
		if existing != null and existing.component_version > definition.component_version:
			errors.append("Нельзя понизить версию компонента '%s' с %d до %d." % [
				component_id,
				existing.component_version,
				definition.component_version
			])
			continue

		var copy := definition.duplicate(true) as ObjectComponentDefinition
		copy.component_id = component_id
		incoming[component_id] = copy

	if not errors.is_empty():
		return errors

	var candidate := _definitions.duplicate(true)
	for component_id in incoming:
		candidate[component_id] = incoming[component_id]

	for component_id in incoming:
		var candidate_definition := candidate[component_id] as ObjectComponentDefinition
		errors.append_array(_validate_definition(candidate_definition, candidate))

	if errors.is_empty():
		errors.append_array(_validate_dependency_graph(candidate))
	if not errors.is_empty():
		return errors

	for component_id in incoming:
		_definitions[component_id] = incoming[component_id]
		_sources[component_id] = normalized_source
	return errors


## Resolves explicit bindings and adds required components before ObjectFactory attaches anything.
## Validation is performed against the actual target nodes, so a failed plan never leaves a partial object.
static func resolve_bindings(
	bindings: Array,
	object_root: Node
) -> Dictionary:
	_ensure_initialized()
	var errors := PackedStringArray()
	var resolved: Array[ObjectComponentBinding] = []
	var used_binding_ids: Dictionary = {}
	var component_ids: Dictionary = {}

	if object_root == null:
		return _binding_resolution_failure(["Не задан корневой узел объекта."])

	for value in bindings:
		if not value is ObjectComponentBinding:
			errors.append("В списке привязок есть запись неверного типа.")
			continue
		var source_binding := value as ObjectComponentBinding
		if not source_binding.enabled:
			continue
		if source_binding.component_definition == null:
			errors.append("У привязки '%s' не выбрано поведение." % source_binding.binding_id)
			continue
		if not source_binding.component_definition.enabled:
			continue

		var binding := source_binding.duplicate(true) as ObjectComponentBinding
		var component_id := _normalize_id(binding.component_definition.component_id)
		if component_id.is_empty():
			errors.append("У привязки '%s' отсутствует ID компонента." % binding.binding_id)
			continue
		if not has_component(component_id):
			errors.append("Неизвестный компонент: " + component_id)
			continue

		var binding_id := binding.ensure_binding_id()
		if used_binding_ids.has(binding_id):
			errors.append("Повторяется ID привязки компонента '%s'." % binding_id)
			continue
		used_binding_ids[binding_id] = true

		var target_node := binding.get_target_node(object_root)
		if target_node == null:
			errors.append(
				"Для компонента «%s» не найден узел «%s». Привязка не перенесена на корень."
				% [get_component_display_name(component_id), str(binding.target_node_path)]
			)
			continue

		var registered_definition := create_definition(component_id)
		if registered_definition == null:
			errors.append("Не удалось загрузить определение компонента: " + component_id)
			continue
		var effective_definition := binding.component_definition
		if effective_definition.component_script == null:
			effective_definition.component_script = registered_definition.component_script
		if effective_definition.component_script == null:
			errors.append("У компонента «%s» отсутствует скрипт." % get_component_display_name(component_id))
			continue
		if not _script_creates_object_component(effective_definition.component_script):
			errors.append("Скрипт компонента «%s» должен наследовать ObjectComponent." % get_component_display_name(component_id))
			continue

		var node_type_error := _validate_target_node_type(effective_definition, target_node)
		if not node_type_error.is_empty():
			errors.append(node_type_error)
			continue

		component_ids[component_id] = true
		resolved.append(binding)

	if not errors.is_empty():
		return _binding_resolution_failure(errors)

	# Resolve dependencies iteratively. A dependency already present anywhere in this object
	# satisfies the requirement, so separate visual/physics/logic nodes remain independent.
	var index := 0
	while index < resolved.size():
		var parent_binding := resolved[index]
		var parent_definition := parent_binding.component_definition
		var parent_component_id := parent_binding.get_component_id()
		for required_id_value in parent_definition.required_component_ids:
			var required_id := _normalize_id(str(required_id_value))
			if component_ids.has(required_id):
				continue
			var required_definition := create_definition(required_id)
			if required_definition == null:
				errors.append(
					"Компонент «%s» требует отсутствующий компонент «%s»."
					% [get_component_display_name(parent_component_id), required_id]
				)
				continue

			var dependency_binding := ObjectComponentBinding.new()
			dependency_binding.component_definition = required_definition
			dependency_binding.target_node_path = parent_binding.target_node_path
			dependency_binding.binding_id = "auto_%s_%s" % [parent_binding.binding_id, required_id]
			dependency_binding.ensure_binding_id()
			var dependency_target := dependency_binding.get_target_node(object_root)
			if dependency_target == null:
				errors.append(
					"Для обязательного компонента «%s» не найден узел «%s»."
					% [required_definition.display_name, str(dependency_binding.target_node_path)]
				)
				continue
			var dependency_type_error := _validate_target_node_type(required_definition, dependency_target)
			if not dependency_type_error.is_empty():
				errors.append(dependency_type_error)
				continue
			if not _script_creates_object_component(required_definition.component_script):
				errors.append("Скрипт обязательного компонента «%s» некорректен." % required_definition.display_name)
				continue
			if used_binding_ids.has(dependency_binding.binding_id):
				errors.append("Повторяется ID автоматической привязки '%s'." % dependency_binding.binding_id)
				continue

			used_binding_ids[dependency_binding.binding_id] = true
			component_ids[required_id] = true
			resolved.append(dependency_binding)
		index += 1

	if not errors.is_empty():
		return _binding_resolution_failure(errors)

	# Component incompatibilities apply to the whole object, not just a single node.
	for binding in resolved:
		var definition := binding.component_definition
		var component_id := binding.get_component_id()
		for incompatible_id_value in definition.incompatible_component_ids:
			var incompatible_id := _normalize_id(str(incompatible_id_value))
			if component_ids.has(incompatible_id):
				errors.append(
					"Компоненты «%s» и «%s» нельзя использовать в одном объекте."
					% [get_component_display_name(component_id), get_component_display_name(incompatible_id)]
				)

	if not errors.is_empty():
		return _binding_resolution_failure(errors)

	return {
		"ok": true,
		"bindings": resolved,
		"errors": PackedStringArray()
	}


static func _validate_target_node_type(
	definition: ObjectComponentDefinition,
	target_node: Node
) -> String:
	if definition == null or target_node == null or definition.supported_node_types.is_empty():
		return ""
	for supported_type_value in definition.supported_node_types:
		var supported_type := str(supported_type_value).strip_edges()
		if not supported_type.is_empty() and target_node.is_class(supported_type):
			return ""
	return "Компонент «%s» нельзя разместить на узле типа %s. Подходящие типы: %s." % [
		definition.display_name if not definition.display_name.is_empty() else definition.component_id,
		target_node.get_class(),
		", ".join(definition.supported_node_types)
	]


static func _script_creates_object_component(script: Script) -> bool:
	if script == null or not script.can_instantiate():
		return false
	var instance: Object = script.new()
	var is_component := instance is ObjectComponent
	if instance is Node:
		(instance as Node).free()
	return is_component


static func _binding_resolution_failure(errors: PackedStringArray) -> Dictionary:
	return {
		"ok": false,
		"bindings": [],
		"errors": errors
	}


static func _make_builtin_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for component_id in ["health", "damageable", "attack", "destructible", "pickup", "interactable"]:
		var definition := ObjectComponentDefinition.new()
		definition.component_id = component_id
		definition.display_name = _get_builtin_display_name(component_id)
		definition.description = _get_builtin_description(component_id)
		definition.category = "Stats" if component_id == "health" else "Combat"
		if component_id == "destructible":
			definition.category = "Destruction"
		elif component_id in ["pickup", "interactable"]:
			definition.category = "Interaction"
		definition.category_id = definition.category
		definition.category_display_name = _get_builtin_category_display_name(definition.category)
		definition.component_version = 1
		match component_id:
			"health":
				definition.component_script = HEALTH_COMPONENT_SCRIPT
			"damageable":
				definition.component_script = DAMAGEABLE_COMPONENT_SCRIPT
			"attack":
				definition.component_script = ATTACK_COMPONENT_SCRIPT
			"destructible":
				definition.component_script = DESTRUCTIBLE_COMPONENT_SCRIPT
			"pickup":
				definition.component_script = PICKUP_COMPONENT_SCRIPT
			"interactable":
				definition.component_script = INTERACTABLE_COMPONENT_SCRIPT
		definition.setting_definitions = ObjectComponentDefinition.get_builtin_setting_definitions(component_id)
		for descriptor in definition.setting_definitions:
			var key := str(descriptor.get("key", ""))
			if not key.is_empty():
				definition.settings[key] = descriptor.get("default_value")
		result.append(definition)

	return result


static func _validate_definition(
	definition: ObjectComponentDefinition,
	candidate: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition.display_name.strip_edges().is_empty():
		errors.append("У компонента '%s' отсутствует пользовательское название." % definition.component_id)
	if definition.component_version < 1:
		errors.append("Версия компонента '%s' должна быть не меньше 1." % definition.component_id)
	if definition.category_id.strip_edges().is_empty() and definition.category.strip_edges().is_empty():
		errors.append("У компонента '%s' должна быть указана категория." % definition.component_id)
	if not definition.category_id.strip_edges().is_empty() and definition.category_display_name.strip_edges().is_empty():
		errors.append("У категории компонента '%s' отсутствует название." % definition.component_id)

	if definition.component_script == null:
		errors.append("У компонента '%s' не назначен скрипт." % definition.component_id)
	elif not definition.component_script.can_instantiate():
		errors.append("Скрипт компонента '%s' не компилируется и не может быть создан." % definition.component_id)
	else:
		var instance: Object = definition.component_script.new()
		if not instance is ObjectComponent:
			errors.append("Скрипт компонента '%s' должен наследовать ObjectComponent." % definition.component_id)
		if instance is Node:
			(instance as Node).free()

	var seen_node_types: Dictionary = {}
	for node_type in definition.supported_node_types:
		var normalized_type := str(node_type).strip_edges()
		if normalized_type.is_empty():
			errors.append("У компонента '%s' есть пустой supported_node_type." % definition.component_id)
		elif seen_node_types.has(normalized_type):
			errors.append("У компонента '%s' повторяется supported_node_type '%s'." % [definition.component_id, normalized_type])
		elif not ClassDB.class_exists(normalized_type):
			errors.append("Компонент '%s' поддерживает неизвестный класс узла '%s'." % [definition.component_id, normalized_type])
		seen_node_types[normalized_type] = true

	var probe := definition.duplicate(true) as ObjectComponentDefinition
	probe.settings = {}
	var setting_ids: Dictionary = {}
	for descriptor in probe.get_setting_definitions():
		var key := str(descriptor.get("key", "")).strip_edges()
		if key.is_empty():
			errors.append("У настройки компонента '%s' отсутствует key." % definition.component_id)
			continue
		if setting_ids.has(key):
			errors.append("У компонента '%s' повторяется настройка '%s'." % [definition.component_id, key])
			continue
		setting_ids[key] = true
		errors.append_array(_validate_setting_metadata(descriptor, key, definition.component_id))
		if not probe.set_setting(key, descriptor.get("default_value")):
			errors.append("У настройки '%s' компонента '%s' некорректное значение по умолчанию." % [key, definition.component_id])

	var required_ids: Dictionary = {}
	for dependency_id in definition.required_component_ids:
		var normalized_dependency := _normalize_id(str(dependency_id))
		if required_ids.has(normalized_dependency):
			errors.append("Компонент '%s' дважды требует компонент '%s'." % [definition.component_id, normalized_dependency])
		required_ids[normalized_dependency] = true
		if not _is_builtin_id(normalized_dependency) and not candidate.has(normalized_dependency):
			errors.append("Компонент '%s' требует неизвестный компонент '%s'." % [definition.component_id, normalized_dependency])

	var incompatible_ids: Dictionary = {}
	for incompatible_id in definition.incompatible_component_ids:
		var normalized_incompatible := _normalize_id(str(incompatible_id))
		if normalized_incompatible == definition.component_id:
			errors.append("Компонент '%s' не может конфликтовать сам с собой." % definition.component_id)
		if incompatible_ids.has(normalized_incompatible):
			errors.append("Компонент '%s' дважды указывает конфликт '%s'." % [definition.component_id, normalized_incompatible])
		incompatible_ids[normalized_incompatible] = true
		if not _is_builtin_id(normalized_incompatible) and not candidate.has(normalized_incompatible):
			errors.append("Компонент '%s' конфликтует с неизвестным компонентом '%s'." % [definition.component_id, normalized_incompatible])

	for dependency_id in required_ids:
		if incompatible_ids.has(dependency_id):
			errors.append("Компонент '%s' одновременно требует и запрещает '%s'." % [definition.component_id, dependency_id])

	for incompatible_id in incompatible_ids:
		var incompatible_definition := candidate.get(incompatible_id) as ObjectComponentDefinition
		if incompatible_definition != null and not incompatible_definition.incompatible_component_ids.has(definition.component_id):
			errors.append(
				"Конфликт между компонентами '%s' и '%s' должен быть указан с обеих сторон."
				% [definition.component_id, incompatible_id]
			)
	return errors


static func _validate_setting_metadata(
	descriptor: Dictionary,
	setting_key: String,
	component_id: String
) -> PackedStringArray:
	var errors := PackedStringArray()
	var display_name := str(descriptor.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		errors.append("У настройки '%s' компонента '%s' отсутствует пользовательское название." % [
			setting_key,
			component_id
		])

	if str(descriptor.get("group_id", "")).strip_edges().is_empty():
		errors.append("У настройки '%s' компонента '%s' отсутствует group_id." % [
			setting_key,
			component_id
		])
	if str(descriptor.get("group_name", "")).strip_edges().is_empty():
		errors.append("У настройки '%s' компонента '%s' отсутствует название группы." % [
			setting_key,
			component_id
		])

	var level := str(descriptor.get("level", "")).strip_edges().to_lower()
	if level not in ["basic", "advanced", "expert"]:
		errors.append("У настройки '%s' компонента '%s' неизвестный уровень: %s." % [
			setting_key,
			component_id,
			level
		])

	var supported_editors := [
		"unspecified",
		"switch",
		"number",
		"slider",
		"range",
		"text",
		"multiline_text",
		"vector2",
		"color",
		"enum",
		"catalog_reference",
		"resource_reference",
		"gameplay_table",
		"structured_list",
		"structured_object"
	]
	var editor := str(descriptor.get("editor", "")).strip_edges().to_lower()
	if not supported_editors.has(editor):
		errors.append("У настройки '%s' компонента '%s' неизвестный editor: %s." % [
			setting_key,
			component_id,
			editor
		])

	var value_type := str(descriptor.get("value_type", ""))
	var compatible_value_types := {
		"switch": ["Boolean"],
		"number": ["Integer", "Float"],
		"slider": ["Integer", "Float"],
		"range": ["Integer", "Float"],
		"text": ["String"],
		"multiline_text": ["String"],
		"vector2": ["Vector2"],
		"color": ["Color"],
		"enum": ["String", "Integer", "Float", "Boolean"],
		"catalog_reference": ["String"],
		"resource_reference": ["String"],
		"gameplay_table": ["String"]
	}
	if compatible_value_types.has(editor) and not compatible_value_types[editor].has(value_type):
		errors.append("Editor '%s' несовместим с типом '%s' у настройки '%s' компонента '%s'." % [
			editor,
			value_type,
			setting_key,
			component_id
		])

	var visibility: Variant = descriptor.get("visibility", "always")
	if typeof(visibility) != TYPE_STRING and typeof(visibility) != TYPE_DICTIONARY:
		errors.append("У настройки '%s' компонента '%s' visibility должна быть строкой или Dictionary." % [
			setting_key,
			component_id
		])
	elif typeof(visibility) == TYPE_STRING and str(visibility).strip_edges().is_empty():
		errors.append("У настройки '%s' компонента '%s' visibility не может быть пустой." % [
			setting_key,
			component_id
		])

	if typeof(descriptor.get("unit", "")) != TYPE_STRING:
		errors.append("Единица измерения настройки '%s' компонента '%s' должна быть строкой." % [
			setting_key,
			component_id
		])
	if typeof(descriptor.get("nullable", false)) != TYPE_BOOL:
		errors.append("nullable настройки '%s' компонента '%s' должна быть Boolean." % [
			setting_key,
			component_id
		])
	if typeof(descriptor.get("required", false)) != TYPE_BOOL:
		errors.append("required настройки '%s' компонента '%s' должна быть Boolean." % [
			setting_key,
			component_id
		])
	if typeof(descriptor.get("editor_config", {})) != TYPE_DICTIONARY:
		errors.append("editor_config настройки '%s' компонента '%s' должна быть Dictionary." % [
			setting_key,
			component_id
		])

	var editor_config_value: Variant = descriptor.get("editor_config", {})
	if typeof(editor_config_value) == TYPE_DICTIONARY:
		var editor_config: Dictionary = editor_config_value
		if editor == "structured_list":
			var structure_type := str(editor_config.get("structure_type", "")).strip_edges().to_lower()
			if structure_type.is_empty():
				errors.append("StructuredList настройки '%s' компонента '%s' должна объявлять structure_type." % [
					setting_key,
					component_id
				])
			if structure_type == "loot_table":
				if value_type != "String":
					errors.append("Legacy loot table '%s' компонента '%s' должна сериализоваться как String до миграции." % [
						setting_key,
						component_id
					])
				if str(editor_config.get("reference_type", "")).strip_edges().to_lower() != "item":
					errors.append("Loot table '%s' компонента '%s' должна ссылаться на каталог предметов." % [
						setting_key,
						component_id
					])
			elif structure_type == "production_table":
				if value_type != "String":
					errors.append("Legacy production table '%s' компонента '%s' должна сериализоваться как String до миграции." % [
						setting_key,
						component_id
					])
				if str(editor_config.get("reference_type", "")).strip_edges().to_lower() != "item":
					errors.append("Production table '%s' компонента '%s' должна ссылаться на каталог предметов." % [
						setting_key,
						component_id
					])
			elif structure_type in ["daily_routine", "day_phase_schedule", "event_schedule"]:
				if value_type != "String":
					errors.append("Legacy schedule '%s' компонента '%s' должна сериализоваться как String до миграции." % [
						setting_key,
						component_id
					])
			elif structure_type not in ["loot_table", "production_table"]:
				errors.append("У настройки '%s' компонента '%s' неизвестный StructuredList type: %s." % [
					setting_key,
					component_id,
					structure_type
				])
		elif editor == "structured_object":
			var structure_type := str(editor_config.get("structure_type", "")).strip_edges().to_lower()
			if structure_type.is_empty():
				errors.append("StructuredObject настройки '%s' компонента '%s' должна объявлять structure_type." % [
					setting_key,
					component_id
				])
			elif structure_type == "recipe_table":
				if value_type != "String":
					errors.append("Legacy recipe table '%s' компонента '%s' должна сериализоваться как String до миграции." % [
					setting_key,
					component_id
				])
				if str(editor_config.get("reference_type", "")).strip_edges().to_lower() != "item":
					errors.append("Recipe table '%s' компонента '%s' должна ссылаться на каталог предметов." % [
					setting_key,
					component_id
				])
			else:
				errors.append("У настройки '%s' компонента '%s' неизвестный StructuredObject type: %s." % [
					setting_key,
					component_id,
					structure_type
				])

	var options_value: Variant = descriptor.get("options", [])
	var option_values: Array = []
	if typeof(options_value) != TYPE_ARRAY:
		errors.append("options настройки '%s' компонента '%s' должен быть Array." % [
			setting_key,
			component_id
		])
	else:
		var seen_options: Dictionary = {}
		for option_value in options_value:
			if not option_value is Dictionary:
				errors.append("Каждый вариант настройки '%s' компонента '%s' должен быть Dictionary с value и label." % [
					setting_key,
					component_id
				])
				continue
			var option: Dictionary = option_value
			if not option.has("value") or typeof(option.get("value")) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
				errors.append("Вариант настройки '%s' компонента '%s' должен иметь скалярное value." % [
					setting_key,
					component_id
				])
				continue
			var option_key := "%s:%s" % [str(typeof(option.get("value"))), str(option.get("value"))]
			if seen_options.has(option_key):
				errors.append("У настройки '%s' компонента '%s' повторяется вариант '%s'." % [
					setting_key,
					component_id,
					str(option.get("value"))
				])
			seen_options[option_key] = true
			option_values.append(option.get("value"))
			if str(option.get("label", "")).strip_edges().is_empty():
				errors.append("У варианта настройки '%s' компонента '%s' отсутствует label." % [
					setting_key,
					component_id
				])

	if editor == "catalog_reference" and str(descriptor.get("reference_type", "")).strip_edges().is_empty():
		errors.append("У CatalogReference настройки '%s' компонента '%s' должен быть указан reference_type." % [
			setting_key,
			component_id
		])
	if editor in ["resource_reference", "gameplay_table"] and str(descriptor.get("resource_type", "")).strip_edges().is_empty():
		errors.append("У ResourceReference настройки '%s' компонента '%s' должен быть указан resource_type." % [
			setting_key,
			component_id
		])

	if editor == "enum":
		if option_values.is_empty():
			errors.append("Enum-настройка '%s' компонента '%s' должна содержать options." % [
				setting_key,
				component_id
			])
		elif not option_values.has(descriptor.get("default_value")):
			errors.append("Default настройки '%s' компонента '%s' отсутствует среди options." % [
				setting_key,
				component_id
			])

	var raw_has_range: Variant = descriptor.get("has_range", false)
	if typeof(raw_has_range) != TYPE_BOOL:
		errors.append("has_range настройки '%s' компонента '%s' должна быть Boolean." % [
			setting_key,
			component_id
		])
	elif bool(raw_has_range):
		if value_type not in ["Integer", "Float"]:
			errors.append("Числовой диапазон настройки '%s' компонента '%s' допустим только для Integer и Float." % [
				setting_key,
				component_id
			])
		var minimum_value: Variant = descriptor.get("minimum")
		var maximum_value: Variant = descriptor.get("maximum")
		if typeof(minimum_value) not in [TYPE_INT, TYPE_FLOAT] or typeof(maximum_value) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("Настройка '%s' компонента '%s' должна иметь числовые minimum и maximum." % [
				setting_key,
				component_id
			])
		else:
			var minimum := float(minimum_value)
			var maximum := float(maximum_value)
			if is_nan(minimum) or is_inf(minimum) or is_nan(maximum) or is_inf(maximum) or minimum > maximum:
				errors.append("Диапазон настройки '%s' компонента '%s' должен иметь конечные границы и minimum <= maximum." % [
					setting_key,
					component_id
				])
			var default_value: Variant = descriptor.get("default_value")
			if typeof(default_value) in [TYPE_INT, TYPE_FLOAT]:
				var numeric_default := float(default_value)
				if is_nan(numeric_default) or is_inf(numeric_default) or numeric_default < minimum or numeric_default > maximum:
					errors.append("Default настройки '%s' компонента '%s' выходит за заданный диапазон." % [
						setting_key,
						component_id
					])
			else:
				errors.append("Default настройки '%s' компонента '%s' должен быть числом для заданного диапазона." % [
					setting_key,
					component_id
				])

	if descriptor.has("step"):
		var step_value: Variant = descriptor.get("step")
		if value_type not in ["Integer", "Float"]:
			errors.append("step настройки '%s' компонента '%s' поддерживается только для Integer и Float." % [
				setting_key,
				component_id
			])
		if typeof(step_value) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("step настройки '%s' компонента '%s' должен быть числом." % [
				setting_key,
				component_id
			])
		elif is_nan(float(step_value)) or is_inf(float(step_value)) or float(step_value) <= 0.0:
			errors.append("step настройки '%s' компонента '%s' должен быть конечным числом больше нуля." % [
				setting_key,
				component_id
			])
	return errors


static func _validate_dependency_graph(candidate: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var states: Dictionary = {}
	for component_id in candidate:
		if not _visit_component(str(component_id), candidate, states, errors):
			break
	return errors


static func _visit_component(
	component_id: String,
	candidate: Dictionary,
	states: Dictionary,
	errors: PackedStringArray
) -> bool:
	if states.get(component_id, 0) == 2:
		return true
	if states.get(component_id, 0) == 1:
		errors.append("Обнаружен цикл зависимостей компонентов: " + component_id)
		return false
	var definition := candidate.get(component_id) as ObjectComponentDefinition
	if definition == null:
		return _is_builtin_id(component_id)
	states[component_id] = 1
	for dependency_id in definition.required_component_ids:
		var normalized_dependency := _normalize_id(str(dependency_id))
		if not candidate.has(normalized_dependency):
			errors.append("Компонент '%s' требует неизвестный компонент '%s'." % [component_id, normalized_dependency])
			return false
		if not _visit_component(normalized_dependency, candidate, states, errors):
			return false
	states[component_id] = 2
	return true


static func _get_builtin_category_display_name(category_id: String) -> String:
	match category_id:
		"Appearance":
			return "Внешний вид"
		"Physics":
			return "Физика"
		"Stats":
			return "Характеристики"
		"Combat":
			return "Бой"
		"Interaction":
			return "Взаимодействие"
		"Destruction":
			return "Разрушение"
		"Audio":
			return "Звук"
		"Procedural":
			return "Процедурная генерация"
	return category_id


static func _get_builtin_display_name(component_id: String) -> String:
	match component_id:
		"health":
			return "Здоровье"
		"damageable":
			return "Приём урона"
		"attack":
			return "Атака"
		"destructible":
			return "Разрушение"
		"pickup":
			return "Подбор предмета"
		"interactable":
			return "Взаимодействие"
	return component_id


static func _get_builtin_description(component_id: String) -> String:
	match component_id:
		"health":
			return "Запас здоровья, получение урона, лечение и сигнал смерти."
		"damageable":
			return "Принимает урон, применяет множитель и плоское снижение, передаёт результат компоненту Health."
		"attack":
			return "Наносит урон цели с Damageable, проверяет расстояние и перезарядку."
		"destructible":
			return "Реагирует на смерть Health, отключает коллизии и получение урона, сообщает о разрушении."
		"pickup":
			return "Передаёт предмет получателю, поддерживает частичный подбор и удаляет источник после опустошения."
		"interactable":
			return "Проверяет радиус и доступность, вызывает назначенный метод объекта и сообщает о взаимодействии."
	return "Компонент без описания."


static func _is_builtin_id(component_id: String) -> bool:
	return component_id in ["health", "damageable", "attack", "destructible", "pickup", "interactable"]


static func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return value[0] != "_" and value[value.length() - 1] != "_"
