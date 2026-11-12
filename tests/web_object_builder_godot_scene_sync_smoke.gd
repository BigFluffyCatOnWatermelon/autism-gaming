extends SceneTree

const BackendScript = preload("res://addons/web_object_builder/services/object_builder_backend.gd")
const ModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const PropertyDefinitionScript = preload("res://scripts/object_system/object_property_definition.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const NodeDefinitionScript = preload("res://scripts/object_system/object_node_definition.gd")
const ObjectLibraryService = preload("res://scripts/object_system/object_library_service.gd")
const LibraryDockScript = preload("res://addons/web_object_builder/ui/object_library_dock.gd")
const SceneDraftServiceScript = preload("res://addons/web_object_builder/services/scene_draft_service.gd")
const ObjectSceneStructureServiceScript = preload("res://scripts/object_system/object_scene_structure_service.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var backend := BackendScript.new()
	for module_error in ModuleLoaderScript.register_modules_in_directory():
		_expect(false, "legacy mechanic migration module registration: " + module_error)
	_test_legacy_mechanic_property_migration(backend)
	_test_legacy_migration_after_capability_enable()
	var library_dock := LibraryDockScript.new()

	# A clean object tab is a cache only. Opening it again must load the latest
	# .tres values even when Godot changed that resource outside this backend.
	var test_library_directory := ObjectLibraryService.OBJECTS_PATH.path_join("other")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_library_directory))
	var test_definition_path := test_library_directory.path_join("__test_reopen_fresh_resource.tres")
	var disk_definition := DefinitionScript.new() as ObjectDefinition
	disk_definition.object_id = "test_reopen_fresh_resource"
	disk_definition.display_name = "__test_reopen_fresh_resource"
	disk_definition.category = "Other"
	disk_definition.object_type = "other"
	disk_definition.collision_offset = Vector2(10.0, 20.0)
	var initial_save_error := ResourceSaver.save(disk_definition, test_definition_path)
	_expect(initial_save_error == OK, "test library definition can be written")
	if initial_save_error == OK:
		var first_open: Dictionary = backend.call("_open_object", disk_definition.object_id)
		_expect(bool(first_open.get("ok", false)), "first open loads the test object")
		var latest_disk_definition := disk_definition.duplicate(true) as ObjectDefinition
		latest_disk_definition.collision_offset = Vector2(91.0, -37.0)
		var external_save_error := ResourceSaver.save(latest_disk_definition, test_definition_path)
		_expect(external_save_error == OK, "external Godot edit can replace the test definition")
		var second_open: Dictionary = backend.call("_open_object", disk_definition.object_id)
		var reopened_working := backend.call("get_working_definition") as ObjectDefinition
		_expect(
			bool(second_open.get("ok", false))
			and reopened_working != null
			and reopened_working.collision_offset.is_equal_approx(Vector2(91.0, -37.0)),
			"reopening a clean cached object adopts the latest values saved by Godot"
		)

		# Dirty Web Builder drafts still outrank the on-disk copy.
		reopened_working.collision_offset = Vector2(7.0, 8.0)
		backend.call("_mark_working_dirty")
		var newer_disk_definition := latest_disk_definition.duplicate(true) as ObjectDefinition
		newer_disk_definition.collision_offset = Vector2(123.0, 456.0)
		var second_external_save_error := ResourceSaver.save(newer_disk_definition, test_definition_path)
		_expect(second_external_save_error == OK, "second external edit can replace the test definition")
		backend.call("_open_object", disk_definition.object_id)
		var protected_working := backend.call("get_working_definition") as ObjectDefinition
		_expect(
			protected_working != null
			and protected_working.collision_offset.is_equal_approx(Vector2(7.0, 8.0)),
			"reopening preserves genuinely unsaved Builder draft changes"
		)

		backend.call("cleanup")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_definition_path))
		backend = BackendScript.new()
	_expect(library_dock.has_method("set_refreshing"), "Object Library Dock exposes the refresh state API")
	library_dock.call("set_refreshing", true)
	library_dock.call("set_refreshing", false)
	library_dock.free()
	_expect(
		ObjectLibraryService.is_managed_scene_path(
			ObjectLibraryService.SCENES_PATH.path_join("objects").path_join("nature").path_join("pine.tscn")
		),
		"category-based object scene paths are recognized as managed"
	)
	_expect(
		ObjectLibraryService.is_managed_scene_path(
			ObjectLibraryService.LEGACY_SCENES_PATH.path_join("Природа").path_join("Дуб.tscn")
		),
		"localized legacy object scene paths are recognized as managed"
	)
	_expect(
		ObjectLibraryService.is_managed_scene_path(
			ObjectLibraryService.SCENES_PATH.path_join("templates").path_join("nature").path_join("pine.tscn")
		),
		"template scene paths are recognized as managed"
	)
	var source_profile := DefinitionScript.new() as ObjectDefinition
	var dirty_profile := DefinitionScript.new() as ObjectDefinition
	source_profile.collision_enabled = true
	source_profile.collision_mode = "area"
	source_profile.collision_shape = "circle"
	source_profile.collision_offset = Vector2(71.0, -29.0)
	source_profile.collision_radius = 23.0
	source_profile.collision_layer = 16
	source_profile.collision_mask = 32
	dirty_profile.collision_offset = Vector2.ZERO
	backend.call("_merge_godot_collision_profile", source_profile, dirty_profile)
	_expect(dirty_profile.collision_enabled, "Godot collision changes merge into an unsaved Web Builder draft")
	_expect(dirty_profile.collision_mode == "area", "Godot collision mode merges into an unsaved draft")
	_expect(
		dirty_profile.collision_offset.is_equal_approx(Vector2(71.0, -29.0)),
		"Godot collision position overwrites only the collision profile in a dirty draft"
	)
	_expect(
		dirty_profile.collision_radius == 23.0
		and dirty_profile.collision_layer == 16
		and dirty_profile.collision_mask == 32,
		"Godot collision geometry and physics bits merge into a dirty draft"
	)
	var source_node_definition := NodeDefinitionScript.new() as ObjectNodeDefinition
	source_node_definition.node_id = "generated_visual"
	source_node_definition.node_name = "GodotRenamedVisual"
	source_node_definition.enabled = true
	source_node_definition.properties = {"position": Vector2(81.0, 92.0)}
	var target_node_definition := NodeDefinitionScript.new() as ObjectNodeDefinition
	target_node_definition.node_id = "generated_visual"
	target_node_definition.node_name = "OldVisual"
	target_node_definition.enabled = false
	target_node_definition.properties = {"position": Vector2.ZERO}
	source_profile.node_definitions = [source_node_definition]
	dirty_profile.node_definitions = [target_node_definition]
	backend.call("_merge_godot_node_definitions", source_profile, dirty_profile)
	_expect(
		target_node_definition.node_name == "GodotRenamedVisual"
		and target_node_definition.enabled
		and target_node_definition.properties.get("position", Vector2.ZERO).is_equal_approx(Vector2(81.0, 92.0)),
		"Godot-generated node Inspector changes merge into a dirty Builder draft"
	)
	var scene_root := Node2D.new()
	scene_root.name = "Pine"
	var identity_reference := Node.new()
	identity_reference.name = "Идентификатор объекта"
	identity_reference.set_script(preload("res://scripts/object_system/object_builder_reference.gd"))
	identity_reference.set("object_id", "test_external_scene_sync")
	scene_root.add_child(identity_reference)
	identity_reference.owner = scene_root
	_expect(
		ObjectLibraryService.get_scene_root_object_id(scene_root) == "test_external_scene_sync",
		"live Godot scene root resolves its durable Object Builder reference"
	)
	var enclosing_scene := Node2D.new()
	var nested_object_instance := Node2D.new()
	var nested_identity_reference := Node.new()
	nested_identity_reference.set_script(preload("res://scripts/object_system/object_builder_reference.gd"))
	nested_identity_reference.set("object_id", "nested_object_must_not_identify_parent")
	nested_object_instance.add_child(nested_identity_reference)
	enclosing_scene.add_child(nested_object_instance)
	_expect(
		ObjectLibraryService.get_scene_root_object_id(enclosing_scene).is_empty(),
		"a nested object instance must not be mistaken for the enclosing level scene identity"
	)
	_expect(
		ObjectLibraryService.find_scene_root_in_tree(
			enclosing_scene,
			"nested_object_must_not_identify_parent"
		) == nested_object_instance,
		"the unique nested Builder object is found from its selected level-scene hierarchy"
	)
	var second_nested_instance := Node2D.new()
	var second_nested_reference := Node.new()
	second_nested_reference.name = "Идентификатор объекта"
	second_nested_reference.set_script(preload("res://scripts/object_system/object_builder_reference.gd"))
	second_nested_reference.set("object_id", "nested_object_must_not_identify_parent")
	second_nested_instance.add_child(second_nested_reference)
	enclosing_scene.add_child(second_nested_instance)
	_expect(
		ObjectLibraryService.find_scene_root_in_tree(
			enclosing_scene,
			"nested_object_must_not_identify_parent"
		) == null,
		"multiple instances with the same ID are rejected instead of selecting an arbitrary collision"
	)
	enclosing_scene.free()

	var managed_sprite := Sprite2D.new()
	managed_sprite.name = "ObjectBuilderSprite"
	managed_sprite.position = Vector2(5.0, 6.0)
	managed_sprite.set_meta("object_builder_sprite", true)
	scene_root.add_child(managed_sprite)
	managed_sprite.owner = scene_root

	var manual_node := Node2D.new()
	manual_node.name = "ManualDecoration"
	manual_node.position = Vector2(12.0, 34.0)
	manual_node.visible = false
	scene_root.add_child(manual_node)
	manual_node.owner = scene_root

	# A nested Object Builder instance owns its own visual and collision
	# nodes. Its metadata must never be imported into the parent definition.
	var nested_owned_object := Node2D.new()
	nested_owned_object.name = "NestedObject"
	scene_root.add_child(nested_owned_object)
	nested_owned_object.owner = scene_root
	var nested_owned_identity := Node.new()
	nested_owned_identity.name = "Идентификатор объекта"
	nested_owned_identity.set_script(preload("res://scripts/object_system/object_builder_reference.gd"))
	nested_owned_identity.set("object_id", "test_nested_object")
	nested_owned_object.add_child(nested_owned_identity)
	nested_owned_identity.owner = nested_owned_object
	var nested_owned_sprite := Sprite2D.new()
	nested_owned_sprite.name = "NestedObjectBuilderSprite"
	nested_owned_sprite.position = Vector2(900.0, 900.0)
	nested_owned_sprite.set_meta("object_builder_sprite", true)
	nested_owned_object.add_child(nested_owned_sprite)
	nested_owned_sprite.owner = nested_owned_object
	var nested_owned_host := Area2D.new()
	nested_owned_host.name = "Коллизия"
	nested_owned_host.collision_layer = 128
	nested_owned_host.collision_mask = 256
	nested_owned_host.set_meta("object_builder_collision_host", true)
	nested_owned_object.add_child(nested_owned_host)
	nested_owned_host.owner = nested_owned_object
	var nested_owned_shape := CollisionShape2D.new()
	nested_owned_shape.name = "Форма коллизии"
	nested_owned_shape.set_meta("object_builder_collision_shape", true)
	nested_owned_shape.position = Vector2(700.0, 800.0)
	var nested_circle := CircleShape2D.new()
	nested_circle.radius = 99.0
	nested_owned_shape.shape = nested_circle
	nested_owned_host.add_child(nested_owned_shape)
	nested_owned_shape.owner = nested_owned_object

	var collision_host := StaticBody2D.new()
	collision_host.name = "Коллизия"
	collision_host.position = Vector2(100.0, 50.0)
	collision_host.set_meta("object_builder_collision_host", true)
	collision_host.collision_layer = 4
	collision_host.collision_mask = 8
	scene_root.add_child(collision_host)
	collision_host.owner = scene_root

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "Форма коллизии"
	collision_shape.set_meta("object_builder_collision_shape", true)
	collision_shape.position = Vector2(23.0, -17.0)
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(46.0, 28.0)
	collision_shape.shape = rectangle
	collision_host.add_child(collision_shape)
	collision_shape.owner = scene_root

	var generated_scene_node := Node2D.new()
	generated_scene_node.name = "GeneratedVisual"
	generated_scene_node.position = Vector2(81.0, 92.0)
	generated_scene_node.visible = true
	generated_scene_node.set_meta("object_builder_node_id", "generated_visual")
	generated_scene_node.add_to_group(
		ObjectSceneStructureServiceScript.node_id_group_name("generated_visual"),
		true
	)
	scene_root.add_child(generated_scene_node)
	generated_scene_node.owner = scene_root

	var ownership_definition := DefinitionScript.new() as ObjectDefinition
	ownership_definition.object_id = "test_external_scene_sync"
	ownership_definition.display_name = "Pine"
	var generated_node_definition := NodeDefinitionScript.new() as ObjectNodeDefinition
	generated_node_definition.node_id = "generated_visual"
	generated_node_definition.node_type = "Node2D"
	generated_node_definition.node_name = "OldGeneratedName"
	generated_node_definition.enabled = false
	generated_node_definition.properties = {
		"position": Vector2.ZERO,
		"visible": false
	}
	ownership_definition.node_definitions.append(generated_node_definition)
	backend.call("_extract_managed_scene_visuals", ownership_definition, scene_root)
	_expect(
		generated_node_definition.node_name == "GeneratedVisual"
		and generated_node_definition.enabled
		and generated_node_definition.properties.get("position", Vector2.ZERO).is_equal_approx(Vector2(81.0, 92.0))
		and bool(generated_node_definition.properties.get("visible", false)),
		"Godot Inspector edits to generated Builder nodes are imported into ObjectNodeDefinition"
	)
	_expect(
		ownership_definition.collision_mode == "solid"
		and ownership_definition.collision_layer == 4
		and ownership_definition.collision_mask == 8
		and ownership_definition.collision_size.is_equal_approx(Vector2(46.0, 28.0))
		and ownership_definition.collision_offset.is_equal_approx(Vector2(123.0, 33.0)),
		"parent collision import ignores a nested object's marked Area2D and its shape"
	)
	_expect(
		ownership_definition.preview_sprite_offset.is_equal_approx(Vector2(5.0, 6.0)),
		"parent sprite import ignores a nested object's marked main sprite"
	)
	nested_owned_object.free()

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(scene_root)
	scene_root.free()
	_expect(pack_error == OK, "test PackedScene can be packed")
	if pack_error != OK:
		quit(1)
		return

	var definition := DefinitionScript.new() as ObjectDefinition
	definition.object_id = "test_external_scene_sync"
	definition.display_name = "Pine"
	definition.node_definitions = ownership_definition.node_definitions.duplicate(true)
	definition.scene = packed_scene

	var reopened_scene := packed_scene.instantiate()
	backend.call("_extract_managed_scene_visuals", definition, reopened_scene)
	_expect(definition.collision_enabled, "managed collision remains enabled after PackedScene round-trip")
	_expect(definition.collision_mode == "solid", "StaticBody2D is synchronized as solid collision")
	_expect(definition.collision_layer == 4 and definition.collision_mask == 8, "collision layer and mask are synchronized from Godot")
	_expect(
		definition.collision_offset.is_equal_approx(Vector2(123.0, 33.0)),
		"CollisionShape2D position includes the full nested host transform relative to the object root"
	)
	_expect(
		ObjectLibraryService.get_scene_root_object_id(reopened_scene) == "test_external_scene_sync",
		"durable object identity survives a PackedScene save/load round-trip"
	)
	_expect(
		definition.collision_size.is_equal_approx(Vector2(46.0, 28.0)),
		"RectangleShape2D size is synchronized from Godot"
	)
	# A parent-scene reconciliation must not find or delete collision nodes
	# that belong to a nested Object Builder instance.
	var nested_editor_object := Node2D.new()
	nested_editor_object.name = "NestedAfterReload"
	reopened_scene.add_child(nested_editor_object)
	nested_editor_object.owner = reopened_scene
	var nested_editor_host := Area2D.new()
	nested_editor_host.name = "Коллизия"
	nested_editor_host.collision_layer = 128
	nested_editor_object.add_child(nested_editor_host)
	nested_editor_host.owner = nested_editor_object
	var nested_editor_shape := CollisionShape2D.new()
	nested_editor_shape.name = "Форма коллизии"
	var nested_editor_circle := CircleShape2D.new()
	nested_editor_circle.radius = 31.0
	nested_editor_shape.shape = nested_editor_circle
	nested_editor_host.add_child(nested_editor_shape)
	nested_editor_shape.owner = nested_editor_object

	SceneDraftServiceScript._sync_managed_nodes(reopened_scene, definition)
	var nested_shape_after_sync := nested_editor_object.get_node_or_null("Коллизия/Форма коллизии") as CollisionShape2D
	_expect(
		nested_shape_after_sync != null
		and nested_shape_after_sync.shape is CircleShape2D
		and is_equal_approx((nested_shape_after_sync.shape as CircleShape2D).radius, 31.0),
		"parent collision reconciliation preserves a nested object's independent collider"
	)
	var resynced_shape := reopened_scene.find_child("Форма коллизии", true, false) as CollisionShape2D
	_expect(
		resynced_shape != null
		and resynced_shape.position.is_equal_approx(Vector2(23.0, -17.0)),
		"writing the root-relative offset back into a transformed collision host does not double its translation"
	)
	_expect(
		resynced_shape != null
		and (resynced_shape.get_parent() as Node2D).position.is_equal_approx(Vector2(100.0, 50.0)),
		"the user's transformed collision host remains in place during Web Builder reconciliation"
	)
	reopened_scene.free()

	var parts: Array[Dictionary] = [{
		"id": "root",
		"name": "Pine",
		"kind": "root",
		"nodeType": "Node2D",
		"parentId": ""
	}]
	backend.call("_append_external_scene_parts", definition, parts)

	_expect(parts.size() == 2, "managed Object Builder sprite is excluded and manual scene node is exposed")
	if parts.size() >= 2:
		var external_part: Dictionary = parts[1]
		_expect(
			bool(external_part.get("external", false)),
			"Godot-authored node is marked as external/read-only"
		)
		_expect(
			str(external_part.get("nodePath", "")) == "ManualDecoration",
			"external node path is synchronized"
		)
		var properties: Dictionary = external_part.get("properties", {})
		_expect(
			properties.has("position"),
			"external node inspector properties are synchronized"
		)
		_expect(
			properties.has("visible") and properties.visible == false,
			"external node visibility changes are synchronized"
		)
		var serialized_position: Variant = properties.get("position", {})
		_expect(
			serialized_position is Dictionary
			and is_equal_approx(float(serialized_position.get("x", 0.0)), 12.0)
			and is_equal_approx(float(serialized_position.get("y", 0.0)), 34.0),
			"external Vector2 values are serialized without losing coordinates"
		)

	var root_properties: Dictionary = parts[0].get("properties", {})
	_expect(
		root_properties.has("position"),
		"root scene inspector properties are included"
	)

	# Keep an old PackedScene cached in the ObjectDefinition while the actual
	# saved .tscn receives newer Inspector values. Serialization must prefer the
	# file saved by Godot instead of silently rendering that stale PackedScene.
	var sync_test_scene_path := ObjectLibraryService.SCENES_PATH.path_join("objects").path_join("__scene_sync_properties_smoke.tscn")
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(sync_test_scene_path.get_base_dir())
	)
	var edited_for_disk := packed_scene.instantiate()
	var edited_manual := edited_for_disk.get_node("ManualDecoration") as Node2D
	edited_manual.position = Vector2(56.0, 78.0)
	edited_manual.visible = true
	var edited_generated := edited_for_disk.get_node("GeneratedVisual") as Node2D
	edited_generated.position = Vector2(181.0, 192.0)
	edited_generated.visible = false
	edited_for_disk.position = Vector2(3.0, 4.0)
	var latest_packed_scene := PackedScene.new()
	var latest_pack_error := latest_packed_scene.pack(edited_for_disk)
	edited_for_disk.free()
	var packed_identity_check := latest_packed_scene.instantiate()
	var packed_identity_node := packed_identity_check.get_node("GeneratedVisual") as Node2D
	_expect(
		packed_identity_node != null
		and packed_identity_node.owner == packed_identity_check
		and packed_identity_node.has_meta("object_builder_node_id")
		and str(packed_identity_node.get_meta("object_builder_node_id")) == "generated_visual"
		and packed_identity_node.is_in_group(
			ObjectSceneStructureServiceScript.node_id_group_name("generated_visual")
		),
		"generated node identity survives saving and reloading its PackedScene"
	)
	packed_identity_check.free()
	_expect(latest_pack_error == OK, "updated Godot scene can be packed for property freshness test")
	var disk_save_error := ResourceSaver.save(latest_packed_scene, sync_test_scene_path)
	_expect(disk_save_error == OK, "updated Godot scene can be saved to its .tscn path")
	if disk_save_error == OK:
		var diagnostic_packed := ResourceLoader.load(
			sync_test_scene_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE_DEEP
		) as PackedScene
		var diagnostic_root := diagnostic_packed.instantiate() as Node2D if diagnostic_packed != null else null
		var diagnostic_node := diagnostic_root.get_node_or_null("GeneratedVisual") as Node2D if diagnostic_root != null else null
		var diagnostic_definition := definition.duplicate(true) as ObjectDefinition
		if diagnostic_root != null and diagnostic_node != null:
			backend.call(
				"_extract_managed_node_definitions",
				diagnostic_definition,
				diagnostic_root
			)
			_expect(
				diagnostic_definition.node_definitions[0].properties.get("position", Vector2.ZERO).is_equal_approx(Vector2(181.0, 192.0))
				and not bool(diagnostic_definition.node_definitions[0].properties.get("visible", true)),
				"direct node extraction reads the actual saved Inspector values"
			)
			diagnostic_root.free()
		var stale_definition := definition.duplicate(true) as ObjectDefinition
		stale_definition.scene = packed_scene
		stale_definition.scene_path = sync_test_scene_path
		var fresh_serialized: Dictionary = backend.call(
			"_serialize_definition",
			stale_definition,
			true
		)
		var fresh_parts: Array = fresh_serialized.get("parts", [])
		var fresh_manual: Dictionary = {}
		for part in fresh_parts:
			if str(part.get("nodePath", "")) == "ManualDecoration":
				fresh_manual = part
				break
		var fresh_properties: Dictionary = fresh_manual.get("properties", {})
		var fresh_position: Dictionary = fresh_properties.get("position", {})
		_expect(
			is_equal_approx(float(fresh_position.get("x", 0.0)), 56.0)
			and is_equal_approx(float(fresh_position.get("y", 0.0)), 78.0)
			and bool(fresh_properties.get("visible", false)),
			"external scene serialization reloads the newest Inspector properties from disk instead of a stale definition.scene"
		)
		var live_override_root := packed_scene.instantiate()
		var live_override_node := live_override_root.get_node("ManualDecoration") as Node2D
		live_override_node.position = Vector2(101.0, 202.0)
		var live_serialized: Dictionary = backend.call(
			"_serialize_definition",
			stale_definition,
			true,
			live_override_root
		)
		var live_parts: Array = live_serialized.get("parts", [])
		var live_manual: Dictionary = {}
		for part in live_parts:
			if str(part.get("nodePath", "")) == "ManualDecoration":
				live_manual = part
				break
		var live_properties: Dictionary = live_manual.get("properties", {})
		var live_position: Dictionary = live_properties.get("position", {})
		_expect(
			is_equal_approx(float(live_position.get("x", 0.0)), 101.0)
			and is_equal_approx(float(live_position.get("y", 0.0)), 202.0),
			"live Godot scene root takes precedence over any cached PackedScene snapshot"
		)
		live_override_root.free()

		# Simulate a complete Godot restart: a fresh backend has no scene_saved
		# event and no live editor root. It must find every linked scene on disk,
		# refresh its ObjectDefinition, and return the changed Inspector values.
		stale_definition.display_name = "__test_offline_scene_rescan"
		stale_definition.category = "Other"
		stale_definition.object_id = "test_external_scene_sync_offline"
		var offline_definition_save := ObjectLibraryService.save_definition(stale_definition)
		_expect(
			offline_definition_save == OK,
			"offline rescan test definition is stored in the project library"
		)
		if offline_definition_save == OK:
			var restarted_backend := BackendScript.new()
			var disk_rescan: Dictionary = restarted_backend.call(
				"_refresh_all_managed_scenes_from_disk",
				PackedStringArray()
			)
			_expect(
				bool(disk_rescan.get("ok", false))
				and int(disk_rescan.get("refreshed_count", 0)) >= 1,
				"a fresh backend reconciles linked Godot scenes from disk without scene_saved"
			)
			var offline_reloaded := ObjectLibraryService.load_definitions()
			var offline_definition: ObjectDefinition
			for candidate in offline_reloaded:
				if candidate.object_id == "test_external_scene_sync_offline":
					offline_definition = candidate
					break
			var offline_node_position := Vector2.ZERO
			var offline_node_visible := true
			if offline_definition != null and not offline_definition.node_definitions.is_empty():
				offline_node_position = offline_definition.node_definitions[0].properties.get("position", Vector2.ZERO)
				offline_node_visible = bool(offline_definition.node_definitions[0].properties.get("visible", true))
			_expect(
				offline_definition != null
				and offline_definition.node_definitions.size() == 1
				and offline_node_position.is_equal_approx(Vector2(181.0, 192.0))
				and not offline_node_visible,
				"full restart disk scan imports saved Inspector properties for Builder-created nodes"
			)
			var offline_external_definitions: Array = disk_rescan.get("external_definitions", [])
			var found_manual := false
			for external_definition in offline_external_definitions:
				if str(external_definition.get("objectId", "")) != "test_external_scene_sync_offline":
					continue
				for part in external_definition.get("parts", []):
					if str(part.get("nodePath", "")) != "ManualDecoration":
						continue
					var part_position: Dictionary = part.get("properties", {}).get("position", {})
					found_manual = (
						is_equal_approx(float(part_position.get("x", 0.0)), 56.0)
						and is_equal_approx(float(part_position.get("y", 0.0)), 78.0)
						and bool(part.get("properties", {}).get("visible", false))
					)
			_expect(
				found_manual,
				"full restart disk scan returns refreshed ordinary-node Inspector values to the WebView"
			)
			if offline_definition != null and not offline_definition.resource_path.is_empty():
				DirAccess.remove_absolute(ProjectSettings.globalize_path(offline_definition.resource_path))
			restarted_backend.call("cleanup")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sync_test_scene_path))

	if failures.is_empty():
		print("Web Object Builder Godot scene sync smoke tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_legacy_mechanic_property_migration(backend: RefCounted) -> void:
	var definition := DefinitionScript.new() as ObjectDefinition
	definition.object_id = "legacy_mechanic_migration_smoke"
	definition.display_name = "Legacy Mechanic Migration Smoke"
	definition.category = "Other"

	var health := ObjectCapabilityCatalog.create_selection("has_health")
	var damageable := ObjectCapabilityCatalog.create_selection("can_receive_damage")
	var loot := ObjectCapabilityCatalog.create_selection("drops_loot_on_destroy")
	_expect(
		health != null and damageable != null and loot != null,
		"legacy migration test resolves health, damage and destruction capabilities"
	)
	if health == null or damageable == null or loot == null:
		return

	definition.capabilities = [health, damageable, loot]
	definition.custom_properties = [
		_make_legacy_property("health", "Float", 75.0),
		_make_legacy_property("material_type", "String", "wood"),
		_make_legacy_property("required_tool_id", "String", "axe"),
		_make_legacy_property("hit_radius", "Float", 28.0),
		_make_legacy_property("drop_item_id", "String", "wood"),
		_make_legacy_property("drop_amount", "Integer", 3),
		_make_legacy_property("custom_note", "String", "keep this")
	]
	var changed := bool(backend.call("_migrate_legacy_mechanic_properties", definition))
	_expect(changed, "legacy mechanic properties are detected and migrated")
	var remaining_ids := PackedStringArray()
	for property_definition in definition.custom_properties:
		if property_definition != null:
			remaining_ids.append(property_definition.property_id)
	_expect(
		not remaining_ids.has("health")
		and not remaining_ids.has("material_type")
		and not remaining_ids.has("required_tool_id")
		and not remaining_ids.has("hit_radius")
		and not remaining_ids.has("drop_item_id")
		and not remaining_ids.has("drop_amount"),
		"system-owned legacy properties are removed from the user property list"
	)
	_expect(
		remaining_ids.has("custom_note"),
		"unrelated user-defined properties survive legacy migration"
	)

	var health_settings: Dictionary = health.get_component_settings("health")
	var damage_settings: Dictionary = damageable.get_component_settings("damageable")
	var loot_settings: Dictionary = loot.get_component_settings("drops_loot_on_destroy")
	_expect(
		is_equal_approx(float(health_settings.get("max_health", -1.0)), 75.0)
		and is_equal_approx(float(health_settings.get("starting_health", -1.0)), 75.0),
		"legacy health is moved into the Health mechanic settings"
	)
	_expect(
		str(damage_settings.get("material_type", "")) == "wood"
		and str(damage_settings.get("required_tool_id", "")) == "axe"
		and is_equal_approx(float(damage_settings.get("hit_radius", -1.0)), 28.0),
		"legacy material, tool and hit radius are moved into Damageable settings"
	)
	var migrated_loot: Variant = JSON.parse_string(str(loot_settings.get("loot_table_json", "[]")))
	var migrated_loot_entry: Dictionary = {}
	if migrated_loot is Array and not migrated_loot.is_empty():
		var first_migrated_entry: Variant = migrated_loot[0]
		if first_migrated_entry is Dictionary:
			migrated_loot_entry = first_migrated_entry
	_expect(
		migrated_loot_entry.get("item_id", "") == "wood"
		and int(migrated_loot_entry.get("minimum", 0)) == 3
		and int(migrated_loot_entry.get("maximum", 0)) == 3,
		"legacy drop item and amount are migrated into the destruction loot table"
	)

	# A preconfigured new loot table must win over stale legacy fields.
	var configured_definition := DefinitionScript.new() as ObjectDefinition
	var configured_loot := ObjectCapabilityCatalog.create_selection("drops_loot_on_destroy")
	configured_loot.set_component_setting(
		"drops_loot_on_destroy",
		"loot_table_json",
		JSON.stringify([{"item_id": "stone", "chance": 0.5, "minimum": 2, "maximum": 4}])
	)
	configured_definition.capabilities = [configured_loot]
	configured_definition.custom_properties = [
		_make_legacy_property("drop_item_id", "String", "wood"),
		_make_legacy_property("drop_amount", "Integer", 3)
	]
	backend.call("_migrate_legacy_mechanic_properties", configured_definition)
	var preserved_loot_settings: Dictionary = configured_loot.get_component_settings("drops_loot_on_destroy")
	var preserved_loot: Variant = JSON.parse_string(str(preserved_loot_settings.get("loot_table_json", "[]")))
	var preserved_loot_entry: Dictionary = {}
	if preserved_loot is Array and not preserved_loot.is_empty():
		var first_preserved_entry: Variant = preserved_loot[0]
		if first_preserved_entry is Dictionary:
			preserved_loot_entry = first_preserved_entry
	_expect(
		preserved_loot_entry.get("item_id", "") == "stone",
		"migration preserves an already configured modern loot table"
	)

	# Even empty legacy defaults are obsolete once the new loot capability owns the field.
	var blank_definition := DefinitionScript.new() as ObjectDefinition
	blank_definition.capabilities = [ObjectCapabilityCatalog.create_selection("drops_loot_on_destroy")]
	blank_definition.custom_properties = [
		_make_legacy_property("drop_item_id", "String", ""),
		_make_legacy_property("drop_amount", "Integer", 0)
	]
	backend.call("_migrate_legacy_mechanic_properties", blank_definition)
	_expect(
		blank_definition.custom_properties.is_empty(),
		"empty obsolete drop fields are removed when the loot mechanic is installed"
	)

	# Objects that already use only the new settings must not be rewritten on
	# every editor start just because the loot capability is present.
	var clean_definition := DefinitionScript.new() as ObjectDefinition
	clean_definition.capabilities = [ObjectCapabilityCatalog.create_selection("drops_loot_on_destroy")]
	clean_definition.custom_properties = [
		_make_legacy_property("custom_note", "String", "keep this")
	]
	var clean_migration_changed := bool(
		backend.call("_migrate_legacy_mechanic_properties", clean_definition)
	)
	_expect(
		not clean_migration_changed
		and clean_definition.custom_properties.size() == 1
		and clean_definition.custom_properties[0].property_id == "custom_note",
		"objects without legacy loot fields are not needlessly rewritten"
	)


func _test_legacy_migration_after_capability_enable() -> void:
	var migration_backend := BackendScript.new()
	var created: Dictionary = migration_backend.call(
		"_create_object",
		{
			"mode": "new",
			"name": "Late Capability Migration Smoke",
			"category": "Other",
			"profile_id": ""
		}
	)
	_expect(bool(created.get("ok", false)), "a clean draft can be created for late capability migration")
	if not bool(created.get("ok", false)):
		migration_backend.call("cleanup")
		return

	var definition := migration_backend.call("get_working_definition") as ObjectDefinition
	if definition == null:
		_expect(false, "late migration draft exposes its working ObjectDefinition")
		migration_backend.call("cleanup")
		return
	definition.custom_properties = [
		_make_legacy_property("health", "Float", 64.0),
		_make_legacy_property("material_type", "String", "wood"),
		_make_legacy_property("required_tool_id", "String", "axe"),
		_make_legacy_property("hit_radius", "Float", 26.0),
		_make_legacy_property("drop_item_id", "String", "wood"),
		_make_legacy_property("drop_amount", "Integer", 2),
		_make_legacy_property("custom_note", "String", "keep after enabling")
	]

	var damage_plan: Dictionary = migration_backend.call(
		"_plan_capability",
		{"capability_id": "can_receive_damage", "enabled": true}
	)
	_expect(bool(damage_plan.get("ok", false)), "Damageable can be enabled for a legacy object")
	if bool(damage_plan.get("ok", false)):
		var damage_commit: Dictionary = migration_backend.call("_commit_capability")
		_expect(bool(damage_commit.get("ok", false)), "enabling Damageable commits successfully")
		definition = migration_backend.call("get_working_definition") as ObjectDefinition
		var damage_settings := definition.capabilities
		var migrated_damage := false
		for selection in damage_settings:
			if selection != null and selection.capability_id == "can_receive_damage":
				var values := selection.get_component_settings("damageable")
				migrated_damage = (
					str(values.get("material_type", "")) == "wood"
					and str(values.get("required_tool_id", "")) == "axe"
					and is_equal_approx(float(values.get("hit_radius", 0.0)), 26.0)
				)
		_expect(migrated_damage, "enabling Damageable immediately adopts legacy material, tool and radius")
		var no_damage_legacy := true
		for property_definition in definition.custom_properties:
			if property_definition != null and property_definition.property_id in [
				"health", "material_type", "required_tool_id", "hit_radius"
			]:
				no_damage_legacy = false
		_expect(no_damage_legacy, "Damageable and Health fields disappear from generic custom properties")

	var loot_plan: Dictionary = migration_backend.call(
		"_plan_capability",
		{"capability_id": "drops_loot_on_destroy", "enabled": true}
	)
	_expect(bool(loot_plan.get("ok", false)), "loot-on-destroy can be enabled for a legacy object")
	if bool(loot_plan.get("ok", false)):
		var loot_commit: Dictionary = migration_backend.call("_commit_capability")
		_expect(bool(loot_commit.get("ok", false)), "enabling loot-on-destroy commits successfully")
		definition = migration_backend.call("get_working_definition") as ObjectDefinition
		var migrated_drop := false
		for selection in definition.capabilities:
			if selection != null and selection.capability_id == "drops_loot_on_destroy":
				var values := selection.get_component_settings("drops_loot_on_destroy")
				var parsed: Variant = JSON.parse_string(str(values.get("loot_table_json", "[]")))
				if parsed is Array and not parsed.is_empty():
					var entry: Variant = parsed[0]
					if entry is Dictionary:
						migrated_drop = (
							str(entry.get("item_id", "")) == "wood"
							and int(entry.get("minimum", 0)) == 2
							and int(entry.get("maximum", 0)) == 2
						)
		_expect(migrated_drop, "enabling loot-on-destroy immediately migrates drop_item_id and drop_amount")
		var generic_drop_fields_removed := true
		for property_definition in definition.custom_properties:
			if property_definition != null and property_definition.property_id in ["drop_item_id", "drop_amount"]:
				generic_drop_fields_removed = false
		_expect(generic_drop_fields_removed, "drop fields disappear from generic custom properties after enabling loot")

	var unrelated_property_retained := false
	for property_definition in definition.custom_properties:
		if property_definition != null and property_definition.property_id == "custom_note":
			unrelated_property_retained = str(property_definition.default_value) == "keep after enabling"
	_expect(unrelated_property_retained, "late mechanic migration retains unrelated custom properties")
	migration_backend.call("cleanup")


func _make_legacy_property(property_id: String, value_type: String, value: Variant) -> ObjectPropertyDefinition:
	var property_definition := PropertyDefinitionScript.new() as ObjectPropertyDefinition
	property_definition.property_id = property_id
	property_definition.display_name = property_id
	property_definition.value_type = value_type
	property_definition.default_value = value
	return property_definition


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
