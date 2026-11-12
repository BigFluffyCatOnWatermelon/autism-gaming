@tool
extends EditorPlugin

## First-stage host for the standalone Web Object Builder.
## The Web Object Builder owns the editor UI; shared ObjectDefinition resources remain the data contract.

signal web_message_received(message: Dictionary)

const WEB_ENTRYPOINT := "res://addons/web_object_builder/web/index.html"
const GameplayTablesScript = preload("res://scripts/object_system/object_gameplay_table_service.gd")
const ItemCatalogServiceScript = preload("res://scripts/item_catalog_service.gd")
const WebObjectBuilderBackendScript = preload("res://addons/web_object_builder/services/object_builder_backend.gd")
const WebObjectBuilderLibraryDockScript = preload("res://addons/web_object_builder/ui/object_library_dock.gd")
const ObjectLibraryService = preload("res://scripts/object_system/object_library_service.gd")
const WEB_DATA_DIRECTORY := "user://web_object_builder/webview"
const WRY_EXTENSION_PATH := "res://addons/godot_wry/WRY.gdextension"
const WRY_SETUP_URL := "https://godot-wry.doce.sh/guide/getting-started.html"
const WRY_RELEASES_URL := "https://github.com/doceazedo/godot_wry/releases"

var _backend: RefCounted
var _editor_file_system: EditorFileSystem
var _filesystem_rescan_queued := false
var _manual_library_refresh_in_progress := false
var _external_scene_sync_pending := {}
var _external_definition_sync_pending := {}
var _scene_import_dialog: FileDialog
var _gameplay_table_dialog: FileDialog
var _main_screen: Control
var _web_view: Control
var _dependency_panel: Control
var _page_loaded := false
var _frontend_ready := false
var _workspace_visible := false
var _workspace_refresh_pending := false
var _browser_initialization_attempted := false
var _object_builder_navigation_started := false
var _pending_object_id_to_open := ""
const OBJECT_LIBRARY_MENU_ITEM := "Открыть библиотеку объектов"
var _object_library_dock: EditorDock
var _object_library_dock_content: Control


func _enter_tree() -> void:
	set_process(true)
	_backend = WebObjectBuilderBackendScript.new()
	_editor_file_system = EditorInterface.get_resource_filesystem()
	if _editor_file_system != null:
		if not _editor_file_system.filesystem_changed.is_connected(_on_editor_filesystem_changed):
			_editor_file_system.filesystem_changed.connect(_on_editor_filesystem_changed)
	if not resource_saved.is_connected(_on_editor_resource_saved):
		resource_saved.connect(_on_editor_resource_saved)
	if not scene_saved.is_connected(_on_editor_scene_saved):
		scene_saved.connect(_on_editor_scene_saved)

	# Register an empty main-screen root first. The native WebView is created
	# lazily only after the user opens this tab, when the editor viewport is live.
	_main_screen = Control.new()
	_main_screen.name = "WebObjectBuilderMainScreen"
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var editor_main_screen := EditorInterface.get_editor_main_screen()
	if editor_main_screen == null:
		push_error("Web Object Builder: editor main screen is unavailable.")
		return

	editor_main_screen.add_child(_main_screen)
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_screen.hide()
	_build_object_library_dock()
	call_deferred("_initial_library_filesystem_scan")
	print("Web Object Builder: main screen registered; WebView will initialize on first open.")


func _process(_delta: float) -> void:
	if _web_view == null or not is_instance_valid(_web_view):
		return
	if not _workspace_visible:
		return
	_sync_webview_bounds()


func _exit_tree() -> void:
	_manual_library_refresh_in_progress = false
	if _editor_file_system != null and is_instance_valid(_editor_file_system):
		if _editor_file_system.filesystem_changed.is_connected(_on_editor_filesystem_changed):
			_editor_file_system.filesystem_changed.disconnect(_on_editor_filesystem_changed)
	_editor_file_system = null
	if resource_saved.is_connected(_on_editor_resource_saved):
		resource_saved.disconnect(_on_editor_resource_saved)
	if scene_saved.is_connected(_on_editor_scene_saved):
		scene_saved.disconnect(_on_editor_scene_saved)
	_filesystem_rescan_queued = false
	_external_scene_sync_pending.clear()
	_external_definition_sync_pending.clear()

	if _gameplay_table_dialog != null and is_instance_valid(_gameplay_table_dialog):
		_gameplay_table_dialog.queue_free()
		_gameplay_table_dialog = null
	if _object_library_dock != null and is_instance_valid(_object_library_dock):
		remove_dock(_object_library_dock)
		_object_library_dock.queue_free()
		_object_library_dock = null
		_object_library_dock_content = null
	remove_tool_menu_item(OBJECT_LIBRARY_MENU_ITEM)
	if _backend != null and _backend.has_method("cleanup"):
		_backend.call("cleanup")
	if _web_view != null and is_instance_valid(_web_view):
		if _web_view.has_method("set_visible"):
			_web_view.call("set_visible", false)

	if _main_screen != null and is_instance_valid(_main_screen):
		_main_screen.queue_free()

	_main_screen = null
	_web_view = null
	_dependency_panel = null
	_backend = null
	_scene_import_dialog = null


func _build_object_library_dock() -> void:
	if _object_library_dock != null and is_instance_valid(_object_library_dock):
		return
	add_tool_menu_item(OBJECT_LIBRARY_MENU_ITEM, Callable(self, "_open_object_library_dock"))

	# Initialize the backend before filling the dock. This also migrates older
	# ID-based or localized library filenames to the readable ASCII layout.
	var initialization_result: Dictionary = _backend.call(
		"handle_request", "workspace_get_state", {}
	)
	if not bool(initialization_result.get("ok", false)):
		push_warning(
			"Web Object Builder: library initialization reported an issue: "
			+ str(initialization_result.get("message", "unknown error"))
		)

	# Use the current EditorDock API instead of inserting a bare Control into
	# a legacy dock slot. This gives the library its own named, reopenable tab.
	var dock_content: Control = WebObjectBuilderLibraryDockScript.new()
	dock_content.name = "WebObjectBuilderLibraryContent"
	dock_content.connect("refresh_requested", Callable(self, "_on_object_library_refresh_requested"))
	dock_content.connect("open_object_requested", Callable(self, "_open_object_in_web_builder"))
	dock_content.connect("scene_path_selected_requested", Callable(self, "_on_object_library_scene_path_selected"))
	dock_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_content.call("build")

	var library_dock := EditorDock.new()
	library_dock.name = "WebObjectBuilderObjectLibraryDock"
	library_dock.title = "Библиотека объектов"
	library_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL
	library_dock.add_child(dock_content)
	_object_library_dock = library_dock
	_object_library_dock_content = dock_content
	add_dock(library_dock)

	_refresh_object_library_dock()
	call_deferred("_open_object_library_dock")
	print("Web Object Builder: independent EditorDock library registered.")

