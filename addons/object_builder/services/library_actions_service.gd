@tool
extends RefCounted
## Safe library operations kept outside the main editor coordinator.

const TRASH_PATH := "user://object_builder_trash"


static func duplicate_definition(source: ObjectDefinition) -> Dictionary:
	return _copy_definition(source, false)


static func create_template(source: ObjectDefinition) -> Dictionary:
	if source == null:
		return _failure("Не выбран объект для создания шаблона.")
	if source.is_template:
		return _failure("Выбранная запись уже является шаблоном.")
	return _copy_definition(source, true)


static func rename_definition(definition: ObjectDefinition, requested_name: String) -> Dictionary:
	if definition == null:
		return _failure("Объект не выбран.")
	var next_name := requested_name.strip_edges()
	if next_name.is_empty():
		return _failure("Название не может быть пустым.")
	if definition.display_name == next_name:
		return {"ok": true, "definition": definition, "message": "Название не изменилось."}

	var previous_name := definition.display_name
	definition.display_name = next_name
	var save_error := (
		ObjectLibraryService.save_template(definition)
		if definition.is_template
		else ObjectLibraryService.save_definition(definition)
	)
	if save_error != OK:
		definition.display_name = previous_name
		return _failure("Не удалось переименовать запись. Код ошибки: %d" % save_error)
	return {"ok": true, "definition": definition, "message": "Запись переименована."}


static func delete_definition(definition: ObjectDefinition) -> Dictionary:
	if definition == null:
		return _failure("Объект не выбран.")
	var source_path := _get_definition_path(definition)
	if not FileAccess.file_exists(source_path):
		return _failure("Файл записи не найден: " + source_path)

	var backup_base := _build_backup_base(definition)
	var backup_definition := backup_base + ".tres"
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(backup_definition)
	)
	if copy_error != OK:
		return _failure("Не удалось создать резервную копию записи. Удаление отменено.")

	var scene_path := definition.scene_path
	var backup_scene := ""
	var managed_scene := (
		not scene_path.is_empty()
		and scene_path.begins_with(ObjectLibraryService.SCENES_PATH + "/")
		and FileAccess.file_exists(scene_path)
	)
	var scene_shared := managed_scene and _is_scene_referenced_by_other_definition(definition, scene_path)
	if managed_scene and not scene_shared:
		backup_scene = backup_base + ".tscn"
		copy_error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(scene_path),
			ProjectSettings.globalize_path(backup_scene)
		)
		if copy_error != OK:
			return _failure("Не удалось создать резервную копию сцены. Удаление отменено.")

	if managed_scene and not scene_shared:
		var remove_scene_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path))
		if remove_scene_error != OK:
			return _failure("Не удалось удалить сцену. Запись библиотеки сохранена.")

	var remove_definition_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))
	if remove_definition_error != OK:
		if managed_scene and not scene_shared:
			DirAccess.copy_absolute(
				ProjectSettings.globalize_path(backup_scene),
				ProjectSettings.globalize_path(scene_path)
			)
		return _failure("Не удалось удалить файл записи. Исходная сцена восстановлена.")

	return {
		"ok": true,
		"message": "Запись удалена. %s" % ("Общая сцена оставлена без изменений." if scene_shared else "Резервная копия сохранена в %s." % TRASH_PATH),
		"backup_path": backup_definition,
		"scene_backup_path": backup_scene
	}


static func export_definition(definition: ObjectDefinition, target_path: String) -> Error:
	if definition == null or target_path.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var export_copy := definition.duplicate(true) as ObjectDefinition
	if export_copy == null:
		return ERR_CANT_CREATE
	return ResourceSaver.save(export_copy, target_path)


