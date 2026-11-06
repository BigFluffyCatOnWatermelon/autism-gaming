extends RefCounted
class_name ObjectCapabilityCatalog

## Registry of user-facing capability cards. Built-in and extension definitions share one API.

const CAPABILITY_LIBRARY_DATA = preload("res://scripts/object_system/object_capability_library_data.gd")

const BUILTIN_CATEGORIES := [
	{"id": "general", "display_name": "Основное", "order": 0},
	{"id": "visual", "display_name": "Внешний вид", "order": 10},
	{"id": "animation", "display_name": "Анимация", "order": 20},
	{"id": "movement", "display_name": "Движение", "order": 30},
	{"id": "physics", "display_name": "Физика", "order": 40},
	{"id": "interaction", "display_name": "Взаимодействие", "order": 50},
	{"id": "stats", "display_name": "Характеристики", "order": 60},
	{"id": "combat", "display_name": "Бой", "order": 70},
	{"id": "defense", "display_name": "Защита", "order": 80},
	{"id": "destruction", "display_name": "Разрушение", "order": 90},
	{"id": "harvesting", "display_name": "Добыча и сбор", "order": 100},
	{"id": "items", "display_name": "Предметы", "order": 110},
	{"id": "inventory", "display_name": "Инвентарь", "order": 120},
	{"id": "containers", "display_name": "Контейнеры", "order": 130},
	{"id": "construction", "display_name": "Строительство", "order": 140},
	{"id": "ai", "display_name": "Поведение и AI", "order": 150},
	{"id": "animals", "display_name": "Животные", "order": 160},
	{"id": "audio_effects", "display_name": "Звук и эффекты", "order": 170},
	{"id": "world_time", "display_name": "Время и события", "order": 180},
	{"id": "world_generation", "display_name": "Генерация мира", "order": 190}
]

static var _definitions: Dictionary = {}
static var _sources: Dictionary = {}
static var _library_definitions: Dictionary = {}
static var _initialized: bool = false


## Registers one extension capability. Built-in IDs are reserved.
static func register_definition(
	definition: ObjectCapabilityDefinition,
	source_id: String = "extension"
) -> bool:
	return register_definitions([definition], source_id).is_empty()


## Validates an entire batch, including dependencies and conflicts, before changing the registry.
static func register_definitions(
	definitions: Array,
	source_id: String = "extension"
) -> PackedStringArray:
	_ensure_initialized()
	var errors := PackedStringArray()
	var normalized_source := source_id.strip_edges()
	if normalized_source.is_empty():
		errors.append("Для регистрации возможностей нужен непустой source_id.")
		return errors

	var incoming: Dictionary = {}
	for value in definitions:
		if not value is ObjectCapabilityDefinition:
			errors.append("Реестр возможностей принимает только ObjectCapabilityDefinition.")
			continue
		var definition := value as ObjectCapabilityDefinition
		var capability_id := _normalize_id(definition.capability_id)
		if not _is_valid_id(capability_id):
			errors.append("Некорректный ID возможности: " + definition.capability_id)
			continue
		if _is_builtin_id(capability_id):
			errors.append("Нельзя переопределить встроенную возможность: " + capability_id)
			continue
		if incoming.has(capability_id):
			errors.append("В пакете повторяется ID возможности: " + capability_id)
			continue

		var existing := _definitions.get(capability_id) as ObjectCapabilityDefinition
		var existing_source := str(_sources.get(capability_id, ""))
		var promotes_catalog_placeholder := (
			existing != null
			and existing.runtime_status == "Planned"
			and _library_definitions.has(capability_id)
			and existing_source == "builtin"
			and normalized_source.begins_with("mechanic_module:")
		)
		if existing != null and existing_source != normalized_source and not promotes_catalog_placeholder:
			errors.append("ID возможности уже зарегистрирован другим источником: " + capability_id)
			continue
		if existing != null and existing.version > definition.version:
			errors.append("Нельзя понизить версию возможности '%s' с %d до %d." % [
				capability_id,
				existing.version,
				definition.version
			])
			continue

		var copy := definition.duplicate(true) as ObjectCapabilityDefinition
		copy.capability_id = capability_id
		incoming[capability_id] = copy

	if not errors.is_empty():
		return errors

	var candidate := _definitions.duplicate(true)
	for capability_id in incoming:
		candidate[capability_id] = incoming[capability_id]

	for capability_id in incoming:
		var definition := candidate[capability_id] as ObjectCapabilityDefinition
		errors.append_array(_validate_definition(definition, candidate))

	if errors.is_empty():
		errors.append_array(_validate_dependency_graph(candidate))
	if not errors.is_empty():
		return errors

	for capability_id in incoming:
		_definitions[capability_id] = incoming[capability_id]
		_sources[capability_id] = normalized_source
	return errors


