@tool
extends RefCounted
class_name WebObjectBuilderLibraryDragService

const ObjectLibraryService = preload("res://scripts/object_system/object_library_service.gd")
const SceneDraftService = preload("res://addons/web_object_builder/services/scene_draft_service.gd")


## Returns a real PackedScene path ready for Godot's native "files" drag contract.
## If a legacy record has no current scene, create it before starting the drag.
static func get_scene_path(definition: ObjectDefinition) -> String:
	if definition == null or definition.is_template:
		return ""
	var expected_path := ObjectLibraryService.get_scene_path_for_definition(definition)
	if definition.scene_path == expected_path and FileAccess.file_exists(expected_path):
		return expected_path

	var previous_scene_path := definition.scene_path
	var previous_scene_resource := definition.scene
	var previous_scene_bytes := (
		FileAccess.get_file_as_bytes(previous_scene_path)
		if not previous_scene_path.is_empty() and FileAccess.file_exists(previous_scene_path)
		else PackedByteArray()
	)
	var target_scene_bytes := (
		FileAccess.get_file_as_bytes(expected_path)
		if FileAccess.file_exists(expected_path)
		else PackedByteArray()
	)
	var had_target_scene := FileAccess.file_exists(expected_path)

	var scene_result := SceneDraftService.sync_scene(definition)
	if not bool(scene_result.get("ok", false)):
		push_warning(
			"Object Builder: не удалось подготовить сцену для размещения: "
			+ str(scene_result.get("message", ""))
		)
		return ""

	var save_error := ObjectLibraryService.save_definition(definition)
	if save_error != OK:
		ObjectLibraryService.remove_scene_if_unreferenced(definition.scene_path, definition.object_id)
		if not previous_scene_path.is_empty() and not previous_scene_bytes.is_empty():
			_restore_file(previous_scene_path, previous_scene_bytes)
		if had_target_scene:
			_restore_file(expected_path, target_scene_bytes)
		elif FileAccess.file_exists(expected_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(expected_path))
		definition.scene_path = previous_scene_path
		definition.scene = previous_scene_resource
		push_warning(
			"Object Builder: сцена подготовлена, но запись библиотеки сохранить не удалось (код %d)."
			% save_error
		)
		return ""

	EditorInterface.get_resource_filesystem().scan()
	return definition.scene_path if FileAccess.file_exists(definition.scene_path) else ""


static func _restore_file(path: String, bytes: PackedByteArray) -> void:
	if path.is_empty() or bytes.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()
