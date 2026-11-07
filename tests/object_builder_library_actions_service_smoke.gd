extends SceneTree

const ActionsService = preload("res://addons/object_builder/services/library_actions_service.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var first_id := str(ActionsService.create_unique_id("object", "tree oak"))
	var second_id := str(ActionsService.create_unique_id("object", "tree oak"))
	_expect(first_id.begins_with("object_tree_oak_"), "generated object IDs replace spaces and remain readable")
	_expect(first_id != second_id, "rapid duplicate operations receive independent IDs")
	_expect(not first_id.contains(" "), "generated object IDs never contain spaces")
	_expect(not bool(ActionsService.duplicate_definition(null).get("ok", false)), "duplicate rejects a missing source")
	_expect(not bool(ActionsService.create_template(null).get("ok", false)), "template creation rejects a missing source")
	_expect(not bool(ActionsService.delete_definition(null).get("ok", false)), "delete rejects a missing source")
	_expect(ActionsService.export_definition(null, "") == ERR_INVALID_PARAMETER, "export rejects missing data and path")

	var definition = DefinitionScript.new()
	definition.object_id = "test_library_action"
	definition.display_name = "Test"
	var rename_result: Dictionary = ActionsService.rename_definition(definition, "   ")
	_expect(not bool(rename_result.get("ok", false)), "rename rejects an empty title")
	_expect(definition.display_name == "Test", "failed rename leaves the source unchanged")

	if failures.is_empty():
		print("Object Builder library action service tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
