extends SceneTree

const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const PresetRegistryScript = preload("res://addons/object_builder/services/capability_preset_registry.gd")
const ControllerScript = preload("res://addons/object_builder/controllers/capability_catalog_controller.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)

	_test_preset_registry()
	_test_preset_preview_and_selection()
	_test_installed_and_selected_states()
	_test_custom_preset_management()

	if failures.is_empty():
		print("Object Builder capability preset tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error("Object Builder capability presets: " + failure)
	quit(1)


func _test_preset_registry() -> void:
	var presets := PresetRegistryScript.get_presets()
	_expect(presets.size() == 6, "catalog has six curated starting presets")
	_expect(PresetRegistryScript.validate_registry().is_empty(), "preset registry references only existing ready capabilities")

	var preset_ids: Dictionary = {}
	for preset in presets:
		var preset_id := str(preset.get("id", ""))
		_expect(not preset_id.is_empty() and not preset_ids.has(preset_id), "preset IDs are unique")
		preset_ids[preset_id] = true
		_expect(not str(preset.get("display_name", "")).is_empty(), "every preset has a readable title")
		_expect(not str(preset.get("description", "")).is_empty(), "every preset explains its result")
		_expect(not (preset.get("capability_ids", []) as Array).is_empty(), "every preset contains at least one capability")

	var resource_bundle := PresetRegistryScript.get_preset("breakable_resource")
	_expect(
		resource_bundle.get("capability_ids", []).has("breaks_when_health_empty"),
		"breakable resource preset includes its destruction behavior"
	)
	_expect(
		resource_bundle.get("capability_ids", []).has("drops_loot_on_destroy"),
		"breakable resource preset includes a result after destruction"
	)
	_expect(
		PresetRegistryScript.get_preset("unknown_preset").is_empty(),
		"unknown preset IDs return no invented bundle"
	)


func _test_preset_preview_and_selection() -> void:
	var controller = ControllerScript.new()
	var no_current_selections: Array[ObjectCapabilitySelection] = []
	controller.call("set_active_preset", "breakable_resource")

	var summaries: Array[Dictionary] = controller.call("build_preset_summaries")
	_expect(summaries.size() == 6, "controller exposes every curated preset to the catalog")
	var details: Dictionary = controller.call(
		"build_active_preset_details",
		no_current_selections
	)
	_expect(
		str(details.get("id", "")) == "breakable_resource",
		"active preset preview retains the selected preset ID"
	)
	var entries: Array = details.get("entries", [])
	_expect(entries.size() == 6, "preset preview exposes every item for individual editing")
	_expect(int(details.get("available_count", 0)) > 0, "ready compatible preset items can be selected")

	var health_entry := _find_entry(entries, "has_health")
	_expect(not health_entry.is_empty(), "preset preview contains Health")
	_expect(
		bool(health_entry.get("can_select", false)),
		"Health is marked as selectable before applying the preset"
	)
	_expect(
		not bool(health_entry.get("installed", false)),
		"preview item is not reported as installed in the object"
	)

	var object_before := no_current_selections.size()
	var added_count := int(controller.call(
		"select_all_available_from_active_preset",
		no_current_selections
	))
	_expect(added_count > 0, "preset action marks its available capabilities in the shared selection session")
	_expect(no_current_selections.size() == object_before, "selecting a preset does not modify the object")
	_expect(
		int(controller.call("get_selected_count")) == added_count,
		"preset selection is stored in the same global multi-selection session"
	)
	var after_details: Dictionary = controller.call(
		"build_active_preset_details",
		no_current_selections
	)
	_expect(
		int(after_details.get("selected_count", 0)) == added_count,
		"preset preview distinguishes selected items from installed items"
	)
	_expect(
		int(after_details.get("installed_count", 0)) == 0,
		"selected preset items are not counted as installed"
	)
	_expect(
		int(after_details.get("available_count", 0)) <= int(details.get("available_count", 0)),
		"available count decreases after marking preset items"
	)

	controller.call("set_active_preset", "")
	_expect(
		(controller.call("build_active_preset_details", no_current_selections) as Dictionary).is_empty(),
		"closing the preset clears only the active preview"
	)
	_expect(
		controller.call("get_selected_count") == added_count,
		"closing a preset preserves the user's selected mechanics"
	)


func _test_installed_and_selected_states() -> void:
	var controller = ControllerScript.new()
	var installed_health := ObjectCapabilityCatalog.create_selection("has_health")
	installed_health.enabled = true
	var current: Array[ObjectCapabilitySelection] = [installed_health]
	controller.call("set_active_preset", "breakable_resource")

	var installed_details: Dictionary = controller.call(
		"build_active_preset_details",
		current
	)
	var installed_entry := _find_entry(installed_details.get("entries", []), "has_health")
	_expect(bool(installed_entry.get("installed", false)), "existing enabled capability is marked as installed")
	_expect(not bool(installed_entry.get("can_select", true)), "installed capability cannot be selected again")
	_expect(int(installed_details.get("installed_count", 0)) >= 1, "preset summary counts capabilities already present in the object")

	controller.call("set_selected", "can_receive_damage", true)
	var with_selected_details: Dictionary = controller.call(
		"build_active_preset_details",
		current
	)
	var selected_entry := _find_entry(with_selected_details.get("entries", []), "can_receive_damage")
	_expect(bool(selected_entry.get("selected", false)), "catalog selection remains checked in preset preview")
	_expect(not bool(selected_entry.get("installed", false)), "catalog selection remains distinct from an installed object capability")
	_expect(bool(selected_entry.get("can_select", false)), "already selected capability can still be unchecked individually")
	_expect(
		int(with_selected_details.get("selected_count", 0)) >= 1,
		"preset summary counts selected but not-yet-installed capabilities"
	)


func _test_custom_preset_management() -> void:
	var controller = ControllerScript.new()
	var preset_store: RefCounted = controller.get("_preset_store")
	var storage_path := "user://object_builder_capability_preset_controller_smoke.json"
	preset_store.set("storage_path", storage_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path + ".bak"))

	controller.call("set_selected", "has_health", true)
	controller.call("set_selected", "can_receive_damage", true)
	var selected_ids: PackedStringArray = controller.call("get_selected_ids")
	_expect(selected_ids.size() == 2, "custom preset creation reads the shared catalog selection")
	var preset_id := str(controller.call("build_unique_custom_preset_id", "Мой ресурс"))
	_expect(preset_id.begins_with("user_moy_resurs"), "Russian preset names receive readable IDs")
	var saved: Dictionary = controller.call("save_custom_preset", {
		"id": preset_id,
		"display_name": "Мой ресурс",
		"description": "Сохранённый пользовательский набор.",
		"capability_ids": Array(selected_ids)
	})
	_expect(bool(saved.get("ok", false)), "controller saves a validated custom preset")
	var second_id := str(controller.call("build_unique_custom_preset_id", "Мой ресурс"))
	_expect(second_id != preset_id, "generated preset IDs remain unique after a save")
	controller.call("set_active_preset", preset_id)
	var no_current_selections: Array[ObjectCapabilitySelection] = []
	var details: Dictionary = controller.call("build_active_preset_details", no_current_selections)
	_expect(bool(details.get("is_custom", false)), "active preset details identify user-owned presets")
	_expect(details.get("capability_ids", []).size() == 2, "active preset details expose the saved composition")

	var updated: Dictionary = controller.call("save_custom_preset", {
		"id": preset_id,
		"display_name": "Мой ресурс обновлён",
		"description": "Новый состав.",
		"capability_ids": ["has_health"]
	})
	_expect(bool(updated.get("ok", false)), "controller updates a custom preset using its stable ID")
	var after_update: Array[Dictionary] = controller.call("get_custom_presets")
	_expect(after_update.size() == 1, "updating a preset does not create a duplicate")
	_expect(after_update[0].get("capability_ids", []).size() == 1, "updated composition is persisted")

	var duplicate_id := str(controller.call("build_unique_custom_preset_id", "Копия ресурса"))
	var duplicated: Dictionary = controller.call("duplicate_custom_preset", preset_id, duplicate_id, "Копия ресурса")
	_expect(bool(duplicated.get("ok", false)), "controller duplicates an existing custom preset")
	_expect(controller.call("get_custom_presets").size() == 2, "duplicate is stored separately")
	var deleted: Dictionary = controller.call("delete_custom_preset", preset_id)
	_expect(bool(deleted.get("ok", false)), "controller deletes a user-owned preset")
	_expect(controller.call("get_custom_presets").size() == 1, "deleting one preset preserves its duplicate")
	_expect(not bool(controller.call("delete_custom_preset", "breakable_resource").get("ok", false)), "controller cannot delete a built-in preset")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path + ".bak"))


func _find_entry(entries: Array, capability_id: String) -> Dictionary:
	for entry_value in entries:
		if entry_value is Dictionary and str(entry_value.get("capability_id", "")) == capability_id:
			return entry_value
	return {}


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
