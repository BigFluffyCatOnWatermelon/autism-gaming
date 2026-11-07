@tool
extends RefCounted
class_name ObjectBuilderPreviewService
## Builds an isolated visual instance from the current editor draft without saving it.


const SceneStructureService = preload("res://scripts/object_system/object_scene_structure_service.gd")


static func create_preview_instance(
	definition: ObjectDefinition,
	edited_scene_root: Node = null
) -> Dictionary:
	if definition == null:
		return _failure("Определение объекта не передано.")

	var source_scene: PackedScene
	if edited_scene_root != null and is_instance_valid(edited_scene_root):
		source_scene = PackedScene.new()
		var pack_error := source_scene.pack(edited_scene_root)
		if pack_error != OK:
			return _failure("Не удалось скопировать открытую сцену. Код ошибки: %d" % pack_error)
	else:
		if not definition.scene_path.strip_edges().is_empty() and ResourceLoader.exists(definition.scene_path):
			source_scene = ResourceLoader.load(
				definition.scene_path,
				"",
				ResourceLoader.CACHE_MODE_REPLACE
			) as PackedScene
		if source_scene == null:
			source_scene = definition.scene

	var preview_root: Node
	if source_scene != null:
		preview_root = source_scene.instantiate()
	else:
		if not ClassDB.class_exists(definition.root_type):
			return _failure("Неизвестный тип корневого узла: " + definition.root_type)
		var created_object: Object = ClassDB.instantiate(definition.root_type)
		if not created_object is Node:
			return _failure("Не удалось создать корневой узел типа " + definition.root_type)
		preview_root = created_object as Node

	if preview_root == null:
		return _failure("Godot не смог создать копию сцены объекта.")

	var structure_result := SceneStructureService.apply_structure(definition, preview_root)
	if not bool(structure_result.get("ok", false)):
		preview_root.free()
		var errors: PackedStringArray = structure_result.get("errors", PackedStringArray())
		return _failure("; ".join(errors))

	if not definition.display_name.strip_edges().is_empty():
		preview_root.name = definition.display_name.validate_node_name()
	preview_root.set_meta("object_definition_id", definition.object_id)
	preview_root.set_meta("object_category", definition.category)

	return {
		"ok": true,
		"instance": preview_root,
		"message": ""
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"instance": null,
		"message": message
	}