static func unregister_source(source_id: String) -> PackedStringArray:
	_ensure_initialized()
	var normalized_source := source_id.strip_edges()
	if normalized_source.is_empty():
		return PackedStringArray(["Для отключения возможностей нужен непустой source_id."])

	var remove_ids := PackedStringArray()
	for capability_id in _sources:
		if str(_sources[capability_id]) == normalized_source:
			remove_ids.append(str(capability_id))
	if remove_ids.is_empty():
		return PackedStringArray()

	# Restore reserved catalogue cards as Planned instead of deleting them.
	var candidate := _definitions.duplicate(true)
	var restore_definitions: Dictionary = {}
	for capability_id in remove_ids:
		if _library_definitions.has(capability_id):
			var fallback := (_library_definitions[capability_id] as ObjectCapabilityDefinition).duplicate(true)
			restore_definitions[capability_id] = fallback
			candidate[capability_id] = fallback
		else:
			candidate.erase(capability_id)

	var errors := _validate_dependency_graph(candidate)
	if not errors.is_empty():
		return errors

	for capability_id in remove_ids:
		if restore_definitions.has(capability_id):
			_definitions[capability_id] = restore_definitions[capability_id]
			_sources[capability_id] = "builtin"
		else:
			_definitions.erase(capability_id)
			_sources.erase(capability_id)
	return PackedStringArray()


static func validate_registry() -> PackedStringArray:
	_ensure_initialized()
	var errors := PackedStringArray()
	for capability_id in _definitions:
		var definition := _definitions[capability_id] as ObjectCapabilityDefinition
		errors.append_array(_validate_definition(definition, _definitions))
	if errors.is_empty():
		errors.append_array(_validate_dependency_graph(_definitions))
	return errors


static func get_source_id(capability_id: String) -> String:
	_ensure_initialized()
	return str(_sources.get(_normalize_id(capability_id), ""))


