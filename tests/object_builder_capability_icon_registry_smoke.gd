extends SceneTree

const LibraryDataScript = preload("res://scripts/object_system/object_capability_library_data.gd")
const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const IconRegistryScript = preload("res://addons/object_builder/services/capability_icon_registry.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)

	var definitions: Array[ObjectCapabilityDefinition] = LibraryDataScript.create_definitions()
	_expect(definitions.size() == 200, "built-in library contains exactly 200 capability definitions")

	var seen_indices: Dictionary = {}
	for definition in definitions:
		var atlas_index := definition.icon_atlas_index
		_expect(atlas_index >= 0 and atlas_index < 200, "library capability has a reserved atlas index")
		_expect(not seen_indices.has(atlas_index), "each library capability owns a unique atlas cell")
		seen_indices[atlas_index] = definition.capability_id
	_expect(seen_indices.size() == 200, "all 200 catalogue atlas cells have an owner")

	var first_icon := IconRegistryScript.get_icon(definitions[0])
	_expect(first_icon is AtlasTexture, "capability icon registry returns an AtlasTexture for library cards")
	if first_icon is AtlasTexture:
		var first_atlas := first_icon as AtlasTexture
		_expect(first_atlas.atlas != null, "atlas texture references the shared SVG atlas")
		_expect(first_atlas.region.size == Vector2(40, 40), "each card icon uses an isolated 40 by 40 cell")

	var builtin_health := ObjectCapabilityCatalog.get_definition_reference("has_health")
	_expect(builtin_health != null and builtin_health.icon_atlas_index == 200, "Health owns its reserved built-in atlas cell")
	if builtin_health != null:
		_expect(IconRegistryScript.get_icon(builtin_health) is AtlasTexture, "built-in Health card resolves its own atlas icon")

	var builtin_damage := ObjectCapabilityCatalog.get_definition_reference("can_receive_damage")
	var builtin_attack := ObjectCapabilityCatalog.get_definition_reference("can_attack")
	var builtin_destroy := ObjectCapabilityCatalog.get_definition_reference("breaks_when_health_empty")
	_expect(builtin_damage != null and builtin_damage.icon_atlas_index == 201, "Damageable owns its reserved atlas cell")
	_expect(builtin_attack != null and builtin_attack.icon_atlas_index == 202, "Attack owns its reserved atlas cell")
	_expect(builtin_destroy != null and builtin_destroy.icon_atlas_index == 203, "Destructible owns its reserved atlas cell")

	var attack_animation := ObjectCapabilityCatalog.get_definition_reference("plays_attack_animation")
	_expect(attack_animation != null, "attack animation capability is registered")
	var attack_relation_found := false
	if attack_animation != null:
		for relation in attack_animation.relations:
			if str(relation.get("target_id", "")) == "can_attack" and str(relation.get("type", "")) == "recommends":
				attack_relation_found = true
	_expect(attack_relation_found, "curated relations connect attack animation with attack capability")
	var total_relation_count := 0
	var known_ids: Dictionary = {
		"has_health": true,
		"can_receive_damage": true,
		"can_attack": true,
		"breaks_when_health_empty": true,
		"is_pickup_item": true,
		"can_interact": true
	}
	for definition in definitions:
		known_ids[definition.capability_id] = true
	for definition in definitions:
		for relation in definition.relations:
			total_relation_count += 1
			var target_id := str(relation.get("target_id", ""))
			_expect(known_ids.has(target_id), "curated relationship target resolves to a catalogue capability")
			_expect(not str(relation.get("explanation", "")).strip_edges().is_empty(), "curated relationship has a user-facing explanation")
	_expect(total_relation_count >= 20, "catalogue begins with a useful curated set of semantic relationships")

	var registry_errors := ObjectCapabilityCatalog.validate_registry()
	for error_message in registry_errors:
		failures.append("registry validation: " + error_message)

	var registered_ids := ObjectCapabilityCatalog.get_capability_ids("", false)
	_expect(registered_ids.size() == 204, "complete registry contains 200 catalogue cards and four base capabilities")
	var registered_atlas_indices: Dictionary = {}
	for capability_id in registered_ids:
		var registered_definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		if registered_definition == null:
			continue
		var atlas_index := registered_definition.icon_atlas_index
		_expect(atlas_index >= 0 and atlas_index < 204, "registered capability preserves a valid atlas index")
		_expect(not registered_atlas_indices.has(atlas_index), "module promotion never duplicates another capability's icon cell")
		registered_atlas_indices[atlas_index] = capability_id
	_expect(registered_atlas_indices.size() == 204, "all registered capabilities retain a unique icon")

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