func _refresh_object_library_dock() -> void:
	if _object_library_dock_content == null or not is_instance_valid(_object_library_dock_content):
		return
	_object_library_dock_content.call("set_definitions", ObjectLibraryService.load_definitions())


func _initial_library_filesystem_scan() -> void:
	# Wait for the editor's first scan and import pass, then read the library.
	# Starting a second scan here is redundant and can leave a worker thread
	# running when headless validation exits.
	await get_tree().process_frame
	while (
		_editor_file_system != null
		and is_instance_valid(_editor_file_system)
		and (_editor_file_system.is_scanning() or _editor_file_system.is_importing())
	):
		await get_tree().process_frame
	if _editor_file_system == null or not is_instance_valid(_editor_file_system):
		return
	if _filesystem_rescan_queued:
		return
	_filesystem_rescan_queued = true
	call_deferred("_rescan_library_after_filesystem_change")


func _scan_filesystem_after_import() -> void:
	# Headless editor validation exits immediately after plugin initialization;
	# do not start an asynchronous filesystem worker which cannot finish before
	# shutdown. Normal GUI sessions still rescan so new records appear in the
	# FileSystem dock without requiring a manual refresh.
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	while (
		_editor_file_system != null
		and is_instance_valid(_editor_file_system)
		and (_editor_file_system.is_scanning() or _editor_file_system.is_importing())
	):
		await get_tree().process_frame
	if _editor_file_system != null and is_instance_valid(_editor_file_system):
		_editor_file_system.scan()


func _on_editor_filesystem_changed() -> void:
	if _backend == null or _filesystem_rescan_queued:
		return
	_filesystem_rescan_queued = true
	call_deferred("_rescan_library_after_filesystem_change")


func _on_object_library_refresh_requested() -> void:
	if _manual_library_refresh_in_progress:
		return
	_manual_library_refresh_in_progress = true
	if (
		_object_library_dock_content != null
		and is_instance_valid(_object_library_dock_content)
		and _object_library_dock_content.has_method("set_refreshing")
	):
		_object_library_dock_content.call("set_refreshing", true)

	# If an automatic scan is already being processed, it will update both
	# the Dock and Web Builder. Wait for that same pass instead of racing it.
	if _filesystem_rescan_queued:
		call_deferred("_wait_for_active_library_rescan")
		return

	_filesystem_rescan_queued = true
	call_deferred("_manual_rescan_object_library")


func _manual_rescan_object_library() -> void:
	await get_tree().process_frame
	if _editor_file_system != null and is_instance_valid(_editor_file_system):
		# Finish any scan/import already in progress before starting a fresh scan.
		while _editor_file_system.is_scanning() or _editor_file_system.is_importing():
			await get_tree().process_frame
		_editor_file_system.scan()
		await get_tree().process_frame
		while _editor_file_system.is_scanning() or _editor_file_system.is_importing():
			await get_tree().process_frame

	# The manual scan suppresses its own filesystem_changed callback via the
	# queued flag above. Run the same importer used by automatic synchronization.
	await _rescan_library_after_filesystem_change()


func _wait_for_active_library_rescan() -> void:
	await get_tree().process_frame
	while _filesystem_rescan_queued:
		await get_tree().process_frame
	_finish_manual_library_refresh()


func _finish_manual_library_refresh() -> void:
	_manual_library_refresh_in_progress = false
	if (
		_object_library_dock_content != null
		and is_instance_valid(_object_library_dock_content)
		and _object_library_dock_content.has_method("set_refreshing")
	):
		_object_library_dock_content.call("set_refreshing", false)


func _rescan_library_after_filesystem_change() -> void:
	await get_tree().process_frame
	while (
		_editor_file_system != null
		and is_instance_valid(_editor_file_system)
		and (_editor_file_system.is_scanning() or _editor_file_system.is_importing())
	):
		await get_tree().process_frame
	if _backend == null:
		_filesystem_rescan_queued = false
		_finish_manual_library_refresh()
		return

	var result: Dictionary = _backend.call(
		"handle_request", "filesystem_rescan", {}
	)
	if not bool(result.get("ok", false)):
		var refresh_error := str(result.get("error", "Неизвестная ошибка."))
		push_warning(
			"Web Object Builder: сканирование библиотеки не удалось: "
			+ refresh_error
		)
		_filesystem_rescan_queued = false
		_finish_manual_library_refresh()
		return

	_refresh_object_library_dock()
	send_to_web("library_filesystem_updated", result)
	var imported_names: Array = result.get("imported_names", [])
	if not imported_names.is_empty():
		print(
			"Web Object Builder: imported from FileSystem: ",
			", ".join(PackedStringArray(imported_names))
		)
		call_deferred("_scan_filesystem_after_import")

	_filesystem_rescan_queued = false
	_finish_manual_library_refresh()


func _on_editor_resource_saved(resource: Resource) -> void:
	if resource == null:
		return
	if resource is PackedScene:
		_queue_external_scene_sync(resource.resource_path)
	elif resource is ObjectDefinition:
		_queue_external_definition_sync(resource.resource_path)


func _on_editor_scene_saved(scene_path: String) -> void:
	_queue_external_scene_sync(scene_path)


func _queue_external_scene_sync(raw_scene_path: String) -> void:
	var saved_scene_path := raw_scene_path.strip_edges()
	if saved_scene_path.is_empty() or saved_scene_path.get_extension().to_lower() not in ["tscn", "scn"]:
		return

	# A saved level may contain one or more Object Builder scene instances.
	# Resolve the object scene from the selected node/active Builder document,
	# not only from the level's root (which usually has no object ID).
	var target := _resolve_scene_sync_target(saved_scene_path)
	var scene_path := str(target.get("scene_path", saved_scene_path)).strip_edges()
	var scene_root := target.get("scene_root") as Node
	var scene_object_id := str(target.get("object_id", "")).strip_edges()
	if scene_path.is_empty() or scene_path.get_extension().to_lower() not in ["tscn", "scn"]:
		return

	var is_linked_scene := (
		ObjectLibraryService.is_managed_scene_path(scene_path)
		or not scene_object_id.is_empty()
	)
	if not is_linked_scene:
		for definition in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
			if definition != null and definition.scene_path == scene_path:
				is_linked_scene = true
				break
	if not is_linked_scene:
		return

	# Do not drop a second save while the first one is queued. Replace its root
	# and increment the revision; the worker will process the newest scene state.
	if _external_scene_sync_pending.has(scene_path):
		var pending_state: Dictionary = _external_scene_sync_pending[scene_path]
		pending_state["scene_root"] = scene_root
		pending_state["revision"] = int(pending_state.get("revision", 1)) + 1
		_external_scene_sync_pending[scene_path] = pending_state
		return
	_external_scene_sync_pending[scene_path] = {
		"scene_root": scene_root,
		"revision": 1
	}
	print(
		"Web Object Builder: queued saved Godot object scene: ",
		scene_path,
		" (object_id: ",
		scene_object_id,
		")"
	)
	call_deferred("_refresh_external_scene_after_godot_save", scene_path)


