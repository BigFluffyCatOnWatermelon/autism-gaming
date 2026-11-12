extends RefCounted
class_name ObjectCapabilityCatalog

## Registry of user-facing capability cards. Built-in and extension definitions share one API.

const CAPABILITY_LIBRARY_DATA = preload("res://scripts/object_system/object_capability_library_data.gd")

const SETTING_PRESENTATION_OVERRIDE_KEYS := [
	"display_name",
	"description",
	"group_id",
	"group_name",
	"group_order",
	"order",
	"level",
	"advanced",
	"visibility",
	"editor",
	"editor_config"
]
const SETTING_SCHEMA_REFERENCE_KEYS := ["component_id", "setting_key", "key"]

const BUILTIN_CATEGORIES := [
	{"id": "general", "display_name": "Основное и данные", "order": 0},
	{"id": "visual", "display_name": "Внешний вид", "order": 10},
	{"id": "animation", "display_name": "Анимации", "order": 20},
	{"id": "physics_movement", "display_name": "Физика и движение", "order": 30},
	{"id": "interaction", "display_name": "Взаимодействие", "order": 40},
	{"id": "stats", "display_name": "Характеристики", "order": 50},
	{"id": "combat_defense", "display_name": "Бой и защита", "order": 60},
	{"id": "destruction", "display_name": "Разрушение и восстановление", "order": 70},
	{"id": "harvesting", "display_name": "Добыча и производство", "order": 80},
	{"id": "items_storage", "display_name": "Предметы и хранилища", "order": 90},
	{"id": "behavior_animals", "display_name": "Поведение и животные", "order": 100},
	{"id": "sound_effects", "display_name": "Звук и эффекты", "order": 110},
	{"id": "world_time", "display_name": "Время и события", "order": 120},
	{"id": "construction_generation", "display_name": "Строительство и генерация", "order": 130}
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
		if promotes_catalog_placeholder:
			var library_definition := _library_definitions.get(capability_id) as ObjectCapabilityDefinition
			_inherit_library_presentation_metadata(copy, library_definition)
		_prepare_settings_schema(copy)
		incoming[capability_id] = copy

	if not errors.is_empty():
		return errors

	var candidate := _definitions.duplicate(true)
	for capability_id in incoming:
		candidate[capability_id] = incoming[capability_id]

	# Resolve merge declarations only after this batch has entered the candidate.
	# Parent definitions can be built-ins or may register in a later package.
	var affected_parent_ids := _apply_merged_component_links(candidate)
	for parent_id in affected_parent_ids:
		var parent_definition := candidate.get(parent_id) as ObjectCapabilityDefinition
		if parent_definition != null:
			_prepare_settings_schema(parent_definition)

	for capability_id in incoming:
		var definition := candidate[capability_id] as ObjectCapabilityDefinition
		errors.append_array(_validate_definition(definition, candidate))
	for parent_id in affected_parent_ids:
		if incoming.has(parent_id):
			continue
		var parent_definition := candidate.get(parent_id) as ObjectCapabilityDefinition
		if parent_definition != null:
			errors.append_array(_validate_definition(parent_definition, candidate))

	if errors.is_empty():
		errors.append_array(_validate_dependency_graph(candidate))
	if not errors.is_empty():
		return errors

	for capability_id in incoming:
		_definitions[capability_id] = candidate[capability_id]
		_sources[capability_id] = normalized_source
	for parent_id in affected_parent_ids:
		if not incoming.has(parent_id):
			_definitions[parent_id] = candidate[parent_id]
	return errors


static func get_canonical_capability_id(capability_id: String) -> String:
	_ensure_initialized()
	var current := _normalize_id(capability_id)
	var visited: Dictionary = {}
	while not current.is_empty() and not visited.has(current):
		visited[current] = true
		var definition := _definitions.get(current) as ObjectCapabilityDefinition
		if definition == null:
			break
		var parent_id := _normalize_id(definition.merged_into_capability_id)
		if parent_id.is_empty():
			break
		current = parent_id
	return current


static func _apply_merged_component_links(candidate: Dictionary) -> PackedStringArray:
	var affected_parent_ids := PackedStringArray()
	for child_id_value in candidate.keys():
		var child_id := str(child_id_value)
		var child := candidate.get(child_id) as ObjectCapabilityDefinition
		if child == null:
			continue
		var parent_id := _normalize_id(child.merged_into_capability_id)
		if parent_id.is_empty():
			continue
		child.editor_hidden = true
		if not candidate.has(parent_id) or parent_id == child_id:
			continue
		var parent := candidate.get(parent_id) as ObjectCapabilityDefinition
		if parent == null:
			continue
		var updated := parent.duplicate(true) as ObjectCapabilityDefinition
		var destination_component := _normalize_id(child.merged_component_id)
		for component_id_value in child.component_ids:
			var source_component_id := _normalize_id(str(component_id_value))
			var target_component_id := destination_component if not destination_component.is_empty() else source_component_id
			if target_component_id.is_empty():
				continue
			if not updated.component_ids.has(target_component_id):
				updated.component_ids.append(target_component_id)
			if child.hide_merged_settings and not updated.hidden_component_ids.has(target_component_id):
				updated.hidden_component_ids.append(target_component_id)
		candidate[parent_id] = updated
		if not affected_parent_ids.has(parent_id):
			affected_parent_ids.append(parent_id)
	affected_parent_ids.sort()
	return affected_parent_ids


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
		if definition != null and not definition.merged_into_capability_id.strip_edges().is_empty():
			var canonical_id := get_canonical_capability_id(capability_id)
			if canonical_id == capability_id or not _definitions.has(canonical_id):
				errors.append("Для объединённой возможности '%s' не найден корректный родитель: '%s'." % [capability_id, definition.merged_into_capability_id])
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
		if definition == null or (simple_only and definition.editor_hidden):
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


## Returns the registered resource for read-only, high-frequency UI rendering.
## Callers must not mutate the returned definition; use get_definition() for an editable copy.
static func get_definition_reference(capability_id: String) -> ObjectCapabilityDefinition:
	_ensure_initialized()
	return _definitions.get(_normalize_id(capability_id)) as ObjectCapabilityDefinition


static func get_definition(capability_id: String) -> ObjectCapabilityDefinition:
	var definition := get_definition_reference(capability_id)
	if definition == null:
		return null
	return definition.duplicate(true) as ObjectCapabilityDefinition


static func has_capability(capability_id: String) -> bool:
	_ensure_initialized()
	return _definitions.has(_normalize_id(capability_id))


static func get_settings_schema(capability_id: String) -> Array[Dictionary]:
	var definition := get_definition(capability_id)
	var result: Array[Dictionary] = []
	if definition == null:
		return result
	for descriptor in definition.settings_schema:
		result.append(descriptor.duplicate(true))
	return result





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
		_prepare_settings_schema(definition)
		_definitions[definition.capability_id] = definition
		_sources[definition.capability_id] = "builtin"


static func _prepare_settings_schema(definition: ObjectCapabilityDefinition) -> void:
	if definition == null:
		return
	_normalize_category_metadata(definition)
	_resolve_settings_schema(definition)
	_apply_default_catalog_metadata(definition)


## Map legacy package categories into the compact user-facing taxonomy.
## Capability IDs and runtime component IDs are intentionally unchanged.
static func _normalize_category_metadata(definition: ObjectCapabilityDefinition) -> void:
	var category_map := {
		"movement": ["physics_movement", "Физика и движение"],
		"physics": ["physics_movement", "Физика и движение"],
		"combat": ["combat_defense", "Бой и защита"],
		"defense": ["combat_defense", "Бой и защита"],
		"items": ["items_storage", "Предметы и хранилища"],
		"inventory": ["items_storage", "Предметы и хранилища"],
		"containers": ["items_storage", "Предметы и хранилища"],
		"ai": ["behavior_animals", "Поведение и животные"],
		"animals": ["behavior_animals", "Поведение и животные"],
		"audio_effects": ["sound_effects", "Звук и эффекты"],
		"construction": ["construction_generation", "Строительство и генерация"],
		"world_generation": ["construction_generation", "Строительство и генерация"]
	}
	var legacy_id := definition.category_id.strip_edges().to_lower()
	if category_map.has(legacy_id):
		var normalized: Array = category_map[legacy_id]
		definition.category_id = str(normalized[0])
		definition.category_name = str(normalized[1])


## Resolve user-facing settings from the actual registered component definitions.
## This must run for every category; category normalization is unrelated to settings.
static func _resolve_settings_schema(definition: ObjectCapabilityDefinition) -> void:
	var explicit_by_key: Dictionary = {}
	var invalid_schema_index := 0
	for descriptor in definition.settings_schema:
		var component_id := _normalize_id(str(descriptor.get("component_id", "")))
		var setting_key := str(descriptor.get("setting_key", descriptor.get("key", ""))).strip_edges()
		if component_id.is_empty() and definition.component_ids.size() == 1:
			component_id = _normalize_id(str(definition.component_ids[0]))
		if component_id.is_empty() or setting_key.is_empty():
			explicit_by_key["__invalid_schema_%d" % invalid_schema_index] = descriptor.duplicate(true)
			invalid_schema_index += 1
			continue
		var schema_key := "%s@%s" % [component_id, setting_key]
		if explicit_by_key.has(schema_key):
			var duplicate_descriptor: Dictionary = descriptor.duplicate(true)
			duplicate_descriptor["_duplicate_schema_key"] = schema_key
			explicit_by_key["__duplicate_schema_%d" % invalid_schema_index] = duplicate_descriptor
			invalid_schema_index += 1
		else:
			explicit_by_key[schema_key] = descriptor.duplicate(true)

	var resolved_schema: Array[Dictionary] = []
	var consumed: Dictionary = {}
	for component_id_value in definition.component_ids:
		var component_id := _normalize_id(str(component_id_value))
		if definition.hidden_component_ids.has(component_id):
			continue
		var component_definition := ObjectComponentCatalog.create_definition(component_id)
		if component_definition == null:
			continue
		for component_descriptor in component_definition.get_setting_definitions():
			var setting_key := str(component_descriptor.get("key", "")).strip_edges()
			if setting_key.is_empty():
				continue
			var schema_key := "%s@%s" % [component_id, setting_key]
			var resolved: Dictionary = component_descriptor.duplicate(true)
			resolved["component_id"] = component_id
			resolved["setting_key"] = setting_key
			var override: Dictionary = explicit_by_key.get(schema_key, {})
			var forbidden_override_keys := PackedStringArray()
			for override_key in override:
				var normalized_override_key := str(override_key)
				if SETTING_SCHEMA_REFERENCE_KEYS.has(normalized_override_key):
					continue
				if SETTING_PRESENTATION_OVERRIDE_KEYS.has(normalized_override_key):
					resolved[normalized_override_key] = override[override_key]
				else:
					forbidden_override_keys.append(normalized_override_key)
			if not forbidden_override_keys.is_empty():
				resolved["_forbidden_overlay_keys"] = forbidden_override_keys
			var raw_level := str(resolved.get("level", "")).strip_edges().to_lower()
			if raw_level.is_empty() or raw_level in ["basic", "advanced", "expert"]:
				resolved["level"] = _normalize_setting_level(raw_level, bool(resolved.get("advanced", false)))
			else:
				# Preserve an invalid declaration so registration can report it clearly.
				resolved["level"] = raw_level
			resolved["advanced"] = str(resolved["level"]).to_lower() != "basic"
			resolved_schema.append(resolved)
			consumed[schema_key] = true

	# Keep invalid/unknown explicit entries so the registry can report them instead of
	# silently discarding extension authoring mistakes.
	for schema_key in explicit_by_key:
		if consumed.has(schema_key):
			continue
		var unresolved: Dictionary = explicit_by_key[schema_key].duplicate(true)
		unresolved["component_id"] = str(unresolved.get("component_id", ""))
		unresolved["setting_key"] = str(unresolved.get("setting_key", unresolved.get("key", "")))
		resolved_schema.append(unresolved)

	definition.settings_schema = resolved_schema


static func _inherit_library_presentation_metadata(
	target: ObjectCapabilityDefinition,
	library_definition: ObjectCapabilityDefinition
) -> void:
	if target == null or library_definition == null:
		return
	if target.icon_atlas_index < 0:
		target.icon_atlas_index = library_definition.icon_atlas_index
	if target.icon_resource_path.strip_edges().is_empty():
		target.icon_resource_path = library_definition.icon_resource_path
	if target.illustration_resource_path.strip_edges().is_empty():
		target.illustration_resource_path = library_definition.illustration_resource_path
	if target.kind_id.strip_edges().is_empty():
		target.kind_id = library_definition.kind_id
	if target.execution_scope == "unclassified":
		target.execution_scope = library_definition.execution_scope
	if target.implementation_type == "unclassified":
		target.implementation_type = library_definition.implementation_type

	for synonym in library_definition.synonyms:
		if not target.synonyms.has(synonym):
			target.synonyms.append(synonym)
	for example_query in library_definition.example_queries:
		if not target.example_queries.has(example_query):
			target.example_queries.append(example_query)

	for library_relation in library_definition.relations:
		var duplicate := false
		for existing_relation in target.relations:
			if (
				str(existing_relation.get("type", "")) == str(library_relation.get("type", ""))
				and str(existing_relation.get("target_id", "")) == str(library_relation.get("target_id", ""))
			):
				duplicate = true
				break
		if not duplicate:
			target.relations.append(library_relation.duplicate(true))


static func _apply_default_catalog_metadata(definition: ObjectCapabilityDefinition) -> void:
	if definition == null:
		return
	if definition.icon_atlas_index < 0 and _library_definitions.has(definition.capability_id):
		var library_icon_definition := _library_definitions[definition.capability_id] as ObjectCapabilityDefinition
		if library_icon_definition != null:
			definition.icon_atlas_index = library_icon_definition.icon_atlas_index

	var category_kinds := {
		"general": "general",
		"visual": "presentation",
		"animation": "animation",
		"movement": "movement",
		"physics": "physics",
		"interaction": "interaction",
		"stats": "attributes",
		"combat": "combat",
		"defense": "defense",
		"destruction": "lifecycle",
		"harvesting": "resources",
		"items": "items",
		"inventory": "inventory",
		"containers": "storage",
		"construction": "construction",
		"ai": "artificial_intelligence",
		"animals": "creature",
		"audio_effects": "audio_effects",
		"world_time": "time_events",
		"world_generation": "world_generation"
	}
	if definition.kind_id.strip_edges().is_empty():
		definition.kind_id = str(category_kinds.get(definition.category_id, definition.category_id))

	if definition.readiness_status.strip_edges().is_empty():
		definition.readiness_status = "ready" if definition.runtime_status == "Implemented" else "planned"

	if definition.execution_scope == "unclassified":
		if not definition.component_ids.is_empty():
			definition.execution_scope = "runtime"
		elif definition.is_ready():
			definition.execution_scope = "data_only"

	if definition.implementation_type == "unclassified":
		if not definition.component_ids.is_empty():
			definition.implementation_type = "component"
		elif definition.is_ready():
			definition.implementation_type = "declarative_data"


static func _normalize_setting_level(value: String, advanced: bool = false) -> String:
	var normalized := value.strip_edges().to_lower()
	match normalized:
		"basic":
			return "Basic"
		"advanced":
			return "Advanced"
		"expert":
			return "Expert"
	return "Advanced" if advanced else "Basic"


static func _make_builtin_definitions() -> Array[ObjectCapabilityDefinition]:
	var result: Array[ObjectCapabilityDefinition] = []
	var health := ObjectCapabilityDefinition.new()
	health.capability_id = "has_health"
	health.display_name = "Есть здоровье"
	health.description = "У объекта есть запас здоровья. Его можно уменьшать и восстанавливать."
	health.category_id = "stats"
	health.category_name = "Характеристики"
	health.icon = "heart"
	health.icon_atlas_index = 60
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
	damageable.icon_atlas_index = 71
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
	attack.icon_atlas_index = 70
	attack.keywords = PackedStringArray(["атака", "урон", "нападение"])
	attack.component_ids = PackedStringArray(["attack"])
	attack.display_order = 20
	result.append(attack)

	var destructible := ObjectCapabilityDefinition.new()
	destructible.capability_id = "breaks_when_health_empty"
	destructible.display_name = "Разрушается"
	destructible.description = "Объект может быть разрушен. Стадии, обломки, добыча, остатки, падение и взрыв настраиваются внутри этой механики."
	destructible.category_id = "destruction"
	destructible.category_name = "Разрушение"
	destructible.icon = "hammer"
	destructible.icon_atlas_index = 90
	destructible.keywords = PackedStringArray(["разрушение", "сломать", "ломается", "прочность"])
	destructible.required_capability_ids = PackedStringArray(["has_health"])
	destructible.component_ids = PackedStringArray(["destructible"])
	destructible.display_order = 10
	result.append(destructible)

	health.settings_schema = [
		{"setting_key": "can_heal", "level": "Advanced"},
		{"setting_key": "invulnerable", "level": "Expert"}
	]
	damageable.settings_schema = [
		{"setting_key": "material_type", "level": "Basic"},
		{"setting_key": "required_tool_id", "level": "Basic"},
		{"setting_key": "hit_radius", "level": "Basic"},
		{"setting_key": "flat_reduction", "level": "Advanced"}
	]
	attack.settings_schema = [
		{"setting_key": "require_range", "level": "Advanced"},
		{"setting_key": "can_attack", "level": "Advanced"}
	]
	destructible.settings_schema = [
		{"setting_key": "destroy_delay", "level": "Advanced"},
		{"setting_key": "disable_collision_on_destroy", "level": "Advanced"},
		{"setting_key": "disable_damage_on_destroy", "level": "Advanced"},
		{"setting_key": "hide_on_destroy", "level": "Expert"},
		{"setting_key": "remove_on_destroy", "level": "Expert"}
	]

	var interactable := ObjectCapabilityDefinition.new()
	interactable.capability_id = "can_interact"
	interactable.display_name = "Взаимодействие"
	interactable.description = "Объект реагирует на запрос игрока или другого инициатора. Дополнительные действия и их условия находятся внутри этой механики."
	interactable.category_id = "interaction"
	interactable.category_name = "Взаимодействие"
	interactable.icon = "hand"
	interactable.keywords = PackedStringArray(["взаимодействие", "interact", "кнопка e"])
	interactable.component_ids = PackedStringArray(["interactable"])
	interactable.available_in_simple_mode = true
	interactable.runtime_status = "Implemented"
	interactable.version = 1
	interactable.definition_schema_version = 1
	interactable.settings_schema = [
		{"setting_key": "can_be_interacted_with", "level": "Basic"},
		{"setting_key": "prompt_text", "level": "Basic"},
		{"setting_key": "interaction_radius", "level": "Basic"},
		{"setting_key": "interaction_method", "level": "Advanced"},
		{"setting_key": "interact_once", "level": "Advanced"},
		{"setting_key": "cooldown_seconds", "level": "Advanced"}
	]

	var pickup := ObjectCapabilityDefinition.new()
	pickup.capability_id = "is_pickup_item"
	pickup.display_name = "Можно подобрать"
	pickup.description = "Предмет можно подобрать в инвентарь с учётом количества, радиуса и правил удаления после подбора."
	pickup.category_id = "items"
	pickup.category_name = "Предметы"
	pickup.icon = "package"
	pickup.keywords = PackedStringArray(["подбор", "pickup", "предмет"])
	pickup.component_ids = PackedStringArray(["pickup"])
	pickup.available_in_simple_mode = true
	pickup.runtime_status = "Implemented"
	pickup.version = 1
	pickup.definition_schema_version = 1
	pickup.settings_schema = [
		{"setting_key": "item_id", "level": "Basic"},
		{"setting_key": "quantity", "level": "Basic"},
		{"setting_key": "pickup_radius", "level": "Advanced"},
		{"setting_key": "can_be_picked_up", "level": "Advanced"},
		{"setting_key": "remove_object_when_empty", "level": "Advanced"}
	]

	var active_by_id: Dictionary = {
		"can_interact": interactable,
		"is_pickup_item": pickup
	}
	for planned_definition in CAPABILITY_LIBRARY_DATA.create_definitions():
		var capability_id := planned_definition.capability_id
		var library_copy := planned_definition.duplicate(true) as ObjectCapabilityDefinition
		_library_definitions[capability_id] = library_copy
		if active_by_id.has(capability_id):
			var active_definition := active_by_id[capability_id] as ObjectCapabilityDefinition
			active_definition.display_order = library_copy.display_order
			active_definition.icon_atlas_index = library_copy.icon_atlas_index
			active_definition.relations = library_copy.relations.duplicate(true)
			active_definition.synonyms = library_copy.synonyms.duplicate()
			active_definition.example_queries = library_copy.example_queries.duplicate()
			active_definition.icon_resource_path = library_copy.icon_resource_path
			active_definition.illustration_resource_path = library_copy.illustration_resource_path
			result.append(active_definition)
		else:
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
	if definition.definition_schema_version < 1:
		errors.append("Версия схемы определения '%s' должна быть не меньше 1." % definition.capability_id)
	if definition.runtime_status not in ["Implemented", "Planned"]:
		errors.append("У возможности '%s' неизвестный runtime_status: %s." % [
			definition.capability_id,
			definition.runtime_status
		])
	if definition.kind_id.strip_edges().is_empty():
		errors.append("У возможности '%s' не указан kind_id." % definition.capability_id)
	if definition.execution_scope not in ["unclassified", "editor_only", "runtime", "hybrid", "data_only"]:
		errors.append("У возможности '%s' неизвестная область действия: %s." % [
			definition.capability_id,
			definition.execution_scope
		])
	if definition.implementation_type.strip_edges().is_empty():
		errors.append("У возможности '%s' не указан способ реализации." % definition.capability_id)
	if definition.readiness_status not in ["ready", "partial", "planned", "blocked", "error"]:
		errors.append("У возможности '%s' неизвестный readiness_status: %s." % [
			definition.capability_id,
			definition.readiness_status
		])

	var relation_keys: Dictionary = {}
	for relation in definition.relations:
		var relation_type := str(relation.get("type", "")).strip_edges().to_lower()
		var target_id := _normalize_id(str(relation.get("target_id", "")))
		var relation_key := relation_type + "@" + target_id
		if relation_type not in ["requires", "recommends", "extends", "alternative", "conflicts", "related"]:
			errors.append("У возможности '%s' неизвестный тип связи: %s." % [
				definition.capability_id,
				relation_type
			])
		if target_id.is_empty() or not candidate.has(target_id):
			errors.append("У возможности '%s' связь указывает на неизвестный ID: %s." % [
				definition.capability_id,
				target_id
			])
		if relation_keys.has(relation_key):
			errors.append("У возможности '%s' повторяется связь '%s'." % [
				definition.capability_id,
				relation_key
			])
		relation_keys[relation_key] = true
		if str(relation.get("explanation", "")).strip_edges().is_empty():
			errors.append("У связи '%s' → '%s' отсутствует объяснение." % [
				definition.capability_id,
				target_id
			])

	var component_ids: Dictionary = {}
	for component_id in definition.component_ids:
		var normalized_component_id := _normalize_id(str(component_id))
		if component_ids.has(normalized_component_id):
			errors.append("Возможность '%s' дважды добавляет компонент '%s'." % [definition.capability_id, normalized_component_id])
		component_ids[normalized_component_id] = true
		if not ObjectComponentCatalog.has_component(normalized_component_id):
			errors.append("Возможность '%s' ссылается на неизвестный компонент '%s'." % [definition.capability_id, normalized_component_id])

	var setting_schema_keys: Dictionary = {}
	for descriptor in definition.settings_schema:
		if descriptor.has("_duplicate_schema_key"):
			errors.append("В схеме возможности '%s' повторяется настройка '%s'." % [
				definition.capability_id,
				str(descriptor.get("_duplicate_schema_key", ""))
			])
			continue
		var forbidden_override_keys: Variant = descriptor.get("_forbidden_overlay_keys", [])
		if forbidden_override_keys is Array or forbidden_override_keys is PackedStringArray:
			for forbidden_key in forbidden_override_keys:
				errors.append(
					"Capability overlay возможности '%s' не может переопределять каноническое поле '%s'. Перенеси его в ObjectComponentDefinition."
					% [definition.capability_id, str(forbidden_key)]
				)
		var component_id := _normalize_id(str(descriptor.get("component_id", "")))
		var setting_key := str(descriptor.get("setting_key", descriptor.get("key", ""))).strip_edges()
		if component_id.is_empty() or setting_key.is_empty():
			errors.append("У схемы настроек возможности '%s' должен быть указан компонент и ключ настройки." % definition.capability_id)
			continue
		if not component_ids.has(component_id):
			errors.append("Схема возможности '%s' ссылается на компонент '%s', которым она не управляет." % [definition.capability_id, component_id])
			continue
		var schema_key := "%s@%s" % [component_id, setting_key]
		if setting_schema_keys.has(schema_key):
			errors.append("В схеме возможности '%s' повторяется настройка '%s'." % [definition.capability_id, schema_key])
			continue
		setting_schema_keys[schema_key] = true
		var component_definition := ObjectComponentCatalog.create_definition(component_id)
		if component_definition == null:
			continue
		var source_descriptor: Dictionary = {}
		for candidate_descriptor in component_definition.get_setting_definitions():
			if str(candidate_descriptor.get("key", "")) == setting_key:
				source_descriptor = candidate_descriptor
				break
		if source_descriptor.is_empty():
			errors.append("Возможность '%s' описывает неизвестную настройку '%s' компонента '%s'." % [definition.capability_id, setting_key, component_id])
			continue
		var declared_type := str(descriptor.get("value_type", source_descriptor.get("value_type", "")))
		var source_type := str(source_descriptor.get("value_type", ""))
		if declared_type != source_type:
			errors.append("Тип настройки '%s' возможности '%s' не совпадает с типом компонента '%s'." % [setting_key, definition.capability_id, component_id])
		var raw_level := str(descriptor.get("level", "")).strip_edges().to_lower()
		if not raw_level.is_empty() and raw_level not in ["basic", "advanced", "expert"]:
			errors.append("Неизвестный уровень настройки '%s' в возможности '%s': %s." % [
				setting_key,
				definition.capability_id,
				raw_level
			])
		if bool(descriptor.get("has_range", false)):
			if declared_type not in ["Integer", "Float"]:
				errors.append("Диапазон настройки '%s' поддерживается только для Integer и Float." % setting_key)
			else:
				var minimum := float(descriptor.get("minimum", 0.0))
				var maximum := float(descriptor.get("maximum", 0.0))
				if minimum > maximum:
					errors.append("Минимум больше максимума у настройки '%s'." % setting_key)
				var default_value: Variant = descriptor.get("default_value", source_descriptor.get("default_value"))
				if typeof(default_value) == TYPE_INT or typeof(default_value) == TYPE_FLOAT:
					if float(default_value) < minimum or float(default_value) > maximum:
						errors.append("Значение по умолчанию настройки '%s' выходит за её диапазон." % setting_key)
				if descriptor.has("step") and float(descriptor["step"]) <= 0.0:
					errors.append("Шаг настройки '%s' должен быть больше нуля." % setting_key)

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
			for incompatible_id in _get_conflicting_capability_ids(definition):
				var normalized_incompatible_id := _normalize_id(str(incompatible_id))
				var other := candidate.get(normalized_incompatible_id) as ObjectCapabilityDefinition
				if other == null:
					continue
				if not _get_conflicting_capability_ids(other).has(str(capability_id)):
					errors.append(
						"Конфликт между '%s' и '%s' должен быть указан с обеих сторон."
						% [str(capability_id), normalized_incompatible_id]
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
	for dependency_id in _get_required_capability_ids(definition):
		if not _visit_capability(_normalize_id(str(dependency_id)), candidate, states, errors):
			return false
	states[capability_id] = 2
	return true


static func _get_required_capability_ids(definition: ObjectCapabilityDefinition) -> PackedStringArray:
	var result := PackedStringArray()
	for dependency_id_value in definition.required_capability_ids:
		var dependency_id := _normalize_id(str(dependency_id_value))
		if not dependency_id.is_empty() and not result.has(dependency_id):
			result.append(dependency_id)
	for relation in definition.relations:
		if str(relation.get("type", "")).strip_edges().to_lower() != "requires":
			continue
		var dependency_id := _normalize_id(str(relation.get("target_id", "")))
		if not dependency_id.is_empty() and not result.has(dependency_id):
			result.append(dependency_id)
	return result


static func _get_conflicting_capability_ids(definition: ObjectCapabilityDefinition) -> PackedStringArray:
	var result := PackedStringArray()
	for conflict_id_value in definition.incompatible_capability_ids:
		var conflict_id := _normalize_id(str(conflict_id_value))
		if not conflict_id.is_empty() and not result.has(conflict_id):
			result.append(conflict_id)
	for relation in definition.relations:
		if str(relation.get("type", "")).strip_edges().to_lower() != "conflicts":
			continue
		var conflict_id := _normalize_id(str(relation.get("target_id", "")))
		if not conflict_id.is_empty() and not result.has(conflict_id):
			result.append(conflict_id)
	return result


static func _is_builtin_id(capability_id: String) -> bool:
	return capability_id in ["has_health", "can_receive_damage", "can_attack", "breaks_when_health_empty", "can_interact", "is_pickup_item"]


static func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return value[0] != "_" and value[value.length() - 1] != "_"
