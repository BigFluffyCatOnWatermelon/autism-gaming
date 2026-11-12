@tool
extends Node
class_name ObjectBuilderReference
## Persistent editor-facing identity for objects created by Object Builder.
## This node stores the link as exported properties so it survives PackedScene serialization.

@export var object_id: String = ""
@export var builder_uri: String = ""
@export var display_name: String = ""
@export var category: String = ""
@export_file("*.tres") var definition_path: String = ""

const ObjectFactoryScript = preload("res://scripts/object_system/object_factory.gd")
const ObjectLibraryServiceScript = preload("res://scripts/object_system/object_library_service.gd")


func configure(
	new_object_id: String,
	new_display_name: String,
	new_category: String,
	new_definition_path: String
) -> void:
	object_id = new_object_id
	builder_uri = "objectbuilder://object/" + new_object_id.uri_encode()
	display_name = new_display_name
	category = new_category
	definition_path = new_definition_path


func _ready() -> void:
	# Editor-placed Object Builder scenes are ordinary PackedScenes. When one
	# enters a running game, attach the same runtime components ObjectFactory
	# would attach if the object had been spawned through the registry.
	if Engine.is_editor_hint():
		return
	_initialize_runtime_instance()


func _initialize_runtime_instance() -> void:
	var object_root := get_parent()
	if object_root == null or not is_instance_valid(object_root):
		return
	if bool(object_root.get_meta("object_builder_runtime_components_ready", false)):
		return

	var resolved_path := definition_path.strip_edges()
	if resolved_path.is_empty() or not FileAccess.file_exists(resolved_path):
		resolved_path = ObjectLibraryServiceScript.find_definition_path(
			object_id,
			false,
			definition_path
		)
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		push_warning(
			"ObjectBuilderReference: не найдено определение для '%s' (%s)."
			% [object_id, display_name]
		)
		return

	var definition := ResourceLoader.load(
		resolved_path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	) as ObjectDefinition
	if definition == null:
		push_warning("ObjectBuilderReference: не удалось загрузить " + resolved_path)
		return
	if not ObjectFactoryScript.initialize_existing_instance(definition, object_root):
		push_error(
			"ObjectBuilderReference: не удалось подключить игровые механики объекта '%s'."
			% object_id
		)