func _get_active_builder_object_id() -> String:
	if _backend == null:
		return ""
	var active_definition: Object = _backend.call("get_working_definition")
	if active_definition == null or not is_instance_valid(active_definition):
		return ""
	return str(active_definition.get("object_id")).strip_edges()


func _get_object_definition_scene_path(object_id: String) -> String:
	var clean_id := object_id.strip_edges()
	if clean_id.is_empty():
		return ""
	for definition in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
		if definition != null and definition.object_id == clean_id:
			return definition.scene_path.strip_edges()
	return ""


func _get_linked_object_id_for_scene_root(scene_root: Node) -> String:
	if scene_root == null:
		return ""
	var object_id := ObjectLibraryService.get_scene_root_object_id(scene_root)
	if not object_id.is_empty():
		return object_id

	# Older object scenes may not contain the persistent reference node.
	# Their instanced root still carries the source scene path in Godot.
	var instance_scene_path := str(scene_root.scene_file_path).strip_edges()
	if instance_scene_path.is_empty():
		return ""
	for definition in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
		if definition != null and definition.scene_path == instance_scene_path:
			return definition.object_id
	return ""


func _find_nested_object_scene_root(
	scene_root: Node,
	object_id: String
) -> Node:
	var persistent_match := ObjectLibraryService.find_scene_root_in_tree(scene_root, object_id)
	if persistent_match != null:
		return persistent_match
	var object_scene_path := _get_object_definition_scene_path(object_id)
	if scene_root == null or object_scene_path.is_empty():
		return null
	var match_root: Node
	for candidate in scene_root.find_children("*", "", true, false):
		if str(candidate.scene_file_path).strip_edges() != object_scene_path:
			continue
		if match_root != null:
			return null
		match_root = candidate
	return match_root