static func get_categories() -> Array[Dictionary]:
	_ensure_initialized()
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for category in BUILTIN_CATEGORIES:
		var copied: Dictionary = category.duplicate(true)
		result.append(copied)
		seen[str(copied.get("id", ""))] = true

	var extra_categories: Dictionary = {}
	for definition_value in _definitions.values():
		var definition := definition_value as ObjectCapabilityDefinition
		if definition == null or seen.has(definition.category_id):
			continue
		extra_categories[definition.category_id] = definition.category_name
	for category_id in extra_categories:
		result.append({
			"id": str(category_id),
			"display_name": str(extra_categories[category_id]),
			"order": 1000
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a := int(a.get("order", 1000))
		var order_b := int(b.get("order", 1000))
		if order_a == order_b:
			return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
		return order_a < order_b
	)
	return result


static func get_capability_ids(
	category_id: String = "",
	simple_only: bool = true
) -> PackedStringArray:
	_ensure_initialized()
	var result: Array[String] = []
	for capability_id in _definitions:
		var definition := _definitions[capability_id] as ObjectCapabilityDefinition
		if definition == null:
			continue
		if not category_id.is_empty() and definition.category_id != category_id:
			continue
		if simple_only and not definition.available_in_simple_mode:
			continue
		result.append(str(capability_id))
	result.sort_custom(func(a: String, b: String) -> bool:
		var def_a := _definitions[a] as ObjectCapabilityDefinition
		var def_b := _definitions[b] as ObjectCapabilityDefinition
		if def_a.display_order == def_b.display_order:
			return def_a.display_name.naturalnocasecmp_to(def_b.display_name) < 0
		return def_a.display_order < def_b.display_order
	)
	var packed := PackedStringArray()
	for capability_id in result:
		packed.append(capability_id)
	return packed


static func get_definition(capability_id: String) -> ObjectCapabilityDefinition:
	_ensure_initialized()
	var definition := _definitions.get(_normalize_id(capability_id)) as ObjectCapabilityDefinition
	if definition == null:
		return null
	return definition.duplicate(true) as ObjectCapabilityDefinition


static func has_capability(capability_id: String) -> bool:
	_ensure_initialized()
	return _definitions.has(_normalize_id(capability_id))


static func create_selection(capability_id: String) -> ObjectCapabilitySelection:
	var normalized_id := _normalize_id(capability_id)
	if not has_capability(normalized_id):
		return null
	var selection := ObjectCapabilitySelection.new()
	selection.capability_id = normalized_id
	return selection


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	for definition in _make_builtin_definitions():
		_definitions[definition.capability_id] = definition
		_sources[definition.capability_id] = "builtin"


static func _make_builtin_definitions() -> Array[ObjectCapabilityDefinition]:
	var result: Array[ObjectCapabilityDefinition] = []
	var health := ObjectCapabilityDefinition.new()
	health.capability_id = "has_health"
	health.display_name = "Есть здоровье"
	health.description = "У объекта есть запас здоровья. Его можно уменьшать и восстанавливать."
	health.category_id = "stats"
	health.category_name = "Характеристики"
	health.icon = "heart"
	health.keywords = PackedStringArray(["здоровье", "прочность", "жизнь", "hp"])
	health.component_ids = PackedStringArray(["health"])
	health.display_order = 10
	result.append(health)

	var damageable := ObjectCapabilityDefinition.new()
	damageable.capability_id = "can_receive_damage"
	damageable.display_name = "Можно повредить"
	damageable.description = "Объект принимает урон. Здоровье будет добавлено автоматически."
	damageable.category_id = "combat"
	damageable.category_name = "Бой"
	damageable.icon = "shield"
	damageable.keywords = PackedStringArray(["урон", "повреждение", "атака", "здоровье"])
	damageable.required_capability_ids = PackedStringArray(["has_health"])
	damageable.component_ids = PackedStringArray(["damageable"])
	damageable.display_order = 10
	result.append(damageable)

	var attack := ObjectCapabilityDefinition.new()
	attack.capability_id = "can_attack"
	attack.display_name = "Может атаковать"
	attack.description = "Объект может наносить урон другим объектам, которые умеют его получать."
	attack.category_id = "combat"
	attack.category_name = "Бой"
	attack.icon = "swords"
	attack.keywords = PackedStringArray(["атака", "урон", "нападение"])
	attack.component_ids = PackedStringArray(["attack"])
	attack.display_order = 20
	result.append(attack)

	var destructible := ObjectCapabilityDefinition.new()
	destructible.capability_id = "breaks_when_health_empty"
	destructible.display_name = "Разрушается при потере здоровья"
	destructible.description = "Когда здоровье закончится, объект перейдёт в разрушенное состояние. Здоровье добавится автоматически."
	destructible.category_id = "destruction"
	destructible.category_name = "Разрушение"
	destructible.icon = "hammer"
	destructible.keywords = PackedStringArray(["разрушение", "сломать", "ломается", "прочность"])
	destructible.required_capability_ids = PackedStringArray(["has_health"])
	destructible.component_ids = PackedStringArray(["destructible"])
	destructible.display_order = 10
	result.append(destructible)
	for planned_definition in CAPABILITY_LIBRARY_DATA.create_definitions():
		var capability_id := planned_definition.capability_id
		var library_copy := planned_definition.duplicate(true) as ObjectCapabilityDefinition
		_library_definitions[capability_id] = library_copy
		result.append(library_copy.duplicate(true) as ObjectCapabilityDefinition)
	return result


static func _validate_definition(
	definition: ObjectCapabilityDefinition,
	candidate: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition.display_name.strip_edges().is_empty():
		errors.append("У возможности '%s' отсутствует пользовательское название." % definition.capability_id)
	if definition.description.strip_edges().is_empty():
		errors.append("У возможности '%s' отсутствует описание." % definition.capability_id)
	if definition.category_id.strip_edges().is_empty() or definition.category_name.strip_edges().is_empty():
		errors.append("У возможности '%s' должна быть категория с ID и названием." % definition.capability_id)
	if definition.version < 1:
		errors.append("Версия возможности '%s' должна быть не меньше 1." % definition.capability_id)
	if definition.runtime_status not in ["Implemented", "Planned"]:
		errors.append("У возможности '%s' неизвестный runtime_status: %s." % [
			definition.capability_id,
			definition.runtime_status
		])

	var component_ids: Dictionary = {}
	for component_id in definition.component_ids:
		var normalized_component_id := _normalize_id(str(component_id))
		if component_ids.has(normalized_component_id):
			errors.append("Возможность '%s' дважды добавляет компонент '%s'." % [definition.capability_id, normalized_component_id])
		component_ids[normalized_component_id] = true
		if not ObjectComponentCatalog.has_component(normalized_component_id):
			errors.append("Возможность '%s' ссылается на неизвестный компонент '%s'." % [definition.capability_id, normalized_component_id])

	var dependency_ids: Dictionary = {}
	for dependency_id in definition.required_capability_ids:
		var normalized_dependency_id := _normalize_id(str(dependency_id))
		if normalized_dependency_id == definition.capability_id:
			errors.append("Возможность '%s' не может зависеть от самой себя." % definition.capability_id)
		if dependency_ids.has(normalized_dependency_id):
			errors.append("Возможность '%s' дважды указывает зависимость '%s'." % [definition.capability_id, normalized_dependency_id])
		dependency_ids[normalized_dependency_id] = true
		if not candidate.has(normalized_dependency_id):
			errors.append("Возможность '%s' требует неизвестную возможность '%s'." % [definition.capability_id, normalized_dependency_id])

	var incompatible_ids: Dictionary = {}
	for incompatible_id in definition.incompatible_capability_ids:
		var normalized_incompatible_id := _normalize_id(str(incompatible_id))
		if normalized_incompatible_id == definition.capability_id:
			errors.append("Возможность '%s' не может конфликтовать сама с собой." % definition.capability_id)
		if incompatible_ids.has(normalized_incompatible_id):
			errors.append("Возможность '%s' дважды указывает конфликт '%s'." % [definition.capability_id, normalized_incompatible_id])
		incompatible_ids[normalized_incompatible_id] = true
		if not candidate.has(normalized_incompatible_id):
			errors.append("Возможность '%s' ссылается на неизвестный конфликт '%s'." % [definition.capability_id, normalized_incompatible_id])

	for dependency_id in dependency_ids:
		if incompatible_ids.has(dependency_id):
			errors.append("Возможность '%s' одновременно требует и запрещает '%s'." % [definition.capability_id, dependency_id])
	return errors


static func _validate_dependency_graph(candidate: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var states: Dictionary = {}
	for capability_id in candidate:
		if not _visit_capability(str(capability_id), candidate, states, errors):
			break
	if errors.is_empty():
		for capability_id in candidate:
			var definition := candidate[capability_id] as ObjectCapabilityDefinition
			if definition == null:
				continue
			for incompatible_id in definition.incompatible_capability_ids:
				var other := candidate.get(_normalize_id(str(incompatible_id))) as ObjectCapabilityDefinition
				if other == null:
					continue
				if other.incompatible_capability_ids.is_empty() or not other.incompatible_capability_ids.has(str(capability_id)):
					errors.append(
						"Конфликт между '%s' и '%s' должен быть указан с обеих сторон."
						% [str(capability_id), str(incompatible_id)]
					)
	return errors


static func _visit_capability(
	capability_id: String,
	candidate: Dictionary,
	states: Dictionary,
	errors: PackedStringArray
) -> bool:
	if states.get(capability_id, 0) == 2:
		return true
	if states.get(capability_id, 0) == 1:
		errors.append("Обнаружен цикл зависимостей возможностей: " + capability_id)
		return false
	var definition := candidate.get(capability_id) as ObjectCapabilityDefinition
	if definition == null:
		errors.append("Неизвестная возможность в графе зависимостей: " + capability_id)
		return false
	states[capability_id] = 1
	for dependency_id in definition.required_capability_ids:
		if not _visit_capability(_normalize_id(str(dependency_id)), candidate, states, errors):
			return false
	states[capability_id] = 2
	return true


static func _is_builtin_id(capability_id: String) -> bool:
	return capability_id in ["has_health", "can_receive_damage", "can_attack", "breaks_when_health_empty"]


static func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return value[0] != "_" and value[value.length() - 1] != "_"
