extends SceneTree

const CreationService = preload("res://addons/object_builder/services/object_creation_service.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const LibraryService = preload("res://scripts/object_system/object_library_service.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var empty_result: Dictionary = CreationService.create_empty_draft({
		"display_name": "Дуб",
		"category": "Nature",
		"description": "Лесное дерево",
		"tags": ["tree", "wood", "tree"]
	})
	_expect(bool(empty_result.get("ok", false)), "scratch workflow creates an object draft")
	var empty_definition := empty_result.get("definition") as ObjectDefinition
	_expect(empty_definition != null, "scratch workflow returns an ObjectDefinition")
	if empty_definition != null:
		_expect(empty_definition.display_name == "Дуб", "scratch workflow applies the display name")
		_expect(empty_definition.category == "Nature", "scratch workflow applies the selected category")
		_expect(empty_definition.tags == PackedStringArray(["tree", "wood"]), "scratch workflow normalizes and deduplicates tags")
		_expect(empty_definition.root_type == "Node2D", "scratch workflow defaults to a normal 2D object")
		_expect(empty_definition.scene == null and empty_definition.scene_path.is_empty(), "scratch workflow leaves the object as an unsaved draft")

	var source := DefinitionScript.new() as ObjectDefinition
	source.object_id = "object_builder_creation_source"
	source.display_name = "Исходник"
	source.category = "Nature"
	source.description = "Исходное описание"
	source.tags = PackedStringArray(["old"])
	source.scene = _make_source_scene()

	var duplicate_result: Dictionary = CreationService.create_from_source(source, {
		"display_name": "Мой дуб",
		"category": "Nature",
		"description": "Новая копия",
		"tags": PackedStringArray(["new", "tree"])
	})
	_expect(bool(duplicate_result.get("ok", false)), "copy workflow creates an independent object draft")
	var duplicate := duplicate_result.get("definition") as ObjectDefinition
	_expect(duplicate != null, "copy workflow returns a definition")
	if duplicate != null:
		_expect(duplicate.object_id != source.object_id, "copy workflow assigns a new object ID")
		_expect(duplicate.display_name == "Мой дуб", "copy workflow applies the requested name")
		_expect(duplicate.tags == PackedStringArray(["new", "tree"]), "copy workflow applies the requested tags")
		_expect(duplicate.scene_path != source.scene_path, "copy workflow uses an independent scene path")
		if duplicate.scene is PackedScene:
			var copy_root := duplicate.scene.instantiate()
			_expect(copy_root != null, "copy workflow scene can be instantiated")
			if copy_root != null:
				_expect(copy_root.get_node_or_null("UnknownPart/NestedMarker") is Marker2D, "copy workflow preserves unknown source nodes")
				copy_root.free()

	LibraryService.ensure_directories()
	var import_source_path := LibraryService.get_scene_path("object_builder_creation_import_source")
	_cleanup_scene_file(import_source_path)
	var import_source := _make_source_scene()
	var import_source_save_error := ResourceSaver.save(import_source, import_source_path)
	_expect(import_source_save_error == OK, "source scene for creation service import test is saved")
	var import_result: Dictionary = CreationService.import_scene_draft(import_source_path, {
		"display_name": "Импортированная сцена",
		"category": "Nature",
		"description": "Копия сцены",
		"tags": PackedStringArray(["imported"])
	})
	_expect(bool(import_result.get("ok", false)), "creation service imports a scene into an independent draft")
	var imported_definition := import_result.get("definition") as ObjectDefinition
	var import_report: Dictionary = import_result.get("import_report", {})
	_expect(imported_definition != null, "creation service import returns an object definition")
	_expect(int(import_report.get("visual_part_count", -1)) == 1, "creation service forwards visual part recognition report")
	_expect(int(import_report.get("advanced_node_count", 0)) >= 2, "creation service forwards advanced node preservation report")
	_expect(imported_definition != null and imported_definition.scene_path != import_source_path, "creation service import saves a separate scene path")
	_expect(FileAccess.file_exists(import_source_path), "creation service import preserves the original scene file")
	var missing_import: Dictionary = CreationService.import_scene_draft("", {})
	_expect(not bool(missing_import.get("ok", true)), "creation service rejects an empty import path")
	var invalid_result: Dictionary = CreationService.create_from_source(null, {})
	_expect(not bool(invalid_result.get("ok", true)), "copy workflow handles a missing source")

	if duplicate != null and not duplicate.scene_path.is_empty():
		_cleanup_scene_file(duplicate.scene_path)
	if imported_definition != null and not imported_definition.scene_path.is_empty():
		_cleanup_scene_file(imported_definition.scene_path)
	_cleanup_scene_file(import_source_path)
	await process_frame
	if failures.is_empty():
		print("Object Builder object creation service tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _make_source_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "SourceRoot"
	var part := Node2D.new()
	part.name = "UnknownPart"
	root.add_child(part)
	part.owner = root
	var visible_sprite := Sprite2D.new()
	visible_sprite.name = "VisibleSprite"
	root.add_child(visible_sprite)
	visible_sprite.owner = root
	var marker := Marker2D.new()
	marker.name = "NestedMarker"
	part.add_child(marker)
	marker.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _cleanup_scene_file(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
