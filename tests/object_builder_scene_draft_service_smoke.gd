extends SceneTree

const SceneDraftService = preload("res://addons/object_builder/services/scene_draft_service.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const PropertyScript = preload("res://scripts/object_system/object_property_definition.gd")

const CREATED_ID := "object_builder_scene_service_smoke_created"
const CLONED_ID := "object_builder_scene_service_smoke_cloned"
const IMPORT_SOURCE_ID := "object_builder_scene_service_smoke_import_source"
const IMPORTED_ID := "object_builder_scene_service_smoke_imported"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ObjectLibraryService.ensure_directories()
	for test_id in [CREATED_ID, CLONED_ID, IMPORTED_ID, IMPORT_SOURCE_ID]:
		_cleanup_scene_file(ObjectLibraryService.get_scene_path(test_id))
	var created_definition: ObjectDefinition = DefinitionScript.new()
	created_definition.object_id = CREATED_ID
	created_definition.display_name = "Scene service test"
	created_definition.category = "Tests"
	created_definition.object_type = "other"
	created_definition.root_type = "Node2D"
	created_definition.custom_properties.append(_make_test_property("health", "Здоровье", 75))

	var create_result: Dictionary = SceneDraftService.create_scene(created_definition)
	_expect(bool(create_result.get("ok", false)), "empty object scene can be created and saved")
	_expect(created_definition.scene is PackedScene, "created definition receives its PackedScene")
	_expect(created_definition.scene_path.ends_with(CREATED_ID + ".tscn"), "created scene path follows object ID")

	if created_definition.scene is PackedScene:
		var created_root := (created_definition.scene as PackedScene).instantiate()
		_expect(created_root != null, "created scene can be instantiated")
		if created_root != null:
			_expect(created_root.name == "Object", "created root keeps the standard name")
			_expect(created_root.get_meta("object_definition_id", "") == CREATED_ID, "created root stores the definition ID")
			_expect(created_root.get_node_or_null("Visuals") is Node2D, "created scene contains the Visuals node")
			var created_data := created_root.get_node_or_null("ObjectProperties") as ObjectPropertyData
			_expect(created_data != null, "created scene contains ObjectPropertyData")
			if created_data != null:
				_expect(created_data.get_custom_property("health", -1) == 75, "created scene gets property defaults")
			created_root.free()

	var template_definition: ObjectDefinition = DefinitionScript.new()
	template_definition.object_id = "object_builder_scene_service_smoke_template"
	template_definition.display_name = "Template source"
	template_definition.scene = _make_template_scene()
	var target_definition: ObjectDefinition = DefinitionScript.new()
	target_definition.object_id = CLONED_ID
	target_definition.display_name = "Template copy"
	target_definition.category = "Tests"
	target_definition.object_type = "other"
	target_definition.root_type = "Node2D"
	target_definition.custom_properties.append(_make_test_property("mana", "Мана", 33))

	var clone_result: Dictionary = SceneDraftService.clone_template_scene(
		template_definition,
		target_definition
	)
	_expect(bool(clone_result.get("ok", false)), "template scene can be copied and saved")
	_expect(target_definition.scene is PackedScene, "cloned definition receives its PackedScene")
	if target_definition.scene is PackedScene:
		var cloned_root := (target_definition.scene as PackedScene).instantiate()
		_expect(cloned_root != null, "cloned scene can be instantiated")
		if cloned_root != null:
			_expect(cloned_root.get_node_or_null("TemplateVisual") is Sprite2D, "cloning preserves template nodes")
			_expect(cloned_root.get_meta("object_definition_id", "") == CLONED_ID, "cloned root receives the target ID")
			var cloned_data := cloned_root.get_node_or_null("ObjectProperties") as ObjectPropertyData
			_expect(cloned_data != null, "cloned scene contains ObjectPropertyData")
			if cloned_data != null:
				_expect(cloned_data.get_custom_property("mana", -1) == 33, "cloned scene receives target property defaults")
			cloned_root.free()

	var import_source_path := ObjectLibraryService.get_scene_path(IMPORT_SOURCE_ID)
	ObjectLibraryService.ensure_directories()
	var source_scene := _make_import_source_scene()
	var source_save_error := ResourceSaver.save(source_scene, import_source_path)
	_expect(source_save_error == OK, "source PackedScene is saved for the import test")

	var imported_definition: ObjectDefinition = DefinitionScript.new()
	imported_definition.object_id = IMPORTED_ID
	imported_definition.display_name = "Imported prototype"
	imported_definition.category = "Tests"
	imported_definition.object_type = "other"
	var import_result: Dictionary = SceneDraftService.import_scene(import_source_path, imported_definition)
	_expect(bool(import_result.get("ok", false)), "existing PackedScene can be imported as a separate object")
	var import_report: Dictionary = import_result.get("import_report", {})
	_expect(int(import_report.get("visual_part_count", -1)) == 1, "import report counts parts supported by the simple visual editor")
	_expect(int(import_report.get("advanced_node_count", 0)) >= 5, "import report counts additional nodes preserved for the advanced editor")
	var visual_paths: Array = import_report.get("visual_part_paths", [])
	var advanced_paths: Array = import_report.get("advanced_node_paths", [])
	_expect(visual_paths.has("VisibleSprite (Sprite2D)"), "import report identifies supported visual parts by path")
	_expect(advanced_paths.has("UnknownRootChild/NestedUnknown (Marker2D)"), "import report identifies preserved advanced nodes by path")
	_expect(imported_definition.scene_path != import_source_path, "imported scene is stored at a new path")
	_expect(imported_definition.root_type == "Node2D", "imported root type is detected from the source scene")
	_expect(FileAccess.file_exists(import_source_path), "import keeps the original scene file on disk")
	if imported_definition.scene is PackedScene:
		var imported_root := imported_definition.scene.instantiate()
		_expect(imported_root != null, "imported scene can be instantiated")
		if imported_root != null:
			_expect(imported_root.name == "ImportedPrototype", "import preserves the source root name")
			_expect(imported_root.get_node_or_null("UnknownRootChild/NestedUnknown") is Marker2D, "import preserves unknown nested nodes")
			var imported_collision := imported_root.get_node_or_null("UnknownCollision/CollisionShape2D") as CollisionShape2D
			_expect(imported_collision != null, "import preserves collision nodes")
			if imported_collision != null:
				_expect(imported_collision.shape is CircleShape2D, "import preserves embedded collision shape resources")
			var imported_marker := imported_root.get_node_or_null("UnknownRootChild/NestedUnknown") as Marker2D
			_expect(imported_marker != null and imported_marker.get_script() != null, "import preserves scripts attached to unknown nodes")
			if imported_marker != null and imported_marker.get_script() != null:
				_expect(int(imported_marker.get("preserved_marker_value")) == 73, "import preserves custom script properties")
			_expect(imported_root.get_meta("object_definition_id", "") == IMPORTED_ID, "import assigns the new definition ID to the copy")
			_expect(imported_root.get_meta("object_category", "") == "Tests", "import assigns the selected category to the copy")
			var imported_data := imported_root.get_node_or_null("ObjectProperties") as ObjectPropertyData
			_expect(imported_data != null, "import preserves an existing ObjectPropertyData node")
			if imported_data != null:
				_expect(imported_data.get_custom_property("legacy_value", -1) == 29, "import preserves existing custom property values")
				_expect(imported_data.get_custom_property_definition("legacy_value") != null, "import preserves existing custom property definitions")
			_expect(imported_definition.custom_properties.size() == 1, "import copies existing custom property definitions into the ObjectDefinition")
			imported_root.free()

	var reloaded_source := ResourceLoader.load(import_source_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	_expect(reloaded_source != null, "original source scene remains readable after import")
	if reloaded_source != null:
		var source_root := reloaded_source.instantiate()
		_expect(source_root != null, "original source scene remains instantiable after import")
		if source_root != null:
			_expect(source_root.name == "ImportedPrototype", "original root name remains unchanged")
			_expect(source_root.get_meta("source_marker", "") == "original", "original metadata remains unchanged")
			_expect(not source_root.has_meta("object_definition_id"), "import metadata never leaks back into the source scene")
			_expect(source_root.get_node_or_null("UnknownRootChild/NestedUnknown") is Marker2D, "original nested nodes remain unchanged")
			source_root.free()

	var unsupported_result: Dictionary = SceneDraftService.import_scene(import_source_path.get_basename() + ".txt", imported_definition)
	_expect(not bool(unsupported_result.get("ok", true)), "unsupported import extensions return a handled failure")

	var missing_source: ObjectDefinition = DefinitionScript.new()
	missing_source.object_id = "object_builder_scene_service_smoke_missing"
	var missing_result: Dictionary = SceneDraftService.clone_template_scene(missing_source, target_definition)
	_expect(not bool(missing_result.get("ok", true)), "missing template scene returns a handled failure")
	_expect(not bool(SceneDraftService.import_scene("res://missing_import_scene.tscn", imported_definition).get("ok", true)), "missing import path returns a handled failure")

	_cleanup_scene_file(created_definition.scene_path)
	_cleanup_scene_file(target_definition.scene_path)
	_cleanup_scene_file(imported_definition.scene_path)
	_cleanup_scene_file(import_source_path)
	await process_frame
	if failures.is_empty():
		print("Object Builder scene draft service tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _make_test_property(property_id: String, display_name: String, default_value: int) -> ObjectPropertyDefinition:
	var definition: ObjectPropertyDefinition = PropertyScript.new()
	definition.property_id = property_id
	definition.display_name = display_name
	definition.value_type = "Integer"
	definition.default_value = default_value
	return definition


func _make_import_source_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "ImportedPrototype"
	root.set_meta("source_marker", "original")

	var unknown_parent := Node2D.new()
	unknown_parent.name = "UnknownRootChild"
	root.add_child(unknown_parent)
	unknown_parent.owner = root
	var unknown_marker := Marker2D.new()
	unknown_marker.name = "NestedUnknown"
	var unknown_script := GDScript.new()
	unknown_script.source_code = "extends Marker2D\n@export var preserved_marker_value: int = 73\n"
	var script_error := unknown_script.reload()
	_expect(script_error == OK, "unknown node fixture script compiles")
	if script_error == OK:
		unknown_marker.set_script(unknown_script)
	unknown_parent.add_child(unknown_marker)
	unknown_marker.owner = root

	var visible_sprite := Sprite2D.new()
	visible_sprite.name = "VisibleSprite"
	root.add_child(visible_sprite)
	visible_sprite.owner = root

	var property_data := ObjectPropertyData.new()
	property_data.name = "ObjectProperties"
	property_data.property_definitions.append(_make_test_property("legacy_value", "Сохранённое свойство", 12))
	property_data.stored_values["legacy_value"] = 29
	root.add_child(property_data)
	property_data.owner = root

	var unknown_body := StaticBody2D.new()
	unknown_body.name = "UnknownCollision"
	root.add_child(unknown_body)
	unknown_body.owner = root
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = CircleShape2D.new()
	unknown_body.add_child(collision)
	collision.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _make_template_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "Template"
	var sprite := Sprite2D.new()
	sprite.name = "TemplateVisual"
	root.add_child(sprite)
	sprite.owner = root
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