static func create_unique_id(prefix: String, source_id: String, is_template: bool = false) -> String:
	var clean_prefix := prefix.strip_edges().to_lower()
	var clean_source := source_id.strip_edges().validate_filename().to_lower().replace(" ", "_")
	if clean_prefix.is_empty():
		clean_prefix = "object"
	if clean_source.is_empty():
		clean_source = "item"
	var base_id := "%s_%s_%d" % [clean_prefix, clean_source, Time.get_ticks_usec()]
	var candidate := base_id
	var suffix := 2
	while _definition_exists(candidate, is_template) or FileAccess.file_exists(ObjectLibraryService.get_scene_path(candidate)):
		candidate = base_id + "_" + str(suffix)
		suffix += 1
	return candidate


static func _copy_definition(source: ObjectDefinition, as_template: bool) -> Dictionary:
	if source == null:
		return _failure("Объект для копирования не выбран.")

	var prefix := "template" if as_template else "object"
	var target := source.duplicate(true) as ObjectDefinition
	if target == null:
		return _failure("Не удалось создать копию определения.")
	target.object_id = create_unique_id(prefix, source.object_id, as_template)
	target.display_name = source.display_name + (" — шаблон" if as_template else " — копия")
	target.is_template = as_template
	target.template_id = source.object_id if source.is_template or as_template else ""
	target.scene = null
	target.scene_path = ""

	var has_source_scene := source.scene != null or (
		not source.scene_path.is_empty() and FileAccess.file_exists(source.scene_path)
	)
	if has_source_scene:
		var scene_result: Dictionary = ObjectBuilderSceneDraftService.clone_template_scene(source, target)
		if not bool(scene_result.get("ok", false)):
			return _failure(str(scene_result.get("message", "Не удалось скопировать сцену.")))

	var save_error := (
		ObjectLibraryService.save_template(target)
		if as_template
		else ObjectLibraryService.save_definition(target)
	)
	if save_error != OK:
		_cleanup_generated_scene(target)
		return _failure("Не удалось сохранить копию. Код ошибки: %d" % save_error)
	return {"ok": true, "definition": target, "message": "Копия сохранена в библиотеку."}


static func _is_scene_referenced_by_other_definition(
	deleted_definition: ObjectDefinition,
	scene_path: String
) -> bool:
	for candidate in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
		if candidate == null or _get_definition_path(candidate) == _get_definition_path(deleted_definition):
			continue
		if candidate.scene_path == scene_path:
			return true
	return false


static func _get_definition_path(definition: ObjectDefinition) -> String:
	var directory_path := ObjectLibraryService.TEMPLATES_PATH if definition.is_template else ObjectLibraryService.OBJECTS_PATH
	return directory_path.path_join(definition.object_id.strip_edges().validate_filename().replace(".", "_") + ".tres")


static func _definition_exists(object_id: String, is_template: bool) -> bool:
	var directory_path := ObjectLibraryService.TEMPLATES_PATH if is_template else ObjectLibraryService.OBJECTS_PATH
	var resource_path := directory_path.path_join(object_id.validate_filename().replace(".", "_") + ".tres")
	return FileAccess.file_exists(resource_path)


static func _build_backup_base(definition: ObjectDefinition) -> String:
	var directory_path := ProjectSettings.globalize_path(TRASH_PATH)
	DirAccess.make_dir_recursive_absolute(directory_path)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var object_id := definition.object_id.validate_filename()
	var base_name := "%s_%s" % [stamp, object_id]
	var candidate := TRASH_PATH.path_join(base_name)
	var suffix := 2
	while FileAccess.file_exists(candidate + ".tres"):
		candidate = TRASH_PATH.path_join(base_name + "_" + str(suffix))
		suffix += 1
	return candidate


static func _cleanup_generated_scene(definition: ObjectDefinition) -> void:
	if definition == null or definition.scene_path.is_empty():
		return
	if definition.scene_path.begins_with(ObjectLibraryService.SCENES_PATH + "/"):
		if FileAccess.file_exists(definition.scene_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(definition.scene_path))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "definition": null, "message": message}