func _find_selected_object_scene_root(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var selection := EditorInterface.get_selection()
	if selection == null:
		return null
	var matches: Array[Node] = []
	for selected_node in selection.get_selected_nodes():
		var current := selected_node as Node
		while current != null:
			if not _get_linked_object_id_for_scene_root(current).is_empty():
				if not matches.has(current):
					matches.append(current)
				break
			if current == scene_root:
				break
			current = current.get_parent()
	return matches[0] if matches.size() == 1 else null


func _resolve_scene_sync_target(saved_scene_path: String) -> Dictionary:
	var edited_root := EditorInterface.get_edited_scene_root()
	if edited_root == null:
		return {"scene_path": saved_scene_path, "scene_root": null, "object_id": ""}

	var edited_scene_path := str(edited_root.scene_file_path).strip_edges()
	# scene_saved can also fire for another tab during Save All. Never pair that
	# path with the live tree of the currently edited scene.
	if (
		not saved_scene_path.strip_edges().is_empty()
		and edited_scene_path != saved_scene_path.strip_edges()
	):
		return {"scene_path": saved_scene_path, "scene_root": null, "object_id": ""}

	# If the edited scene itself is a Builder object, it is the target.
	var root_object_id := _get_linked_object_id_for_scene_root(edited_root)
	if not root_object_id.is_empty():
		var root_definition_path := _get_object_definition_scene_path(root_object_id)
		return {
			"scene_path": root_definition_path if not root_definition_path.is_empty() else saved_scene_path,
			"scene_root": edited_root,
			"object_id": root_object_id
		}

	# Legacy objects may be linked by their scene path without an identity node.
	if str(edited_root.scene_file_path).strip_edges() == saved_scene_path:
		for definition in ObjectLibraryService.load_definitions() + ObjectLibraryService.load_templates():
			if definition != null and definition.scene_path == saved_scene_path:
				return {
					"scene_path": saved_scene_path,
					"scene_root": edited_root,
					"object_id": definition.object_id
				}

	# In a level scene, a selected collision/sprite/node can belong to an
	# instanced Builder object below the level root. Prefer that exact instance.
	var selected_object_root := _find_selected_object_scene_root(edited_root)
	if selected_object_root != null:
		var selected_object_id := _get_linked_object_id_for_scene_root(selected_object_root)
		var selected_definition_path := _get_object_definition_scene_path(selected_object_id)
		if not selected_definition_path.is_empty():
			return {
				"scene_path": selected_definition_path,
				"scene_root": selected_object_root,
				"object_id": selected_object_id
			}

	# When selection is elsewhere, the currently open Builder document can
	# still identify its corresponding instance in the edited level.
	var active_object_id := _get_active_builder_object_id()
	if not active_object_id.is_empty():
		var active_object_root := _find_nested_object_scene_root(edited_root, active_object_id)
		if active_object_root != null:
			var active_definition_path := _get_object_definition_scene_path(active_object_id)
			if not active_definition_path.is_empty():
				return {
					"scene_path": active_definition_path,
					"scene_root": active_object_root,
					"object_id": active_object_id
				}

	return {"scene_path": saved_scene_path, "scene_root": null, "object_id": ""}


func _queue_external_definition_sync(raw_resource_path: String) -> void:
	var resource_path := raw_resource_path.strip_edges()
	if not (
		resource_path.begins_with(ObjectLibraryService.OBJECTS_PATH + "/")
		or resource_path.begins_with(ObjectLibraryService.LEGACY_OBJECTS_PATH + "/")
		or resource_path.begins_with(ObjectLibraryService.TEMPLATES_PATH + "/")
		or resource_path.begins_with(ObjectLibraryService.LEGACY_TEMPLATES_PATH + "/")
	):
		return
	if _external_definition_sync_pending.has(resource_path):
		return
	_external_definition_sync_pending[resource_path] = true
	call_deferred(
		"_refresh_external_definition_after_godot_save", resource_path
	)


func _refresh_external_definition_after_godot_save(resource_path: String) -> void:
	await get_tree().process_frame
	if _backend == null:
		_external_definition_sync_pending.erase(resource_path)
		return
	var result: Dictionary = _backend.call(
		"handle_request",
		"external_definition_saved",
		{"resource_path": resource_path}
	)
	_external_definition_sync_pending.erase(resource_path)
	if not bool(result.get("ok", false)):
		push_warning(
			"Web Object Builder: не удалось синхронизировать ObjectDefinition из Godot: "
			+ str(result.get("error", "Неизвестная ошибка."))
		)
		return
	if not bool(result.get("external_definition_found", false)):
		return
	_refresh_object_library_dock()
	send_to_web("external_definition_updated", result)


func _refresh_external_scene_after_godot_save(scene_path: String) -> void:
	await get_tree().process_frame
	while _external_scene_sync_pending.has(scene_path):
		var pending_state: Dictionary = _external_scene_sync_pending.get(scene_path, {})
		var revision := int(pending_state.get("revision", 1))
		var scene_root := pending_state.get("scene_root") as Node
		if scene_root != null and not is_instance_valid(scene_root):
			scene_root = null

		if scene_root == null:
			var active_root := EditorInterface.get_edited_scene_root()
			if (
				active_root != null
				and str(active_root.scene_file_path).strip_edges() == scene_path
			):
				scene_root = active_root

		# Only wait for the editor's filesystem scanner when we have no live root
		# and must fall back to loading the saved PackedScene from disk.
		if scene_root == null:
			while (
				_editor_file_system != null
				and is_instance_valid(_editor_file_system)
				and (_editor_file_system.is_scanning() or _editor_file_system.is_importing())
			):
				await get_tree().process_frame

		if _backend == null:
			_external_scene_sync_pending.erase(scene_path)
			return

		var request_payload := {"scene_path": scene_path}
		if scene_root != null and is_instance_valid(scene_root):
			request_payload["scene_root"] = scene_root
		var result: Dictionary = _backend.call(
			"handle_request", "external_scene_saved", request_payload
		)

		# A newer save may have arrived while this request was being prepared.
		# Process it before clearing the queue so the latest edit always wins.
		var latest_state: Dictionary = _external_scene_sync_pending.get(scene_path, {})
		if int(latest_state.get("revision", revision)) != revision:
			continue
		_external_scene_sync_pending.erase(scene_path)

		if not bool(result.get("ok", false)):
			push_warning(
				"Web Object Builder: не удалось синхронизировать сцену из Godot: "
				+ str(result.get("error", "Неизвестная ошибка."))
			)
			return
		if not bool(result.get("external_scene_found", false)):
			push_warning(
				"Web Object Builder: сохранённая сцена не сопоставлена с объектом. "
				+ "Путь: " + scene_path
				+ "; ID сцены: " + str(result.get("scene_object_id", ""))
			)
			return

		_refresh_object_library_dock()
		print(
			"Web Object Builder: synchronized Godot scene: ",
			scene_path,
			" (object_id: ",
			str(result.get("scene_object_id", "")),
			", source: ",
			"live editor tree" if bool(result.get("live_scene_root_used", false)) else "PackedScene fallback",
			")"
		)
		send_to_web("external_scene_updated", result)
		if (
			_editor_file_system != null
			and not _editor_file_system.is_scanning()
			and not _editor_file_system.is_importing()
		):
			_editor_file_system.scan()
		return


func _sync_open_scenes_after_web_save(save_result: Dictionary) -> void:
	var changed_ids: Dictionary = {}
	var working_value: Variant = save_result.get("working", null)
	if bool(save_result.get("ok", false)) and working_value is Dictionary:
		var primary_id := str(working_value.get("objectId", "")).strip_edges()
		if not primary_id.is_empty():
			changed_ids[primary_id] = true

	var related_names := PackedStringArray()
	for name_value in save_result.get("saved_related_names", []):
		related_names.append(str(name_value))
	var workspace_value: Variant = save_result.get("workspace", {})
	if workspace_value is Dictionary:
		var objects_value: Variant = workspace_value.get("objects", [])
		if objects_value is Array:
			for object_value in objects_value:
				if not object_value is Dictionary:
					continue
				var object_name := str(object_value.get("name", ""))
				if related_names.has(object_name):
					var related_id := str(object_value.get("objectId", "")).strip_edges()
					if not related_id.is_empty():
						changed_ids[related_id] = true

	if changed_ids.is_empty():
		return

	var scene_paths := PackedStringArray()
	if workspace_value is Dictionary:
		var objects: Variant = workspace_value.get("objects", [])
		if objects is Array:
			for object_value in objects:
				if not object_value is Dictionary:
					continue
				if not changed_ids.has(str(object_value.get("objectId", ""))):
					continue
				var object_scene_path := str(object_value.get("scenePath", "")).strip_edges()
				if (
					not object_scene_path.is_empty()
					and FileAccess.file_exists(object_scene_path)
					and not scene_paths.has(object_scene_path)
				):
					scene_paths.append(object_scene_path)
	if working_value is Dictionary:
		var working_scene_path := str(working_value.get("scenePath", "")).strip_edges()
		if (
			not working_scene_path.is_empty()
			and FileAccess.file_exists(working_scene_path)
			and not scene_paths.has(working_scene_path)
		):
			scene_paths.append(working_scene_path)
	if scene_paths.is_empty():
		return

	# Wait for Godot's FileSystem scanner before evicting cached PackedScenes.
	await get_tree().process_frame
	while (
		_editor_file_system != null
		and is_instance_valid(_editor_file_system)
		and (_editor_file_system.is_scanning() or _editor_file_system.is_importing())
	):
		await get_tree().process_frame
	for scene_path in scene_paths:
		ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)

	var open_scenes := EditorInterface.get_open_scenes()
	var unsaved_scenes := EditorInterface.get_unsaved_scenes()
	for open_scene_path in open_scenes:
		var uses_changed_object := scene_paths.has(open_scene_path)
		if not uses_changed_object:
			for dependency in ResourceLoader.get_dependencies(open_scene_path):
				var dependency_path := str(dependency).get_slice("::", 0)
				if scene_paths.has(dependency_path):
					uses_changed_object = true
					break
		if not uses_changed_object:
			continue
		if unsaved_scenes.has(open_scene_path):
			var warning_message := (
				"Web Object Builder: «%s» обновлён на диске, но открытая сцена содержит несохранённые изменения. "
				% open_scene_path
			)
			warning_message += "Она не перезагружена, чтобы не потерять работу. Сохрани сцену и обнови её вручную."
			push_warning(warning_message)
			send_to_web("editor_scene_reload_skipped", {"scene_path": open_scene_path})
			continue
		EditorInterface.reload_scene_from_path(open_scene_path)
		print("Web Object Builder: reloaded open Godot scene: ", open_scene_path)


func _open_object_library_dock() -> bool:
	if _object_library_dock == null or not is_instance_valid(_object_library_dock):
		return false
	_object_library_dock.make_visible()
	return true

func _open_object_in_web_builder(object_id: String) -> void:
	var clean_id := object_id.strip_edges()
	if clean_id.is_empty():
		return
	var settings := EditorInterface.get_editor_settings()
	settings.set_project_metadata("ObjectBuilder", "web_page_object_id", clean_id)
	EditorInterface.set_main_screen_editor("Web Object Builder")


