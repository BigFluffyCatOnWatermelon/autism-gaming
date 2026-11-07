extends SceneTree

const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const ControllerScript = preload("res://addons/object_builder/controllers/capability_catalog_controller.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)

	_test_profile_metadata()
	_test_recommendations_for_empty_object()
	_test_installed_and_selected_filtering()
	_test_query_and_tag_ranking()
	_test_category_profile_fallback()
	_test_unknown_profile()

	if failures.is_empty():
		print("Object Builder contextual capability recommendations tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error("Object Builder contextual recommendations: " + failure)
	quit(1)


func _test_profile_metadata() -> void:
	var resource_profile := ObjectCreationProfileRegistry.get_definition("resource")
	_expect(resource_profile != null, "resource profile exists")
	if resource_profile == null:
		return
	_expect(
		resource_profile.suggested_capability_ids.has("has_health"),
		"resource profile explicitly recommends Health"
	)
	_expect(
		resource_profile.suggested_capability_ids.has("can_receive_damage"),
		"resource profile explicitly recommends receiving damage"
	)
	_expect(
		resource_profile.suggested_capability_ids.has("breaks_when_health_empty"),
		"resource profile explicitly recommends a destruction behavior"
	)

	var item_profile := ObjectCreationProfileRegistry.get_definition("item")
	_expect(
		item_profile != null and item_profile.suggested_capability_ids.has("is_pickup_item"),
		"item profile recommends the pickup capability"
	)
	var decoration_profile := ObjectCreationProfileRegistry.get_definition("decoration")
	_expect(
		decoration_profile != null and decoration_profile.suggested_capability_ids.is_empty(),
		"decoration profile is allowed to have no behavior recommendations"
	)
	_expect(
		ObjectCreationProfileRegistry.validate_registry().is_empty(),
		"all built-in profile recommendations pass profile metadata validation"
	)


func _test_recommendations_for_empty_object() -> void:
	var controller = ControllerScript.new()
	var no_selections: Array[ObjectCapabilitySelection] = []
	var recommendations: Array[Dictionary] = controller.call(
		"build_recommended_entries",
		no_selections,
		"",
		8,
		"resource",
		"Nature",
		PackedStringArray(["tree", "wood"])
	)
	_expect(
		not recommendations.is_empty(),
		"new empty resource object receives profile recommendations before any mechanic is installed"
	)

	var health_entry := _find_recommendation(recommendations, "has_health")
	var damage_entry := _find_recommendation(recommendations, "can_receive_damage")
	_expect(not health_entry.is_empty(), "resource profile recommends the Health capability")
	_expect(not damage_entry.is_empty(), "resource profile recommends the Damageable capability")
	if not health_entry.is_empty():
		_expect(
			str(health_entry.get("relation_type", "")) == "profile",
			"profile recommendation is distinguishable from a mechanic-to-mechanic relation"
		)
		_expect(
			str(health_entry.get("explanation", "")).contains("Ресурс"),
			"profile recommendation explains which profile it belongs to"
		)
	if not damage_entry.is_empty():
		var dependencies: PackedStringArray = damage_entry.get("automatic_dependencies", PackedStringArray())
		_expect(
			dependencies.has("Здоровье"),
			"recommendation preview names the automatic Health dependency"
		)
		_expect(
			str(damage_entry.get("explanation", "")).contains("потребуется"),
			"recommendation explains that the dependency will be added with the selection"
		)

	for entry in recommendations:
		var definition := entry.get("definition") as ObjectCapabilityDefinition
		_expect(
			definition != null and definition.is_ready(),
			"planned or unavailable capabilities never appear as one-click recommendations"
		)


func _test_installed_and_selected_filtering() -> void:
	var controller = ControllerScript.new()
	var installed_health := ObjectCapabilityCatalog.create_selection("has_health")
	installed_health.enabled = true
	var current: Array[ObjectCapabilitySelection] = [installed_health]
	var recommendations: Array[Dictionary] = controller.call(
		"build_recommended_entries",
		current,
		"",
		8,
		"resource",
		"Nature",
		PackedStringArray()
	)
	_expect(
		_find_recommendation(recommendations, "has_health").is_empty(),
		"already installed capabilities are not recommended again"
	)
	var damage_entry := _find_recommendation(recommendations, "can_receive_damage")
	if not damage_entry.is_empty():
		var dependencies: PackedStringArray = damage_entry.get("automatic_dependencies", PackedStringArray())
		_expect(
			dependencies.is_empty(),
			"existing Health dependency is not shown as a new automatic addition"
		)

	controller.call("set_selected", "can_regrow", true)
	var with_selection: Array[Dictionary] = controller.call(
		"build_recommended_entries",
		current,
		"",
		8,
		"resource",
		"Nature",
		PackedStringArray()
	)
	_expect(
		_find_recommendation(with_selection, "can_regrow").is_empty(),
		"capabilities already selected in the catalog are excluded from recommendations"
	)
	_expect(
		controller.call("get_selected_count") == 1,
		"recommendation calculation does not clear or rewrite the user's catalog selection"
	)


func _test_query_and_tag_ranking() -> void:
	var controller = ControllerScript.new()
	var no_selections: Array[ObjectCapabilitySelection] = []
	var base: Array[Dictionary] = controller.call(
		"build_recommended_entries",
		no_selections,
		"",
		8,
		"resource",
		"Nature",
		PackedStringArray()
	)
	var contextual: Array[Dictionary] = controller.call(
		"build_recommended_entries",
		no_selections,
		"здоровье",
		8,
		"resource",
		"Nature",
		PackedStringArray(["здоровье"])
	)
	var base_health := _find_recommendation(base, "has_health")
	var contextual_health := _find_recommendation(contextual, "has_health")
	_expect(not base_health.is_empty() and not contextual_health.is_empty(), "health remains recommended with or without an active query")
	if not base_health.is_empty() and not contextual_health.is_empty():
		_expect(
			int(contextual_health.get("score", 0)) > int(base_health.get("score", 0)),
			"matching object tags and a natural-language query increase recommendation relevance"
		)
		_expect(
			str(contextual_health.get("explanation", "")).contains("поисковому запросу"),
			"recommendation explains when it matches the current search query"
		)
		_expect(
			str(contextual_health.get("explanation", "")).contains("метки объекта"),
			"recommendation explains matching object tags"
		)


func _test_category_profile_fallback() -> void:
	var controller = ControllerScript.new()
	var no_selections: Array[ObjectCapabilitySelection] = []
	var recommendations: Array[Dictionary] = controller.call(
		"build_recommended_entries",
		no_selections,
		"",
		8,
		"other",
		"Nature",
		PackedStringArray(["tree"])
	)
	_expect(
		not recommendations.is_empty(),
		"objects without a specialized profile can receive suggestions from their library category"
	)
	var health_entry := _find_recommendation(recommendations, "has_health")
	_expect(
		not health_entry.is_empty(),
		"Nature category falls back to the resource profile's Health suggestion"
	)
	if not health_entry.is_empty():
		_expect(
			str(health_entry.get("explanation", "")).contains("Ресурс"),
			"category-based recommendation explains which matching profile supplied it"
		)


func _test_unknown_profile() -> void:
	var controller = ControllerScript.new()
	var no_selections: Array[ObjectCapabilitySelection] = []
	var recommendations: Array[Dictionary] = controller.call(
		"build_recommended_entries",
		no_selections,
		"",
		8,
		"unknown_profile_id",
		"Other",
		PackedStringArray()
	)
	_expect(
		recommendations.is_empty(),
		"unknown profile does not create invented recommendations"
	)


func _find_recommendation(entries: Array[Dictionary], capability_id: String) -> Dictionary:
	for entry in entries:
		if str(entry.get("capability_id", "")) == capability_id:
			return entry
	return {}


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
