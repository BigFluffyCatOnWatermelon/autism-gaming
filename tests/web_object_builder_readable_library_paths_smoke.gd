extends SceneTree

const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const ObjectLibraryService = preload("res://scripts/object_system/object_library_service.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pine := DefinitionScript.new() as ObjectDefinition
	pine.object_id = "object_builtin_tpl_023_383510412"
	pine.display_name = "Сосна"
	pine.category = "Nature"

	_expect(
		ObjectLibraryService.get_definition_path_for_definition(pine)
			.ends_with("/objects/nature/sosna.tres"),
		"ObjectDefinition uses a readable ASCII filename derived from its display name"
	)
	_expect(
		ObjectLibraryService.get_scene_path_for_definition(pine)
			.ends_with("/scenes/objects/nature/sosna.tscn"),
		"PackedScene uses a readable ASCII filename instead of the generated object ID"
	)

	var wood := DefinitionScript.new() as ObjectDefinition
	wood.object_id = "object_manual_wood_987654321"
	wood.display_name = "Древесина"
	wood.category = "Resources"
	_expect(
		ObjectLibraryService.get_scene_path_for_definition(wood)
			.ends_with("/scenes/objects/resources/drevesina.tscn"),
		"Russian material names are transliterated to stable ASCII filenames"
	)

	var custom := DefinitionScript.new() as ObjectDefinition
	custom.object_id = "object_custom_123"
	custom.display_name = "Пень (сосны)"
	custom.category = "Nature"
	_expect(
		ObjectLibraryService.get_scene_path_for_definition(custom)
			.ends_with("/scenes/objects/nature/pen_sosny.tscn"),
		"punctuation and whitespace are normalized without leaving unsafe path characters"
	)

	_expect(
		ObjectLibraryService.is_managed_scene_path(
			"res://data/object_library/scenes/objects/nature/sosna.tscn"
		),
		"readable object scene paths remain managed by the library"
	)

	if failures.is_empty():
		print("Web Object Builder readable library path tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