func _on_object_library_scene_path_selected(scene_path: String) -> void:
	if scene_path.strip_edges().is_empty() or not ResourceLoader.exists(scene_path):
		return
	EditorInterface.select_file(scene_path)


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Web Object Builder"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Control", "EditorIcons")


func _make_visible(visible: bool) -> void:
	_workspace_visible = visible
	if visible:
		_workspace_refresh_pending = true
	print("Web Object Builder: workspace visibility changed to ", visible)
	if visible:
		var settings := EditorInterface.get_editor_settings()
		var requested_object_id := str(
			settings.get_project_metadata("ObjectBuilder", "web_page_object_id", "")
		).strip_edges()
		if not requested_object_id.is_empty():
			settings.set_project_metadata("ObjectBuilder", "web_page_object_id", "")
			_pending_object_id_to_open = requested_object_id
	if _main_screen == null or not is_instance_valid(_main_screen):
		return

	_main_screen.visible = visible

	if visible and not _browser_initialization_attempted:
		_browser_initialization_attempted = true
		_ensure_wry_extension_loaded()
		_build_main_screen()
		return

	if _web_view != null and is_instance_valid(_web_view):
		if _web_view.has_method("set_visible"):
			_web_view.call_deferred("set_visible", visible)
		else:
			_web_view.visible = visible

		if visible and _web_view.has_method("focus"):
			_web_view.call_deferred("focus")
		if visible and _page_loaded and _frontend_ready:
			# The WebView stays alive when another editor tab is selected. Its page
			# may have missed scene-save events while hidden, so always pull a fresh
			# snapshot when the user returns to this main screen.
			call_deferred("_refresh_workspace_after_show")
		if visible and not _pending_object_id_to_open.is_empty():
			var object_id := _pending_object_id_to_open
			_pending_object_id_to_open = ""
			call_deferred("_load_object_builder_page", object_id)


func _ensure_wry_extension_loaded() -> void:
	if ClassDB.class_exists("WebView"):
		print("Web Object Builder: WebView class is already registered.")
		return

	if not FileAccess.file_exists(WRY_EXTENSION_PATH):
		push_warning(
			"Web Object Builder: WRY extension file is missing: " + WRY_EXTENSION_PATH
		)
		return

	var absolute_extension_path := ProjectSettings.globalize_path(WRY_EXTENSION_PATH)
	if GDExtensionManager.is_extension_loaded(absolute_extension_path):
		push_warning(
			"Web Object Builder: WRY is marked as loaded, but WebView is not registered."
		)
		return

	var load_status: int = GDExtensionManager.load_extension(absolute_extension_path)
	print("Web Object Builder: WRY load status = ", load_status)

	if not ClassDB.class_exists("WebView"):
		push_warning(
			"Web Object Builder: WRY did not register WebView after loading. "
			+ "Check the Output panel for GDExtension errors and verify the platform DLL."
		)


func _build_main_screen() -> void:
	if not ClassDB.class_exists("WebView"):
		_show_dependency_notice(
			"Класс WebView не зарегистрирован после попытки загрузить встроенный Godot WRY. "
			+ "Проверь WRY load status и ошибки GDExtension в Output. "
			+ "Также проверь наличие WebView2 Runtime в Windows."
		)
		return

	var instance := ClassDB.instantiate("WebView")
	if not instance is Control:
		if instance != null:
			instance.free()
		_show_dependency_notice(
			"Godot WRY зарегистрировал WebView, но не удалось создать узел. "
			+ "Проверь совместимость сборки с Godot 4.7.2."
		)
		return

	_web_view = instance as Control
	_web_view.name = "ObjectBuilderWebView"
	_web_view.anchor_left = 0.0
	_web_view.anchor_top = 0.0
	_web_view.anchor_right = 0.0
	_web_view.anchor_bottom = 0.0
	_web_view.position = Vector2.ZERO
	_web_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_web_view.size_flags_vertical = Control.SIZE_EXPAND_FILL

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(WEB_DATA_DIRECTORY)
	)

	# WRY 1.0.2 exposes this setting as data_directory (user_data_directory
	# was its pre-release name). Keep one source of truth for WebView2's profile.
	_set_webview_property("data_directory", WEB_DATA_DIRECTORY)
	_set_webview_property("devtools", true)
	_set_webview_property("forward_input_events", false)
	# The editor may be changing main-screen tabs while the native child HWND is
	# created. Asking WebView2 to take focus during construction can fail with
	# E_INVALIDARG; focus it only after the page has finished loading.
	_set_webview_property("focused_when_created", false)
	_set_webview_property("clipboard", true)
	_set_webview_property("zoom_hotkeys", false)
	_set_webview_property("full_window_size", false)
	_set_webview_property("transparent", false)
	# WRY initializes the native child WebView from ready(), but this GDExtension
	# is not a tool class, so Godot skips that callback inside the editor.
	# Attach the Control first and create the native view manually below.
	# Use the real local entrypoint as the initial URL; an empty URL takes
	# precedence over HTML in WRY and produces a blank page.
	# WRY gives `url` priority over `html`. Never assign an empty URL here:
	# it suppresses the page and leaves a blank native WebView.
	var initial_object_id := _pending_object_id_to_open
	_pending_object_id_to_open = ""
	var initial_url := _build_object_builder_url(initial_object_id)
	_object_builder_navigation_started = true
	_page_loaded = false
	if not _set_webview_property("url", initial_url):
		push_error("Web Object Builder: WRY WebView does not expose its initial url property.")
		_web_view.queue_free()
		_web_view = null
		_show_dependency_notice("Установленная сборка Godot WRY не предоставляет свойство url. Обнови addons/godot_wry до совместимой версии.")
		return
	print("Web Object Builder: initial page URL = ", initial_url)

	if _web_view.has_signal("ipc_message"):
		_web_view.connect(
			"ipc_message",
			Callable(self, "_on_web_ipc_message"),
			CONNECT_DEFERRED
		)
	if _web_view.has_signal("page_load_started"):
		_web_view.connect(
			"page_load_started",
			Callable(self, "_on_page_load_started"),
			CONNECT_DEFERRED
		)
	if _web_view.has_signal("page_load_finished"):
		_web_view.connect(
			"page_load_finished",
			Callable(self, "_on_page_load_finished"),
			CONNECT_DEFERRED
		)

	_main_screen.add_child(_web_view)
	_web_view.show()
	_sync_webview_bounds(true)

	if not _web_view.has_method("create_webview"):
		_web_view.queue_free()
		_web_view = null
		_show_dependency_notice(
			"Эта сборка WRY не предоставляет create_webview(). "
			+ "Нужна сборка с ручной инициализацией WebView для запуска в редакторе."
		)
		return

	# Critical editor workaround: the GDExtension's ready() callback is not
	# executed for a non-tool native class while running inside the editor.
	# Defer creation until the WebView is fully attached and the editor has
	# completed the current main-screen transition.
	call_deferred("_create_embedded_webview")


