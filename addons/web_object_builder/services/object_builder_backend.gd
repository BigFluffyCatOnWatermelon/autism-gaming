@tool
extends RefCounted
## Shared data/application layer for the web workspace.
## ObjectDefinition resources and ObjectLibraryService are the only source of truth.

const ModuleLoader = preload("res://scripts/object_system/mechanic_module_loader.gd")
const CreationService = preload("res://addons/web_object_builder/services/object_creation_service.gd")
const SceneDraftService = preload("res://addons/web_object_builder/services/scene_draft_service.gd")
const LibraryActionsService = preload("res://addons/web_object_builder/services/library_actions_service.gd")
const PropertyScript = preload("res://scripts/object_system/object_property_definition.gd")
const NodeDefinitionScript = preload("res://scripts/object_system/object_node_definition.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const ObjectSceneStructureServiceScript = preload("res://scripts/object_system/object_scene_structure_service.gd")
const BuiltinTemplateCatalogScript = preload("res://scripts/object_system/object_builtin_template_catalog.gd")
const ItemCatalogServiceScript = preload("res://scripts/item_catalog_service.gd")

const METADATA_SECTION := "ObjectBuilder"
const RECENT_LIMIT := 20

var _working: ObjectDefinition
var _open_drafts: Dictionary = {}
var _new_draft_ids: Dictionary = {}
var _saved_draft_ids: Dictionary = {}
var _dirty_draft_ids: Dictionary = {}
var _pending_selections: Array[ObjectCapabilitySelection] = []
var _pending_plan: Dictionary = {}
var _initialized := false
var _favorites := PackedStringArray()
var _recent := PackedStringArray()
var _collections: Dictionary = {}
var _custom_categories := PackedStringArray()


func handle_request(kind: String, payload: Dictionary = {}) -> Dictionary:
	_ensure_initialized()
	match kind:
		"workspace_get_state":
			return _ok({"workspace": get_workspace_state()})
		"filesystem_rescan":
			return _rescan_library_filesystem()
		"external_scene_saved":
			return _refresh_external_scene_from_godot(
				str(payload.get("scene_path", "")),
				payload.get("scene_root") as Node
			)
		"external_scenes_rescan":
			return _refresh_all_managed_scenes_from_disk(
				payload.get("skip_scene_paths", [])
			)
		"external_definition_saved":
			return _refresh_external_definition_from_godot(str(payload.get("resource_path", "")))
		"workspace_cleanup":
			cleanup()
			return _ok()
		"native_editor_open":
			return _request_native_editor_open(str(payload.get("object_id", "")))
		"workspace_sync":
			return _sync_working(payload)
		"object_create":
			return _create_object(payload)
		"object_create_related":
			return _create_related_object(payload)
		"object_open":
			return _open_object(str(payload.get("object_id", "")))
		"object_close":
			return _close_object(payload)
		"object_update":
			return _update_metadata(payload)
		"object_save":
			return _save_working(payload)
		"object_save_as":
			return _save_working_as(payload)
		"sprite_upload":
			return _set_preview_texture(payload)
		"sprite_clear":
			return _clear_preview_texture()
		"sprite_sheet_upload":
			return _set_sprite_sheet(payload)
		"sprite_sheet_clear":
			return _clear_sprite_sheet()
		"object_duplicate":
			return _duplicate_object(str(payload.get("object_id", "")))
		"object_create_template":
			return _create_template(str(payload.get("object_id", "")))
		"object_delete":
			return _delete_object(str(payload.get("object_id", "")))
		"capability_plan":
			return _plan_capability(payload)
		"capability_commit":
			return _commit_capability()
		"capability_settings_save":
			return _save_capability_settings(payload)
		"property_add":
			return _add_property(payload)
		"property_update":
			return _update_property(payload)
		"property_remove":
			return _remove_property(str(payload.get("property_id", "")))
		"component_add":
			return _add_component(str(payload.get("component_id", "")))
		"component_remove":
			return _remove_component(str(payload.get("component_id", "")))
		"component_settings_save":
			return _save_component_settings(payload)
		"part_add":
			return _add_part(payload)
		"part_update":
			return _update_part(payload)
		"part_remove":
			return _remove_part(str(payload.get("part_id", "")))
		"relation_add":
			return _add_relation(payload)
		"relation_embed_as_part":
			return _embed_relation_as_part(payload)
		"relation_update":
			return _update_relation(payload)
		"relation_remove":
			return _remove_relation(str(payload.get("relation_id", "")))
		"category_add":
			return _add_category(str(payload.get("name", "")))
		"category_rename":
			return _rename_category(str(payload.get("old_name", "")), str(payload.get("new_name", "")))
		"category_delete":
			return _delete_category(str(payload.get("category", "")))
		"template_classify":
			return _classify_template(payload)
		"favorite_toggle":
			return _toggle_favorite(str(payload.get("object_id", "")))
		"recent_record":
			_record_recent(str(payload.get("object_id", "")))
			return _ok({"workspace": get_workspace_state()})
		"collection_create":
			return _create_collection(str(payload.get("name", "")))
		"collection_update":
			return _update_collection(payload)
		"collection_delete":
			return _delete_collection(str(payload.get("collection_id", "")))
		_:
			return _fail("Неизвестная команда Object Builder: " + kind)



func _request_native_editor_open(object_id: String) -> Dictionary:
	var clean_id := object_id.strip_edges()
	if clean_id.is_empty():
		return _ok({"object_id": "", "message": "Открыть Web Object Builder."})
	if _find_definition(clean_id) == null and _find_template(clean_id) == null and not _open_drafts.has(clean_id):
		return _fail("Объект или шаблон не найден в библиотеке: " + clean_id)
	return _ok({
		"object_id": clean_id,
		"message": "Объект передан в Web Object Builder."
	})

func get_workspace_state() -> Dictionary:
	var objects: Array[Dictionary] = []
	var templates: Array[Dictionary] = []
	var categories := PackedStringArray()
	var subcategories: Dictionary = {}
	for definition in ObjectLibraryService.load_definitions():
		objects.append(_serialize_definition(definition))
		_add_classification(definition, categories, subcategories)
	for definition in BuiltinTemplateCatalogScript.get_all_definitions():
		templates.append(_serialize_definition(definition))
		_add_classification(definition, categories, subcategories)
	for definition in ObjectLibraryService.load_templates():
		templates.append(_serialize_definition(definition))
		_add_classification(definition, categories, subcategories)
	if _working != null:
		_add_classification(_working, categories, subcategories)
	for custom_category in _custom_categories:
		if not custom_category.is_empty() and not categories.has(custom_category):
			categories.append(custom_category)
	categories.sort()
	var open_documents: Array[Dictionary] = []
	var open_ids: Dictionary = {}
	for object_id in _open_drafts:
		var draft := _open_drafts[object_id] as ObjectDefinition
		if draft == null:
			continue
		open_documents.append(_serialize_definition(draft, true))
		open_ids[str(object_id)] = true
	if _working != null and not open_ids.has(_working.object_id):
		open_documents.append(_serialize_definition(_working, true))
	var capability_catalog := _get_capabilities()
	var profiles := _get_profiles()
	return {
		"protocol_version": 1,
		"objects": objects,
		"templates": templates,
		"working": _serialize_definition(_working, true) if _working != null else null,
		"open_documents": open_documents,
		"capabilities": capability_catalog.items,
		"capability_categories": capability_catalog.categories,
		"components": _get_components().items,
		"component_categories": _get_components().categories,
		"creation_profiles": profiles,
		"categories": categories,
		"subcategories": subcategories,
		"physics_layers": _get_physics_layer_names(),
		"favorites": _favorites.duplicate(),
		"recent_ids": _recent.duplicate(),
		"collections": _collections.duplicate(true),
		"counts": {
			"objects": objects.size(),
			"templates": templates.size(),
			"capabilities": capability_catalog.items.size(),
			"profiles": profiles.size()
		}
	}


func get_working_definition() -> ObjectDefinition:
	return _working


func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	for error_message in ModuleLoader.register_modules_in_directory():
		push_warning("Web Object Builder: " + error_message)
	_migrate_legacy_library_storage()
	# Filesystem discovery is deferred to the plugin after EditorFileSystem's
	# initial scan has completed. Calling scan() during _enter_tree can race
	# Godot's own first scan and leave its worker thread active at shutdown.
	var settings := EditorInterface.get_editor_settings()
	_favorites = _string_array(settings.get_project_metadata(METADATA_SECTION, "favorites", PackedStringArray()))
	_recent = _string_array(settings.get_project_metadata(METADATA_SECTION, "recent", PackedStringArray()))
	_collections = _normalize_collections(settings.get_project_metadata(METADATA_SECTION, "custom_collections", {}))
	_custom_categories = _string_array(settings.get_project_metadata(METADATA_SECTION, "custom_categories", PackedStringArray()))


func _migrate_legacy_library_storage() -> void:
	# Migrate both localized legacy paths and the earlier ID-based filenames.
	# Existing ObjectDefinition IDs remain unchanged; only their disk names are
	# normalized to readable ASCII slugs derived from the display name.
	var migration_found := false
	var definitions := ObjectLibraryService.load_definitions()
	var templates := ObjectLibraryService.load_templates()
	for definition in definitions:
		if _definition_paths_need_migration(definition):
			migration_found = true
		_migrate_legacy_definition(definition, false)
	for definition in templates:
		if _definition_paths_need_migration(definition):
			migration_found = true
		_migrate_legacy_definition(definition, true)
	# The plugin performs one safe deferred EditorFileSystem.scan() after
	# startup. Do not start a second scan from inside backend initialization.


## Moves system-owned fields from old generic properties into their owning mechanics.
## Unrelated custom properties are retained unchanged.
func _migrate_legacy_mechanic_properties(definition: ObjectDefinition) -> bool:
	if definition == null or definition.custom_properties.is_empty():
		return false
	var health_selection: ObjectCapabilitySelection
	var damage_selection: ObjectCapabilitySelection
	var loot_selection: ObjectCapabilitySelection
	for selection in definition.capabilities:
		if selection == null or not selection.enabled:
			continue
		match selection.capability_id:
			"has_health":
				health_selection = selection
			"can_receive_damage":
				damage_selection = selection
			"drops_loot_on_destroy":
				loot_selection = selection

	var legacy_values: Dictionary = {}
	for property_definition in definition.custom_properties:
		if property_definition != null:
			legacy_values[property_definition.property_id] = property_definition.default_value
	var remove_ids: Dictionary = {}

	if health_selection != null and legacy_values.has("health"):
		var health_settings := health_selection.get_component_settings("health")
		var old_health := maxf(0.0, float(legacy_values["health"]))
		if not health_settings.has("max_health"):
			health_selection.set_component_setting("health", "max_health", old_health)
		if not health_settings.has("starting_health"):
			health_selection.set_component_setting("health", "starting_health", old_health)
		remove_ids["health"] = true

	if damage_selection != null:
		var damage_settings := damage_selection.get_component_settings("damageable")
		for property_id in ["material_type", "hit_radius"]:
			if not legacy_values.has(property_id):
				continue
			var current_value: Variant = damage_settings.get(property_id, null)
			if current_value == null or (current_value is String and str(current_value).strip_edges().is_empty()):
				damage_selection.set_component_setting("damageable", property_id, legacy_values[property_id])
			remove_ids[property_id] = true

		var old_tool := str(legacy_values.get("required_tool_id", "")).strip_edges()
		if old_tool.is_empty():
			old_tool = str(legacy_values.get("required_tool", "")).strip_edges()
		if legacy_values.has("required_tool_id") or legacy_values.has("required_tool"):
			var configured_tool := str(damage_settings.get("required_tool_id", "")).strip_edges()
			if configured_tool.is_empty() and not old_tool.is_empty():
				damage_selection.set_component_setting("damageable", "required_tool_id", old_tool)
			remove_ids["required_tool_id"] = true
			remove_ids["required_tool"] = true

	if loot_selection != null:
		var loot_settings := loot_selection.get_component_settings("drops_loot_on_destroy")
		var existing_table := str(loot_settings.get("loot_table_json", "[]")).strip_edges()
		var existing_entries: Variant = JSON.parse_string(existing_table)
		var table_is_configured: bool = false
		if existing_entries is Array:
			table_is_configured = not existing_entries.is_empty()
		var item_id := str(legacy_values.get("drop_item_id", "")).strip_edges()
		var amount := maxi(0, int(legacy_values.get("drop_amount", 1)))
		if (
			not table_is_configured
			and (legacy_values.has("drop_item_id") or legacy_values.has("drop_amount"))
			and not item_id.is_empty()
			and amount > 0
		):
			var migrated_table := [{
				"item_id": item_id,
				"chance": 1.0,
				"minimum": amount,
				"maximum": amount
			}]
			loot_selection.set_component_setting(
				"drops_loot_on_destroy",
				"loot_table_json",
				JSON.stringify(migrated_table)
			)
		# Once the new loot mechanic is installed, its table is authoritative.
		# Remove legacy fields even when empty so they do not remain visible as
		# misleading editable custom properties.
		if legacy_values.has("drop_item_id"):
			remove_ids["drop_item_id"] = true
		if legacy_values.has("drop_amount"):
			remove_ids["drop_amount"] = true

	if remove_ids.is_empty():
		return false
	var retained_properties: Array[ObjectPropertyDefinition] = []
	for property_definition in definition.custom_properties:
		if property_definition == null:
			continue
		if not remove_ids.has(property_definition.property_id):
			retained_properties.append(property_definition)
	definition.custom_properties = retained_properties
	return true


func _definition_paths_need_migration(definition: ObjectDefinition) -> bool:
	if definition == null:
		return false
	var target_definition_path := ObjectLibraryService.get_definition_path_for_definition(definition)
	var target_scene_path := ObjectLibraryService.get_scene_path_for_definition(definition)
	return (
		(
			ObjectLibraryService.is_managed_definition_path(definition.resource_path)
			and definition.resource_path != target_definition_path
		)
		or (
			ObjectLibraryService.is_managed_scene_path(definition.scene_path)
			and definition.scene_path != target_scene_path
		)
	)


func _migrate_legacy_definition(definition: ObjectDefinition, as_template: bool) -> void:
	if definition == null:
		return
	definition.is_template = as_template
	ObjectLibraryService.ensure_unique_display_name(definition)
	var mechanic_settings_migrated := _migrate_legacy_mechanic_properties(definition)

	var old_definition_path := definition.resource_path
	var old_scene_path := definition.scene_path
	var target_definition_path := ObjectLibraryService.get_definition_path_for_definition(definition)
	var target_scene_path := ObjectLibraryService.get_scene_path_for_definition(definition)
	var needs_definition_migration := (
		ObjectLibraryService.is_managed_definition_path(old_definition_path)
		and old_definition_path != target_definition_path
	)
	var needs_scene_migration := (
		ObjectLibraryService.is_managed_scene_path(old_scene_path)
		and old_scene_path != target_scene_path
	)
	if not needs_definition_migration and not needs_scene_migration:
		if mechanic_settings_migrated:
			var mechanic_save_error := (
				ObjectLibraryService.save_template(definition)
				if as_template
				else ObjectLibraryService.save_definition(definition)
			)
			if mechanic_save_error != OK:
				push_warning(
					"Web Object Builder: legacy mechanic settings could not be saved for %s (error %d)."
					% [definition.display_name, mechanic_save_error]
				)
		return

	var old_scene_resource := definition.scene
	var old_scene_bytes := (
		FileAccess.get_file_as_bytes(old_scene_path)
		if not old_scene_path.is_empty() and FileAccess.file_exists(old_scene_path)
		else PackedByteArray()
	)
	var target_scene_existed := FileAccess.file_exists(target_scene_path)
	var target_scene_bytes := (
		FileAccess.get_file_as_bytes(target_scene_path)
		if target_scene_existed
		else PackedByteArray()
	)

	if needs_scene_migration:
		if not old_scene_bytes.is_empty():
			var scene_result := SceneDraftService.sync_scene(definition)
			if not bool(scene_result.get("ok", false)):
				push_warning(
					"Web Object Builder: scene filename migration skipped for %s: %s"
					% [definition.display_name, str(scene_result.get("message", ""))]
				)
				return
		elif target_scene_existed:
			definition.scene = ResourceLoader.load(
				target_scene_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
			) as PackedScene
			definition.scene_path = target_scene_path
		else:
			# Do not retain a pointer to a scene file which no longer exists.
			definition.scene = null
			definition.scene_path = ""

	var save_error := (
		ObjectLibraryService.save_template(definition)
		if as_template
		else ObjectLibraryService.save_definition(definition)
	)
	if save_error == OK:
		return

	# Preserve both scene files and the old resource pointer if the matching
	# ObjectDefinition could not be moved to its readable filename.
	if needs_scene_migration:
		if not old_scene_bytes.is_empty():
			var old_scene_file := FileAccess.open(old_scene_path, FileAccess.WRITE)
			if old_scene_file != null:
				old_scene_file.store_buffer(old_scene_bytes)
				old_scene_file.close()
		if target_scene_existed:
			var target_file := FileAccess.open(target_scene_path, FileAccess.WRITE)
			if target_file != null:
				target_file.store_buffer(target_scene_bytes)
				target_file.close()
		elif FileAccess.file_exists(target_scene_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target_scene_path))
		definition.scene = old_scene_resource
		definition.scene_path = old_scene_path
	push_warning(
		"Web Object Builder: could not migrate library record '%s' (error %d)."
		% [definition.display_name, save_error]
	)


func _rescan_library_filesystem() -> Dictionary:
	var imported_names := _scan_library_filesystem()
	return _ok({
		"workspace": get_workspace_state(),
		"imported_names": imported_names
	})


func _scan_library_filesystem() -> Array[String]:
	var imported_names: Array[String] = []
	_import_duplicate_definition_files(imported_names)
	_import_unregistered_object_scenes(imported_names)
	return imported_names


func _import_duplicate_definition_files(imported_names: Array[String]) -> void:
	var definitions := ObjectLibraryService.load_all_definition_files()
	var first_by_id: Dictionary = {}
	for definition in definitions:
		if definition == null or definition.is_template or definition.object_id.strip_edges().is_empty():
			continue
		var object_id := definition.object_id
		if not first_by_id.has(object_id):
			first_by_id[object_id] = definition
			continue
		var original := first_by_id[object_id] as ObjectDefinition
		if original == null or definition.resource_path == original.resource_path:
			continue
		var imported_name := _register_duplicate_definition_file(original, definition)
		if not imported_name.is_empty() and not imported_names.has(imported_name):
			imported_names.append(imported_name)


