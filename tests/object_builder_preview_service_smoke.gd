extends SceneTree

const PreviewService = preload("res://addons/object_builder/services/preview_service.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition: ObjectDefinition = DefinitionScript.new()
	definition.object_id = "preview_service_draft"
	definition.display_name = "Draft preview"
	definition.root_type = "Node2D"

	var draft_root := Node2D.new()
	draft_root.name = "UnsavedDraft"
	var draft_sprite := Sprite2D.new()
	draft_sprite.name = "UnsavedSprite"
	draft_sprite.position = Vector2(42, 18)
	draft_root.add_child(draft_sprite)
	draft_sprite.owner = draft_root

	var preview_result: Dictionary = PreviewService.create_preview_instance(definition, draft_root)
	_expect(bool(preview_result.get("ok", false)), "an unsaved editor scene can be previewed")
	var preview_root := preview_result.get("instance") as Node
	_expect(preview_root != null, "preview returns an independent scene instance")
	if preview_root != null:
		_expect(preview_root != draft_root, "preview does not reuse the editor scene root")
		var preview_sprite := preview_root.get_node_or_null("UnsavedSprite") as Sprite2D
		_expect(preview_sprite != null, "preview keeps nodes from the unsaved draft")
		if preview_sprite != null:
			_expect(preview_sprite.position == Vector2(42, 18), "preview keeps unsaved node transforms")
			preview_sprite.position = Vector2(100, 100)
			_expect(draft_sprite.position == Vector2(42, 18), "preview edits cannot mutate the editor scene")
		preview_root.free()

	_expect(draft_root.get_node_or_null("UnsavedSprite") == draft_sprite, "the original draft remains intact")
	_expect(definition.scene_path.is_empty(), "preview does not assign or write a scene path")
	draft_root.free()

	var fallback_definition: ObjectDefinition = DefinitionScript.new()
	fallback_definition.object_id = "preview_service_saved"
	fallback_definition.display_name = "Saved preview"
	fallback_definition.root_type = "Node2D"
	var saved_root := Node2D.new()
	var saved_sprite := Sprite2D.new()
	saved_sprite.name = "SavedSprite"
	saved_root.add_child(saved_sprite)
	saved_sprite.owner = saved_root
	var packed := PackedScene.new()
	var pack_error := packed.pack(saved_root)
	saved_root.free()
	_expect(pack_error == OK, "test source scene packs successfully")
	fallback_definition.scene = packed
	var fallback_result: Dictionary = PreviewService.create_preview_instance(fallback_definition)
	_expect(bool(fallback_result.get("ok", false)), "preview can use a saved PackedScene")
	var fallback_instance := fallback_result.get("instance") as Node
	if fallback_instance != null:
		_expect(fallback_instance.get_node_or_null("SavedSprite") is Sprite2D, "saved scene nodes appear in preview")
		fallback_instance.free()

	var missing_result: Dictionary = PreviewService.create_preview_instance(null)
	_expect(not bool(missing_result.get("ok", true)), "missing definitions return a handled error")

	await process_frame
	if failures.is_empty():
		print("Object Builder preview service checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
