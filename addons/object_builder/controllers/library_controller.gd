@tool
extends RefCounted
## Owns object-library data, filtering and local favorites/recent state.

const RECENT_LIMIT := 20
const CATEGORY_LABELS := {
	"Nature": "Природа",
	"Buildings": "Здания",
	"Items": "Предметы",
	"Equipment": "Экипировка",
	"Furniture": "Мебель",
	"Characters": "Персонажи",
	"Animals": "Животные",
	"Interactive": "Интерактивные",
	"Effects": "Эффекты",
	"Transport": "Транспорт",
	"Decorations": "Декорации",
	"Other": "Другое"
}

var definitions: Array[ObjectDefinition] = []
var templates: Array[ObjectDefinition] = []
var favorites := PackedStringArray()
var recent_ids := PackedStringArray()
var _visible_definitions: Array[ObjectDefinition] = []
var _definitions_by_id: Dictionary = {}
var _search_text_by_instance_id: Dictionary = {}


func load_library() -> void:
	set_library_data(ObjectLibraryService.load_definitions(), ObjectLibraryService.load_templates())


func load_templates() -> void:
	templates = ObjectLibraryService.load_templates()


func set_library_data(
	new_definitions: Array[ObjectDefinition],
	new_templates: Array[ObjectDefinition] = []
) -> void:
	definitions.clear()
	for definition in new_definitions:
		if definition != null:
			definitions.append(definition)
	definitions.sort_custom(func(a: ObjectDefinition, b: ObjectDefinition) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)
	templates.clear()
	for template_definition in new_templates:
		if template_definition != null:
			templates.append(template_definition)
	templates.sort_custom(func(a: ObjectDefinition, b: ObjectDefinition) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)
	_rebuild_indexes()


func set_local_state(favorites_value: Variant, recent_value: Variant) -> void:
	favorites = _to_packed_string_array(favorites_value)
	recent_ids = _to_packed_string_array(recent_value)


func get_favorites() -> PackedStringArray:
	return favorites.duplicate()


func get_recent_ids() -> PackedStringArray:
	return recent_ids.duplicate()


func get_definition_count() -> int:
	return definitions.size()


func get_template_count() -> int:
	return templates.size()


func get_template(index: int) -> ObjectDefinition:
	if index < 0 or index >= templates.size():
		return null
	return templates[index]


func get_template_names() -> Array[String]:
	var result: Array[String] = []
	for definition in templates:
		result.append(definition.display_name)
	return result


func get_visible_definition(index: int) -> ObjectDefinition:
	if index < 0 or index >= _visible_definitions.size():
		return null
	return _visible_definitions[index]


func get_category_options(_selected_value: String = "") -> Array[Dictionary]:
	var categories: Array[String] = []
	for category_key in CATEGORY_LABELS.keys():
		categories.append(str(category_key))
	for definition in definitions + templates:
		if not definition.category.is_empty() and not categories.has(definition.category):
			categories.append(definition.category)
	categories.sort()
	var options: Array[Dictionary] = []
	for category_name in categories:
		options.append({"id": category_name, "label": str(CATEGORY_LABELS.get(category_name, category_name))})
	return options


func get_tag_options(_selected_value: String = "") -> Array[Dictionary]:
	var tags := PackedStringArray()
	for definition in definitions + templates:
		for tag in definition.tags:
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
	tags.sort()
	var options: Array[Dictionary] = []
	for tag in tags:
		options.append({"id": tag, "label": "#" + tag})
	return options


func build_visible_entries(
	query: String,
	selected_category: String,
	selected_tag: String,
	selected_mode: String
) -> Array[Dictionary]:
	_visible_definitions.clear()
	var candidates: Array[ObjectDefinition] = []
	if selected_mode == "recent":
		for object_id in recent_ids:
			var recent_definition := find_definition(object_id)
			if recent_definition != null:
				candidates.append(recent_definition)
	elif selected_mode == "templates":
		candidates.assign(templates)
	else:
		for definition in definitions:
			if selected_mode == "favorites" and not is_favorite(definition.object_id):
				continue
			candidates.append(definition)

	var entries: Array[Dictionary] = []
	for definition in candidates:
		if not selected_category.is_empty() and definition.category != selected_category:
			continue
		if not selected_tag.is_empty() and not definition.tags.has(selected_tag):
			continue
		var searchable_text := str(_search_text_by_instance_id.get(definition.get_instance_id(), ""))
		var normalized_query := query.strip_edges().to_lower()
		if not normalized_query.is_empty() and not searchable_text.contains(normalized_query):
			continue
		_visible_definitions.append(definition)
		var title_prefix := "★ " if is_favorite(definition.object_id) else ""
		entries.append({
			"title": title_prefix + definition.display_name,
			"tooltip": "%s\nТип: %s\nID: %s\nТеги: %s" % [
				definition.description,
				get_object_type_display_name(definition.object_type),
				definition.object_id,
				join_tags(definition.tags)
			],
			"definition": definition
		})
	return entries