func _create_embedded_webview() -> void:
	await get_tree().process_frame
	if _web_view == null or not is_instance_valid(_web_view):
		return
	_sync_webview_bounds(true)
	_web_view.call("create_webview")
	if _web_view.has_method("set_visible"):
		_web_view.call("set_visible", _workspace_visible)
	print("Web Object Builder: create_webview() called explicitly for editor mode.")
	print(
		"Web Object Builder: WebView created. Control rect = ",
		_web_view.get_rect(),
		"; viewport rect = ",
		_web_view.get_viewport_rect()
	)
	# The actual res:// page is loaded by WRY from the initial `url` property.


func _sync_webview_bounds(force: bool = false) -> void:
	if _web_view == null or not is_instance_valid(_web_view):
		return
	if _main_screen == null or not is_instance_valid(_main_screen):
		return

	# WRY's native child can cause Godot's anchored Control to report a zero
	# height after the editor changes main-screen tabs. Keep a concrete rect
	# instead of relying on PRESET_FULL_RECT's deferred container layout.
	var target_size := _main_screen.size
	if target_size.x <= 1.0 or target_size.y <= 1.0:
		var parent := _main_screen.get_parent_control()
		if parent != null and parent.size.x > 1.0 and parent.size.y > 1.0:
			target_size = parent.size

	if target_size.x <= 1.0 or target_size.y <= 1.0:
		return

	var needs_resize := force or _web_view.size != target_size or _web_view.position != Vector2.ZERO
	if not needs_resize:
		return

	_web_view.anchor_left = 0.0
	_web_view.anchor_top = 0.0
	_web_view.anchor_right = 0.0
	_web_view.anchor_bottom = 0.0
	_web_view.position = Vector2.ZERO
	_web_view.size = target_size

	if _web_view.has_method("resize"):
		_web_view.call("resize")

	print(
		"Web Object Builder: WebView bounds synchronized. Target = ",
		target_size,
		"; actual = ",
		_web_view.get_rect()
	)


func _set_webview_property(property_name: String, value: Variant) -> bool:
	if _web_view == null:
		return false

	for property_info in _web_view.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			_web_view.set(property_name, value)
			return true
	return false


func _show_dependency_notice(details: String) -> void:
	var center := CenterContainer.new()
	center.name = "WebObjectBuilderDependencyNotice"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_screen.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 310)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title := Label.new()
	title.text = "Web Object Builder"
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)

	var status := Label.new()
	status.text = "Встроенный браузер пока не запущен"
	status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.42))
	content.add_child(status)

	var explanation := Label.new()
	explanation.text = details
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)

	var path_label := Label.new()
	path_label.text = "Папка веб-интерфейса:\n" + WEB_ENTRYPOINT
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	content.add_child(path_label)

	var setup_button := Button.new()
	setup_button.text = "Инструкция по установке Godot WRY"
	setup_button.pressed.connect(func() -> void:
		OS.shell_open(WRY_SETUP_URL)
	)
	content.add_child(setup_button)

	var release_button := Button.new()
	release_button.text = "Скачать Godot WRY"
	release_button.pressed.connect(func() -> void:
		OS.shell_open(WRY_RELEASES_URL)
	)
	content.add_child(release_button)


func _on_page_load_started(url: String) -> void:
	_page_loaded = false
	_frontend_ready = false
	print("Web Object Builder: page load started: ", url)


func _on_page_load_finished(url: String) -> void:
	_page_loaded = true
	print("Web Object Builder: page load finished: ", url)
	if _workspace_visible and _web_view != null and _web_view.has_method("focus"):
		_web_view.call_deferred("focus")
	if _workspace_visible and _frontend_ready and _workspace_refresh_pending:
		call_deferred("_refresh_workspace_after_show")


func _refresh_workspace_after_show() -> void:
	if not _workspace_visible or _backend == null:
		return
	if not _workspace_refresh_pending:
		return
	if not _page_loaded or not _frontend_ready:
		return
	_workspace_refresh_pending = false

	# Re-entering Godot or reopening this tab must not depend on receiving
	# EditorPlugin.scene_saved. Rebuild all linked ObjectDefinitions from their
	# current .tscn files on disk before sending the library snapshot.
	while (
		_editor_file_system != null
		and is_instance_valid(_editor_file_system)
		and (_editor_file_system.is_scanning() or _editor_file_system.is_importing())
	):
		await get_tree().process_frame
		if not _workspace_visible:
			return

	# The current editor scene may contain unsaved changes. Never replace its
	# in-memory work with a disk snapshot; all other linked object scenes are
	# safe to reconcile from their last saved .tscn file.
	var unsaved_scene_paths := EditorInterface.get_unsaved_scenes()
	var rescan_result: Dictionary = _backend.call(
		"handle_request",
		"external_scenes_rescan",
		{"skip_scene_paths": unsaved_scene_paths}
	)
	if not bool(rescan_result.get("ok", false)):
		push_warning(
			"Web Object Builder: не удалось восстановить объекты из сохранённых сцен Godot: "
			+ str(rescan_result.get("error", "Неизвестная ошибка."))
		)
	else:
		var refreshed_count := int(rescan_result.get("refreshed_count", 0))
		var skipped_count := int(rescan_result.get("skipped_count", 0))
		print(
			"Web Object Builder: disk reconciliation finished. Refreshed: ",
			refreshed_count,
			", skipped unsaved: ",
			skipped_count,
			", missing: ",
			(rescan_result.get("missing_paths", []) as Array).size(),
			", errors: ",
			(rescan_result.get("errors", []) as Array).size()
		)
		for error_message in rescan_result.get("errors", []):
			push_warning("Web Object Builder: " + str(error_message))

	var snapshot: Dictionary = _backend.call("handle_request", "workspace_get_state", {})
	if not bool(snapshot.get("ok", false)):
		push_warning(
			"Web Object Builder: не удалось обновить снимок библиотеки: "
			+ str(snapshot.get("error", "Неизвестная ошибка."))
		)
		return
	_refresh_object_library_dock()
	send_to_web("workspace_snapshot", {
		"workspace": snapshot.get("workspace", {}),
		"external_definitions": rescan_result.get("external_definitions", [])
	})
	print("Web Object Builder: authoritative Godot disk snapshot sent to the active WebView.")


