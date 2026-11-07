extends SceneTree

const DependencyService = preload("res://addons/object_builder/services/scene_node_dependency_service.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const NodeDefinitionScript = preload("res://scripts/object_system/object_node_definition.gd")
const SignalDefinitionScript = preload("res://scripts/object_system/object_signal_connection_definition.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node2D.new()
	scene_root.name = "ObjectRoot"
	root.add_child(scene_root)

	var target := Sprite2D.new()
	target.name = "Target"
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	target.texture = ImageTexture.create_from_image(image)
	scene_root.add_child(target)

	var emitter := Node2D.new()
	emitter.name = "Emitter"
	scene_root.add_child(emitter)
	emitter.visibility_changed.connect(Callable(target, "queue_redraw"))
	target.visibility_changed.connect(Callable(emitter, "queue_redraw"))

	var animation_player := AnimationPlayer.new()
	animation_player.name = "Animator"
	animation_player.root_node = NodePath("../Target")
	scene_root.add_child(animation_player)
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 1.0
	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath(".:visible"))
	animation.track_insert_key(track_index, 0.0, true)
	var add_animation_error := library.add_animation(&"idle", animation)
	_expect(add_animation_error == OK, "animation fixture is added to its library")
	var add_library_error := animation_player.add_animation_library(&"", library)
	_expect(add_library_error == OK, "animation library is attached to the scene player")

	var definition := DefinitionScript.new() as ObjectDefinition
	target.set_meta("object_builder_node_id", "generated_visual")
	var generated_parent := NodeDefinitionScript.new() as ObjectNodeDefinition
	generated_parent.node_id = "generated_visual"
	generated_parent.node_type = "Sprite2D"
	generated_parent.node_name = "Target"
	definition.node_definitions.append(generated_parent)
	var generated_child := NodeDefinitionScript.new() as ObjectNodeDefinition
	generated_child.node_id = "generated_child"
	generated_child.parent_node_id = "generated_visual"
	definition.node_definitions.append(generated_child)
	var signal_definition := SignalDefinitionScript.new() as ObjectSignalConnectionDefinition
	signal_definition.connection_id = "generated_connection"
	signal_definition.source_node_id = "generated_visual"
	signal_definition.signal_name = "visibility_changed"
	signal_definition.target_node_id = "generated_child"
	signal_definition.method_name = "refresh"
	definition.signal_connections.append(signal_definition)

	var references: Array[Dictionary] = DependencyService.inspect(scene_root, target, definition)
	_expect(_has_kind(references, "NodePath на удаляемую часть"), "external NodePath properties referencing the part are detected")
	_expect(_has_kind(references, "Внешний сигнал на удаляемую часть"), "signal connections targeting the part are detected")
	_expect(_has_kind(references, "Сигнал удаляемой части"), "signals emitted by the part and connected externally are detected")
	_expect(_has_kind(references, "AnimationPlayer с треком на удаляемую часть"), "animation tracks targeting the part are detected")
	_expect(_has_kind(references, "Декларативный узел"), "generated node definitions attached to the deleted part are detected")
	_expect(_has_kind(references, "Декларативная структура"), "generated child definitions referencing the part are detected")
	_expect(_has_kind(references, "Декларативный сигнал"), "generated signal definitions referencing the part are detected")
	_expect(references.size() >= 7, "dependency report contains separate entries for all discovered reference groups")

	var internal_parent := Node2D.new()
	internal_parent.name = "InternalParent"
	var internal_child := Node2D.new()
	internal_child.name = "InternalChild"
	internal_parent.add_child(internal_child)
	scene_root.add_child(internal_parent)
	internal_parent.visibility_changed.connect(Callable(internal_child, "queue_redraw"))
	var internal_references: Array[Dictionary] = DependencyService.inspect(scene_root, internal_parent)
	_expect(internal_references.is_empty(), "connections entirely inside a deleted subtree are not reported as external dependencies")

	var outside_node := Node2D.new()
	outside_node.name = "Outside"
	scene_root.add_child(outside_node)
	var outside_references: Array[Dictionary] = DependencyService.inspect(scene_root, outside_node)
	_expect(outside_references.is_empty(), "unreferenced nodes can be removed without a warning")

	root.remove_child(scene_root)
	scene_root.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder scene node dependency service tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _has_kind(references: Array[Dictionary], expected_kind: String) -> bool:
	for reference in references:
		if str(reference.get("kind", "")) == expected_kind:
			return true
	return false


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)