func find_definition(object_id: String) -> ObjectDefinition:
	return _definitions_by_id.get(object_id) as ObjectDefinition


func is_favorite(object_id: String) -> bool:
	return favorites.has(object_id)


func toggle_favorite(object_id: String) -> bool:
	if object_id.is_empty():
		return false
	if favorites.has(object_id):
		favorites.erase(object_id)
		return false
	favorites.append(object_id)
	return true


func remove_local_entry(object_id: String) -> void:
	if object_id.is_empty():
		return
	favorites.erase(object_id)
	recent_ids.erase(object_id)


func build_detail_data(definition: ObjectDefinition) -> Dictionary:
	if definition == null:
		return {}
	var capability_names := PackedStringArray()
	var dependency_names := PackedStringArray()
	for selection in definition.capabilities:
		if selection == null or not selection.enabled:
			continue
		var capability_id := selection.capability_id.strip_edges().to_lower()
		if capability_id.is_empty():
			continue
		var capability := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		var capability_name := capability.display_name if capability != null else capability_id
		if not capability_names.has(capability_name):
			capability_names.append(capability_name)
		if capability == null:
			continue
		for dependency_id in capability.required_capability_ids:
			var dependency := ObjectCapabilityCatalog.get_definition_reference(str(dependency_id))
			var dependency_name := dependency.display_name if dependency != null else str(dependency_id)
			var dependency_line := "%s → %s" % [capability_name, dependency_name]
			if not dependency_names.has(dependency_line):
				dependency_names.append(dependency_line)
	capability_names.sort()
	dependency_names.sort()
	return {
		"display_name": definition.display_name,
		"object_id": definition.object_id,
		"category": definition.category,
		"description": definition.description,
		"is_template": definition.is_template,
		"preview_texture": definition.preview_texture,
		"tags_text": join_tags(definition.tags) if not definition.tags.is_empty() else "Нет тегов.",
		"capabilities_text": "\n".join(capability_names) if not capability_names.is_empty() else "Пока не выбраны.",
		"dependencies_text": "\n".join(dependency_names) if not dependency_names.is_empty() else "Нет обязательных зависимостей."
	}


func record_recent(object_id: String) -> void:
	if object_id.is_empty():
		return
	recent_ids.erase(object_id)
	recent_ids.insert(0, object_id)
	while recent_ids.size() > RECENT_LIMIT:
		recent_ids.remove_at(recent_ids.size() - 1)


func join_tags(tags: PackedStringArray) -> String:
	return " ".join(tags)


func get_object_type_display_name(type_id: String) -> String:
	var profile_name := ObjectCreationProfileRegistry.get_display_name(type_id)
	if not profile_name.is_empty():
		return profile_name
	return "Другой объект" if type_id.strip_edges().is_empty() or type_id == "other" else type_id.capitalize()


func _rebuild_indexes() -> void:
	_definitions_by_id.clear()
	_search_text_by_instance_id.clear()
	for definition in definitions + templates:
		if not definition.is_template:
			_definitions_by_id[definition.object_id] = definition

		var searchable_parts := PackedStringArray([
			definition.display_name,
			definition.object_id,
			definition.description,
			definition.category,
			definition.object_type,
			join_tags(definition.tags)
		])
		for selection in definition.capabilities:
			if selection == null or not selection.enabled:
				continue
			var capability_id := selection.capability_id.strip_edges().to_lower()
			if capability_id.is_empty():
				continue
			searchable_parts.append(capability_id)
			var capability := ObjectCapabilityCatalog.get_definition_reference(capability_id)
			if capability == null:
				continue
			searchable_parts.append(capability.display_name)
			searchable_parts.append(capability.description)
			searchable_parts.append(" ".join(capability.keywords))
			for dependency_id in capability.required_capability_ids:
				var dependency := ObjectCapabilityCatalog.get_definition_reference(str(dependency_id))
				searchable_parts.append(str(dependency_id))
				if dependency != null:
					searchable_parts.append(dependency.display_name)
		for property_definition in definition.custom_properties:
			if property_definition == null:
				continue
			searchable_parts.append(property_definition.property_id)
			searchable_parts.append(property_definition.display_name)
			searchable_parts.append(property_definition.description)
		_search_text_by_instance_id[definition.get_instance_id()] = " ".join(searchable_parts).to_lower()


func _to_packed_string_array(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is PackedStringArray:
		return value.duplicate()
	if value is Array:
		for entry in value:
			if entry is String and not entry.is_empty() and not result.has(entry):
				result.append(entry)
	return result
