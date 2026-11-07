extends SceneTree

const LibraryDataScript = preload("res://scripts/object_system/object_capability_library_data.gd")
const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const IconRegistryScript = preload("res://addons/object_builder/services/capability_icon_registry.gd")
const IconIndexDataScript = preload("res://scripts/object_system/object_capability_icon_index_data.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)

	var definitions: Array[ObjectCapabilityDefinition] = LibraryDataScript.create_definitions()
	_expect(definitions.size() == 196, "library data contains 196 non-builtin definitions")
	_expect(IconIndexDataScript.get_count() == 200, "stable ID-to-icon map contains exactly 200 catalogue entries")

	var seen_library_indices: Dictionary = {}
	for definition in definitions:
		_expect(not definition.synonyms.is_empty(), "every library capability has searchable synonyms")
		_expect(not definition.example_queries.is_empty(), "every library capability has example search phrases")
		var atlas_index := definition.icon_atlas_index
		_expect(atlas_index >= 0 and atlas_index < 200, "library capability has a stable atlas index")
		_expect(
			IconIndexDataScript.get_index(definition.capability_id) == atlas_index,
			"library capability index matches its permanent ID mapping"
		)
		_expect(not seen_library_indices.has(atlas_index), "library entries never share an atlas cell")
		seen_library_indices[atlas_index] = definition.capability_id
	_expect(seen_library_indices.size() == 196, "all 196 library definitions own unique cells")

	var builtin_expected := {
		"has_health": 60,
		"can_attack": 70,
		"can_receive_damage": 71,
		"breaks_when_health_empty": 90
	}
	for capability_id in builtin_expected:
		var expected_index := int(builtin_expected[capability_id])
		_expect(
			IconIndexDataScript.get_index(capability_id) == expected_index,
			"built-in ID uses its position in the 200-entry catalogue"
		)
		var builtin_definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		_expect(builtin_definition != null, "built-in capability is registered")
		if builtin_definition != null:
			_expect(
				builtin_definition.icon_atlas_index == expected_index,
				"built-in definition uses its permanent catalogue cell"
			)
			_expect(
				IconRegistryScript.get_icon(builtin_definition) is AtlasTexture,
				"built-in capability resolves its own atlas icon"
			)

	var first_icon := IconRegistryScript.get_icon(definitions[0])
	_expect(first_icon is AtlasTexture, "capability icon registry returns an AtlasTexture for library cards")
	if first_icon is AtlasTexture:
		var first_atlas := first_icon as AtlasTexture
		_expect(first_atlas.atlas != null, "atlas texture references the shared SVG atlas")
		_expect(first_atlas.region.size == Vector2(40, 40), "each card icon uses an isolated 40 by 40 cell")
		_expect(
			first_atlas.region.position.y + first_atlas.region.size.y <= 800,
			"icon regions stay inside the 400 by 800 atlas"
		)

	var attack_animation := ObjectCapabilityCatalog.get_definition_reference("plays_attack_animation")
	_expect(attack_animation != null, "attack animation capability is registered")
	var attack_relation_found := false
	if attack_animation != null:
		for relation in attack_animation.relations:
			if str(relation.get("target_id", "")) == "can_attack" and str(relation.get("type", "")) == "recommends":
				attack_relation_found = true
	_expect(attack_relation_found, "curated relations connect attack animation with attack capability")

	var total_relation_count := 0
	var known_ids: Dictionary = {}
	for capability_id in IconIndexDataScript.ICON_INDEX_BY_ID:
		known_ids[capability_id] = true
	for definition in definitions:
		for relation in definition.relations:
			total_relation_count += 1
			var target_id := str(relation.get("target_id", ""))
			_expect(known_ids.has(target_id), "curated relationship target resolves to a catalogue capability")
			_expect(not str(relation.get("explanation", "")).strip_edges().is_empty(), "curated relationship has a user-facing explanation")
	_expect(total_relation_count >= 60, "catalogue has a broad curated network of semantic relationships")

	var registry_errors := ObjectCapabilityCatalog.validate_registry()
	for error_message in registry_errors:
		failures.append("registry validation: " + error_message)

	var registered_ids := ObjectCapabilityCatalog.get_capability_ids("", false)
	_expect(registered_ids.size() == 200, "complete capability registry has exactly 200 cards")
	var registered_indices: Dictionary = {}
	for capability_id in registered_ids:
		var registered_definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		_expect(registered_definition != null, "every ID resolves to a registered capability")
		if registered_definition == null:
			continue
		var atlas_index := registered_definition.icon_atlas_index
		_expect(
			IconIndexDataScript.get_index(capability_id) == atlas_index,
			"registered capability retains the permanent ID mapping"
		)
		_expect(not registered_indices.has(atlas_index), "registered cards never share an atlas cell")
		registered_indices[atlas_index] = capability_id
	_expect(registered_indices.size() == 200, "all 200 registered cards have unique icon cells")

	for library_definition in definitions:
		var registered_definition := ObjectCapabilityCatalog.get_definition_reference(library_definition.capability_id)
		_expect(registered_definition != null, "library capability remains registered after mechanic modules load")
		if registered_definition != null:
			_expect(
				registered_definition.icon_atlas_index == library_definition.icon_atlas_index,
				"module promotion preserves the original capability icon cell"
			)

	IconRegistryScript.clear_cache()
	if failures.is_empty():
		print("Object Builder capability icon registry tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error("Object Builder capability icon registry: " + failure)
	quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
