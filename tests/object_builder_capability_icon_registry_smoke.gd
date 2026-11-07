extends SceneTree

const LibraryDataScript = preload("res://scripts/object_system/object_capability_library_data.gd")
const IconRegistryScript = preload("res://addons/object_builder/services/capability_icon_registry.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
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
