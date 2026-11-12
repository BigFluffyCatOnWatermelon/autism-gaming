extends SceneTree

const BackendScript = preload("res://addons/web_object_builder/services/object_builder_backend.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const ObjectLibraryService = preload("res://scripts/object_system/object_library_service.gd")
const CapabilitySelectionScript = preload("res://scripts/object_system/object_capability_selection.gd")

var failures: Array[String] = []
var test_path := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ObjectLibraryService.ensure_directories()
	var suffix := str(Time.get_ticks_usec())
	var existing := DefinitionScript.new() as ObjectDefinition
	existing.object_id = "web_builder_reuse_smoke_" + suffix
	existing.display_name = "Smoke Wood " + suffix
	existing.category = "Resources"
	existing.subcategory = "Raw materials"
	existing.object_type = "resource"
	existing.root_type = "Node2D"
	existing.template_id = "smoke_wood_template"
	test_path = ObjectLibraryService.get_definition_path_for_definition(existing)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(test_path.get_base_dir())
	)
	var save_error := ResourceSaver.save(existing, test_path)
	_expect(save_error == OK, "existing library record can be created for related-object reuse")
	if save_error != OK:
		_finish()
		return

	var backend := BackendScript.new()
	var same_name_draft := existing.duplicate(true) as ObjectDefinition
	same_name_draft.object_id = "draft_same_name_" + suffix
	same_name_draft.template_id = ""
	var same_name_match := backend._find_existing_related_match(same_name_draft, "")
	_expect(
		same_name_match != null and same_name_match.object_id == existing.object_id,
		"new related draft reuses an existing record with the same name and category"
	)

	var same_template_draft := existing.duplicate(true) as ObjectDefinition
	same_template_draft.object_id = "draft_same_template_" + suffix
	same_template_draft.display_name = "Different draft name"
	same_template_draft.category = "Other"
	var same_template_match := backend._find_existing_related_match(same_template_draft, "")
	_expect(
		same_template_match != null and same_template_match.object_id == existing.object_id,
		"new related draft reuses an existing record with the same template identity"
	)

	var different_category_draft := existing.duplicate(true) as ObjectDefinition
	different_category_draft.object_id = "draft_different_category_" + suffix
	different_category_draft.template_id = ""
	different_category_draft.category = "Nature"
	var different_category_match := backend._find_existing_related_match(different_category_draft, "")
	_expect(
		different_category_match == null,
		"objects with the same name but a different category are not merged"
	)

	# Embedding a remains object is a separate, explicit copy operation:
	# the original library record survives and all copied sprite layers start
	# hidden in the runtime scene.
	var remains_texture_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	remains_texture_image.fill(Color.WHITE)
	var remains_texture := ImageTexture.create_from_image(remains_texture_image)
	var remains_source := DefinitionScript.new() as ObjectDefinition
	remains_source.object_id = "smoke_remains_source_" + suffix
	remains_source.display_name = "Smoke Stump " + suffix
	remains_source.preview_texture = remains_texture
	remains_source.preview_hash = "smoke-remains-" + suffix
	var remains_parent := DefinitionScript.new() as ObjectDefinition
	remains_parent.object_id = "smoke_remains_parent_" + suffix
	remains_parent.display_name = "Smoke Tree " + suffix
	var destruction_selection := CapabilitySelectionScript.new()
	destruction_selection.capability_id = "breaks_when_health_empty"
	destruction_selection.enabled = true
	remains_parent.capabilities.append(destruction_selection)
	backend.set("_working", remains_parent)
	var open_drafts: Dictionary = backend.get("_open_drafts")
	open_drafts[remains_source.object_id] = remains_source
	backend.set("_open_drafts", open_drafts)
	var embed_result: Dictionary = backend.call("_embed_relation_as_part", {
		"target_object_id": remains_source.object_id,
		"mechanic_id": "breaks_when_health_empty",
		"kind": "remains",
		"label": "Пень",
		"quantity": 1,
		"settings": {"embed_in_parent": true}
	})
	_expect(bool(embed_result.get("ok", false)), "a new remains relation can be embedded directly without creating a separate relation first")
	_expect(remains_parent.relations.size() == 1, "embedding a new remains also creates its owning mechanic relation")
	_expect(remains_parent.sprite_layers.size() == 1, "the source object's main sprite is copied into the parent as an editable layer")
	if not remains_parent.sprite_layers.is_empty():
		var embedded_layer: Dictionary = remains_parent.sprite_layers[0]
		_expect(not bool(embedded_layer.get("runtime_visible", true)), "embedded remain layer is hidden in the runtime scene by default")
		_expect(
			str(embedded_layer.get("embedded_relation_id", "")).begins_with("relation_"),
			"embedded remain layer keeps its owning relation ID"
		)
	_expect(
		remains_source.preview_texture == remains_texture and remains_source.object_id == "smoke_remains_source_" + suffix,
		"embedding copies the source sprite without modifying or deleting the original library object"
	)
	backend.call("cleanup")

	_finish()


func _finish() -> void:
	if not test_path.is_empty() and FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if failures.is_empty():
		print("Web Object Builder related-object reuse tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