func _on_web_ipc_message(raw_message: String) -> void:
	if raw_message.length() > 1_048_576:
		push_warning("Web Object Builder: incoming message is larger than 1 MiB.")
		return

	var parsed: Variant = JSON.parse_string(raw_message)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Web Object Builder: invalid IPC message received.")
		return

	var message: Dictionary = parsed
	if str(message.get("channel", "")) != "object-builder":
		return

	var message_type := str(message.get("type", ""))
	print("Web Object Builder: IPC received: ", message_type)

	if message_type == "frontend_ready":
		# The frontend sends this only after its IPC listeners and first snapshot
		# are ready. This is the reliable first-open refresh handshake.
		_frontend_ready = true
		_workspace_refresh_pending = true
		call_deferred("_refresh_workspace_after_show")
		return

	if message_type == "open_object_builder":
		var requested_object_id := _pending_object_id_to_open
		_pending_object_id_to_open = ""
		_load_object_builder_page(requested_object_id)
		return

	if _backend == null:
		push_warning("Web Object Builder: backend is not initialized.")
		return

	var raw_payload: Variant = message.get("payload", {})
	var payload: Dictionary = raw_payload.duplicate(true) if raw_payload is Dictionary else {}
	var request_id := str(message.get("request_id", payload.get("request_id", "")))
	payload.erase("request_id")

	if message_type == "object_library_open":
		var library_opened := _open_object_library_dock()
		_reply_to_web_request(request_id, {
			"ok": library_opened,
			"message": "Библиотека объектов открыта в панели Godot." if library_opened else "",
			"error": "" if library_opened else "Панель библиотеки Web Object Builder не зарегистрирована. Перезапусти плагин Web Object Builder."
		})
		web_message_received.emit(message)
		return

	if message_type == "native_editor_open":
		var object_id := str(payload.get("object_id", "")).strip_edges()
		if object_id.is_empty():
			EditorInterface.set_main_screen_editor("Web Object Builder")
			_reply_to_web_request(request_id, {"ok": true, "message": "Открыт Web Object Builder."})
		else:
			_open_object_in_web_builder(object_id)
			_reply_to_web_request(request_id, {"ok": true, "object_id": object_id, "message": "Объект открыт в Web Object Builder."})
		web_message_received.emit(message)
		return

	if message_type == "scene_open":
		var scene_path := str(payload.get("scene_path", "")).strip_edges()
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			_reply_to_web_request(request_id, {"ok": false, "error": "Сцена не найдена: " + scene_path})
		else:
			EditorInterface.open_scene_from_path(scene_path)
			_reply_to_web_request(request_id, {"ok": true, "message": "Сцена открыта в Godot."})
		web_message_received.emit(message)
		return

	if message_type == "scene_import_request":
		_show_scene_import_dialog(request_id)
		web_message_received.emit(message)
		return

	if message_type == "gameplay_table_pick_request":
		_show_gameplay_table_dialog(
			request_id,
			str(payload.get("table_type", "")),
			str(payload.get("current_path", ""))
		)
		web_message_received.emit(message)
		return

	if message_type == "gameplay_table_create_from_legacy":
		_create_gameplay_table_from_legacy(
			request_id,
			str(payload.get("table_type", "")),
			str(payload.get("legacy_json", "")),
			str(payload.get("table_id", ""))
		)
		web_message_received.emit(message)
		return

	var result: Dictionary = _backend.call("handle_request", message_type, payload)
	if not result.get("ok", false):
		push_warning("Web Object Builder: " + str(result.get("error", "Backend request failed.")))
	_reply_to_web_request(request_id, result)
	if message_type in ["workspace_get_state", "object_save", "object_save_as", "object_delete", "object_duplicate"]:
		# object_save can persist several linked ObjectDefinitions in one call.
		# Refresh regardless of the parent result because linked objects may have
		# been committed before a later parent-save error was returned.
		call_deferred("_refresh_object_library_dock")
	if message_type in ["object_save", "object_save_as", "object_duplicate"]:
		call_deferred("_sync_open_scenes_after_web_save", result.duplicate(true))

	web_message_received.emit(message)



func _reply_to_web_request(request_id: String, result: Dictionary) -> void:
	if request_id.is_empty():
		return
	send_to_web("response", {
		"request_id": request_id,
		"result": result
	})


func _show_scene_import_dialog(request_id: String) -> void:
	if _scene_import_dialog != null and is_instance_valid(_scene_import_dialog):
		_scene_import_dialog.queue_free()
	_scene_import_dialog = FileDialog.new()
	_scene_import_dialog.name = "WebObjectBuilderSceneImportDialog"
	_scene_import_dialog.title = "Импортировать сцену в Web Object Builder"
	_scene_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_scene_import_dialog.access = FileDialog.ACCESS_RESOURCES
	_scene_import_dialog.add_filter("*.tscn", "Godot Scene")
	_scene_import_dialog.add_filter("*.scn", "Compiled Godot Scene")
	_scene_import_dialog.file_selected.connect(func(selected_path: String) -> void:
		if _backend == null:
			_reply_to_web_request(request_id, {"ok": false, "error": "Нативный backend не загружен."})
			return
		var default_name := selected_path.get_file().get_basename().replace("_", " ").capitalize()
		var result: Dictionary = _backend.call("handle_request", "object_create", {
			"mode": "import",
			"import_path": selected_path,
			"name": default_name,
			"category": "Other",
			"description": "Импортировано из сцены Godot."
		})
		_reply_to_web_request(request_id, result)
		if bool(result.get("ok", false)):
			print("Web Object Builder: scene imported into Web Object Builder draft: ", selected_path)
		else:
			push_warning("Web Object Builder: scene import failed: " + str(result.get("error", "Unknown error.")))
		_scene_import_dialog.queue_free()
		_scene_import_dialog = null
	)
	_scene_import_dialog.canceled.connect(func() -> void:
		_reply_to_web_request(request_id, {"ok": false, "error": "Импорт сцены отменён."})
		if is_instance_valid(_scene_import_dialog):
			_scene_import_dialog.queue_free()
		_scene_import_dialog = null
	)
	add_child(_scene_import_dialog)
	_scene_import_dialog.popup_centered_ratio(0.78)


