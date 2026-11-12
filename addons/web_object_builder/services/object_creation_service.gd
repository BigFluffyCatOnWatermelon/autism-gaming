@tool
extends RefCounted
## Builds unsaved object-definition drafts for the guided creation workflow.

const SceneDraftService = preload("res://addons/web_object_builder/services/scene_draft_service.gd")
const LibraryActionsService = preload("res://addons/web_object_builder/services/library_actions_service.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")


static func create_empty_draft(values: Dictionary, profile: Object = null) -> Dictionary:
	var definition := DefinitionScript.new() as ObjectDefinition
	definition.object_id = LibraryActionsService.create_unique_id("object", "new")
	definition.root_type = "Node2D"
	definition.object_type = "other"
	definition.category = "Other"
	if profile != null:
		definition.root_type = str(profile.get("suggested_root_type"))
		definition.object_type = str(profile.get("profile_id"))
		definition.category = str(profile.get("suggested_category"))
		for source_property in profile.get("suggested_properties"):
			if source_property != null:
				var property_copy := source_property.duplicate(true) as ObjectPropertyDefinition
				if property_copy != null:
					definition.custom_properties.append(property_copy)
	_apply_metadata(definition, values)
	return {"ok": true, "definition": definition, "message": ""}


static func create_from_source(source: ObjectDefinition, values: Dictionary) -> Dictionary:
	if source == null:
		return _failure("Исходный объект или шаблон не найден.")
	var definition := source.duplicate(true) as ObjectDefinition
	if definition == null:
		return _failure("Не удалось создать копию определения.")
	definition.object_id = LibraryActionsService.create_unique_id("object", source.object_id)
	definition.is_template = false
	definition.template_id = source.object_id if source.is_template else source.template_id
	definition.scene = null
	definition.scene_path = ""
	_apply_metadata(definition, values)

	var scene_result: Dictionary = SceneDraftService.clone_object_scene(source, definition)
	if not bool(scene_result.get("ok", false)):
		return _failure(str(scene_result.get("message", "Не удалось создать независимую копию сцены.")))
	return {"ok": true, "definition": definition, "message": ""}


static func import_scene_draft(source_path: String, values: Dictionary) -> Dictionary:
	if source_path.strip_edges().is_empty():
		return _failure("Сначала выбери файл сцены для импорта.")
	var definition := DefinitionScript.new() as ObjectDefinition
	definition.object_id = LibraryActionsService.create_unique_id("object", source_path.get_file().get_basename())
	definition.root_type = "Node2D"
	definition.object_type = "other"
	definition.category = "Other"
	_apply_metadata(definition, values)
	var import_result: Dictionary = SceneDraftService.import_scene(source_path, definition)
	if not bool(import_result.get("ok", false)):
		return _failure(str(import_result.get("message", "Не удалось импортировать сцену.")))
	return {
		"ok": true,
		"definition": definition,
		"import_report": import_result.get("import_report", {}),
		"message": ""
	}


static func _apply_metadata(definition: ObjectDefinition, values: Dictionary) -> void:
	if definition == null:
		return
	var display_name := str(values.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		definition.display_name = display_name
	var category := str(values.get("category", "")).strip_edges()
	if not category.is_empty():
		definition.category = category
	definition.description = str(values.get("description", definition.description)).strip_edges()
	var raw_tags: Variant = values.get("tags", definition.tags)
	var tags := PackedStringArray()
	if raw_tags is PackedStringArray or raw_tags is Array:
		for raw_tag in raw_tags:
			var tag := str(raw_tag).strip_edges()
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
	definition.tags = tags


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "definition": null, "message": message}
