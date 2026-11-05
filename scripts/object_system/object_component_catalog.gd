extends RefCounted
class_name ObjectComponentCatalog

const HEALTH_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/health_component.gd")
const DAMAGEABLE_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/damageable_component.gd")
const ATTACK_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/attack_component.gd")
const DESTRUCTIBLE_COMPONENT_SCRIPT := preload("res://scripts/object_system/components/destructible_component.gd")

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

static var _custom_definitions: Dictionary = {}
static var _custom_sources: Dictionary = {}


## Registers one extension component. IDs are global and cannot shadow built-ins or another source.
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
		if _is_builtin_id(component_id):
			errors.append("Нельзя переопределить встроенный компонент: " + component_id)
			continue
		if incoming.has(component_id):
			errors.append("В пакете повторяется ID компонента: " + component_id)
			continue
		if _custom_definitions.has(component_id) and str(_custom_sources.get(component_id, "")) != normalized_source:
			errors.append("ID компонента уже зарегистрирован другим источником: " + component_id)
			continue
		var existing := _custom_definitions.get(component_id) as ObjectComponentDefinition
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

	var candidate := _custom_definitions.duplicate(true)
	for component_id in incoming:
		candidate[component_id] = incoming[component_id]

	for component_id in incoming:
		var definition := candidate[component_id] as ObjectComponentDefinition
		errors.append_array(_validate_custom_definition(definition, candidate))

	if errors.is_empty():
		errors.append_array(_validate_dependency_graph(candidate))
	if not errors.is_empty():
		return errors

	for component_id in incoming:
		_custom_definitions[component_id] = incoming[component_id]
		_custom_sources[component_id] = normalized_source
	return errors


## Removes all components registered by one source, unless another capability still depends on them.
static func unregister_source(source_id: String) -> PackedStringArray:
	var normalized_source := source_id.strip_edges()
	var remove_ids := PackedStringArray()
	for component_id in _custom_sources:
		if str(_custom_sources[component_id]) == normalized_source:
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
		_custom_definitions.erase(component_id)
		_custom_sources.erase(component_id)
	return PackedStringArray()


static func get_source_id(component_id: String) -> String:
	return str(_custom_sources.get(_normalize_id(component_id), "builtin" if _is_builtin_id(_normalize_id(component_id)) else ""))


static func get_categories() -> Array[Dictionary]:
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
	var result := PackedStringArray(["health", "damageable", "attack", "destructible"])
	for custom_id in _custom_definitions:
		result.append(str(custom_id))
	if not category_id.is_empty():
		var filtered := PackedStringArray()
		for component_id in result:
			var definition := create_definition(component_id)
			if definition == null:
				continue
			var resolved_category := definition.category_id if not definition.category_id.is_empty() else definition.category
			if resolved_category == category_id:
				filtered.append(component_id)
		result = filtered
	result.sort()
	return result


static func get_component_display_name(component_id: String) -> String:
	var definition := create_definition(component_id)
	return definition.display_name if definition != null else component_id


static func get_component_description(component_id: String) -> String:
	var definition := create_definition(component_id)
	return definition.description if definition != null else "Компонент без описания."


static func has_component(component_id: String) -> bool:
	var normalized_id := _normalize_id(component_id)
	return _is_builtin_id(normalized_id) or _custom_definitions.has(normalized_id)


static func create_definition(component_id: String) -> ObjectComponentDefinition:
	var normalized_id := _normalize_id(component_id)
	if _custom_definitions.has(normalized_id):
		return (_custom_definitions[normalized_id] as ObjectComponentDefinition).duplicate(true) as ObjectComponentDefinition
	if not _is_builtin_id(normalized_id):
		return null

	var definition := ObjectComponentDefinition.new()
	definition.component_id = normalized_id
	definition.display_name = _get_builtin_display_name(normalized_id)
	definition.description = _get_builtin_description(normalized_id)
	definition.category = "Stats" if normalized_id == "health" else "Combat"
	definition.category_id = definition.category
	definition.category_display_name = _get_builtin_category_display_name(definition.category)
	definition.component_version = 1
	match normalized_id:
		"health":
			definition.component_script = HEALTH_COMPONENT_SCRIPT
		"damageable":
			definition.component_script = DAMAGEABLE_COMPONENT_SCRIPT
		"attack":
			definition.component_script = ATTACK_COMPONENT_SCRIPT
		"destructible":
			definition.category = "Destruction"
			definition.category_id = "Destruction"
			definition.category_display_name = "Разрушение"
			definition.component_script = DESTRUCTIBLE_COMPONENT_SCRIPT
	definition.setting_definitions = ObjectComponentDefinition.get_builtin_setting_definitions(normalized_id)
	for setting_definition in definition.setting_definitions:
		var setting_key := str(setting_definition.get("key", ""))
		if not setting_key.is_empty():
			definition.settings[setting_key] = setting_definition.get("default_value")
	return definition


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


static func _validate_custom_definition(
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
		errors.append("У пользовательской категории компонента '%s' отсутствует название." % definition.component_id)
	if definition.component_script == null:
		errors.append("У компонента '%s' не назначен скрипт." % definition.component_id)
	else:
		var instance: Object = definition.component_script.new()
		if not instance is ObjectComponent:
			errors.append("Скрипт компонента '%s' должен наследовать ObjectComponent." % definition.component_id)
		if instance is Node:
			(instance as Node).free()

	var setting_ids: Dictionary = {}
	var probe := definition.duplicate(true) as ObjectComponentDefinition
	probe.settings = {}
	for descriptor in probe.get_setting_definitions():
		var key := str(descriptor.get("key", "")).strip_edges()
		if key.is_empty():
			errors.append("У настройки компонента '%s' отсутствует key." % definition.component_id)
			continue
		if setting_ids.has(key):
			errors.append("У компонента '%s' повторяется настройка '%s'." % [definition.component_id, key])
			continue
		setting_ids[key] = true
		if bool(descriptor.get("has_range", false)) and float(descriptor.get("minimum", 0.0)) > float(descriptor.get("maximum", 0.0)):
			errors.append("У настройки '%s' компонента '%s' перепутаны границы." % [key, definition.component_id])
			continue
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
		if _is_builtin_id(normalized_dependency):
			continue
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
	return "Компонент без описания."


static func _is_builtin_id(component_id: String) -> bool:
	return component_id in ["health", "damageable", "attack", "destructible"]


static func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return value[0] != "_" and value[value.length() - 1] != "_"
