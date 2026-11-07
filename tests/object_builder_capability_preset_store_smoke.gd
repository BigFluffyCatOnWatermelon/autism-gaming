extends SceneTree

const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const StoreScript = preload("res://addons/object_builder/services/capability_preset_store.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	for error_message in MechanicModuleLoaderScript.register_modules_in_directory():
		failures.append("module registration: " + error_message)
	var store = StoreScript.new()
	store.storage_path = "user://object_builder_preset_store_smoke_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.storage_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.storage_path + ".tmp"))

	var custom := {
		"id": "my_resource_bundle",
		"display_name": "Мой ресурс",
		"description": "Мой пользовательский набор.",
		"capability_ids": ["has_health", "can_receive_damage"]
	}
	var saved: Dictionary = store.save_preset(custom)
	_expect(bool(saved.get("ok", false)), "valid custom preset is saved")
	var loaded: Array[Dictionary] = store.load_presets()
	_expect(loaded.size() == 1, "saved custom preset is loaded")
	_expect(loaded[0].get("capability_ids", []).size() == 2, "preset composition survives serialization")
	_expect(loaded[0].get("id", "") == "my_resource_bundle", "stable preset ID survives serialization")

	var updated := custom.duplicate(true)
	updated["display_name"] = "Обновлённый ресурс"
	updated["capability_ids"] = ["has_health"]
	var update_result: Dictionary = store.save_preset(updated)
	_expect(bool(update_result.get("ok", false)), "existing custom preset can be updated")
	_expect(store.load_presets().size() == 1, "updating does not create a duplicate")
	_expect(store.load_presets()[0].get("display_name", "") == "Обновлённый ресурс", "updated title is persisted")

	var builtin_override: Dictionary = store.save_preset({
		"id": "breakable_resource",
		"display_name": "Подмена",
		"capability_ids": ["has_health"]
	})
	_expect(not bool(builtin_override.get("ok", false)), "custom presets cannot overwrite built-in IDs")

	var unknown_capability: Dictionary = store.save_preset({
		"id": "unknown_mechanic_bundle",
		"display_name": "Неизвестная механика",
		"capability_ids": ["mechanic_that_does_not_exist"]
	})
	_expect(not bool(unknown_capability.get("ok", false)), "unknown capability IDs are rejected")

	var invalid_id: Dictionary = store.save_preset({
		"id": "../unsafe",
		"display_name": "Небезопасный ID",
		"capability_ids": ["has_health"]
	})
	_expect(not bool(invalid_id.get("ok", false)), "unsafe preset IDs are rejected")

	var duplicate: Dictionary = store.duplicate_preset(
		"breakable_resource",
		"my_breakable_copy",
		"Копия разрушаемого ресурса"
	)
	_expect(bool(duplicate.get("ok", false)), "built-in presets can be copied into user presets")
	_expect(store.load_presets().size() == 2, "duplicating a built-in creates a separate custom preset")

	var deleted: Dictionary = store.delete_preset("my_resource_bundle")
	_expect(bool(deleted.get("ok", false)), "custom preset can be deleted")
	_expect(store.load_presets().size() == 1, "deletion leaves other custom presets intact")
	_expect(not bool(store.delete_preset("missing_preset").get("ok", false)), "deleting a missing preset reports a safe error")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.storage_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.storage_path + ".tmp"))
	if failures.is_empty():
		print("Object Builder custom preset store tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("Object Builder custom preset store: " + failure)
	quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