func _create_gameplay_table_from_legacy(
	request_id: String,
	table_type: String,
	legacy_json: String,
	table_id: String
) -> void:
	if table_type not in ["yield", "loot", "recipe", "production"]:
		_reply_to_web_request(request_id, {"ok": false, "error": "Неизвестный тип игровой таблицы."})
		return
	var parsed: Variant = JSON.parse_string(legacy_json)
	if parsed == null:
		_reply_to_web_request(request_id, {"ok": false, "error": "Legacy JSON пустой или содержит синтаксическую ошибку."})
		return
	var entries: Array[Dictionary] = []
	match table_type:
		"yield", "loot":
			if not parsed is Array:
				_reply_to_web_request(request_id, {"ok": false, "error": "Таблица добычи должна быть JSON-массивом."})
				return
			entries = GameplayTablesScript.normalize_yield_table(parsed)
		"production":
			if not parsed is Array:
				_reply_to_web_request(request_id, {"ok": false, "error": "Таблица производства должна быть JSON-массивом."})
				return
			entries = GameplayTablesScript.normalize_production_table(parsed)
		"recipe":
			var recipe_dictionary: Dictionary = {}
			if parsed is Dictionary:
				recipe_dictionary = parsed
			elif parsed is Array:
				for raw_recipe in parsed:
					if raw_recipe is Dictionary:
						var recipe_id := str(raw_recipe.get("recipe_id", raw_recipe.get("id", ""))).strip_edges()
						if not recipe_id.is_empty():
							recipe_dictionary[recipe_id] = raw_recipe
			else:
				_reply_to_web_request(request_id, {"ok": false, "error": "Таблица рецептов должна быть JSON-словарём или массивом записей."})
				return
			var normalized_recipes := GameplayTablesScript.normalize_recipe_table(recipe_dictionary)
			for recipe_key in normalized_recipes:
				var recipe: Dictionary = normalized_recipes[recipe_key].duplicate(true)
				recipe["recipe_id"] = str(recipe_key)
				entries.append(recipe)
	if entries.is_empty():
		_reply_to_web_request(request_id, {"ok": false, "error": "В JSON нет корректных записей для создания таблицы."})
		return
	var item_ids: Array[String] = []
	for entry in entries:
		if table_type == "recipe":
			for item_id in entry.get("ingredients", {}).keys():
				item_ids.append(str(item_id))
			item_ids.append(str(entry.get("output", {}).get("item_id", "")))
		else:
			item_ids.append(str(entry.get("item_id", "")))
	var validation := ItemCatalogServiceScript.validate_item_ids(item_ids)
	var table := GameplayTableDefinition.new()
	table.table_type = table_type
	table.table_id = table_id.strip_edges()
	if table.table_id.is_empty():
		table.table_id = table_type + "_table"
	table.entries = entries
	var directory := "res://data/gameplay_tables"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var base_name := table.table_id.to_lower().validate_filename()
	if base_name.is_empty():
		base_name = table_type + "_table"
	var resource_path := directory.path_join(base_name + ".tres")
	var suffix := 2
	while ResourceLoader.exists(resource_path) or FileAccess.file_exists(resource_path):
		resource_path = directory.path_join("%s_%d.tres" % [base_name, suffix])
		suffix += 1
	var save_error := ResourceSaver.save(table, resource_path)
	if save_error != OK:
		_reply_to_web_request(request_id, {"ok": false, "error": "Не удалось сохранить ресурс таблицы. Код ошибки: " + str(save_error)})
		return
	if _editor_file_system != null and is_instance_valid(_editor_file_system):
		_editor_file_system.scan()
	_reply_to_web_request(request_id, {
		"ok": true,
		"path": resource_path,
		"table_id": table.table_id,
		"unknown_item_ids": validation.get("missing", [])
	})


func _show_gameplay_table_dialog(request_id: String, expected_type: String, current_path: String) -> void:
	if expected_type not in ["yield", "loot", "recipe", "production"]:
		_reply_to_web_request(request_id, {"ok": false, "error": "Неизвестный тип игровой таблицы."})
		return
	if _gameplay_table_dialog != null and is_instance_valid(_gameplay_table_dialog):
		_gameplay_table_dialog.queue_free()
	_gameplay_table_dialog = FileDialog.new()
	_gameplay_table_dialog.name = "WebObjectBuilderGameplayTableDialog"
	_gameplay_table_dialog.title = "Выбрать ресурс игровой таблицы"
	_gameplay_table_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_gameplay_table_dialog.access = FileDialog.ACCESS_RESOURCES
	_gameplay_table_dialog.add_filter("*.tres", "Godot Resource")
	_gameplay_table_dialog.current_dir = "res://data/gameplay_tables"
	if current_path.begins_with("res://") and current_path.get_base_dir().begins_with("res://"):
		_gameplay_table_dialog.current_dir = current_path.get_base_dir()
	_gameplay_table_dialog.file_selected.connect(func(selected_path: String) -> void:
		var table := ResourceLoader.load(selected_path) as GameplayTableDefinition
		if table == null:
			_reply_to_web_request(request_id, {"ok": false, "error": "Выбранный файл не является GameplayTableDefinition."})
		elif table.table_type != expected_type:
			_reply_to_web_request(request_id, {"ok": false, "error": "Тип таблицы не совпадает. Ожидается: " + expected_type})
		else:
			_reply_to_web_request(request_id, {"ok": true, "path": selected_path, "table_id": table.table_id})
		if is_instance_valid(_gameplay_table_dialog):
			_gameplay_table_dialog.queue_free()
		_gameplay_table_dialog = null
	)
	_gameplay_table_dialog.canceled.connect(func() -> void:
		_reply_to_web_request(request_id, {"ok": false, "error": "Выбор таблицы отменён."})
		if is_instance_valid(_gameplay_table_dialog):
			_gameplay_table_dialog.queue_free()
		_gameplay_table_dialog = null
	)
	add_child(_gameplay_table_dialog)
	_gameplay_table_dialog.popup_centered_ratio(0.72)


func _build_object_builder_url(object_id: String = "") -> String:
	var target_url := WEB_ENTRYPOINT
	var clean_id := object_id.strip_edges()
	if not clean_id.is_empty():
		target_url += "?open_object_id=" + clean_id.uri_encode()
	return target_url


func _load_object_builder_page(object_id: String = "") -> void:
	if _object_builder_navigation_started and object_id.strip_edges().is_empty():
		return
	if _web_view == null or not is_instance_valid(_web_view):
		if not object_id.strip_edges().is_empty():
			_pending_object_id_to_open = object_id.strip_edges()
		return
	if not _web_view.has_method("load_url"):
		push_error("Web Object Builder: WebView does not expose load_url().")
		return

	var target_url := _build_object_builder_url(object_id)
	_object_builder_navigation_started = true
	print("Web Object Builder: navigating to Web Object Builder page: ", target_url)
	_web_view.call("load_url", target_url)


## Sends a typed event to the web frontend. The first-stage UI does not
## consume domain events yet; this is the transport seam for the next phase.
func send_to_web(message_type: String, payload: Dictionary = {}) -> void:
	if _web_view == null or not is_instance_valid(_web_view):
		return
	if not _web_view.has_method("post_message"):
		return

	var envelope := {
		"channel": "object-builder",
		"type": message_type,
		"payload": payload,
		"source": "godot"
	}
	_web_view.call("post_message", JSON.stringify(envelope))