func _register_duplicate_definition_file(
	original: ObjectDefinition,
	duplicate_file: ObjectDefinition
) -> String:
	if original == null or duplicate_file == null:
		return ""
	var duplicate_path := duplicate_file.resource_path
	if duplicate_path.is_empty() or not FileAccess.file_exists(duplicate_path):
		return ""

	var copy_definition := duplicate_file.duplicate(true) as ObjectDefinition
	if copy_definition == null:
		return ""
	copy_definition.object_id = LibraryActionsService.create_unique_id(
		"object", original.object_id
	)
	copy_definition.template_id = ""
	copy_definition.is_template = false
	copy_definition.display_name = duplicate_file.display_name
	copy_definition.scene = null
	copy_definition.scene_path = ""
	copy_definition.resource_path = duplicate_path
	ObjectLibraryService.ensure_unique_display_name(copy_definition)

	# When both companion files were copied, use the copied scene as the source.
	# It may contain edits that must not be silently replaced by the original.
	var source_definition := original
	var source_scene_copy := _guess_companion_scene_copy_path(duplicate_path)
	var copied_scene: PackedScene
	if (
		not source_scene_copy.is_empty()
		and source_scene_copy != original.scene_path
		and FileAccess.file_exists(source_scene_copy)
	):
		copied_scene = ResourceLoader.load(
			source_scene_copy, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as PackedScene
		if (
			copied_scene != null
			and ObjectLibraryService.get_packed_scene_object_id(copied_scene) == original.object_id
		):
			source_definition = original.duplicate(true) as ObjectDefinition
			source_definition.scene = copied_scene
			source_definition.scene_path = source_scene_copy
			var copied_root := copied_scene.instantiate()
			if copied_root != null:
				_extract_managed_scene_visuals(copy_definition, copied_root)
				copied_root.free()
		else:
			copied_scene = null

	var scene_result := SceneDraftService.clone_object_scene(
		source_definition, copy_definition
	)
	if not bool(scene_result.get("ok", false)):
		push_warning(
			"Web Object Builder: не удалось создать сцену для копии «%s»: %s"
			% [duplicate_file.display_name, str(scene_result.get("message", ""))]
		)
		return ""

	var save_error := ObjectLibraryService.save_definition(copy_definition)
	if save_error != OK:
		ObjectLibraryService.remove_scene_if_unreferenced(
			copy_definition.scene_path, copy_definition.object_id
		)
		push_warning(
			"Web Object Builder: не удалось добавить скопированную запись «%s» (код %d)."
			% [duplicate_file.display_name, save_error]
		)
		return ""

	# Remove copied source files only after the new independent definition and
	# PackedScene have both been committed successfully.
	if copied_scene != null and FileAccess.file_exists(source_scene_copy):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(source_scene_copy))
	return copy_definition.display_name


func _guess_companion_scene_copy_path(definition_path: String) -> String:
	var relative_directory := ""
	if definition_path.begins_with(ObjectLibraryService.OBJECTS_PATH + "/"):
		relative_directory = definition_path.trim_prefix(
			ObjectLibraryService.OBJECTS_PATH + "/"
		).get_base_dir()
	elif definition_path.begins_with(ObjectLibraryService.LEGACY_OBJECTS_PATH + "/"):
		relative_directory = definition_path.trim_prefix(
			ObjectLibraryService.LEGACY_OBJECTS_PATH + "/"
		).get_base_dir()
	else:
		return ""
	var base_name := definition_path.get_file().get_basename()
	var scene_directory := ObjectLibraryService.SCENES_PATH.path_join("objects")
	if not relative_directory.is_empty() and relative_directory != ".":
		scene_directory = scene_directory.path_join(relative_directory)
	return scene_directory.path_join(base_name + ".tscn")


func _import_unregistered_object_scenes(imported_names: Array[String]) -> void:
	var scene_paths: Array[String] = []
	_collect_object_scene_paths(
		ObjectLibraryService.SCENES_PATH.path_join("objects"), scene_paths
	)
	var known_scene_paths: Dictionary = {}
	for definition in ObjectLibraryService.load_definitions():
		if definition != null and not definition.scene_path.is_empty():
			known_scene_paths[definition.scene_path] = true

	for scene_path in scene_paths:
		if known_scene_paths.has(scene_path):
			continue
		var imported_name := _register_untracked_object_scene(scene_path)
		if not imported_name.is_empty() and not imported_names.has(imported_name):
			imported_names.append(imported_name)
			var registered := ObjectLibraryService.load_definitions()
			for definition in registered:
				if definition != null and definition.display_name == imported_name:
					known_scene_paths[definition.scene_path] = true
					break


