extends SceneTree

const SceneDraftService = preload("res://addons/object_builder/services/scene_draft_service.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const PropertyScript = preload("res://scripts/object_system/object_property_definition.gd")

const CREATED_ID := "object_builder_scene_service_smoke_created"
const CLONED_ID := "object_builder_scene_service_smoke_cloned"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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

	var missing_source: ObjectDefinition = DefinitionScript.new()
	missing_source.object_id = "object_builder_scene_service_smoke_missing"
	var missing_result: Dictionary = SceneDraftService.clone_template_scene(missing_source, target_definition)
	_expect(not bool(missing_result.get("ok", true)), "missing template scene returns a handled failure")

	_cleanup_scene_file(created_definition.scene_path)
	_cleanup_scene_file(target_definition.scene_path)
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
