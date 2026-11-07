@tool
extends RefCounted
class_name ObjectBuilderSceneDraftService
## Creates and copies PackedScene drafts without depending on EditorInterface.


static func create_scene(definition: ObjectDefinition) -> Dictionary:
	if definition == null:
		return _failure("Определение объекта не создано.")

	var created_object: Object = ClassDB.instantiate(definition.root_type)
	if not created_object is Node:
		return _failure("Не удалось создать корневой узел типа " + definition.root_type)

	var scene_root := created_object as Node
	scene_root.name = "Object"
	scene_root.set_meta("object_definition_id", definition.object_id)
	scene_root.set_meta("object_category", definition.category)

	var visuals := Node2D.new()
	visuals.name = "Visuals"
	scene_root.add_child(visuals)
	visuals.owner = scene_root

	var property_data := ObjectPropertyData.new()
	property_data.name = "ObjectProperties"
	scene_root.add_child(property_data)
	property_data.owner = scene_root
	property_data.configure(definition.custom_properties)

	return _pack_and_save(scene_root, definition)


static func clone_template_scene(
	template_definition: ObjectDefinition,
	target_definition: ObjectDefinition
) -> Dictionary:
	if template_definition == null or target_definition == null:
		return _failure("Не удалось определить шаблон или целевой объект.")

	var source_scene: PackedScene = template_definition.scene
	if not template_definition.scene_path.is_empty() and FileAccess.file_exists(template_definition.scene_path):
		var loaded_scene := ResourceLoader.load(
			template_definition.scene_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		)
		if loaded_scene is PackedScene:
			source_scene = loaded_scene as PackedScene
	if source_scene == null:
		return _failure("У шаблона нет сохранённой сцены для копирования.")

	var scene_root := source_scene.instantiate()
	if scene_root == null:
		return _failure("Не удалось создать экземпляр сцены шаблона.")
	scene_root.set_meta("object_definition_id", target_definition.object_id)
	scene_root.set_meta("object_category", target_definition.category)

	var property_data := scene_root.get_node_or_null("ObjectProperties") as ObjectPropertyData
	if property_data == null:
		property_data = ObjectPropertyData.new()
		property_data.name = "ObjectProperties"
		scene_root.add_child(property_data)
	property_data.configure(target_definition.custom_properties, {}, true)
	property_data.owner = scene_root

	return _pack_and_save(scene_root, target_definition)


static func import_scene(source_path: String, target_definition: ObjectDefinition) -> Dictionary:
	var clean_source_path := source_path.strip_edges()
	if clean_source_path.is_empty() or target_definition == null:
		return _failure("Не выбран файл сцены или не подготовлено определение объекта.")
	if clean_source_path.get_extension().to_lower() not in ["tscn", "scn"]:
		return _failure("Поддерживаются только сцены .tscn и .scn: " + clean_source_path)
	if not ResourceLoader.exists(clean_source_path):
		return _failure("Файл сцены не найден или недоступен Godot: " + clean_source_path)

	var loaded_resource := ResourceLoader.load(
		clean_source_path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	if loaded_resource == null:
		return _failure("Godot не смог загрузить сцену или один из её ресурсов: " + clean_source_path)
	if not loaded_resource is PackedScene:
		return _failure("Выбранный файл не является PackedScene: " + clean_source_path)

	var source_scene := loaded_resource as PackedScene
	var imported_root := source_scene.instantiate()
	if imported_root == null:
		return _failure("Не удалось создать временную копию сцены: " + clean_source_path)
	if not imported_root is Node2D:
		var unsupported_root_type := imported_root.get_class()
		imported_root.free()
		return _failure(
			"Для игрового 2D-объекта нужен корень Node2D или его наследник. "
			+ "В выбранной сцене корень %s: %s" % [unsupported_root_type, clean_source_path]
		)
	if imported_root.name.is_empty():
		imported_root.name = "Object"
	target_definition.root_type = imported_root.get_class()
	imported_root.set_meta("object_definition_id", target_definition.object_id)
	imported_root.set_meta("object_category", target_definition.category)

	var property_node := imported_root.find_child("ObjectProperties", true, false)
	if property_node != null and not property_node is ObjectPropertyData:
		imported_root.free()
		return _failure(
			"В импортируемой сцене уже есть узел ObjectProperties другого типа: "
			+ clean_source_path
		)
	var property_data := property_node as ObjectPropertyData
	if property_data == null:
		property_data = ObjectPropertyData.new()
		property_data.name = "ObjectProperties"
		imported_root.add_child(property_data)
		property_data.configure(target_definition.custom_properties, {}, true)
	else:
		if target_definition.custom_properties.is_empty():
			for existing_property in property_data.property_definitions:
				if existing_property != null:
					target_definition.custom_properties.append(
						existing_property.duplicate(true) as ObjectPropertyDefinition
					)
		if not target_definition.custom_properties.is_empty():
			property_data.configure(target_definition.custom_properties, {}, true)
	property_data.owner = imported_root

	return _pack_and_save(imported_root, target_definition)


static func clone_object_scene(
	source_definition: ObjectDefinition,
	target_definition: ObjectDefinition
) -> Dictionary:
	if source_definition == null or target_definition == null:
		return _failure("Не выбран исходный или целевой объект.")
	var has_scene := source_definition.scene != null or (
		not source_definition.scene_path.is_empty()
		and ResourceLoader.exists(source_definition.scene_path)
	)
	if has_scene:
		return clone_template_scene(source_definition, target_definition)
	return create_scene(target_definition)

static func _pack_and_save(scene_root: Node, definition: ObjectDefinition) -> Dictionary:
	if scene_root == null or definition == null:
		if scene_root != null:
			scene_root.free()
		return _failure("Не удалось подготовить сцену для сохранения.")

	_set_owner_recursive(scene_root, scene_root)
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(scene_root)
	scene_root.free()
	if pack_error != OK:
		return _failure("Не удалось собрать PackedScene. Код ошибки: %d" % pack_error)

	ObjectLibraryService.ensure_directories()
	var target_path := ObjectLibraryService.get_scene_path(definition.object_id)
	var save_error := ResourceSaver.save(packed_scene, target_path)
	if save_error != OK:
		return _failure("Не удалось сохранить сцену. Код ошибки: %d" % save_error)

	definition.scene = packed_scene
	definition.scene_path = target_path
	return {
		"ok": true,
		"scene": packed_scene,
		"scene_path": target_path,
		"message": ""
	}


static func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"scene": null,
		"scene_path": "",
		"message": message
	}