func _collect_object_scene_paths(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() in ["tscn", "scn"]:
			output.append(directory_path.path_join(file_name))
	for child_directory in directory.get_directories():
		_collect_object_scene_paths(
			directory_path.path_join(child_directory), output
		)


func _register_untracked_object_scene(scene_path: String) -> String:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return ""
	var packed_scene := ResourceLoader.load(
		scene_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as PackedScene
	if packed_scene == null:
		return ""
	# Instantiate the PackedScene loaded above. Keep the base type explicit so
	# GDScript does not try to infer a type from an unresolved identifier.
	var scene_root: Node = packed_scene.instantiate()
	if scene_root == null or not scene_root is Node2D:
		if scene_root != null:
			scene_root.free()
		return ""

	var source_object_id := str(
		scene_root.get_meta(
			"object_builder_id",
			scene_root.get_meta("object_definition_id", "")
		)
	).strip_edges()
	var source_definition := (
		ObjectLibraryService.load_definition(source_object_id)
		if not source_object_id.is_empty()
		else null
	)
	var definition: ObjectDefinition
	if source_definition != null:
		definition = source_definition.duplicate(true) as ObjectDefinition
		definition.object_id = LibraryActionsService.create_unique_id(
			"object", source_definition.object_id
		)
		definition.template_id = ""
		definition.is_template = false
	else:
		definition = DefinitionScript.new() as ObjectDefinition
		# An unregistered scene can still carry an ID from a deleted or
		# copied object. Never reuse that ID for a new library entry.
		definition.object_id = LibraryActionsService.create_unique_id(
			"object",
			source_object_id if not source_object_id.is_empty() else scene_path.get_file().get_basename()
		)
		definition.root_type = scene_root.get_class()
		definition.object_type = "other"
		definition.category = str(
			scene_root.get_meta("object_category", _category_from_scene_path(scene_path))
		)

	definition.display_name = str(
		scene_root.get_meta(
			"object_builder_name",
			source_definition.display_name if source_definition != null else scene_root.name
		)
	).strip_edges()
	if definition.display_name.is_empty():
		definition.display_name = scene_path.get_file().get_basename().replace("_", " ").capitalize()
	if definition.category.strip_edges().is_empty():
		definition.category = "Other"
	definition.scene = packed_scene
	definition.scene_path = scene_path
	definition.resource_path = ""
	ObjectLibraryService.ensure_unique_display_name(definition)
	# Read edited Object Builder-managed sprites/layers from the copied scene
	# before sync_scene reconciles the managed nodes from ObjectDefinition.
	_extract_managed_scene_visuals(definition, scene_root)
	scene_root.free()

	var original_scene_bytes := FileAccess.get_file_as_bytes(scene_path)
	var scene_result := SceneDraftService.sync_scene(definition)
	if not bool(scene_result.get("ok", false)):
		push_warning(
			"Web Object Builder: не удалось подготовить скопированную сцену «%s»: %s"
			% [definition.display_name, str(scene_result.get("message", ""))]
		)
		return ""

	var save_error := ObjectLibraryService.save_definition(definition)
	if save_error != OK:
		ObjectLibraryService.remove_scene_if_unreferenced(
			definition.scene_path, definition.object_id
		)
		_restore_library_file(scene_path, original_scene_bytes)
		push_warning(
			"Web Object Builder: сцена «%s» обнаружена, но запись библиотеки сохранить не удалось (код %d)."
			% [definition.display_name, save_error]
		)
		return ""
	return definition.display_name


func _category_from_scene_path(scene_path: String) -> String:
	var folder := scene_path.get_base_dir().get_file().to_lower()
	const CATEGORY_NAMES := {
		"nature": "Nature",
		"buildings": "Buildings",
		"items": "Items",
		"equipment": "Equipment",
		"furniture": "Furniture",
		"characters": "Characters",
		"animals": "Animals",
		"interactive": "Interactive",
		"effects": "Effects",
		"transport": "Transport",
		"decorations": "Decorations",
		"other": "Other",
		"environment": "Environment",
		"resources": "Resources",
		"weapons": "Weapons",
		"tools": "Tools",
		"npc": "NPC"
	}
	return str(CATEGORY_NAMES.get(folder, "Other"))


func _restore_library_file(path: String, bytes: PackedByteArray) -> void:
	if path.is_empty() or bytes.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()


func _refresh_external_definition_from_godot(resource_path: String) -> Dictionary:
	var clean_path := resource_path.strip_edges()
	var is_object_path := (
		clean_path.begins_with(ObjectLibraryService.OBJECTS_PATH + "/")
		or clean_path.begins_with(ObjectLibraryService.LEGACY_OBJECTS_PATH + "/")
	)
	var is_template_path := (
		clean_path.begins_with(ObjectLibraryService.TEMPLATES_PATH + "/")
		or clean_path.begins_with(ObjectLibraryService.LEGACY_TEMPLATES_PATH + "/")
	)
	if clean_path.is_empty() or not ObjectLibraryService.is_managed_definition_path(clean_path):
		return _ok({
			"workspace": get_workspace_state(),
			"external_definition_found": false,
			"conflict": false
		})
	if not is_object_path and not is_template_path:
		return _ok({
			"workspace": get_workspace_state(),
			"external_definition_found": false,
			"conflict": false
		})

	var external_definition := ResourceLoader.load(
		clean_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ObjectDefinition
	if external_definition == null:
		return _fail("Не удалось перечитать ObjectDefinition из Godot: " + clean_path)
	if external_definition.object_id.strip_edges().is_empty():
		return _fail("У сохранённого ObjectDefinition не указан постоянный object_id.")

	var current_definition: ObjectDefinition
	var registered_definitions := (
		ObjectLibraryService.load_templates()
		if is_template_path
		else ObjectLibraryService.load_definitions()
	)
	for candidate in registered_definitions:
		if candidate != null and candidate.object_id == external_definition.object_id:
			current_definition = candidate
			break
	if current_definition == null or current_definition.resource_path != clean_path:
		# A second file with the same ID is a filesystem copy, not an edit of
		# the registered resource. Leave it for the duplicate-ID importer.
		return _ok({
			"workspace": get_workspace_state(),
			"external_definition_found": false,
			"conflict": false
		})

	var has_conflict := _dirty_draft_ids.has(external_definition.object_id)
	if not has_conflict:
		_open_drafts[external_definition.object_id] = external_definition
		_saved_draft_ids[external_definition.object_id] = true
		_new_draft_ids.erase(external_definition.object_id)
		_dirty_draft_ids.erase(external_definition.object_id)
		if _working != null and _working.object_id == external_definition.object_id:
			_working = external_definition

	return _ok({
		"workspace": get_workspace_state(),
		"working": _serialize_definition(_working, true) if _working != null else null,
		"external_definition": _serialize_definition(external_definition, true),
		"external_definition_found": true,
		"conflict": has_conflict,
		"resource_path": clean_path
	})


func _refresh_all_managed_scenes_from_disk(skip_scene_paths: Variant = []) -> Dictionary:
	var skip_paths: Dictionary = {}
	if skip_scene_paths is Array or skip_scene_paths is PackedStringArray:
		for value in skip_scene_paths:
			var path := str(value).strip_edges()
			if not path.is_empty():
				skip_paths[path] = true

	var refreshed_count := 0
	var skipped_count := 0
	var missing_paths: Array[String] = []
	var errors: Array[String] = []
	var external_definitions: Array[Dictionary] = []
	var seen_scene_paths: Dictionary = {}
	var candidates := ObjectLibraryService.load_definitions()
	candidates.append_array(ObjectLibraryService.load_templates())

	for candidate in candidates:
		if candidate == null:
			continue
		var scene_path := str(candidate.scene_path).strip_edges()
		if (
			scene_path.is_empty()
			or scene_path.get_extension().to_lower() not in ["tscn", "scn"]
			or seen_scene_paths.has(scene_path)
		):
			continue
		seen_scene_paths[scene_path] = true

		if skip_paths.has(scene_path):
			skipped_count += 1
			continue
		if not ResourceLoader.exists(scene_path):
			missing_paths.append(scene_path)
			continue

		# No live Editor root is required here. This path deliberately rebuilds
		# ObjectDefinitions from the .tscn files on disk, so edits survive closing
		# Godot or reopening the plugin even if scene_saved was missed entirely.
		var refresh_result := _refresh_external_scene_from_godot(
			scene_path,
			null,
			false
		)
		if not bool(refresh_result.get("ok", false)):
			errors.append(
				scene_path + ": " + str(refresh_result.get("error", "Неизвестная ошибка."))
			)
			continue
		if not bool(refresh_result.get("external_scene_found", false)):
			errors.append(scene_path + ": сцена не сопоставлена с ObjectDefinition.")
			continue

		refreshed_count += 1
		var external_definition: Variant = refresh_result.get("external_definition", {})
		if external_definition is Dictionary and not external_definition.is_empty():
			external_definitions.append(external_definition)

	return _ok({
		"workspace": get_workspace_state(),
		"refreshed_count": refreshed_count,
		"skipped_count": skipped_count,
		"missing_paths": missing_paths,
		"errors": errors,
		"external_definitions": external_definitions
	})


func _refresh_external_scene_from_godot(
	scene_path: String,
	supplied_scene_root: Node = null,
	include_workspace_in_response: bool = true
) -> Dictionary:
	var clean_path := scene_path.strip_edges()
	if clean_path.is_empty():
		return _fail("Не указан путь сохранённой сцены.")

	# Prefer the actual scene tree owned by the editor. Reloading a PackedScene
	# while Godot is editing it can return a stale cached snapshot or omit the
	# most recent inspector changes. A PackedScene instance is only the fallback
	# for scenes saved in another tab or refreshes without an editor root.
	var scene_root: Node = supplied_scene_root
	var packed_scene: PackedScene
	var owns_scene_root := false
	if scene_root == null:
		packed_scene = ResourceLoader.load(
			clean_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as PackedScene
		if packed_scene == null:
			return _fail("Не удалось перечитать сохранённую в Godot сцену: " + clean_path)
		scene_root = packed_scene.instantiate()
		if scene_root == null:
			return _fail("Не удалось создать экземпляр сохранённой сцены: " + clean_path)
		owns_scene_root = true
	elif not is_instance_valid(scene_root):
		scene_root = null
		return _fail("Корень сцены Godot больше недоступен: " + clean_path)
	var used_live_scene_root := supplied_scene_root != null

	# Resolve the link from the live root's persistent identity first, then
	# fall back to the exact recorded scene path for older definitions.
	var scene_object_id := ObjectLibraryService.get_scene_root_object_id(scene_root)
	var definition: ObjectDefinition
	for candidate in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
		if candidate == null:
			continue
		if candidate.scene_path == clean_path or (
			not scene_object_id.is_empty() and candidate.object_id == scene_object_id
		):
			definition = candidate
			if not candidate.resource_path.is_empty():
				var reloaded := ResourceLoader.load(
					candidate.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
				) as ObjectDefinition
				if reloaded != null and reloaded.object_id == candidate.object_id:
					definition = reloaded
			break

	if definition == null:
		if owns_scene_root:
			scene_root.free()
		return _ok({
			"workspace": get_workspace_state() if include_workspace_in_response else {},
			"external_scene_found": false,
			"conflict": false,
			"scene_path": clean_path,
			"scene_object_id": scene_object_id,
			"live_scene_root_used": used_live_scene_root
		})

	# The path remains the durable scene link. When we had to load a PackedScene,
	# keep that resource reference too; with the live editor root, do not replace
	# the editor's scene resource with another cached instance.
	definition.scene_path = clean_path
	if packed_scene != null:
		definition.scene = packed_scene
	_extract_managed_scene_visuals(definition, scene_root)
	if owns_scene_root:
		scene_root.free()

	var save_error := (
		ObjectLibraryService.save_template(definition)
		if definition.is_template
		else ObjectLibraryService.save_definition(definition)
	)
	if save_error != OK:
		return _fail(
			"Сцена Godot сохранена, но изменения ObjectDefinition записать не удалось (код %d)."
			% save_error
		)

	var has_conflict := _dirty_draft_ids.has(definition.object_id)
	var refreshed_definition: ObjectDefinition
	for candidate in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
		if candidate != null and candidate.object_id == definition.object_id:
			refreshed_definition = candidate
			break

	if not has_conflict:
		if refreshed_definition != null:
			_open_drafts[definition.object_id] = refreshed_definition
			_saved_draft_ids[definition.object_id] = true
			_new_draft_ids.erase(definition.object_id)
			_dirty_draft_ids.erase(definition.object_id)
			if _working != null and _working.object_id == definition.object_id:
				_working = refreshed_definition
	else:
		# Preserve unrelated unsaved Web Builder fields, but merge the scene-owned
		# sprite and collision profiles from the newly saved Godot scene.
		var preserved_draft := _open_drafts.get(definition.object_id) as ObjectDefinition
		if preserved_draft != null:
			_merge_godot_sprite_profile(definition, preserved_draft)
			_merge_godot_collision_profile(definition, preserved_draft)
			_merge_godot_node_definitions(definition, preserved_draft)
			_open_drafts[definition.object_id] = preserved_draft
		if _working != null and _working.object_id == definition.object_id:
			_merge_godot_sprite_profile(definition, _working)
			_merge_godot_collision_profile(definition, _working)
			_merge_godot_node_definitions(definition, _working)

	var response_definition := (
		refreshed_definition if refreshed_definition != null else definition
	)
	var response_scene_root := scene_root if used_live_scene_root else null
	var external_definition_payload := _serialize_definition(
		response_definition,
		true,
		response_scene_root
	)
	return _ok({
		"workspace": get_workspace_state() if include_workspace_in_response else {},
		"working": _serialize_definition(_working, true) if _working != null else null,
		"external_definition": external_definition_payload,
		"external_scene_found": true,
		"conflict": has_conflict,
		"scene_path": clean_path,
		"scene_object_id": scene_object_id,
		"live_scene_root_used": used_live_scene_root
	})


func _merge_godot_sprite_profile(
	source: ObjectDefinition,
	target: ObjectDefinition
) -> void:
	if source == null or target == null:
		return
	target.preview_texture = source.preview_texture
	target.preview_hash = source.preview_hash
	target.preview_sprite_scale = source.preview_sprite_scale
	target.preview_sprite_offset = source.preview_sprite_offset
	target.preview_sprite_rotation_degrees = source.preview_sprite_rotation_degrees
	target.preview_sprite_z_index = source.preview_sprite_z_index
	target.sprite_layers.clear()
	for layer in source.sprite_layers:
		if layer is Dictionary:
			target.sprite_layers.append(layer.duplicate(true))


func _merge_godot_node_definitions(
	source: ObjectDefinition,
	target: ObjectDefinition
) -> void:
	if source == null or target == null:
		return
	var target_by_id: Dictionary = {}
	for node_definition in target.node_definitions:
		if node_definition != null and not node_definition.node_id.strip_edges().is_empty():
			target_by_id[node_definition.node_id] = node_definition
	for source_definition in source.node_definitions:
		if source_definition == null:
			continue
		var node_id := source_definition.node_id.strip_edges()
		if not target_by_id.has(node_id):
			continue
		var target_definition := target_by_id[node_id] as ObjectNodeDefinition
		target_definition.node_name = source_definition.node_name
		target_definition.enabled = source_definition.enabled
		target_definition.properties = source_definition.properties.duplicate(true)
		target_definition.groups = source_definition.groups.duplicate()
		target_definition.node_type = source_definition.node_type


func _merge_godot_collision_profile(
	source: ObjectDefinition,
	target: ObjectDefinition
) -> void:
	if source == null or target == null:
		return
	target.collision_enabled = source.collision_enabled
	target.collision_mode = source.collision_mode
	target.collision_shape = source.collision_shape
	target.collision_size = source.collision_size
	target.collision_radius = source.collision_radius
	target.collision_height = source.collision_height
	target.collision_offset = source.collision_offset
	target.collision_layer = source.collision_layer
	target.collision_mask = source.collision_mask


func _node_2d_transform_relative_to_root(
	node: Node2D,
	scene_root: Node
) -> Transform2D:
	if node == null:
		return Transform2D.IDENTITY
	var chain: Array[Node2D] = []
	var current: Node = node
	while current != null and current != scene_root:
		if current is Node2D:
			chain.push_front(current as Node2D)
		current = current.get_parent()
	if current != scene_root:
		return node.transform
	var relative_transform := Transform2D.IDENTITY
	for transform_node in chain:
		relative_transform = relative_transform * transform_node.transform
	return relative_transform


func _sprite_transform_relative_to_root(
	sprite: Node2D,
	scene_root: Node
) -> Transform2D:
	return _node_2d_transform_relative_to_root(sprite, scene_root)


func _extract_managed_scene_visuals(definition: ObjectDefinition, scene_root: Node) -> void:
	if definition == null or scene_root == null:
		return
	var main_sprite: Sprite2D
	var next_layers: Array[Dictionary] = []
	var previous_layers: Dictionary = {}
	for layer in definition.sprite_layers:
		if layer is Dictionary:
			previous_layers[str(layer.get("id", ""))] = layer

	for candidate in scene_root.find_children("*", "", true, false):
		if candidate is not Sprite2D:
			continue
		# A parent object can contain nested Object Builder instances. Their
		# sprites belong to their own PackedScene owners and must not overwrite
		# the parent object's visual profile.
		if not _is_owned_by_object_scene(candidate, scene_root):
			continue
		var sprite := candidate as Sprite2D
		if bool(sprite.get_meta("object_builder_sprite", false)):
			main_sprite = sprite
			continue
		if not bool(sprite.get_meta("object_builder_sprite_layer", false)):
			continue
		var layer_id := str(
			sprite.get_meta("object_builder_sprite_layer_id", "")
		).strip_edges()
		if layer_id.is_empty():
			layer_id = "sprite_%d" % next_layers.size()
		var texture_hash := ""
		if sprite.texture != null:
			var texture_image := sprite.texture.get_image()
			if texture_image != null and not texture_image.is_empty():
				texture_hash = str(hash(texture_image.save_png_to_buffer()))
		var layer_transform := _sprite_transform_relative_to_root(sprite, scene_root)
		var previous_layer: Dictionary = previous_layers.get(layer_id, {})
		var runtime_visible := bool(previous_layer.get("runtime_visible", true))
		next_layers.append({
			"id": layer_id,
			"name": str(sprite.name).trim_prefix("Спрайт — "),
			"texture": sprite.texture,
			"texture_hash": texture_hash,
			"position": layer_transform.origin,
			"scale": layer_transform.get_scale(),
			"rotation": rad_to_deg(layer_transform.get_rotation()),
			"z_index": sprite.z_index,
			# Embedded remains are intentionally hidden in the saved game scene.
			# Their separate editor visibility is retained in the ObjectDefinition.
			"visible": bool(previous_layer.get("visible", true)) if not runtime_visible else sprite.visible,
			"runtime_visible": runtime_visible,
			"embedded_relation_id": str(previous_layer.get("embedded_relation_id", "")),
			"embedded_object_id": str(previous_layer.get("embedded_object_id", "")),
			"embedded_source_name": str(previous_layer.get("embedded_source_name", ""))
		})

	if main_sprite != null:
		var main_transform := _sprite_transform_relative_to_root(main_sprite, scene_root)
		definition.preview_texture = main_sprite.texture
		definition.preview_sprite_offset = main_transform.origin
		definition.preview_sprite_scale = main_transform.get_scale()
		definition.preview_sprite_rotation_degrees = rad_to_deg(main_transform.get_rotation())
		definition.preview_sprite_z_index = main_sprite.z_index
		if main_sprite.texture != null:
			var image := main_sprite.texture.get_image()
			definition.preview_hash = (
				str(hash(image.save_png_to_buffer()))
				if image != null and not image.is_empty()
				else ""
			)
		else:
			definition.preview_hash = ""
	definition.sprite_layers = next_layers
	_extract_managed_node_definitions(definition, scene_root)
	_extract_managed_scene_collision(definition, scene_root)


func _extract_managed_node_definitions(
	definition: ObjectDefinition,
	scene_root: Node
) -> void:
	if definition == null or scene_root == null or definition.node_definitions.is_empty():
		return

	var nodes_by_id: Dictionary = {}
	var duplicate_ids: Dictionary = {}
	var id_by_group: Dictionary = {}
	for node_definition in definition.node_definitions:
		if node_definition == null or node_definition.node_id.strip_edges().is_empty():
			continue
		id_by_group[
			ObjectSceneStructureServiceScript.node_id_group_name(node_definition.node_id)
		] = node_definition.node_id
	for candidate in scene_root.find_children("*", "", true, false):
		if not _is_owned_by_object_scene(candidate, scene_root):
			continue
		var node_id := ""
		if candidate.has_meta("object_builder_node_id"):
			node_id = str(candidate.get_meta("object_builder_node_id")).strip_edges()
		if node_id.is_empty():
			for identity_group in id_by_group:
				if candidate.is_in_group(str(identity_group)):
					node_id = str(id_by_group[identity_group]).strip_edges()
					break
		if node_id.is_empty():
			continue
		if nodes_by_id.has(node_id):
			duplicate_ids[node_id] = true
			continue
		nodes_by_id[node_id] = candidate

	for node_definition in definition.node_definitions:
		if node_definition == null:
			continue
		var node_id := node_definition.node_id.strip_edges()
		if node_id.is_empty() or duplicate_ids.has(node_id):
			if duplicate_ids.has(node_id):
				push_warning(
					"Web Object Builder: ID узла '%s' встречается несколько раз; свойства не синхронизированы."
					% node_id
				)
			continue
		var scene_node := nodes_by_id.get(node_id) as Node
		if scene_node == null:
			continue

		# Keep the definition's property contract, but take the actual saved
		# Godot values for every property represented by that contract.
		var next_properties := node_definition.properties.duplicate(true)
		for property_name in next_properties.keys():
			var property_key := str(property_name)
			if property_key in ["name", "owner", "script", "scene_file_path"]:
				continue
			if not _has_node_property(scene_node, property_key):
				continue
			next_properties[property_key] = scene_node.get(property_key)
		node_definition.properties = next_properties
		node_definition.node_name = str(scene_node.name)
		node_definition.enabled = scene_node.process_mode != Node.PROCESS_MODE_DISABLED
		var next_groups := PackedStringArray()
		for group_name in scene_node.get_groups():
			next_groups.append(str(group_name))
		node_definition.groups = next_groups


func _has_node_property(node: Node, property_name: String) -> bool:
	if node == null or property_name.is_empty():
		return false
	for property_info in node.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


func _is_owned_by_object_scene(node: Node, scene_root: Node) -> bool:
	if node == null or scene_root == null or node == scene_root:
		return false
	# Godot assigns owner=scene_root to nodes serialized in this PackedScene.
	# Nodes inside a nested scene instance have a different owner and must stay
	# with that child object's ObjectDefinition.
	return node.owner == scene_root


func _extract_managed_scene_collision(
	definition: ObjectDefinition,
	scene_root: Node
) -> void:
	if definition == null or scene_root == null:
		return

	var managed_shape: CollisionShape2D
	var managed_shapes: Array[CollisionShape2D] = []
	var collision_nodes: Array[CollisionShape2D] = []
	for candidate in scene_root.find_children("*", "CollisionShape2D", true, false):
		if candidate is not CollisionShape2D:
			continue
		# Only import nodes owned by this object's scene. A nested child object
		# has its own owner and its own collision profile.
		if not _is_owned_by_object_scene(candidate, scene_root):
			continue
		var collision_node := candidate as CollisionShape2D
		collision_nodes.append(collision_node)
		if bool(collision_node.get_meta("object_builder_collision_shape", false)):
			managed_shapes.append(collision_node)

	if managed_shapes.size() == 1:
		managed_shape = managed_shapes[0]
	elif managed_shapes.size() > 1:
		push_warning(
			"Web Object Builder: в сцене объекта найдено несколько управляемых CollisionShape2D. Профиль не изменён, чтобы не выбрать произвольную форму."
		)
		return

	# Adopt the reserved legacy path only within this scene's ownership boundary.
	if managed_shape == null:
		var legacy_host: CollisionObject2D
		if scene_root is CollisionObject2D:
			legacy_host = scene_root as CollisionObject2D
		else:
			for candidate in scene_root.find_children("*", "", true, false):
				if (
					candidate is CollisionObject2D
					and candidate.name == "Коллизия"
					and _is_owned_by_object_scene(candidate, scene_root)
				):
					legacy_host = candidate as CollisionObject2D
					break
		if legacy_host != null:
			var legacy_shape := legacy_host.get_node_or_null("Форма коллизии") as CollisionShape2D
			if legacy_shape != null and _is_owned_by_object_scene(legacy_shape, scene_root):
				managed_shape = legacy_shape

	# Godot users may add a single CollisionShape2D themselves or remove the
	# Builder metadata while editing. Adopt an unambiguous single supported shape.
	if managed_shape == null and collision_nodes.size() == 1:
		var only_shape := collision_nodes[0]
		var only_resource := only_shape.shape
		if (
			only_shape.get_parent() is CollisionObject2D
			and (
				only_resource is RectangleShape2D
				or only_resource is CircleShape2D
				or only_resource is CapsuleShape2D
			)
		):
			managed_shape = only_shape

	if managed_shape == null:
		if collision_nodes.is_empty():
			# Removing the Builder-owned shape in Godot explicitly disables this profile.
			definition.collision_enabled = false
		else:
			push_warning(
				"Web Object Builder: найдено несколько или неподдерживаемых CollisionShape2D без метки билдера. Профиль коллизии оставлен без изменений, чтобы не выбрать чужую форму."
			)
		return

	var collision_host := managed_shape.get_parent() as CollisionObject2D
	if collision_host == null:
		push_warning("Web Object Builder: управляемая CollisionShape2D не находится внутри CollisionObject2D; профиль коллизии не изменён.")
		return

	var shape_resource := managed_shape.shape
	if not (
		shape_resource is RectangleShape2D
		or shape_resource is CircleShape2D
		or shape_resource is CapsuleShape2D
	):
		push_warning(
			"Web Object Builder: форма коллизии %s сохранена в сцене Godot, но не поддерживается веб-профилем. Старые параметры ObjectDefinition оставлены без изменений."
			% (shape_resource.get_class() if shape_resource != null else "null")
		)
		return

	definition.collision_enabled = not managed_shape.disabled
	definition.collision_mode = "area" if collision_host is Area2D else "solid"
	definition.collision_layer = collision_host.collision_layer
	definition.collision_mask = collision_host.collision_mask

	# Compose local transforms from the scene root to the shape. This works
	# both for the live editor tree and for PackedScene instances that are not
	# inside a SceneTree, and it includes transformed nested collision hosts.
	definition.collision_offset = _node_2d_transform_relative_to_root(
		managed_shape,
		scene_root
	).origin

	if shape_resource is RectangleShape2D:
		definition.collision_shape = "rectangle"
		definition.collision_size = (shape_resource as RectangleShape2D).size
	elif shape_resource is CircleShape2D:
		definition.collision_shape = "circle"
		definition.collision_radius = (shape_resource as CircleShape2D).radius
	elif shape_resource is CapsuleShape2D:
		var capsule := shape_resource as CapsuleShape2D
		definition.collision_shape = "capsule"
		definition.collision_radius = capsule.radius
		definition.collision_height = capsule.height
	else:
		push_warning(
			"Web Object Builder: форма коллизии %s сохранена в сцене Godot, но веб-профиль поддерживает только RectangleShape2D, CircleShape2D и CapsuleShape2D."
			% (shape_resource.get_class() if shape_resource != null else "null")
		)


func _save_local_state() -> void:
	# EditorInterface project metadata exists only inside an editor session.
	# SceneTree smoke tests and runtime use can still update the in-memory lists.
	if not Engine.is_editor_hint():
		return
	var settings := EditorInterface.get_editor_settings()
	settings.set_project_metadata(METADATA_SECTION, "favorites", _favorites)
	settings.set_project_metadata(METADATA_SECTION, "recent", _recent)
	settings.set_project_metadata(METADATA_SECTION, "custom_collections", _collections)
	settings.set_project_metadata(METADATA_SECTION, "custom_categories", _custom_categories)


func _create_object(payload: Dictionary) -> Dictionary:
	if _working != null:
		_open_drafts[_working.object_id] = _working
	var mode := str(payload.get("mode", "new"))
	var values := {
		"display_name": str(payload.get("name", "Новый объект")).strip_edges(),
		"category": str(payload.get("category", "Other")).strip_edges(),
		"description": str(payload.get("description", "")),
		"tags": payload.get("tags", [])
	}
	if str(values.display_name).is_empty():
		values.display_name = "Новый объект"
	if str(values.category).is_empty():
		values.category = "Other"
	var result: Dictionary
	match mode:
		"new":
			var profile_id := str(payload.get("profile_id", "other")).strip_edges()
			var profile := ObjectCreationProfileRegistry.get_definition(profile_id) if not profile_id.is_empty() else null
			result = CreationService.create_empty_draft(values, profile)
		"template", "duplicate":
			var source_id := str(payload.get("source_id", "")).strip_edges()
			var source := _find_definition(source_id)
			if source == null and mode == "template":
				source = _find_template(source_id)
			result = CreationService.create_from_source(source, values)
		"import":
			result = CreationService.import_scene_draft(str(payload.get("import_path", "")), values)
		_:
			return _fail("Неизвестный способ создания объекта: " + mode)
	if not bool(result.get("ok", false)):
		return _fail(str(result.get("message", "Не удалось создать объект.")))
	_working = result.get("definition") as ObjectDefinition
	if _working == null:
		return _fail("Конструктор не вернул ObjectDefinition.")
	_pending_selections.clear()
	_pending_plan.clear()
	_new_draft_ids[_working.object_id] = true
	_dirty_draft_ids.erase(_working.object_id)
	_saved_draft_ids.erase(_working.object_id)
	_open_drafts[_working.object_id] = _working
	return _ok({
		"working": _serialize_definition(_working, true),
		"workspace": get_workspace_state(),
		"message": "Создан независимый черновик. Исходник не изменён."
	})


func _create_related_object(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой исходный объект.")
	var parent_definition := _working
	var mode := str(payload.get("mode", "new")).strip_edges()
	var display_name := str(payload.get("name", "Новый связанный объект")).strip_edges()
	if display_name.is_empty():
		display_name = "Новый связанный объект"
	var category := str(payload.get("category", "Other")).strip_edges()
	if category.is_empty():
		category = "Other"
	var values := {
		"display_name": display_name,
		"category": category,
		"description": str(payload.get("description", "Создан как связанный объект.")),
		"tags": payload.get("tags", [])
	}
	var creation_result: Dictionary
	match mode:
		"new":
			var profile_id := str(payload.get("profile_id", "other")).strip_edges()
			var profile := ObjectCreationProfileRegistry.get_definition(profile_id) if not profile_id.is_empty() else null
			creation_result = CreationService.create_empty_draft(values, profile)
		"template":
			var source_id := str(payload.get("source_id", "")).strip_edges()
			var source := _find_template(source_id)
			if source == null:
				return _fail("Шаблон связанного объекта не найден: " + source_id)
			creation_result = CreationService.create_from_source(source, values)
		_:
			return _fail("Неизвестный способ создания связанного объекта: " + mode)
	if not bool(creation_result.get("ok", false)):
		return _fail(str(creation_result.get("message", "Не удалось создать связанный объект.")))
	var related_definition := creation_result.get("definition") as ObjectDefinition
	if related_definition == null:
		return _fail("Создание не вернуло ObjectDefinition связанного объекта.")
	var relation_data: Variant = payload.get("relation", {})
	if not relation_data is Dictionary:
		_cleanup_draft_scene(related_definition)
		return _fail("Не заданы параметры связи с созданным объектом.")
	var mechanic_id := str(relation_data.get("mechanic_id", "")).strip_edges()
	var relation_kind := str(relation_data.get("kind", "related")).strip_edges()
	var owner_error := _validate_relation_owner(mechanic_id, relation_kind, related_definition.object_id)
	if not owner_error.is_empty():
		_cleanup_draft_scene(related_definition)
		return _fail(owner_error)
	var relation_id := "relation_" + str(Time.get_ticks_usec())
	var relation_settings: Variant = relation_data.get("settings", {})
	parent_definition.relations.append({
		"relation_id": relation_id,
		"target_object_id": related_definition.object_id,
		"mechanic_id": mechanic_id,
		"kind": relation_kind,
		"label": str(relation_data.get("label", "Связанный объект")),
		"quantity": maxi(1, int(relation_data.get("quantity", 1))),
		"settings": relation_settings.duplicate(true) if relation_settings is Dictionary else {}
	})
	# The child is registered as an open draft before the request returns. The
	# parent remains active, so there is no editor-tab switch or race between
	# creating the child, adding its relation, and saving the bundle.
	_new_draft_ids[related_definition.object_id] = true
	_saved_draft_ids.erase(related_definition.object_id)
	_dirty_draft_ids.erase(related_definition.object_id)
	_open_drafts[related_definition.object_id] = related_definition
	_working = parent_definition
	_mark_working_dirty()
	return _ok({
		"related": _serialize_definition(related_definition, true),
		"working": _serialize_definition(parent_definition, true),
		"workspace": get_workspace_state(),
		"message": "Связанный объект создан как отдельный черновик и сразу подключён к механике."
	})


func _open_object(object_id: String) -> Dictionary:
	var clean_id := object_id.strip_edges()
	if clean_id.is_empty():
		return _fail("Не указан ID объекта для открытия.")

	if _working != null and _working.object_id != clean_id:
		_open_drafts[_working.object_id] = _working

	var cached_draft := _open_drafts.get(clean_id) as ObjectDefinition
	var has_unsaved_changes := (
		_dirty_draft_ids.has(clean_id)
		or _new_draft_ids.has(clean_id)
	)

	# Unsaved Builder work must remain intact. A clean open document, however,
	# is only a cache: Godot can edit and save its .tscn/.tres files without
	# notifying this in-memory backend. Always reload clean documents from the
	# library so reopening can never resurrect an obsolete collision profile.
	if cached_draft != null and has_unsaved_changes:
		_working = cached_draft
	else:
		var source := _find_definition(clean_id)
		if source == null:
			source = _find_template(clean_id)
		if source == null:
			# Newly-created unsaved drafts may not be in the on-disk library yet.
			if cached_draft != null and _new_draft_ids.has(clean_id):
				_working = cached_draft
			else:
				return _fail("Объект не найден в нативной библиотеке: " + clean_id)
		else:
			_working = source.duplicate(true) as ObjectDefinition
			var merge_result := ObjectCapabilityService.migrate_merged_selections(_working.capabilities)
			if bool(merge_result.get("changed", false)):
				_working.capabilities = merge_result.get("selections", [])
				_dirty_draft_ids[clean_id] = true
			_open_drafts[clean_id] = _working
			_saved_draft_ids[clean_id] = true
			_new_draft_ids.erase(clean_id)
			_dirty_draft_ids.erase(clean_id)

	_record_recent(clean_id)
	_pending_selections.clear()
	_pending_plan.clear()
	return _ok({"working": _serialize_definition(_working, true), "workspace": get_workspace_state()})


func _close_object(payload: Dictionary) -> Dictionary:
	var object_id := str(payload.get("object_id", _working.object_id if _working != null else "")).strip_edges()
	if object_id.is_empty():
		return _fail("Не выбрана вкладка для закрытия.")
	var closing_draft := _open_drafts.get(object_id) as ObjectDefinition
	# Do not discard a draft that is still the target of another open object's
	# relation. Otherwise the parent would retain a dangling object ID and the
	# save dialog could no longer offer that child for persistence.
	if _find_definition(object_id) == null:
		for source_id in _open_drafts:
			if str(source_id) == object_id:
				continue
			var source_definition := _open_drafts[source_id] as ObjectDefinition
			if source_definition == null:
				continue
			for relation in source_definition.relations:
				if str(relation.get("target_object_id", "")) == object_id:
					return _fail(
						"Нельзя закрыть связанный черновик «%s»: на него ссылается объект «%s». Сначала сохрани его или удали связь."
						% [closing_draft.display_name if closing_draft != null else object_id, source_definition.display_name]
					)
	if _new_draft_ids.has(object_id) and closing_draft != null:
		_cleanup_draft_scene(closing_draft)
	_new_draft_ids.erase(object_id)
	_dirty_draft_ids.erase(object_id)
	_saved_draft_ids.erase(object_id)
	_open_drafts.erase(object_id)
	if _working != null and _working.object_id == object_id:
		var next_id := str(payload.get("next_object_id", "")).strip_edges()
		var next_draft := _open_drafts.get(next_id) as ObjectDefinition
		_working = next_draft
		_pending_selections.clear()
		_pending_plan.clear()
	return _ok({"workspace": get_workspace_state()})


func _update_metadata(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var next_name := str(payload.get("name", _working.display_name)).strip_edges()
	var next_category := str(payload.get("category", _working.category)).strip_edges()
	var next_root := str(payload.get("root_type", _working.root_type)).strip_edges()
	if next_name.is_empty():
		return _fail("Название объекта не может быть пустым.")
	if next_category.is_empty():
		return _fail("Категория объекта не может быть пустой.")
	if not ClassDB.class_exists(next_root) or not ClassDB.can_instantiate(next_root):
		return _fail("Неизвестный или недоступный тип корневого узла: " + next_root)
	_working.display_name = next_name
	_working.description = str(payload.get("description", _working.description))
	_working.category = next_category
	_working.subcategory = str(payload.get("subcategory", _working.subcategory)).strip_edges()
	_working.root_type = next_root
	_working.is_template = bool(payload.get("is_template", _working.is_template))
	if payload.has("tags"):
		_working.tags = _string_array(payload.tags)
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _sync_working(payload: Dictionary) -> Dictionary:
	var record: Variant = payload.get("working", null)
	if not record is Dictionary or record.is_empty():
		return _ok({"working": _serialize_definition(_working, true) if _working != null else null})
	if _working == null or str(record.get("objectId", "")) != _working.object_id:
		var record_id := str(record.get("objectId", ""))
		var open_draft := _open_drafts.get(record_id) as ObjectDefinition
		if open_draft != null:
			_working = open_draft
		else:
			var source := _find_definition(record_id)
			if source != null:
				_working = source.duplicate(true) as ObjectDefinition
	if _working == null:
		return _fail("Активный объект не найден. Сначала открой его из библиотеки.")
	var before_sync := _serialize_definition(_working, true)
	var result := _apply_web_record(record)
	if not bool(result.get("ok", false)):
		return result
	var after_sync := _serialize_definition(_working, true)
	if before_sync != after_sync:
		_mark_working_dirty()
	_open_drafts[_working.object_id] = _working
	return _ok({"working": _serialize_definition(_working, true), "workspace": get_workspace_state()})


func _apply_web_record(record: Dictionary) -> Dictionary:
	_working.display_name = str(record.get("name", _working.display_name)).strip_edges()
	_working.description = str(record.get("description", _working.description))
	_working.category = str(record.get("category", _working.category)).strip_edges()
	_working.is_template = bool(record.get("isTemplate", _working.is_template))
	_working.subcategory = str(record.get("subcategory", _working.subcategory)).strip_edges()
	if record.has("nativeRootType"):
		var root_type := str(record.nativeRootType)
		if ClassDB.class_exists(root_type) and ClassDB.can_instantiate(root_type):
			_working.root_type = root_type
	if record.has("nativeObjectType"):
		_working.object_type = str(record.nativeObjectType)
	if record.has("emoji"):
		_working.preview_emoji = str(record.get("emoji", "◆"))
	if record.has("objectSize") and record.objectSize is Dictionary:
		_working.object_size = Vector2(
			clampf(float(record.objectSize.get("x", _working.object_size.x)), 1.0, 8192.0),
			clampf(float(record.objectSize.get("y", _working.object_size.y)), 1.0, 8192.0)
		)
	if record.has("spriteSheetHash") and str(record.spriteSheetHash) != _working.sprite_sheet_hash:
		var sheet_data := str(record.get("spriteSheetDataUrl", ""))
		if sheet_data.is_empty():
			_working.sprite_sheet_texture = null
			_working.sprite_sheet_hash = ""
		else:
			var decoded_sheet := _decode_preview_texture(sheet_data)
			if not bool(decoded_sheet.get("ok", false)):
				return _fail(str(decoded_sheet.get("error", "Не удалось восстановить spritesheet.")))
			_working.sprite_sheet_texture = decoded_sheet.get("texture") as Texture2D
			_working.sprite_sheet_hash = str(decoded_sheet.get("hash", ""))
	if record.has("spriteAnimations") and record.spriteAnimations is Array:
		_working.sprite_animations = _normalize_sprite_animations(record.spriteAnimations)
	if record.has("previewHash") and str(record.previewHash) != _working.preview_hash:
		var preview_data := str(record.get("previewDataUrl", ""))
		if preview_data.is_empty():
			_working.preview_texture = null
			_working.preview_hash = ""
		else:
			var decoded_preview := _decode_preview_texture(preview_data)
			if not bool(decoded_preview.get("ok", false)):
				return _fail(str(decoded_preview.get("error", "Не удалось восстановить спрайт.")))
			_working.preview_texture = decoded_preview.get("texture") as Texture2D
			_working.preview_hash = str(decoded_preview.get("hash", ""))
	if record.has("sprite") and record.sprite is Dictionary:
		var sprite_settings: Dictionary = record.sprite
		var sprite_scale: Variant = sprite_settings.get("scale", {})
		if sprite_scale is Dictionary:
			_working.preview_sprite_scale = Vector2(
				clampf(float(sprite_scale.get("x", _working.preview_sprite_scale.x)), 0.05, 16.0),
				clampf(float(sprite_scale.get("y", _working.preview_sprite_scale.y)), 0.05, 16.0)
			)
		var sprite_offset: Variant = sprite_settings.get("offset", {})
		if sprite_offset is Dictionary:
			_working.preview_sprite_offset = Vector2(
				clampf(float(sprite_offset.get("x", _working.preview_sprite_offset.x)), -8192.0, 8192.0),
				clampf(float(sprite_offset.get("y", _working.preview_sprite_offset.y)), -8192.0, 8192.0)
			)
		_working.preview_sprite_rotation_degrees = clampf(float(sprite_settings.get("rotation", _working.preview_sprite_rotation_degrees)), -36000.0, 36000.0)
		_working.preview_sprite_z_index = clampi(int(sprite_settings.get("zIndex", _working.preview_sprite_z_index)), -4096, 4096)
	if record.has("spriteLayers") and record.spriteLayers is Array:
		var previous_layers: Dictionary = {}
		for previous_layer in _working.sprite_layers:
			if previous_layer is Dictionary:
				previous_layers[str(previous_layer.get("id", ""))] = previous_layer
		var next_layers: Array[Dictionary] = []
		for layer_index in range(record.spriteLayers.size()):
			var raw_layer: Variant = record.spriteLayers[layer_index]
			if not raw_layer is Dictionary:
				continue
			var layer_data: Dictionary = raw_layer
			var layer_id := str(layer_data.get("id", "sprite_%d" % layer_index)).strip_edges()
			if layer_id.is_empty():
				layer_id = "sprite_%d" % layer_index
			var position_data: Variant = layer_data.get("position", {})
			var scale_data: Variant = layer_data.get("scale", {})
			var position := Vector2.ZERO
			var scale := Vector2.ONE
			if position_data is Dictionary:
				position = Vector2(
					clampf(float(position_data.get("x", 0.0)), -8192.0, 8192.0),
					clampf(float(position_data.get("y", 0.0)), -8192.0, 8192.0)
				)
			if scale_data is Dictionary:
				scale = Vector2(
					clampf(float(scale_data.get("x", 1.0)), 0.05, 16.0),
					clampf(float(scale_data.get("y", 1.0)), 0.05, 16.0)
				)
			var previous: Dictionary = previous_layers.get(layer_id, {})
			var layer_texture: Texture2D = previous.get("texture") as Texture2D
			var incoming_hash := str(layer_data.get("textureHash", ""))
			if incoming_hash != str(previous.get("texture_hash", "")) or (
				layer_texture == null and not str(layer_data.get("textureDataUrl", "")).is_empty()
			):
				var texture_data := str(layer_data.get("textureDataUrl", ""))
				if texture_data.is_empty():
					layer_texture = null
				else:
					var decoded_layer := _decode_preview_texture(texture_data)
					if not bool(decoded_layer.get("ok", false)):
						return _fail("Спрайт «%s»: %s" % [str(layer_data.get("name", layer_id)), str(decoded_layer.get("error", "не удалось загрузить изображение."))])
					layer_texture = decoded_layer.get("texture") as Texture2D
					incoming_hash = str(decoded_layer.get("hash", incoming_hash))
			next_layers.append({
				"id": layer_id,
				"name": str(layer_data.get("name", "Спрайт %d" % (layer_index + 1))),
				"texture": layer_texture,
				"texture_hash": incoming_hash,
				"position": position,
				"scale": scale,
				"rotation": clampf(float(layer_data.get("rotation", 0.0)), -36000.0, 36000.0),
				"z_index": clampi(int(layer_data.get("zIndex", 0)), -4096, 4096),
				"visible": bool(layer_data.get("visible", true)),
				"runtime_visible": bool(layer_data.get("runtimeVisible", true)),
				"embedded_relation_id": str(layer_data.get("embeddedRelationId", "")),
				"embedded_object_id": str(layer_data.get("embeddedObjectId", "")),
				"embedded_source_name": str(layer_data.get("embeddedSourceName", ""))
			})
		_working.sprite_layers = next_layers
	if record.has("collision") and record.collision is Dictionary:
		var collision: Dictionary = record.collision
		_working.collision_enabled = bool(collision.get("enabled", _working.collision_enabled))
		var collision_mode := str(collision.get("mode", _working.collision_mode))
		_working.collision_mode = collision_mode if collision_mode in ["solid", "area"] else "solid"
		var collision_shape := str(collision.get("shape", _working.collision_shape))
		_working.collision_shape = collision_shape if collision_shape in ["rectangle", "circle", "capsule"] else "rectangle"
		var collision_size: Variant = collision.get("size", {})
		if collision_size is Dictionary:
			_working.collision_size = Vector2(
				clampf(float(collision_size.get("x", _working.collision_size.x)), 1.0, 8192.0),
				clampf(float(collision_size.get("y", _working.collision_size.y)), 1.0, 8192.0)
			)
		_working.collision_radius = clampf(float(collision.get("radius", _working.collision_radius)), 1.0, 4096.0)
		_working.collision_height = clampf(float(collision.get("height", _working.collision_height)), 2.0, 8192.0)
		var collision_offset: Variant = collision.get("offset", {})
		if collision_offset is Dictionary:
			_working.collision_offset = Vector2(
				clampf(float(collision_offset.get("x", _working.collision_offset.x)), -8192.0, 8192.0),
				clampf(float(collision_offset.get("y", _working.collision_offset.y)), -8192.0, 8192.0)
			)
		_working.collision_layer = maxi(0, int(collision.get("layer", _working.collision_layer)))
		_working.collision_mask = maxi(0, int(collision.get("mask", _working.collision_mask)))
	if record.has("tags"):
		_working.tags = _string_array(record.tags)
	if record.has("relations") and record.relations is Array:
		_working.relations = _normalize_relations(record.relations)

	if record.has("properties") and record.properties is Array:
		var next_properties: Array[ObjectPropertyDefinition] = []
		for item in record.properties:
			if not item is Dictionary:
				continue
			var property_definition := PropertyScript.new() as ObjectPropertyDefinition
			property_definition.property_id = str(item.get("id", item.get("property_id", ""))).strip_edges()
			property_definition.display_name = str(item.get("name", item.get("display_name", ""))).strip_edges()
			property_definition.value_type = str(item.get("type", item.get("value_type", "String")))
			property_definition.default_value = _from_json(item.get("default", item.get("default_value", "")))
			property_definition.group_name = str(item.get("group", item.get("group_name", "Основное")))
			property_definition.description = str(item.get("description", ""))
			property_definition.advanced = bool(item.get("advanced", false))
			property_definition.has_range = bool(item.get("hasRange", item.get("has_range", false)))
			property_definition.minimum = float(item.get("min", item.get("minimum", 0.0)))
			property_definition.maximum = float(item.get("max", item.get("maximum", 100.0)))
			next_properties.append(property_definition)
		_working.custom_properties = next_properties

	if record.has("parts") and record.parts is Array:
		var next_nodes: Array[ObjectNodeDefinition] = []
		for item in record.parts:
			if not item is Dictionary:
				continue
			if bool(item.get("external", false)):
				# Nodes authored directly in Godot are exposed read-only in the
				# builder. They remain in the PackedScene and must not be cloned
				# into ObjectSceneStructureService's generated-node list.
				continue
			var node_id := str(item.get("id", ""))
			if node_id.is_empty() or node_id == "root":
				continue
			var node_definition := NodeDefinitionScript.new() as ObjectNodeDefinition
			node_definition.node_id = node_id
			node_definition.parent_node_id = str(item.get("parentId", item.get("parent_node_id", "root")))
			node_definition.node_type = str(item.get("nodeType", item.get("node_type", _node_type_for_kind(str(item.get("kind", "visual"))))))
			node_definition.node_name = str(item.get("name", item.get("node_name", "Node")))
			node_definition.enabled = bool(item.get("enabled", true))
			var node_properties: Variant = item.get("properties", {})
			node_definition.properties = node_properties.duplicate(true) if node_properties is Dictionary else {}
			node_definition.groups = _string_array(item.get("groups", []))
			var node_metadata: Variant = item.get("metadata", {})
			node_definition.metadata = node_metadata.duplicate(true) if node_metadata is Dictionary else {}
			next_nodes.append(node_definition)
		_working.node_definitions = next_nodes

	if record.has("components") and record.components is Array:
		var next_components: Array[ObjectComponentDefinition] = []
		for item in record.components:
			if not item is Dictionary:
				continue
			var component := ObjectComponentCatalog.create_definition(str(item.get("component_id", "")))
			if component == null:
				continue
			component.enabled = bool(item.get("enabled", true))
			var settings_value: Variant = item.get("settings", {})
			if settings_value is Dictionary:
				for setting_key in settings_value:
					if not component.set_setting(str(setting_key), _from_json(settings_value[setting_key])):
						return _fail("Некорректная настройка компонента '%s': %s" % [component.component_id, str(setting_key)])
			next_components.append(component)
		_working.components = next_components

	if record.has("caps") and record.caps is Array:
		var settings_by_capability: Variant = record.get("mechanicSettings", {})
		var automatic: PackedStringArray = _string_array(record.get("autoCaps", []))
		var next_capabilities: Array[ObjectCapabilitySelection] = []
		for id_value in record.caps:
			var capability_id := str(id_value).strip_edges().to_lower()
			var selection := ObjectCapabilityCatalog.create_selection(capability_id)
			if selection == null:
				continue
			selection.automatically_added = automatic.has(capability_id)
			if settings_by_capability is Dictionary and settings_by_capability.has(capability_id):
				var setting_data: Variant = settings_by_capability[capability_id]
				if setting_data is Dictionary:
					selection.settings_by_component = setting_data.duplicate(true)
			next_capabilities.append(selection)
		var errors := ObjectCapabilityService.validate_selections(next_capabilities)
		if not errors.is_empty():
			return _fail("Механики не прошли нативную проверку: " + "; ".join(errors))
		_working.capabilities = next_capabilities
	return _ok({"working": _serialize_definition(_working, true)})


func _save_working(payload: Dictionary = {}) -> Dictionary:
	if not _has_working():
		return _fail("Нет объекта для сохранения.")
	var primary_definition := _working
	var primary_id := primary_definition.object_id
	_open_drafts[primary_id] = primary_definition
	var selected_related_ids := _string_array(payload.get("related_object_ids", []))
	var saved_related_names: Array[String] = []
	var reused_related_names: Array[String] = []

	# Reconcile duplicate targets before processing the save-dialog selection.
	# Even an unchecked duplicate draft must not leave the parent linked to a
	# second unsaved identity when an equivalent saved library object exists.
	for relation_value in primary_definition.relations.duplicate(true):
		if not relation_value is Dictionary:
			continue
		var relation: Dictionary = relation_value
		var target_id := str(relation.get("target_object_id", "")).strip_edges()
		if target_id.is_empty() or target_id == primary_id:
			continue
		var existing_match: ObjectDefinition
		var target_draft := _open_drafts.get(target_id) as ObjectDefinition
		if target_draft != null and _new_draft_ids.has(target_id):
			existing_match = _find_existing_related_match(target_draft, primary_id)
		elif _find_definition(target_id) == null:
			var target_template := _find_template(target_id)
			if target_template != null:
				existing_match = _find_existing_related_match(target_template, primary_id)
		if existing_match != null:
			_replace_related_target_id(target_id, existing_match.object_id)
			if not reused_related_names.has(existing_match.display_name):
				reused_related_names.append(existing_match.display_name)

	for related_id in selected_related_ids:
		if related_id.is_empty() or related_id == primary_id:
			continue
		var related_definition := _open_drafts.get(related_id) as ObjectDefinition
		if related_definition == null:
			if _find_definition(related_id) != null:
				continue
			# Older builder versions could store a direct link to a template ID
			# instead of cloning that template into an object draft. Repair that
			# legacy relation here by creating a real independent object and
			# redirecting every open relation to its new persistent ID.
			var template_source := _find_template(related_id)
			if template_source != null:
				var existing_template_match := _find_existing_related_match(template_source, primary_id)
				if existing_template_match != null:
					_replace_related_target_id(related_id, existing_template_match.object_id)
					if not reused_related_names.has(existing_template_match.display_name):
						reused_related_names.append(existing_template_match.display_name)
					continue
				var template_values := {
					"display_name": template_source.display_name,
					"category": template_source.category,
					"description": template_source.description,
					"tags": template_source.tags
				}
				var repaired_result: Dictionary = CreationService.create_from_source(template_source, template_values)
				if bool(repaired_result.get("ok", false)):
					related_definition = repaired_result.get("definition") as ObjectDefinition
				if related_definition != null:
					_new_draft_ids[related_definition.object_id] = true
					_saved_draft_ids.erase(related_definition.object_id)
					_dirty_draft_ids.erase(related_definition.object_id)
					_open_drafts[related_definition.object_id] = related_definition
					_replace_related_target_id(related_id, related_definition.object_id)
			if related_definition == null:
				var source_name := related_id
				for relation in primary_definition.relations:
					if str(relation.get("target_object_id", "")) == related_id:
						source_name = str(relation.get("label", related_id))
						break
				var missing_result := _fail("Связанный объект «%s» больше не существует. Связь сохранена, но для неё нужно выбрать существующий объект или удалить её." % source_name)
				missing_result["workspace"] = get_workspace_state()
				missing_result["working"] = _serialize_definition(primary_definition, true)
				return missing_result
		# A new related draft can be an accidental second copy of an object
		# that is already in the project library. Reuse that saved definition
		# by its template identity first, then by exact name/category identity.
		if _new_draft_ids.has(related_id):
			var existing_match := _find_existing_related_match(related_definition, primary_id)
			if existing_match != null:
				_replace_related_target_id(related_id, existing_match.object_id)
				if not reused_related_names.has(existing_match.display_name):
					reused_related_names.append(existing_match.display_name)
				continue

		var library_definition := _find_definition(related_id)
		var is_dirty_related := _dirty_draft_ids.has(related_id)
		# An open ObjectDefinition is a real save candidate even if its "new draft"
		# bookkeeping was lost during an editor/tab switch. The library lookup is
		# the source of truth: if it is absent, persist the draft instead of silently
		# skipping it and reporting the parent as fully saved.
		if library_definition != null and not is_dirty_related:
			continue
		_working = related_definition
		_ensure_unique_display_name(saved_related_names)
		var related_result := _save_working_single()
		if not bool(related_result.get("ok", false)):
			_working = primary_definition
			_open_drafts[primary_id] = primary_definition
			var related_failure := _fail(
				"Не удалось сохранить связанный объект «%s». Основной объект пока не сохранён. %s"
				% [related_definition.display_name, str(related_result.get("error", "Ошибка сохранения."))]
			)
			related_failure["workspace"] = get_workspace_state()
			related_failure["working"] = _serialize_definition(primary_definition, true)
			related_failure["reused_related_names"] = reused_related_names
			return related_failure
		saved_related_names.append(_working.display_name)
		# A legacy template relation may have been remapped to a freshly cloned
		# object ID above. Always index the saved draft by its actual object ID.
		_open_drafts[_working.object_id] = _working
		_working = primary_definition

	_working = primary_definition
	_ensure_unique_display_name(saved_related_names)
	var primary_result := _save_working_single()
	if not bool(primary_result.get("ok", false)):
		var failure_message := str(primary_result.get("error", "Ошибка сохранения."))
		if not saved_related_names.is_empty():
			failure_message = "Связанные объекты сохранены (%s), но основной объект сохранить не удалось: %s" % [", ".join(saved_related_names), failure_message]
		var primary_failure := _fail(failure_message)
		primary_failure["workspace"] = get_workspace_state()
		primary_failure["working"] = _serialize_definition(primary_definition, true)
		primary_failure["saved_related_names"] = saved_related_names
		primary_failure["reused_related_names"] = reused_related_names
		return primary_failure
	primary_result["saved_related_names"] = saved_related_names
	primary_result["reused_related_names"] = reused_related_names
	primary_result["workspace"] = get_workspace_state()
	if saved_related_names.is_empty() and reused_related_names.is_empty():
		primary_result["message"] = "ObjectDefinition и сцена сохранены."
	elif saved_related_names.is_empty():
		primary_result["message"] = "Основной объект сохранён. Использованы существующие связанные записи: " + ", ".join(reused_related_names)
	else:
		var message_names := saved_related_names.duplicate()
		for reused_name in reused_related_names:
			if not message_names.has(reused_name):
				message_names.append(reused_name)
		primary_result["message"] = "Основной объект и связи сохранены. Связанные объекты: " + ", ".join(message_names)
	return primary_result


func _save_working_as(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Нет объекта для сохранения.")
	var source_definition := _working
	var requested_name := str(payload.get("name", "")).strip_edges()
	if requested_name.is_empty():
		return _fail("Укажи название новой копии.")

	# Keep links intact. Reuse a matching saved target in the copy without
	# changing the original object's relation list.
	var relation_remaps: Dictionary = {}
	for relation in source_definition.relations:
		var target_id := str(relation.get("target_object_id", "")).strip_edges()
		if target_id.is_empty() or _find_definition(target_id) != null:
			continue
		var target_draft := _open_drafts.get(target_id) as ObjectDefinition
		if target_draft != null and _new_draft_ids.has(target_id):
			var existing_target := _find_existing_related_match(target_draft, source_definition.object_id)
			if existing_target != null:
				relation_remaps[target_id] = existing_target.object_id
				continue
			return _fail(
				"Нельзя выполнить «Сохранить как»: связанный объект «%s» ещё не сохранён. Сначала сохрани его в библиотеку."
				% target_draft.display_name
			)
		var target_template := _find_template(target_id)
		if target_template != null:
			var existing_template := _find_existing_related_match(target_template, source_definition.object_id)
			if existing_template != null:
				relation_remaps[target_id] = existing_template.object_id
				continue
		return _fail(
			"Нельзя выполнить «Сохранить как»: связанный объект с ID %s не найден в библиотеке."
			% target_id
		)

	var creation_result: Dictionary = CreationService.create_from_source(source_definition, {
		"display_name": requested_name,
		"category": source_definition.category,
		"description": source_definition.description,
		"tags": source_definition.tags
	})
	if not bool(creation_result.get("ok", false)):
		return _fail(str(creation_result.get("message", "Не удалось создать копию объекта.")))
	var copy_definition := creation_result.get("definition") as ObjectDefinition
	if copy_definition == null:
		return _fail("Не удалось получить определение новой копии.")

	# Apply compatibility/reuse remaps to the copy only. The source stays untouched.
	for relation_index in range(copy_definition.relations.size()):
		var copy_relation: Dictionary = copy_definition.relations[relation_index]
		var previous_target_id := str(copy_relation.get("target_object_id", "")).strip_edges()
		if relation_remaps.has(previous_target_id):
			copy_relation["target_object_id"] = str(relation_remaps[previous_target_id])
			copy_definition.relations[relation_index] = copy_relation

	var source_id := source_definition.object_id
	var copy_id := copy_definition.object_id
	_open_drafts[source_id] = source_definition
	_open_drafts[copy_id] = copy_definition
	_new_draft_ids[copy_id] = true
	_dirty_draft_ids.erase(copy_id)
	_saved_draft_ids.erase(copy_id)
	_working = copy_definition

	var save_result := _save_working_single()
	if not bool(save_result.get("ok", false)):
		_working = source_definition
		_open_drafts.erase(copy_id)
		_new_draft_ids.erase(copy_id)
		_dirty_draft_ids.erase(copy_id)
		_saved_draft_ids.erase(copy_id)
		_cleanup_draft_scene(copy_definition)
		save_result["working"] = _serialize_definition(source_definition, true)
		save_result["workspace"] = get_workspace_state()
		return save_result

	save_result["working"] = _serialize_definition(_working, true)
	save_result["workspace"] = get_workspace_state()
	save_result["message"] = "Создана и сохранена отдельная копия «%s». Исходный объект не изменён." % _working.display_name
	return save_result


func _find_existing_related_match(candidate: ObjectDefinition, excluded_id: String = "") -> ObjectDefinition:
	if candidate == null:
		return null
	var existing_objects := ObjectLibraryService.load_definitions()
	var source_template_id := candidate.template_id.strip_edges()
	if not source_template_id.is_empty():
		for existing in existing_objects:
			if (
				existing != null
				and existing.object_id != excluded_id
				and existing.template_id == source_template_id
			):
				return existing

	var candidate_name := candidate.display_name.strip_edges().to_lower().replace("ё", "е")
	var candidate_category := candidate.category.strip_edges().to_lower()
	var candidate_subcategory := candidate.subcategory.strip_edges().to_lower()
	if candidate_name.is_empty() or candidate_category.is_empty():
		return null
	for existing in existing_objects:
		if existing == null or existing.object_id == excluded_id:
			continue
		if existing.display_name.strip_edges().to_lower().replace("ё", "е") != candidate_name:
			continue
		if existing.category.strip_edges().to_lower() != candidate_category:
			continue
		var existing_subcategory := existing.subcategory.strip_edges().to_lower()
		if not candidate_subcategory.is_empty() and not existing_subcategory.is_empty():
			if existing_subcategory != candidate_subcategory:
				continue
		return existing
	return null


func _replace_related_target_id(old_id: String, new_id: String) -> void:
	if old_id.is_empty() or new_id.is_empty() or old_id == new_id:
		return
	for draft_id in _open_drafts:
		var draft := _open_drafts[draft_id] as ObjectDefinition
		if draft == null:
			continue
		var changed := false
		for index in range(draft.relations.size()):
			var relation: Dictionary = draft.relations[index]
			if str(relation.get("target_object_id", "")) != old_id:
				continue
			relation["target_object_id"] = new_id
			draft.relations[index] = relation
			changed = true
		if changed:
			_dirty_draft_ids[draft.object_id] = true
			_open_drafts[draft.object_id] = draft
	if _working != null:
		for index in range(_working.relations.size()):
			var relation: Dictionary = _working.relations[index]
			if str(relation.get("target_object_id", "")) == old_id:
				relation["target_object_id"] = new_id
				_working.relations[index] = relation
		_dirty_draft_ids[_working.object_id] = true
		_open_drafts[_working.object_id] = _working


func _ensure_unique_display_name(reserved_names: Array[String] = []) -> void:
	if _working == null:
		return
	var base_name := _working.display_name.strip_edges()
	if base_name.is_empty():
		base_name = "Новый объект"
	var definitions: Array[ObjectDefinition] = (
		ObjectLibraryService.load_templates() if _working.is_template
		else ObjectLibraryService.load_definitions()
	)
	var duplicate_found := false
	for existing in definitions:
		if existing != null and existing.object_id != _working.object_id and existing.display_name.strip_edges().to_lower() == base_name.to_lower():
			duplicate_found = true
			break
	if not duplicate_found:
		for reserved_name in reserved_names:
			if reserved_name.strip_edges().to_lower() == base_name.to_lower():
				duplicate_found = true
				break
	if not duplicate_found:
		_working.display_name = base_name
		return
	var suffix := 2
	var candidate := ""
	while suffix < 10000:
		candidate = "%s (%d)" % [base_name, suffix]
		var occupied := false
		for existing in definitions:
			if existing != null and existing.object_id != _working.object_id and existing.display_name.strip_edges().to_lower() == candidate.to_lower():
				occupied = true
				break
		if not occupied:
			for reserved_name in reserved_names:
				if reserved_name.strip_edges().to_lower() == candidate.to_lower():
					occupied = true
					break
		if not occupied:
			break
		suffix += 1
	_working.display_name = candidate


func _save_working_single() -> Dictionary:
	if not _has_working():
		return _fail("Нет объекта для сохранения.")
	_working.relations = _normalize_relations(_working.relations)
	if _working.display_name.strip_edges().is_empty():
		return _fail("Название объекта не может быть пустым.")
	if _working.category.strip_edges().is_empty():
		return _fail("Категория объекта не может быть пустой.")
	var errors := ObjectLibraryService.validate_definition(_working)
	if not errors.is_empty():
		return _fail("Сохранение отменено: " + "; ".join(errors))

	# Keep byte-for-byte snapshots of both paths because a name/category change moves
	# the PackedScene before the matching ObjectDefinition is committed.
	var previous_scene_path := _working.scene_path
	var previous_scene_resource := _working.scene
	var target_scene_path := ObjectLibraryService.get_scene_path_for_definition(_working)
	var had_previous_scene := not previous_scene_path.is_empty() and FileAccess.file_exists(previous_scene_path)
	var previous_scene_bytes := FileAccess.get_file_as_bytes(previous_scene_path) if had_previous_scene else PackedByteArray()
	var target_is_previous := target_scene_path == previous_scene_path
	var had_target_scene := not target_is_previous and FileAccess.file_exists(target_scene_path)
	var target_scene_bytes := FileAccess.get_file_as_bytes(target_scene_path) if had_target_scene else PackedByteArray()

	var scene_result: Dictionary = SceneDraftService.sync_scene(_working)
	if not bool(scene_result.get("ok", false)):
		var restored := _restore_scene_save_snapshot(
			previous_scene_path, previous_scene_bytes, had_previous_scene,
			target_scene_path, target_scene_bytes, had_target_scene,
			previous_scene_resource
		)
		EditorInterface.get_resource_filesystem().scan()
		var sync_message := str(scene_result.get("message", "Не удалось синхронизировать сцену объекта."))
		if not restored:
			sync_message += " Не удалось автоматически восстановить один из файлов сцены."
		return _fail(sync_message)

	var save_error: Error = ObjectLibraryService.save_template(_working) if _working.is_template else ObjectLibraryService.save_definition(_working)
	if save_error != OK:
		var restored := _restore_scene_save_snapshot(
			previous_scene_path, previous_scene_bytes, had_previous_scene,
			target_scene_path, target_scene_bytes, had_target_scene,
			previous_scene_resource
		)
		EditorInterface.get_resource_filesystem().scan()
		if not restored:
			return _fail(
				"Не удалось сохранить ObjectDefinition (код %d). Автоматическое восстановление старой/новой сцены не удалось."
				% save_error
			)
		return _fail("Не удалось сохранить ObjectDefinition. Предыдущая сцена восстановлена. Код ошибки: %d" % save_error)

	EditorInterface.get_resource_filesystem().scan()
	_working = ObjectLibraryService.load_definition(_working.object_id) if not _working.is_template else _find_template(_working.object_id)
	_open_drafts[_working.object_id] = _working
	_new_draft_ids.erase(_working.object_id)
	_dirty_draft_ids.erase(_working.object_id)
	_saved_draft_ids[_working.object_id] = true
	_record_recent(_working.object_id)
	return _ok({
		"working": _serialize_definition(_working, true),
		"workspace": get_workspace_state(),
		"message": "ObjectDefinition и сцена сохранены."
	})


func _restore_scene_save_snapshot(
	previous_scene_path: String,
	previous_scene_bytes: PackedByteArray,
	had_previous_scene: bool,
	target_scene_path: String,
	target_scene_bytes: PackedByteArray,
	had_target_scene: bool,
	previous_scene_resource: PackedScene
) -> bool:
	var restored := true
	if not previous_scene_path.is_empty() and had_previous_scene:
		var previous_file := FileAccess.open(previous_scene_path, FileAccess.WRITE)
		if previous_file == null:
			restored = false
		else:
			previous_file.store_buffer(previous_scene_bytes)
			restored = previous_file.get_error() == OK and restored
			previous_file.close()

	if target_scene_path == previous_scene_path:
		if not had_previous_scene and FileAccess.file_exists(target_scene_path):
			var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(target_scene_path))
			restored = remove_error == OK and restored
	else:
		if had_target_scene:
			var target_file := FileAccess.open(target_scene_path, FileAccess.WRITE)
			if target_file == null:
				restored = false
			else:
				target_file.store_buffer(target_scene_bytes)
				restored = target_file.get_error() == OK and restored
				target_file.close()
		elif FileAccess.file_exists(target_scene_path):
			var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(target_scene_path))
			restored = remove_error == OK and restored

	_working.scene = previous_scene_resource
	_working.scene_path = previous_scene_path
	return restored


func _plan_capability(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var capability_id := str(payload.get("capability_id", "")).strip_edges().to_lower()
	var plan := ObjectCapabilityService.plan_selection_change(
		_working.capabilities, capability_id, bool(payload.get("enabled", true))
	)
	if not bool(plan.get("ok", false)):
		return _fail("; ".join(plan.get("errors", PackedStringArray())))
	var next_values: Array[ObjectCapabilitySelection] = []
	for value in plan.get("selections", []):
		if value is ObjectCapabilitySelection:
			next_values.append(value as ObjectCapabilitySelection)
	var application := ObjectCapabilityService.build_application_plan(_working.capabilities, next_values)
	if not bool(application.get("ok", false)):
		return _fail("; ".join(application.get("errors", PackedStringArray())))
	_pending_selections = next_values
	_pending_plan = application
	return _ok({
		"requires_confirmation": bool(application.get("changed", false)),
		"summary_lines": application.get("summary_lines", PackedStringArray()),
		"added_capability_ids": application.get("added_capability_ids", PackedStringArray()),
		"removed_capability_ids": application.get("removed_capability_ids", PackedStringArray())
	})


func _commit_capability() -> Dictionary:
	if not _has_working() or _pending_plan.is_empty():
		return _fail("Нет подготовленного изменения механик.")
	var application := ObjectCapabilityService.build_application_plan(_working.capabilities, _pending_selections)
	if not bool(application.get("ok", false)):
		_pending_selections.clear()
		_pending_plan.clear()
		return _fail("Изменение не применено: " + "; ".join(application.get("errors", PackedStringArray())))
	_working.capabilities = _pending_selections.duplicate(true)
	# Fold deprecated standalone choices immediately when the user changes the
	# mechanic set; no reopen or editor restart is needed.
	var merged_result := ObjectCapabilityService.migrate_merged_selections(_working.capabilities)
	_working.capabilities = merged_result.get("selections", [])
	# Older objects may still carry system fields as custom properties when
	# their owning mechanic had not been enabled during the startup migration.
	# Adopt those fields as soon as the user installs the mechanic.
	_migrate_legacy_mechanic_properties(_working)
	_pending_selections.clear()
	_pending_plan.clear()
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _save_capability_settings(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var capability_id := str(payload.get("capability_id", "")).strip_edges().to_lower()
	var current := _find_selection(capability_id)
	if current == null or not current.enabled:
		return _fail("Механика не подключена к объекту.")
	var updated := current.duplicate(true) as ObjectCapabilitySelection
	var changes: Variant = payload.get("settings", [])
	if changes is Array:
		for entry in changes:
			if entry is Dictionary:
				updated.set_component_setting(
					str(entry.get("component_id", "")),
					str(entry.get("setting_key", "")),
					_from_json(entry.get("value"))
				)
	var next_values: Array[ObjectCapabilitySelection] = []
	for selection in _working.capabilities:
		next_values.append(updated if selection.capability_id == capability_id else selection.duplicate(true) as ObjectCapabilitySelection)
	var application := ObjectCapabilityService.build_application_plan(_working.capabilities, next_values)
	if not bool(application.get("ok", false)):
		return _fail("Настройки не применены: " + "; ".join(application.get("errors", PackedStringArray())))
	_working.capabilities = next_values
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _add_property(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var property_id := str(payload.get("id", "")).strip_edges()
	if property_id.is_empty():
		return _fail("У свойства должен быть ID.")
	for current in _working.custom_properties:
		if current != null and current.property_id == property_id:
			return _fail("Свойство с таким ID уже существует.")
	var definition := PropertyScript.new() as ObjectPropertyDefinition
	definition.property_id = property_id
	definition.display_name = str(payload.get("name", property_id)).strip_edges()
	definition.value_type = str(payload.get("type", "String"))
	definition.default_value = _from_json(payload.get("default", ""))
	definition.group_name = str(payload.get("group", "Основное"))
	definition.description = str(payload.get("description", ""))
	definition.advanced = bool(payload.get("advanced", false))
	definition.has_range = bool(payload.get("has_range", false))
	definition.minimum = float(payload.get("minimum", 0.0))
	definition.maximum = float(payload.get("maximum", 100.0))
	_working.custom_properties.append(definition)
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _update_property(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var property_id := str(payload.get("id", ""))
	for definition in _working.custom_properties:
		if definition == null or definition.property_id != property_id:
			continue
		definition.display_name = str(payload.get("name", definition.display_name))
		definition.value_type = str(payload.get("type", definition.value_type))
		definition.default_value = _from_json(payload.get("default", definition.default_value))
		definition.group_name = str(payload.get("group", definition.group_name))
		definition.description = str(payload.get("description", definition.description))
		definition.advanced = bool(payload.get("advanced", definition.advanced))
		definition.has_range = bool(payload.get("has_range", definition.has_range))
		definition.minimum = float(payload.get("minimum", definition.minimum))
		definition.maximum = float(payload.get("maximum", definition.maximum))
		_mark_working_dirty()
		return _ok({"working": _serialize_definition(_working, true)})
	return _fail("Свойство не найдено: " + property_id)


func _remove_property(property_id: String) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	for index in range(_working.custom_properties.size()):
		var definition := _working.custom_properties[index]
		if definition != null and definition.property_id == property_id:
			_working.custom_properties.remove_at(index)
			_mark_working_dirty()
			return _ok({"working": _serialize_definition(_working, true)})
	return _fail("Свойство не найдено: " + property_id)


func _add_part(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var node_type := str(payload.get("node_type", "Node2D")).strip_edges()
	if not ClassDB.class_exists(node_type) or not ClassDB.can_instantiate(node_type):
		return _fail("Неизвестный тип узла: " + node_type)
	var node_id := str(payload.get("id", "")).strip_edges()
	if node_id.is_empty():
		node_id = "node_" + str(Time.get_ticks_usec())
	if _find_node(node_id) != null:
		return _fail("Узел с таким ID уже существует.")
	var parent_id := str(payload.get("parent_id", "root")).strip_edges()
	if parent_id != "root" and _find_node(parent_id) == null:
		return _fail("Родительский узел не найден: " + parent_id)
	var definition := NodeDefinitionScript.new() as ObjectNodeDefinition
	definition.node_id = node_id
	definition.parent_node_id = parent_id
	definition.node_type = node_type
	definition.node_name = str(payload.get("name", node_type))
	_working.node_definitions.append(definition)
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _update_part(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var node_id := str(payload.get("id", ""))
	var definition := _find_node(node_id)
	if definition == null:
		return _fail("Часть объекта не найдена: " + node_id)
	var next_parent := str(payload.get("parent_id", definition.parent_node_id))
	if next_parent == node_id or _is_descendant(next_parent, node_id):
		return _fail("Нельзя переместить узел внутрь самого себя или собственного потомка.")
	if next_parent != "root" and _find_node(next_parent) == null:
		return _fail("Родительский узел не найден: " + next_parent)
	definition.parent_node_id = next_parent
	definition.node_name = str(payload.get("name", definition.node_name))
	var requested_type := str(payload.get("node_type", definition.node_type)).strip_edges()
	if not ClassDB.class_exists(requested_type) or not ClassDB.can_instantiate(requested_type):
		return _fail("Неизвестный тип узла: " + requested_type)
	definition.node_type = requested_type
	definition.enabled = bool(payload.get("enabled", definition.enabled))
	var properties_value: Variant = payload.get("properties", definition.properties)
	if properties_value is Dictionary:
		definition.properties = properties_value.duplicate(true)
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _remove_part(node_id: String) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var target := _find_node(node_id)
	if target == null:
		return _fail("Часть объекта не найдена: " + node_id)
	# Reparent children; deleting one visual node must not silently erase its subtree.
	for definition in _working.node_definitions:
		if definition != null and definition.parent_node_id == node_id:
			definition.parent_node_id = target.parent_node_id
	_working.node_definitions.erase(target)
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _add_relation(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var target_id := str(payload.get("target_object_id", "")).strip_edges()
	if target_id.is_empty():
		return _fail("Для связи выбери существующий объект из библиотеки.")
	if target_id == _working.object_id:
		return _fail("Объект не может ссылаться сам на себя.")
	if _find_definition(target_id) == null and not _open_drafts.has(target_id):
		return _fail("Целевой объект отсутствует в библиотеке и среди открытых черновиков: " + target_id)
	var mechanic_id := str(payload.get("mechanic_id", "")).strip_edges()
	var relation_kind := str(payload.get("kind", "related")).strip_edges()
	var owner_error := _validate_relation_owner(mechanic_id, relation_kind, target_id)
	if not owner_error.is_empty():
		return _fail(owner_error)
	var relation_id := str(payload.get("relation_id", "")).strip_edges()
	if relation_id.is_empty():
		relation_id = "relation_" + str(Time.get_ticks_usec())
	for relation in _working.relations:
		if str(relation.get("relation_id", "")) == relation_id:
			return _fail("Связь с таким ID уже существует.")
	var settings: Variant = payload.get("settings", {})
	_working.relations.append({
		"relation_id": relation_id,
		"target_object_id": target_id,
		"mechanic_id": mechanic_id,
		"kind": relation_kind,
		"label": str(payload.get("label", "")),
		"quantity": maxi(1, int(payload.get("quantity", 1))),
		"settings": settings.duplicate(true) if settings is Dictionary else {}
	})
	_open_drafts[_working.object_id] = _working
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _embed_relation_as_part(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай родительский объект.")
	var relation_id := str(payload.get("relation_id", "")).strip_edges()
	var relation_index := -1
	for index in range(_working.relations.size()):
		if str(_working.relations[index].get("relation_id", "")) == relation_id:
			relation_index = index
			break

	var is_new_relation := relation_index < 0
	var relation: Dictionary
	if is_new_relation:
		if not relation_id.is_empty():
			return _fail("Связь остатков не найдена: " + relation_id)
		var new_target_id := str(payload.get("target_object_id", "")).strip_edges()
		if new_target_id.is_empty() or new_target_id == _working.object_id:
			return _fail("Не выбран корректный объект-остаток.")
		if _find_definition(new_target_id) == null and not _open_drafts.has(new_target_id):
			return _fail("Объект-остаток не найден в библиотеке или среди открытых черновиков.")
		var new_mechanic_id := str(payload.get("mechanic_id", "breaks_when_health_empty")).strip_edges()
		var owner_error := _validate_relation_owner(new_mechanic_id, "remains", new_target_id)
		if not owner_error.is_empty():
			return _fail(owner_error)
		relation_id = "relation_" + str(Time.get_ticks_usec())
		var incoming_settings: Variant = payload.get("settings", {})
		relation = {
			"relation_id": relation_id,
			"target_object_id": new_target_id,
			"mechanic_id": new_mechanic_id,
			"kind": "remains",
			"label": str(payload.get("label", "Остаток после разрушения")),
			"quantity": maxi(1, int(payload.get("quantity", 1))),
			"settings": incoming_settings.duplicate(true) if incoming_settings is Dictionary else {}
		}
	else:
		relation = _working.relations[relation_index].duplicate(true)
		if str(relation.get("kind", "")) != "remains":
			return _fail("Встраивать в объект можно только связь «Остаётся после разрушения».")
		var updated_target_id := str(payload.get("target_object_id", relation.get("target_object_id", ""))).strip_edges()
		if updated_target_id.is_empty() or updated_target_id == _working.object_id:
			return _fail("Не выбран корректный объект-остаток.")
		var updated_mechanic_id := str(payload.get("mechanic_id", relation.get("mechanic_id", "breaks_when_health_empty"))).strip_edges()
		var owner_error := _validate_relation_owner(updated_mechanic_id, "remains", updated_target_id, relation_id)
		if not owner_error.is_empty():
			return _fail(owner_error)
		relation["target_object_id"] = updated_target_id
		relation["mechanic_id"] = updated_mechanic_id
	var settings_value: Variant = relation.get("settings", {})
	var settings: Dictionary = settings_value.duplicate(true) if settings_value is Dictionary else {}
	# A new relation arrives with embed_in_parent=true as the user's requested
	# action. Only an already-stored relation can be considered embedded.
	if not is_new_relation and bool(settings.get("embed_in_parent", false)):
		return _ok({"working": _serialize_definition(_working, true), "message": "Остаток уже встроен."})

	var target_id := str(relation.get("target_object_id", "")).strip_edges()
	if target_id.is_empty() or target_id == _working.object_id:
		return _fail("Не выбран корректный объект-остаток.")
	var target := _open_drafts.get(target_id) as ObjectDefinition
	if target == null:
		target = _find_definition(target_id)
	if target == null:
		return _fail("Объект-остаток не найден в библиотеке или среди открытых черновиков.")

	var source_layers: Array[Dictionary] = []
	if target.preview_texture != null:
		source_layers.append({
			"name": "Основной спрайт",
			"texture": target.preview_texture,
			"texture_hash": target.preview_hash,
			"position": target.preview_sprite_offset,
			"scale": target.preview_sprite_scale,
			"rotation": target.preview_sprite_rotation_degrees,
			"z_index": target.preview_sprite_z_index,
			"visible": true
		})
	for source_value in target.sprite_layers:
		if not source_value is Dictionary:
			continue
		var source_layer: Dictionary = source_value
		var source_texture := source_layer.get("texture") as Texture2D
		if source_texture == null:
			continue
		var source_position: Variant = source_layer.get("position", Vector2.ZERO)
		var source_scale: Variant = source_layer.get("scale", Vector2.ONE)
		source_layers.append({
			"name": str(source_layer.get("name", "Спрайт")),
			"texture": source_texture,
			"texture_hash": str(source_layer.get("texture_hash", "")),
			"position": source_position if source_position is Vector2 else Vector2.ZERO,
			"scale": source_scale if source_scale is Vector2 else Vector2.ONE,
			"rotation": float(source_layer.get("rotation", 0.0)),
			"z_index": int(source_layer.get("z_index", 0)),
			"visible": bool(source_layer.get("visible", true))
		})
	if source_layers.is_empty():
		return _fail("У выбранного объекта нет спрайтов. Сначала добавь ему основной или дополнительный спрайт.")

	if _working.sprite_layers.size() + source_layers.size() > 24:
		return _fail("Для встраивания не хватает места: в объекте может быть не больше 24 дополнительных слоёв.")
	var base_z := 0
	for existing_layer in _working.sprite_layers:
		if existing_layer is Dictionary:
			base_z = maxi(base_z, int(existing_layer.get("z_index", 0)) + 1)
	var embedded_ids := PackedStringArray()
	var safe_relation_id := relation_id.validate_filename()
	if safe_relation_id.is_empty():
		safe_relation_id = str(Time.get_ticks_usec())
	for source_index in range(source_layers.size()):
		var source_layer: Dictionary = source_layers[source_index]
		var layer_id := "embedded_%s_%d" % [safe_relation_id, source_index]
		embedded_ids.append(layer_id)
		var source_position: Variant = source_layer.get("position", Vector2.ZERO)
		var source_scale: Variant = source_layer.get("scale", Vector2.ONE)
		_working.sprite_layers.append({
			"id": layer_id,
			"name": "%s — %s" % [target.display_name, str(source_layer.get("name", "Спрайт"))],
			"texture": source_layer.get("texture") as Texture2D,
			"texture_hash": str(source_layer.get("texture_hash", "")),
			"position": source_position if source_position is Vector2 else Vector2.ZERO,
			"scale": source_scale if source_scale is Vector2 else Vector2.ONE,
			"rotation": float(source_layer.get("rotation", 0.0)),
			"z_index": clampi(base_z + int(source_layer.get("z_index", 0)), -4096, 4096),
			"visible": bool(source_layer.get("visible", true)),
			"runtime_visible": false,
			"embedded_relation_id": relation_id,
			"embedded_object_id": target_id,
			"embedded_source_name": target.display_name
		})

	settings["embed_in_parent"] = true
	settings["embedded_layer_ids"] = _to_json(embedded_ids)
	settings["embedded_source_name"] = target.display_name
	relation["settings"] = settings
	relation["label"] = str(payload.get("label", relation.get("label", "Остаток после разрушения")))
	relation["quantity"] = maxi(1, int(payload.get("quantity", relation.get("quantity", 1))))
	if is_new_relation:
		_working.relations.append(relation)
	else:
		_working.relations[relation_index] = relation
	_mark_working_dirty()
	return _ok({
		"working": _serialize_definition(_working, true),
		"message": "Спрайты объекта скопированы в родительский объект отдельными скрытыми слоями."
	})


func _update_relation(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var relation_id := str(payload.get("relation_id", ""))
	for index in range(_working.relations.size()):
		var relation: Dictionary = _working.relations[index]
		if str(relation.get("relation_id", "")) != relation_id:
			continue
		var target_id := str(payload.get("target_object_id", relation.get("target_object_id", "")))
		if target_id == _working.object_id:
			return _fail("Объект не может ссылаться сам на себя.")
		if _find_definition(target_id) == null and not _open_drafts.has(target_id):
			return _fail("Целевой объект не найден ни в библиотеке, ни среди открытых черновиков.")
		var next_mechanic_id := str(payload.get("mechanic_id", relation.get("mechanic_id", ""))).strip_edges()
		var next_kind := str(payload.get("kind", relation.get("kind", "related"))).strip_edges()
		var owner_error := _validate_relation_owner(next_mechanic_id, next_kind, target_id, relation_id)
		if not owner_error.is_empty():
			return _fail(owner_error)
		relation["target_object_id"] = target_id
		relation["mechanic_id"] = next_mechanic_id
		relation["kind"] = next_kind
		relation["label"] = str(payload.get("label", relation.get("label", "")))
		relation["quantity"] = maxi(1, int(payload.get("quantity", relation.get("quantity", 1))))
		if payload.get("settings") is Dictionary:
			relation["settings"] = payload.settings.duplicate(true)
		_working.relations[index] = relation
		_mark_working_dirty()
		return _ok({"working": _serialize_definition(_working, true)})
	return _fail("Связь не найдена: " + relation_id)

func _remove_relation(relation_id: String) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	for index in range(_working.relations.size()):
		if str(_working.relations[index].get("relation_id", "")) == relation_id:
			_working.relations.remove_at(index)
			_mark_working_dirty()
			return _ok({"working": _serialize_definition(_working, true)})
	return _fail("Связь не найдена: " + relation_id)

func _duplicate_object(object_id: String) -> Dictionary:
	if _working != null:
		_open_drafts[_working.object_id] = _working
	var source := _find_definition(object_id)
	if source == null:
		return _fail("Объект не найден.")
	var result: Dictionary = LibraryActionsService.duplicate_definition(source)
	if not bool(result.get("ok", false)):
		return _fail(str(result.get("message", "Не удалось дублировать объект.")))
	_working = (result.get("definition") as ObjectDefinition).duplicate(true) as ObjectDefinition
	_open_drafts[_working.object_id] = _working
	_new_draft_ids.erase(_working.object_id)
	_dirty_draft_ids.erase(_working.object_id)
	_saved_draft_ids[_working.object_id] = true
	_record_recent(_working.object_id)
	EditorInterface.get_resource_filesystem().scan()
	return _ok({"working": _serialize_definition(_working, true), "workspace": get_workspace_state()})


func _create_template(object_id: String) -> Dictionary:
	var source := _find_definition(object_id)
	if source == null:
		return _fail("Исходный объект не найден.")
	var result: Dictionary = LibraryActionsService.create_template(source)
	if not bool(result.get("ok", false)):
		return _fail(str(result.get("message", "Не удалось создать шаблон.")))
	EditorInterface.get_resource_filesystem().scan()
	return _ok({"template": _serialize_definition(result.get("definition") as ObjectDefinition), "workspace": get_workspace_state()})


func _delete_object(object_id: String) -> Dictionary:
	var source := _find_definition(object_id)
	if source == null:
		return _fail("Объект не найден.")
	# Object relations are non-owning: deletion never cascades into related objects.
	var result: Dictionary = LibraryActionsService.delete_definition(source)
	if not bool(result.get("ok", false)):
		return _fail(str(result.get("message", "Не удалось удалить объект.")))
	if _working != null and _working.object_id == object_id:
		_working = null
	_open_drafts.erase(object_id)
	_new_draft_ids.erase(object_id)
	_dirty_draft_ids.erase(object_id)
	_saved_draft_ids.erase(object_id)
	EditorInterface.get_resource_filesystem().scan()
	_favorites.erase(object_id)
	_recent.erase(object_id)
	for collection_id in _collections:
		var collection: Dictionary = _collections[collection_id]
		var ids := _string_array(collection.get("object_ids", []))
		ids.erase(object_id)
		collection["object_ids"] = ids
		_collections[collection_id] = collection
	_save_local_state()
	return _ok({"workspace": get_workspace_state(), "message": str(result.get("message", "Объект удалён."))})


func _classify_template(payload: Dictionary) -> Dictionary:
	var template := _find_template(str(payload.get("template_id", "")))
	if template == null:
		return _fail("Шаблон не найден.")
	var category := str(payload.get("category", template.category)).strip_edges()
	if category.is_empty():
		return _fail("Категория не может быть пустой.")
	template.category = category
	template.subcategory = str(payload.get("subcategory", template.subcategory)).strip_edges()
	var save_error := ObjectLibraryService.save_template(template)
	if save_error != OK:
		return _fail("Не удалось сохранить классификацию шаблона. Код ошибки: %d" % save_error)
	EditorInterface.get_resource_filesystem().scan()
	return _ok({"workspace": get_workspace_state()})



func _add_component(component_id: String) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var normalized_id := component_id.strip_edges().to_lower()
	if normalized_id.is_empty() or not ObjectComponentCatalog.has_component(normalized_id):
		return _fail("Компонент не найден в нативном каталоге: " + normalized_id)
	for existing in _working.components:
		if existing != null and existing.component_id.to_lower() == normalized_id:
			return _fail("Компонент уже добавлен: " + normalized_id)
	var definition := ObjectComponentCatalog.create_definition(normalized_id)
	if definition == null:
		return _fail("Не удалось создать определение компонента: " + normalized_id)
	_working.components.append(definition)
	_mark_working_dirty()
	return _ok({"working": _serialize_definition(_working, true)})


func _remove_component(component_id: String) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	for index in range(_working.components.size()):
		var definition := _working.components[index]
		if definition != null and definition.component_id == component_id:
			_working.components.remove_at(index)
			_mark_working_dirty()
			return _ok({"working": _serialize_definition(_working, true)})
	return _fail("Компонент не найден: " + component_id)


func _save_component_settings(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var component_id := str(payload.get("component_id", "")).strip_edges().to_lower()
	for definition in _working.components:
		if definition == null or definition.component_id.to_lower() != component_id:
			continue
		var settings_value: Variant = payload.get("settings", {})
		if settings_value is Dictionary:
			for setting_key in settings_value:
				if not definition.set_setting(str(setting_key), _from_json(settings_value[setting_key])):
					return _fail("Некорректное значение настройки: " + str(setting_key))
		_mark_working_dirty()
		return _ok({"working": _serialize_definition(_working, true)})
	return _fail("Компонент не найден: " + component_id)


func _add_category(name: String) -> Dictionary:
	var clean_name := name.strip_edges()
	if clean_name.is_empty():
		return _fail("Название категории не может быть пустым.")
	for existing in _custom_categories:
		if existing.to_lower() == clean_name.to_lower():
			return _fail("Категория уже существует.")
	for existing in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
		if existing.category.to_lower() == clean_name.to_lower():
			return _fail("Категория уже существует.")
	_custom_categories.append(clean_name)
	_custom_categories.sort()
	_save_local_state()
	return _ok({"workspace": get_workspace_state()})


func _rename_category(old_name: String, new_name: String) -> Dictionary:
	if old_name.strip_edges().is_empty() or new_name.strip_edges().is_empty():
		return _fail("Укажи старое и новое название категории.")
	if old_name in ["Other", "Без категории"]:
		return _fail("Системную категорию нельзя переименовать.")
	for existing in _custom_categories:
		if existing.to_lower() == new_name.to_lower() and existing != old_name:
			return _fail("Категория с таким названием уже существует.")
	var definitions := ObjectLibraryService.load_definitions()
	var templates := ObjectLibraryService.load_templates()
	for definition in definitions + templates:
		if definition.category != old_name:
			continue
		definition.category = new_name
		var save_error := ObjectLibraryService.save_template(definition) if definition.is_template else ObjectLibraryService.save_definition(definition)
		if save_error != OK:
			return _fail("Не удалось переименовать все записи категории. Сохранение остановлено.")
	if _working != null and _working.category == old_name:
		_working.category = new_name
	for index in range(_custom_categories.size()):
		if _custom_categories[index] == old_name:
			_custom_categories[index] = new_name
	_custom_categories.sort()
	_save_local_state()
	EditorInterface.get_resource_filesystem().scan()
	return _ok({"workspace": get_workspace_state()})


func _delete_category(category_name: String) -> Dictionary:
	if category_name.strip_edges().is_empty() or category_name in ["Other", "Без категории"]:
		return _fail("Системную категорию нельзя удалить.")
	_custom_categories.erase(category_name)
	for definition in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
		if definition.category != category_name:
			continue
		definition.category = "Other"
		definition.subcategory = ""
		var save_error := ObjectLibraryService.save_template(definition) if definition.is_template else ObjectLibraryService.save_definition(definition)
		if save_error != OK:
			return _fail("Не удалось перенести все записи категории в Other.")
	if _working != null and _working.category == category_name:
		_working.category = "Other"
		_working.subcategory = ""
	_save_local_state()
	EditorInterface.get_resource_filesystem().scan()
	return _ok({"workspace": get_workspace_state()})


func _toggle_favorite(object_id: String) -> Dictionary:
	if object_id.is_empty():
		return _fail("Не указан объект.")
	if _favorites.has(object_id):
		_favorites.erase(object_id)
	else:
		_favorites.append(object_id)
	_save_local_state()
	return _ok({"workspace": get_workspace_state()})


func _record_recent(object_id: String) -> void:
	if object_id.is_empty():
		return
	_recent.erase(object_id)
	_recent.insert(0, object_id)
	while _recent.size() > RECENT_LIMIT:
		_recent.remove_at(_recent.size() - 1)
	_save_local_state()


func _create_collection(name: String) -> Dictionary:
	var clean_name := name.strip_edges()
	if clean_name.is_empty():
		return _fail("Название коллекции не может быть пустым.")
	var slug := clean_name.to_lower().validate_filename().replace(" ", "_")
	if slug.is_empty():
		slug = "collection"
	var base_id := "collection_" + slug
	var collection_id := base_id
	var suffix := 2
	while _collections.has(collection_id):
		collection_id = base_id + "_" + str(suffix)
		suffix += 1
	_collections[collection_id] = {"name": clean_name, "object_ids": PackedStringArray()}
	_save_local_state()
	return _ok({"workspace": get_workspace_state()})


func _update_collection(payload: Dictionary) -> Dictionary:
	var collection_id := str(payload.get("collection_id", ""))
	if not _collections.has(collection_id):
		return _fail("Коллекция не найдена.")
	var collection: Dictionary = _collections[collection_id]
	if payload.has("name"):
		var next_name := str(payload.name).strip_edges()
		if next_name.is_empty():
			return _fail("Название коллекции не может быть пустым.")
		collection["name"] = next_name
	if payload.has("object_id"):
		var object_id := str(payload.object_id)
		var ids := _string_array(collection.get("object_ids", []))
		if bool(payload.get("remove", false)):
			ids.erase(object_id)
		elif not ids.has(object_id):
			if _find_definition(object_id) == null:
				return _fail("Объект для коллекции не найден.")
			ids.append(object_id)
		collection["object_ids"] = ids
	_collections[collection_id] = collection
	_save_local_state()
	return _ok({"workspace": get_workspace_state()})


func _delete_collection(collection_id: String) -> Dictionary:
	if not _collections.erase(collection_id):
		return _fail("Коллекция не найдена.")
	_save_local_state()
	return _ok({"workspace": get_workspace_state()})


func _mark_working_dirty() -> void:
	if _working == null:
		return
	_dirty_draft_ids[_working.object_id] = true
	_open_drafts[_working.object_id] = _working


func _append_external_scene_parts(
	definition: ObjectDefinition,
	parts: Array[Dictionary],
	live_scene_root: Node = null
) -> void:
	if definition == null:
		return

	var scene_root := live_scene_root
	var owns_scene_root := false
	if scene_root == null:
		# The .tscn on disk is authoritative after Godot reports scene_saved.
		# definition.scene can be an older PackedScene instance retained by an
		# already-open ObjectDefinition, so always replace that cache first.
		var packed_scene: PackedScene
		if (
			not definition.scene_path.strip_edges().is_empty()
			and ResourceLoader.exists(definition.scene_path)
		):
			packed_scene = ResourceLoader.load(
				definition.scene_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
			) as PackedScene
		if packed_scene == null:
			packed_scene = definition.scene
		if packed_scene == null:
			return
		scene_root = packed_scene.instantiate()
		if scene_root == null:
			return
		owns_scene_root = true

	var generated_ids: Dictionary = {}
	for node_definition in definition.node_definitions:
		if node_definition != null and not node_definition.node_id.strip_edges().is_empty():
			generated_ids[node_definition.node_id] = true
	if not parts.is_empty():
		parts[0]["properties"] = _collect_external_node_properties(scene_root)
	_collect_external_scene_parts(
		scene_root, "root", "", parts, generated_ids
	)
	if owns_scene_root:
		scene_root.free()


func _collect_external_scene_parts(
	parent: Node,
	parent_id: String,
	parent_path: String,
	parts: Array[Dictionary],
	generated_ids: Dictionary
) -> void:
	if parent == null:
		return
	for child_value in parent.get_children():
		if not child_value is Node:
			continue
		var child := child_value as Node
		var child_path: String = (
			child.name
			if parent_path.is_empty()
			else parent_path.path_join(child.name)
		)
		if _is_object_builder_managed_scene_node(child, generated_ids):
			# Hide editor-owned infrastructure, but continue walking so any
			# user-authored child under a managed container remains discoverable.
			_collect_external_scene_parts(
				child, parent_id, child_path, parts, generated_ids
			)
			continue

		var external_id: String = "external:" + child_path
		parts.append({
			"id": external_id,
			"name": child.name,
			"kind": _kind_for_node_type(child.get_class()),
			"nodeType": child.get_class(),
			"parentId": parent_id,
			"enabled": child.process_mode != Node.PROCESS_MODE_DISABLED,
			"properties": _collect_external_node_properties(child),
			"groups": [],
			"metadata": {"nodePath": child_path},
			"external": true,
			"nodePath": child_path
		})
		_collect_external_scene_parts(
			child, external_id, child_path, parts, generated_ids
		)


func _collect_external_node_properties(node: Node) -> Dictionary:
	var result: Dictionary = {}
	if node == null:
		return result
	var ignored_properties := [
		"name", "owner", "script", "scene_file_path",
		"unique_name_in_owner", "editor_description"
	]
	for property_info in node.get_property_list():
		var property_name := str(property_info.get("name", ""))
		if property_name.is_empty() or ignored_properties.has(property_name):
			continue
		var usage := int(property_info.get("usage", 0))
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		var value: Variant = node.get(property_name)
		match typeof(value):
			TYPE_NIL, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
				continue
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
				result[property_name] = value
			TYPE_STRING_NAME, TYPE_NODE_PATH:
				result[property_name] = str(value)
			TYPE_VECTOR2:
				result[property_name] = _to_json(value)
			TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_DICTIONARY:
				result[property_name] = _to_json(value)
			TYPE_OBJECT:
				if value is Resource:
					var resource := value as Resource
					result[property_name] = {
						"resource_type": resource.get_class(),
						"resource_path": resource.resource_path
					}
			TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I:
				result[property_name] = str(value)
			TYPE_TRANSFORM2D, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_PLANE:
				result[property_name] = str(value)
			TYPE_QUATERNION, TYPE_AABB, TYPE_BASIS, TYPE_TRANSFORM3D:
				result[property_name] = str(value)
			TYPE_PROJECTION, TYPE_COLOR:
				result[property_name] = str(value)
			TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
				result[property_name] = str(value)
			TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
				result[property_name] = str(value)
	return result


func _is_object_builder_managed_scene_node(
	node: Node,
	generated_ids: Dictionary
) -> bool:
	if node == null:
		return true
	if node.name in [
		"Идентификатор объекта",
		"Свойства объекта"
	]:
		return true
	var managed_metadata_keys := [
		"object_builder_sprite",
		"object_builder_sprite_layer",
		"object_builder_animated_sprite",
		"object_builder_visuals",
		"object_builder_collision_host",
		"object_builder_collision_shape",
		"object_builder_managed_collision",
		"object_builder_world_sort_controller"
	]
	for metadata_key in managed_metadata_keys:
		if node.has_meta(metadata_key):
			return true
	if node.has_meta("object_builder_node_id"):
		var generated_id := str(node.get_meta("object_builder_node_id"))
		if generated_ids.has(generated_id):
			return true
	return false


func _serialize_definition(
	definition: ObjectDefinition,
	include_preview_data: bool = false,
	live_scene_root: Node = null
) -> Variant:
	if definition == null:
		return null
	var saved_by_path := (
		ObjectLibraryService.is_managed_definition_path(definition.resource_path)
		and FileAccess.file_exists(definition.resource_path)
	)
	var is_saved := (
		not _dirty_draft_ids.has(definition.object_id)
		and bool(_saved_draft_ids.get(
			definition.object_id,
			false if _new_draft_ids.has(definition.object_id) else saved_by_path
		))
	)
	var capabilities: Array[String] = []
	var auto_caps: Array[String] = []
	var mechanic_settings: Dictionary = {}
	var merge_result := ObjectCapabilityService.migrate_merged_selections(definition.capabilities)
	var serialized_selections: Array[ObjectCapabilitySelection] = merge_result.get("selections", [])
	for selection in serialized_selections:
		if selection == null:
			continue
		if selection.enabled:
			capabilities.append(selection.capability_id)
		if selection.automatically_added:
			auto_caps.append(selection.capability_id)
		mechanic_settings[selection.capability_id] = _to_json(selection.settings_by_component)
	var properties: Array[Dictionary] = []
	for property_definition in definition.custom_properties:
		if property_definition == null:
			continue
		properties.append({
			"id": property_definition.property_id,
			"name": property_definition.display_name,
			"type": property_definition.value_type,
			"default": _to_json(property_definition.default_value),
			"group": property_definition.group_name,
			"description": property_definition.description,
			"advanced": property_definition.advanced,
			"hasRange": property_definition.has_range,
			"min": property_definition.minimum,
			"max": property_definition.maximum
		})
	var parts: Array[Dictionary] = [{
		"id": "root", "name": definition.display_name, "kind": "root",
		"nodeType": definition.root_type, "parentId": ""
	}]
	for node_definition in definition.node_definitions:
		if node_definition == null:
			continue
		parts.append({
			"id": node_definition.node_id,
			"name": node_definition.node_name,
			"kind": _kind_for_node_type(node_definition.node_type),
			"nodeType": node_definition.node_type,
			"parentId": node_definition.parent_node_id,
			"enabled": node_definition.enabled,
			"properties": _to_json(node_definition.properties),
			"groups": _to_json(node_definition.groups),
			"metadata": _to_json(node_definition.metadata),
			"external": false
		})
	if include_preview_data:
		_append_external_scene_parts(definition, parts, live_scene_root)
	var sprite_layers: Array[Dictionary] = []
	for layer_index in range(definition.sprite_layers.size()):
		var layer: Dictionary = definition.sprite_layers[layer_index]
		var layer_texture := layer.get("texture") as Texture2D
		var position_value: Variant = layer.get("position", Vector2.ZERO)
		var scale_value: Variant = layer.get("scale", Vector2.ONE)
		var position := position_value if position_value is Vector2 else Vector2.ZERO
		var scale := scale_value if scale_value is Vector2 else Vector2.ONE
		sprite_layers.append({
			"id": str(layer.get("id", "sprite_%d" % layer_index)),
			"name": str(layer.get("name", "Спрайт %d" % (layer_index + 1))),
			"textureHash": str(layer.get("texture_hash", "")),
			"textureDataUrl": _texture_data_url(layer_texture) if include_preview_data else "",
			"textureSize": {
				"x": layer_texture.get_width() if layer_texture != null else 0,
				"y": layer_texture.get_height() if layer_texture != null else 0
			},
			"position": {"x": position.x, "y": position.y},
			"scale": {"x": scale.x, "y": scale.y},
			"rotation": float(layer.get("rotation", 0.0)),
			"zIndex": int(layer.get("z_index", 0)),
			"visible": bool(layer.get("visible", true)),
			"runtimeVisible": bool(layer.get("runtime_visible", true)),
			"embeddedRelationId": str(layer.get("embedded_relation_id", "")),
			"embeddedObjectId": str(layer.get("embedded_object_id", "")),
			"embeddedSourceName": str(layer.get("embedded_source_name", ""))
		})
	var components: Array[Dictionary] = []
	for component in definition.components:
		if component != null:
			var setting_schema: Array[Dictionary] = []
			for setting_definition in component.get_setting_definitions():
				setting_schema.append(_to_json(setting_definition))
			components.append({
				"component_id": component.component_id,
				"name": component.display_name,
				"description": component.description,
				"category": component.category_display_name if not component.category_display_name.is_empty() else component.category,
				"enabled": component.enabled,
				"settings": _to_json(component.settings),
				"settings_schema": setting_schema
			})
	return {
		"objectId": definition.object_id,
		"templateId": definition.template_id,
		"name": definition.display_name,
		"type": ObjectCreationProfileRegistry.get_display_name(definition.object_type) if ObjectCreationProfileRegistry.has_profile(definition.object_type) else definition.object_type,
		"nativeObjectType": definition.object_type,
		"nativeRootType": definition.root_type,
		"emoji": definition.preview_emoji if not definition.preview_emoji.strip_edges().is_empty() else _emoji_for_type(definition.object_type),
		"builtin": BuiltinTemplateCatalogScript.is_builtin_id(definition.object_id),
		"description": definition.description,
		"category": definition.category,
		"subcategory": definition.subcategory,
		"tags": _to_json(definition.tags),
		"objectSize": {"x": definition.object_size.x, "y": definition.object_size.y},
		"spriteAnimations": _normalize_sprite_animations(definition.sprite_animations),
		"spriteLayers": sprite_layers,
		"spriteSheetHash": definition.sprite_sheet_hash,
		"spriteSheetDataUrl": _texture_data_url(definition.sprite_sheet_texture) if include_preview_data else "",
		"parts": parts,
		"caps": capabilities,
		"autoCaps": auto_caps,
		"mechanicSettings": mechanic_settings,
		"relations": _normalize_relations(definition.relations),
		"properties": properties,
		"components": components,
		"scenePath": definition.scene_path,
		"previewPath": definition.preview_texture.resource_path if definition.preview_texture != null else "",
		"previewDataUrl": _preview_data_url(definition) if include_preview_data else "",
		"previewHash": definition.preview_hash,
		"sprite": {
			"textureSize": {
				"x": definition.preview_texture.get_width() if definition.preview_texture != null else 0,
				"y": definition.preview_texture.get_height() if definition.preview_texture != null else 0
			},
			"scale": {"x": definition.preview_sprite_scale.x, "y": definition.preview_sprite_scale.y},
			"offset": {"x": definition.preview_sprite_offset.x, "y": definition.preview_sprite_offset.y},
			"rotation": definition.preview_sprite_rotation_degrees,
			"zIndex": definition.preview_sprite_z_index
		},
		"collision": {
			"enabled": definition.collision_enabled,
			"mode": definition.collision_mode,
			"shape": definition.collision_shape,
			"size": {"x": definition.collision_size.x, "y": definition.collision_size.y},
			"radius": definition.collision_radius,
			"height": definition.collision_height,
			"offset": {"x": definition.collision_offset.x, "y": definition.collision_offset.y},
			"layer": definition.collision_layer,
			"mask": definition.collision_mask
		},
		"isTemplate": definition.is_template,
		"saved": is_saved
	}




func _decode_preview_texture(data_url: String) -> Dictionary:
	var separator := data_url.find(",")
	if separator < 0 or not data_url.begins_with("data:image/"):
		return {"ok": false, "error": "Не удалось прочитать изображение. Выбери PNG, JPEG или WebP."}
	var header := data_url.substr(0, separator)
	if not header.ends_with(";base64"):
		return {"ok": false, "error": "Изображение должно передаваться в формате base64."}
	var mime_type := header.substr(5, header.find(";") - 5)
	var encoded := data_url.substr(separator + 1)
	if encoded.length() > 7 * 1024 * 1024:
		return {"ok": false, "error": "Изображение слишком большое. Максимальный размер — 5 МБ."}
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.is_empty() or bytes.size() > 5 * 1024 * 1024:
		return {"ok": false, "error": "Изображение пустое или превышает лимит 5 МБ."}
	var image := Image.new()
	var decode_error: Error
	match mime_type:
		"image/png":
			decode_error = image.load_png_from_buffer(bytes)
		"image/jpeg", "image/jpg":
			decode_error = image.load_jpg_from_buffer(bytes)
		"image/webp":
			decode_error = image.load_webp_from_buffer(bytes)
		_:
			return {"ok": false, "error": "Поддерживаются PNG, JPEG и WebP."}
	if decode_error != OK or image.is_empty():
		return {"ok": false, "error": "Godot не смог декодировать изображение."}
	if image.get_width() > 8192 or image.get_height() > 8192 or image.get_width() * image.get_height() > 16777216:
		return {"ok": false, "error": "Слишком большое разрешение. Максимум — 8192×8192 и 16 мегапикселей."}
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		return {"ok": false, "error": "Не удалось создать текстуру из изображения."}
	return {"ok": true, "texture": texture, "hash": str(hash(bytes))}


func _set_sprite_sheet(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var decoded := _decode_preview_texture(str(payload.get("data_url", "")))
	if not bool(decoded.get("ok", false)):
		return _fail(str(decoded.get("error", "Не удалось загрузить spritesheet.")))
	_working.sprite_sheet_texture = decoded.get("texture") as Texture2D
	_working.sprite_sheet_hash = str(decoded.get("hash", ""))
	_mark_working_dirty()
	_open_drafts[_working.object_id] = _working
	return _ok({
		"working": _serialize_definition(_working, true),
		"message": "Spritesheet загружен. Теперь можно нарезать строки на анимации."
	})


func _clear_sprite_sheet() -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	_working.sprite_sheet_texture = null
	_working.sprite_sheet_hash = ""
	_working.sprite_animations.clear()
	_mark_working_dirty()
	_open_drafts[_working.object_id] = _working
	return _ok({
		"working": _serialize_definition(_working, true),
		"message": "Spritesheet удалён из объекта."
	})


func _set_preview_texture(payload: Dictionary) -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	var decoded := _decode_preview_texture(str(payload.get("data_url", "")))
	if not bool(decoded.get("ok", false)):
		return _fail(str(decoded.get("error", "Не удалось загрузить спрайт.")))
	_working.preview_texture = decoded.get("texture") as Texture2D
	_working.preview_hash = str(decoded.get("hash", ""))
	_mark_working_dirty()
	_open_drafts[_working.object_id] = _working
	return _ok({
		"working": _serialize_definition(_working, true),
		"message": "Спрайт добавлен в предпросмотр. Нажми «Сохранить», чтобы записать его в объект."
	})


func _clear_preview_texture() -> Dictionary:
	if not _has_working():
		return _fail("Сначала открой или создай объект.")
	_working.preview_texture = null
	_working.preview_hash = ""
	_mark_working_dirty()
	_open_drafts[_working.object_id] = _working
	return _ok({
		"working": _serialize_definition(_working, true),
		"message": "Спрайт убран. Файлы исходного изображения не затрагиваются."
	})


func _preview_data_url(definition: ObjectDefinition) -> String:
	return _texture_data_url(definition.preview_texture if definition != null else null)


func _texture_data_url(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var image := texture.get_image()
	if image == null or image.is_empty():
		return ""
	var png_bytes := image.save_png_to_buffer()
	if png_bytes.is_empty():
		return ""
	return "data:image/png;base64," + Marshalls.raw_to_base64(png_bytes)


func _normalize_sprite_animations(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_names: Dictionary = {}
	for value in values:
		if not value is Dictionary:
			continue
		var animation_name := str(value.get("name", "animation")).strip_edges()
		if animation_name.is_empty():
			animation_name = "animation_%d" % (result.size() + 1)
		var unique_name := animation_name
		var suffix := 2
		while used_names.has(unique_name.to_lower()):
			unique_name = "%s_%d" % [animation_name, suffix]
			suffix += 1
		used_names[unique_name.to_lower()] = true
		var rows := clampi(int(value.get("rows", 1)), 1, 256)
		var columns := clampi(int(value.get("columns", 1)), 1, 256)
		var row := clampi(int(value.get("row", 0)), 0, rows - 1)
		var start_column := clampi(int(value.get("start_column", 0)), 0, columns - 1)
		var frame_count := clampi(int(value.get("frame_count", columns - start_column)), 1, columns - start_column)
		var margin_x := clampi(int(value.get("margin_x", 0)), 0, 8192)
		var margin_y := clampi(int(value.get("margin_y", 0)), 0, 8192)
		var separation_x := clampi(int(value.get("separation_x", 0)), 0, 8192)
		var separation_y := clampi(int(value.get("separation_y", 0)), 0, 8192)
		result.append({
			"name": unique_name,
			"rows": rows,
			"columns": columns,
			"row": row,
			"start_column": start_column,
			"frame_count": frame_count,
			"margin_x": margin_x,
			"margin_y": margin_y,
			"separation_x": separation_x,
			"separation_y": separation_y,
			"fps": clampf(float(value.get("fps", 8.0)), 0.1, 60.0),
			"loop": bool(value.get("loop", true))
		})
	return result


func _get_physics_layer_names() -> Array[String]:
	var names: Array[String] = []
	for layer_index in range(1, 33):
		var setting_path := "layer_names/2d_physics/layer_%d" % layer_index
		var layer_name := str(ProjectSettings.get_setting(setting_path, "")).strip_edges()
		names.append(layer_name if not layer_name.is_empty() else "Слой %d" % layer_index)
	return names


func _get_capabilities() -> Dictionary:
	var items: Array[Dictionary] = []
	var category_names: Dictionary = {}
	var reference_options_by_type: Dictionary = {}
	for category in ObjectCapabilityCatalog.get_categories():
		category_names[str(category.get("id", ""))] = str(category.get("display_name", ""))
	for capability_id in ObjectCapabilityCatalog.get_capability_ids("", false):
		var capability := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		if capability == null or capability.editor_hidden:
			continue
		var schema: Array[Dictionary] = []
		for setting in ObjectCapabilityCatalog.get_settings_schema(capability_id):
			var serialized_setting: Dictionary = _to_json(setting)
			var reference_type := ""
			if str(setting.get("editor", "")) == "catalog_reference":
				reference_type = str(setting.get("reference_type", "")).strip_edges().to_lower()
			elif str(setting.get("editor", "")) in ["structured_list", "structured_object"]:
				var editor_config_value: Variant = setting.get("editor_config", {})
				if editor_config_value is Dictionary:
					reference_type = str(editor_config_value.get("reference_type", "")).strip_edges().to_lower()
			if not reference_type.is_empty():
				if not reference_options_by_type.has(reference_type):
					reference_options_by_type[reference_type] = _get_setting_reference_options(reference_type)
				if str(setting.get("editor", "")) == "catalog_reference":
					serialized_setting["reference_options"] = reference_options_by_type[reference_type]
				elif str(setting.get("editor", "")) in ["structured_list", "structured_object"]:
					var editor_config: Dictionary = serialized_setting.get("editor_config", {})
					editor_config["reference_options"] = reference_options_by_type[reference_type]
					serialized_setting["editor_config"] = editor_config
			schema.append(serialized_setting)
		items.append({
			"id": capability_id,
			"name": capability.display_name,
			"description": capability.description,
			"category": str(category_names.get(capability.category_id, capability.category_name)),
			"categoryId": capability.category_id,
			"status": "Работает" if capability.is_ready() else "В разработке",
			"readiness": capability.get_effective_readiness_status(),
			"kind": capability.kind_id,
			"executionScope": capability.execution_scope,
			"implementationType": capability.implementation_type,
			"required": _to_json(capability.required_capability_ids),
			"incompatible": _to_json(capability.incompatible_capability_ids),
			"componentIds": _to_json(capability.component_ids),
			"settingsSchema": schema,
			"keywords": _to_json(capability.keywords)
		})
	return {"items": items, "categories": ObjectCapabilityCatalog.get_categories()}



func _get_setting_reference_options(reference_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match reference_type:
		"item", "tool":
			var catalog_data := ItemCatalogServiceScript.load_all()
			var definitions_value: Variant = catalog_data.get("definitions", {})
			if not definitions_value is Dictionary:
				return result
			var definitions: Dictionary = definitions_value
			var item_ids := definitions.keys()
			item_ids.sort()
			for item_id_value in item_ids:
				var item_id := str(item_id_value)
				var definition := definitions.get(item_id) as ItemDefinition
				if definition == null:
					continue
				var category := str(definition.category).strip_edges().to_lower()
				if reference_type == "tool" and category != "tools":
					continue
				var category_label := category
				match category:
					"tools": category_label = "Инструменты"
					"weapons": category_label = "Оружие"
					"food": category_label = "Еда"
					"materials": category_label = "Материалы"
					"ammunition": category_label = "Боеприпасы"
				var display_name := definition.display_name.strip_edges()
				if display_name.is_empty():
					display_name = item_id
				result.append({
					"value": item_id,
					"label": display_name,
					"category": category_label,
					"description": definition.description
				})
	return result


func _get_components() -> Dictionary:
	var items: Array[Dictionary] = []
	var categories := ObjectComponentCatalog.get_categories()
	for component_id in ObjectComponentCatalog.get_component_ids():
		var definition := ObjectComponentCatalog.create_definition(component_id)
		if definition == null:
			continue
		var settings_schema: Array[Dictionary] = []
		for descriptor in definition.get_setting_definitions():
			settings_schema.append(_to_json(descriptor))
		items.append({
			"id": component_id,
			"name": definition.display_name,
			"description": definition.description,
			"category": definition.category_display_name if not definition.category_display_name.is_empty() else definition.category,
			"categoryId": definition.category_id,
			"settingsSchema": settings_schema
		})
	return {"items": items, "categories": categories}


func _get_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile_id in ObjectCreationProfileRegistry.get_profile_ids():
		var profile := ObjectCreationProfileRegistry.get_definition(profile_id)
		if profile == null:
			continue
		var properties: Array[Dictionary] = []
		for definition in profile.suggested_properties:
			if definition == null:
				continue
			properties.append({
				"id": definition.property_id,
				"name": definition.display_name,
				"type": definition.value_type,
				"default": _to_json(definition.default_value),
				"group": definition.group_name,
				"description": definition.description,
				"hasRange": definition.has_range,
				"min": definition.minimum,
				"max": definition.maximum
			})
		result.append({
			"id": profile.profile_id,
			"name": profile.display_name,
			"description": profile.description,
			"category": profile.suggested_category,
			"rootType": profile.suggested_root_type,
			"capabilities": _to_json(profile.suggested_capability_ids),
			"properties": properties
		})
	return result


func _add_classification(definition: ObjectDefinition, categories: PackedStringArray, subcategories: Dictionary) -> void:
	var category := definition.category.strip_edges()
	if not category.is_empty() and not categories.has(category):
		categories.append(category)
	if not subcategories.has(category):
		subcategories[category] = PackedStringArray()
	var values: PackedStringArray = subcategories[category]
	if not definition.subcategory.is_empty() and not values.has(definition.subcategory):
		values.append(definition.subcategory)
	subcategories[category] = values



func cleanup() -> void:
	for object_id in _new_draft_ids.keys():
		var draft := _open_drafts.get(str(object_id)) as ObjectDefinition
		if draft != null:
			_cleanup_draft_scene(draft)
	_open_drafts.clear()
	_new_draft_ids.clear()
	_dirty_draft_ids.clear()
	_saved_draft_ids.clear()
	_working = null
	_pending_selections.clear()
	_pending_plan.clear()


func _cleanup_draft_scene(definition: ObjectDefinition) -> void:
	if definition == null or definition.scene_path.strip_edges().is_empty():
		return
	var scene_path := definition.scene_path
	if not scene_path.begins_with(ObjectLibraryService.SCENES_PATH + "/"):
		return
	if not FileAccess.file_exists(scene_path):
		return
	# A temporary draft owns only its generated scene path. Never remove a scene
	# that has been adopted by any saved object or template.
	for saved_definition in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
		if saved_definition.object_id != definition.object_id and saved_definition.scene_path == scene_path:
			return
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path))
	if remove_error != OK:
		push_warning("Web Object Builder: could not remove abandoned draft scene: " + scene_path)


func _find_definition(object_id: String) -> ObjectDefinition:
	for definition in ObjectLibraryService.load_definitions():
		if definition.object_id == object_id:
			return definition
	return null


func _find_template(template_id: String) -> ObjectDefinition:
	for definition in ObjectLibraryService.load_templates():
		if definition.object_id == template_id:
			return definition
	return BuiltinTemplateCatalogScript.find_definition(template_id)


func _find_node(node_id: String) -> ObjectNodeDefinition:
	if _working == null:
		return null
	for definition in _working.node_definitions:
		if definition != null and definition.node_id == node_id:
			return definition
	return null


func _is_descendant(candidate_id: String, ancestor_id: String) -> bool:
	var current := _find_node(candidate_id)
	var visited: Dictionary = {}
	while current != null:
		if visited.has(current.node_id):
			return false
		visited[current.node_id] = true
		if current.parent_node_id == ancestor_id:
			return true
		if current.parent_node_id == "root":
			return false
		current = _find_node(current.parent_node_id)
	return false


func _find_selection(capability_id: String) -> ObjectCapabilitySelection:
	if _working == null:
		return null
	for selection in _working.capabilities:
		if selection != null and selection.capability_id == capability_id:
			return selection
	return null


func _validate_relation_owner(
	mechanic_id: String,
	relation_kind: String,
	target_id: String,
	ignore_relation_id: String = ""
) -> String:
	if mechanic_id.is_empty():
		if relation_kind != "related":
			return "Связь с типом «%s» должна принадлежать соответствующей механике." % relation_kind
		for existing in _working.relations:
			if (
				str(existing.get("relation_id", "")) != ignore_relation_id
				and str(existing.get("mechanic_id", "")) == ""
				and str(existing.get("kind", "")) == relation_kind
				and str(existing.get("target_object_id", "")) == target_id
			):
				return "Такая общая связь с этим объектом уже существует."
		return ""
	var selection := _find_selection(mechanic_id)
	if selection == null or not selection.enabled:
		var is_existing_preset_link := false
		if not ignore_relation_id.is_empty():
			for existing in _working.relations:
				if (
					str(existing.get("relation_id", "")) == ignore_relation_id
					and str(existing.get("mechanic_id", "")) == mechanic_id
					and str(existing.get("kind", "")) == relation_kind
				):
					is_existing_preset_link = true
					break
		if not is_existing_preset_link:
			return "Сначала подключи механику, которая должна владеть этой связью."
	var supported_kinds := {
		"can_be_harvested": ["harvest"],
		"can_produce_resources": ["produce"],
		"supports_item_crafting": ["input", "produce"],
		"breaks_when_health_empty": ["drop", "remains"]
	}
	if not supported_kinds.has(mechanic_id) or relation_kind not in supported_kinds[mechanic_id]:
		return "Эта механика не поддерживает выбранный тип связи."
	for existing in _working.relations:
		if str(existing.get("relation_id", "")) == ignore_relation_id:
			continue
		if (
			str(existing.get("mechanic_id", "")) == mechanic_id
			and str(existing.get("kind", "")) == relation_kind
			and str(existing.get("target_object_id", "")) == target_id
		):
			return "Такая связь уже добавлена в эту механику."
	return ""


func _normalize_relations(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value in values:
		if not value is Dictionary:
			continue
		var relation_id := str(value.get("relation_id", value.get("id", ""))).strip_edges()
		var target_id := str(value.get("target_object_id", value.get("targetId", ""))).strip_edges()
		if relation_id.is_empty() or target_id.is_empty() or seen.has(relation_id):
			continue
		seen[relation_id] = true
		var relation_kind := str(value.get("kind", "related")).strip_edges()
		result.append({
			"relation_id": relation_id,
			"target_object_id": target_id,
			"mechanic_id": str(value.get("mechanic_id", value.get("mechanicId", ""))),
			"kind": relation_kind,
			"label": str(value.get("label", "")),
			"quantity": maxi(1, int(value.get("quantity", 1))),
			"settings": _normalize_relation_settings(value.get("settings", {}), relation_kind)
		})
	return result


func _normalize_relation_settings(value: Variant, relation_kind: String) -> Dictionary:
	var settings: Dictionary = value.duplicate(true) if value is Dictionary else {}
	var allowed_placements: Array[String] = []
	var default_placement := "attach"
	match relation_kind:
		"drop":
			allowed_placements = ["drop", "replace", "attach"]
			default_placement = "drop"
		"remains":
			allowed_placements = ["replace", "attach", "spawn"]
			default_placement = "replace"
		"harvest":
			allowed_placements = ["spawn", "drop", "attach"]
			default_placement = "spawn"
		"produce":
			allowed_placements = ["spawn", "attach"]
			default_placement = "spawn"
		"input":
			allowed_placements = ["consume", "attach"]
			default_placement = "consume"
		_:
			allowed_placements = ["attach", "spawn"]
			default_placement = "attach"
	var placement := str(settings.get("placement", default_placement))
	if not allowed_placements.has(placement):
		placement = default_placement
	var position_value: Variant = settings.get("local_position", {})
	var position: Dictionary = position_value if position_value is Dictionary else {}
	var scale_value: Variant = settings.get("local_scale", {})
	var scale: Dictionary = scale_value if scale_value is Dictionary else {}
	settings["placement"] = placement
	settings["embed_in_parent"] = relation_kind == "remains" and bool(settings.get("embed_in_parent", false))
	settings["local_position"] = {
		"x": clampf(float(position.get("x", 0.0)), -8192.0, 8192.0),
		"y": clampf(float(position.get("y", -12.0 if relation_kind == "drop" else 0.0)), -8192.0, 8192.0)
	}
	settings["rotation"] = clampf(float(settings.get("rotation", 0.0)), -360.0, 360.0)
	settings["local_scale"] = {
		"x": clampf(float(scale.get("x", 1.0)), 0.05, 16.0),
		"y": clampf(float(scale.get("y", 1.0)), 0.05, 16.0)
	}
	return settings


func _node_type_for_kind(kind: String) -> String:
	match kind:
		"sprite": return "Sprite2D"
		"collision": return "CollisionShape2D"
		_: return "Node2D"


func _kind_for_node_type(node_type: String) -> String:
	if node_type in ["Sprite2D", "AnimatedSprite2D"]:
		return "sprite"
	if node_type in ["CollisionShape2D", "CollisionPolygon2D"]:
		return "collision"
	return "visual"


func _emoji_for_type(object_type: String) -> String:
	var icons := {
		"npc": "🧙", "resource": "🪨", "construction": "🏠", "item": "🧪",
		"weapon": "⚔️", "tool": "🪓", "animal": "🐾", "interactive": "⚙️",
		"decoration": "🪴", "transport": "🛒", "effect": "✨", "other": "◆"
	}
	return str(icons.get(object_type, "◆"))


func _string_array(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is PackedStringArray:
		return value.duplicate()
	if value is Array:
		for item in value:
			var clean := str(item).strip_edges()
			if not clean.is_empty() and not result.has(clean):
				result.append(clean)
	return result


func _to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_COLOR:
			return {"__type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_VECTOR2:
			return {"__type": "Vector2", "x": value.x, "y": value.y}
		TYPE_NODE_PATH, TYPE_STRING_NAME:
			return str(value)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var array_result: Array = []
			for item in value:
				array_result.append(_to_json(item))
			return array_result
		TYPE_DICTIONARY:
			var dictionary_result: Dictionary = {}
			for key in value:
				dictionary_result[str(key)] = _to_json(value[key])
			return dictionary_result
		TYPE_OBJECT:
			if value is Resource:
				return {"__resource": value.resource_path}
			return null
		_:
			return value


func _from_json(value: Variant) -> Variant:
	if value is Dictionary:
		if str(value.get("__type", "")) == "Color":
			return Color(
				float(value.get("r", 1.0)),
				float(value.get("g", 1.0)),
				float(value.get("b", 1.0)),
				float(value.get("a", 1.0))
			)
		if str(value.get("__type", "")) == "Vector2":
			return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		var result: Dictionary = {}
		for key in value:
			result[key] = _from_json(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_from_json(item))
		return result
	return value


func _normalize_collections(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for raw_id in value:
		var collection_id := str(raw_id).strip_edges().to_lower()
		if collection_id.is_empty() or not value[raw_id] is Dictionary:
			continue
		var source: Dictionary = value[raw_id]
		result[collection_id] = {
			"name": str(source.get("name", collection_id)),
			"object_ids": _string_array(source.get("object_ids", []))
		}
	return result


func _has_working() -> bool:
	return _working != null


func _ok(data: Dictionary = {}) -> Dictionary:
	data["ok"] = true
	return data


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
