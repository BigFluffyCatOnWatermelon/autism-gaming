@tool
extends EditorPlugin

const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const ObjectBuilderUIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")
const ObjectBuilderLibraryViewScript = preload("res://addons/object_builder/ui/library_view.gd")
const ObjectBuilderLibraryDetailsViewScript = preload("res://addons/object_builder/ui/library_details_view.gd")
const ObjectBuilderPropertiesInspectorScript = preload("res://addons/object_builder/ui/properties_inspector_view.gd")
const ObjectBuilderLibraryActionDialogsScript = preload("res://addons/object_builder/ui/library_action_dialogs.gd")
const ObjectBuilderLibraryActionsService = preload("res://addons/object_builder/services/library_actions_service.gd")
const ObjectBuilderObjectCreationService = preload("res://addons/object_builder/services/object_creation_service.gd")
const ObjectBuilderEditorViewScript = preload("res://addons/object_builder/ui/object_editor_view.gd")
const ObjectPropertyValueCodec = preload("res://scripts/object_system/object_property_value_codec.gd")
const ObjectBuilderPropertyListViewScript = preload("res://addons/object_builder/ui/property_list_view.gd")
const ObjectBuilderComponentEditorViewScript = preload("res://addons/object_builder/ui/component_editor_view.gd")
const ObjectBuilderCapabilityListViewScript = preload("res://addons/object_builder/ui/capability_list_view.gd")
const ObjectBuilderCapabilityPresetDialogScript = preload("res://addons/object_builder/ui/capability_preset_dialog.gd")
const ObjectBuilderCapabilitySettingsPanelScript = preload("res://addons/object_builder/ui/capability_settings_panel.gd")
const ObjectBuilderCapabilityCatalogControllerScript = preload("res://addons/object_builder/controllers/capability_catalog_controller.gd")
const ObjectBuilderSceneTreeViewScript = preload("res://addons/object_builder/ui/scene_tree_view.gd")
const ObjectBuilderVisualEditorViewScript = preload("res://addons/object_builder/ui/visual_editor_view.gd")
const ObjectBuilderSpriteFramesEditorDialogScript = preload("res://addons/object_builder/ui/sprite_frames_editor_dialog.gd")
const ObjectBuilderDialogViewScript = preload("res://addons/object_builder/ui/dialog_view.gd")
const ObjectBuilderDialogService = preload("res://addons/object_builder/services/dialog_service.gd")
const ObjectBuilderEditorSceneTreeFilterScript = preload("res://addons/object_builder/services/editor_scene_tree_filter.gd")
const ObjectBuilderWorkspaceViewScript = preload("res://addons/object_builder/ui/workspace_view.gd")
const ObjectBuilderLibraryControllerScript = preload("res://addons/object_builder/controllers/library_controller.gd")
const ObjectBuilderEditorSessionScript = preload("res://addons/object_builder/controllers/object_editor_session.gd")
const ObjectBuilderSceneDraftService = preload("res://addons/object_builder/services/scene_draft_service.gd")
const ObjectBuilderSceneNodeDependencyService = preload("res://addons/object_builder/services/scene_node_dependency_service.gd")
const ObjectBuilderPreviewService = preload("res://addons/object_builder/services/preview_service.gd")
const ObjectBuilderPreviewViewScript = preload("res://addons/object_builder/ui/preview_view.gd")
const ObjectBuilderCanvasViewScript = preload("res://addons/object_builder/ui/canvas_view.gd")
const ObjectBuilderVisualPartsViewScript = preload("res://addons/object_builder/ui/visual_parts_view.gd")
const ObjectBuilderSpriteQuickSettingsViewScript = preload("res://addons/object_builder/ui/sprite_quick_settings_view.gd")

const METADATA_SECTION := "ObjectBuilder"
const ROOT_TYPES := [
	"Node2D",
	"StaticBody2D",
	"Area2D",
	"CharacterBody2D",
	"RigidBody2D",
	"AnimatableBody2D"
]
const CHILD_NODE_TYPES := [
	"Node",
	"Node2D",
	"Sprite2D",
	"AnimatedSprite2D",
	"Polygon2D",
	"Line2D",
	"Marker2D",
	"Area2D",
	"StaticBody2D",
	"CollisionShape2D",
	"CollisionPolygon2D",
	"AudioStreamPlayer2D",
	"AnimationPlayer"
]
var _main_screen: MarginContainer
var _workspace_view: Control
var _workspace_layout_state: Dictionary = {}
var _library_view: Control
var _library_details_view: Control
var _undo_toolbar_button: Button
var _redo_toolbar_button: Button
var _properties_inspector: Control
var _library_action_dialogs: Node
var _pending_library_definition: ObjectDefinition
var _pending_collection_id := ""
var _pending_scene_node_removal: Node
var _scene_node_delete_dialog: ConfirmationDialog
var _editor_view: TabContainer
var _dialog_view: Node
var _library_controller: RefCounted = ObjectBuilderLibraryControllerScript.new()
var _editor_session: RefCounted = ObjectBuilderEditorSessionScript.new()
var _name_edit: LineEdit
var _id_edit: LineEdit
var _category_edit: LineEdit
var _root_type: OptionButton
var _object_type_label: Label
var _tags_edit: LineEdit
var _description_edit: TextEdit
var _template_check: CheckBox
var _favorite_button: Button
var _property_list: VBoxContainer
var _component_view: Control
var _capability_view: Control
var _capability_preset_dialog: ConfirmationDialog
var _capability_preset_delete_dialog: ConfirmationDialog
var _pending_capability_preset_action := ""
var _pending_capability_preset_id := ""
var _pending_capability_preset_icon := "shapes"
var _pending_capability_preset_capability_ids := PackedStringArray()
var _capability_settings_panel: Control
var _editing_capability_selection: ObjectCapabilitySelection
var _capability_change_dialog: AcceptDialog
var _pending_capability_values: Array[ObjectCapabilitySelection] = []
var _pending_capability_summary := PackedStringArray()
var _capability_catalog_controller: RefCounted = ObjectBuilderCapabilityCatalogControllerScript.new()
var _pending_capability_batch := false
var _editing_property: ObjectPropertyDefinition
var _scene_tree_view: Control
var _visual_editor_view: Control
var _canvas_view: Control
var _visual_parts_view: Control
var _sprite_quick_settings_view: Control
var _sprite_frames_editor_dialog: ConfirmationDialog
var _pending_sprite_frames_editor_path := NodePath("")
var _status_label: Label
var _preview_view: Window
var _open_scene_button: Button
var _connected_scene_tree: SceneTree
var _connected_scene_root: Node
var _tree_refresh_queued := false
var _syncing_tree_selection := false
var _working_definition: ObjectDefinition
var _is_loading_editor_form := false
var _can_save_as_template := true
var _locked_visual_part_keys := PackedStringArray()
var _canvas_vertical_guides: Array[float] = []
var _canvas_horizontal_guides: Array[float] = []


func _enter_tree() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		push_warning("Object Builder: " + error_message)
	_load_local_state()
	_build_ui()
	var editor_main_screen := EditorInterface.get_editor_main_screen()
	editor_main_screen.add_child(_main_screen)
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_screen.hide()
	_connect_editor_sync()
	_refresh_library()


func _exit_tree() -> void:
	_disconnect_editor_sync()
	if _library_controller != null and _workspace_view != null:
		_save_local_state()
	_cleanup_abandoned_new_draft(null)
	if _editor_session != null:
		_editor_session.call("clear")
	_working_definition = null
	_capability_catalog_controller.call("clear_selection")
	if _preview_view != null and is_instance_valid(_preview_view):
		_preview_view.queue_free()
		_preview_view = null
	if _main_screen != null:
		_main_screen.queue_free()
		_main_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _main_screen != null:
		_main_screen.visible = visible


func _get_plugin_name() -> String:
	return "Object Builder"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Node2D", "EditorIcons")


func _connect_editor_sync() -> void:
	var editor_selection := EditorInterface.get_selection()
	if not editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		editor_selection.selection_changed.connect(_on_editor_selection_changed)

	var inspector := EditorInterface.get_inspector()
	if not inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.connect(_on_inspector_property_edited)
	if not inspector.edited_object_changed.is_connected(_on_inspector_edited_object_changed):
		inspector.edited_object_changed.connect(_on_inspector_edited_object_changed)

	if not scene_changed.is_connected(_on_editor_scene_changed):
		scene_changed.connect(_on_editor_scene_changed)
	if not scene_closed.is_connected(_on_editor_scene_closed):
		scene_closed.connect(_on_editor_scene_closed)
	_update_scene_tree_connection()


func _disconnect_editor_sync() -> void:
	var editor_selection := EditorInterface.get_selection()
	if editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		editor_selection.selection_changed.disconnect(_on_editor_selection_changed)

	var inspector := EditorInterface.get_inspector()
	if inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.disconnect(_on_inspector_property_edited)
	if inspector.edited_object_changed.is_connected(_on_inspector_edited_object_changed):
		inspector.edited_object_changed.disconnect(_on_inspector_edited_object_changed)

	if scene_changed.is_connected(_on_editor_scene_changed):
		scene_changed.disconnect(_on_editor_scene_changed)
	if scene_closed.is_connected(_on_editor_scene_closed):
		scene_closed.disconnect(_on_editor_scene_closed)

	if is_instance_valid(_connected_scene_tree):
		if _connected_scene_tree.node_added.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_added.disconnect(_on_editor_scene_node_changed)
		if _connected_scene_tree.node_removed.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_removed.disconnect(_on_editor_scene_node_changed)
		if _connected_scene_tree.node_renamed.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_renamed.disconnect(_on_editor_scene_node_changed)
	_connected_scene_tree = null
	_connected_scene_root = null


func _update_scene_tree_connection() -> void:
	var edited_root := EditorInterface.get_edited_scene_root()
	var next_tree: SceneTree = edited_root.get_tree() if edited_root != null else null
	if next_tree == _connected_scene_tree and edited_root == _connected_scene_root:
		return
	if is_instance_valid(_connected_scene_tree):
		if _connected_scene_tree.node_added.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_added.disconnect(_on_editor_scene_node_changed)
		if _connected_scene_tree.node_removed.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_removed.disconnect(_on_editor_scene_node_changed)
		if _connected_scene_tree.node_renamed.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_renamed.disconnect(_on_editor_scene_node_changed)
	_connected_scene_tree = next_tree
	_connected_scene_root = edited_root
	if is_instance_valid(_connected_scene_tree):
		if not _connected_scene_tree.node_added.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_added.connect(_on_editor_scene_node_changed)
		if not _connected_scene_tree.node_removed.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_removed.connect(_on_editor_scene_node_changed)
		if not _connected_scene_tree.node_renamed.is_connected(_on_editor_scene_node_changed):
			_connected_scene_tree.node_renamed.connect(_on_editor_scene_node_changed)


func _on_editor_scene_changed(_scene_root: Node) -> void:
	_update_scene_tree_connection()
	call_deferred("_refresh_scene_tree")
	call_deferred("_on_editor_selection_changed")


func _on_editor_scene_closed(_path: String) -> void:
	_update_scene_tree_connection()
	call_deferred("_refresh_scene_tree")


func _on_editor_scene_node_changed(changed_node: Node) -> void:
	# The editor SceneTree also contains Object Builder UI and its isolated Canvas preview.
	# Only changes inside the currently edited scene may trigger a scene-tree refresh.
	if not ObjectBuilderEditorSceneTreeFilterScript.belongs_to_scene(_connected_scene_root, changed_node):
		return
	if _tree_refresh_queued:
		return
	_tree_refresh_queued = true
	call_deferred("_deferred_refresh_scene_tree")


func _deferred_refresh_scene_tree() -> void:
	_tree_refresh_queued = false
	_update_scene_tree_connection()
	_refresh_scene_tree()


func _on_editor_selection_changed() -> void:
	if _syncing_tree_selection:
		return
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var selected_node := _get_editor_selected_scene_node(scene_root)
	if selected_node == null:
		_refresh_visual_editor(null)
		if _workspace_view != null:
			_workspace_view.call("set_selection_info", "", "")
		return
	_refresh_scene_tree()
	_sync_scene_tree_selection(selected_node)


func _on_inspector_edited_object_changed() -> void:
	call_deferred("_on_editor_selection_changed")


func _on_inspector_property_edited(_property_name: String) -> void:
	var inspected_object := EditorInterface.get_inspector().get_edited_object()
	if inspected_object is ObjectComponentDefinition and _working_definition != null:
		for component_definition in _working_definition.components:
			if component_definition == inspected_object:
				_mark_editor_session_changed()
				_set_status(
					"Настройки компонента изменены. Нажми «Сохранить в библиотеку», чтобы записать их.",
					false
				)
				break
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var target_node: Node = null
	if inspected_object is Node:
		target_node = inspected_object as Node
	else:
		target_node = _get_editor_selected_scene_node(scene_root)
	if target_node != null and (target_node == scene_root or scene_root.is_ancestor_of(target_node)):
		_refresh_visual_editor(target_node)
		_refresh_canvas()

func _get_editor_selected_scene_node(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	for selected_node in EditorInterface.get_selection().get_selected_nodes():
		if selected_node is Node:
			var selected := selected_node as Node
			if selected == scene_root or scene_root.is_ancestor_of(selected):
				return selected
	var inspected_object := EditorInterface.get_inspector().get_edited_object()
	if inspected_object is Node:
		var inspected_node := inspected_object as Node
		if inspected_node == scene_root or scene_root.is_ancestor_of(inspected_node):
			return inspected_node
	return null


func _sync_scene_tree_selection(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var scene_root := _get_open_object_scene_root()
	if scene_root == null or _scene_tree_view == null:
		return
	_syncing_tree_selection = true
	_scene_tree_view.call("select_node", scene_root, node)
	_syncing_tree_selection = false
	_refresh_visual_editor(node)
	if _canvas_view != null:
		_canvas_view.call("set_selected_path", scene_root.get_path_to(node))
	if _visual_parts_view != null:
		_visual_parts_view.call("set_selected_path", scene_root.get_path_to(node))
	if _workspace_view != null:
		_workspace_view.call("set_selection_info", node.name, str(node.get_path()))
func _build_ui() -> void:
	_main_screen = MarginContainer.new()
	_main_screen.name = "Object Builder"
	_main_screen.custom_minimum_size = Vector2(620, 320)
	_main_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for margin_name in ["left", "top", "right", "bottom"]:
		_main_screen.add_theme_constant_override("margin_" + margin_name, 8)

	_workspace_view = ObjectBuilderWorkspaceViewScript.new()
	_workspace_view.name = "WorkspaceView"
	_workspace_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_screen.add_child(_workspace_view)
	_workspace_view.call("build")
	_workspace_view.call("apply_layout_state", _workspace_layout_state)
	_workspace_view.connect("layout_changed", Callable(self, "_save_local_state"))
	var inspector_host := _workspace_view.call("get_inspector_host") as VBoxContainer
	_build_library_details(inspector_host)
	_build_capability_settings_panel(inspector_host)
	_build_library_action_dialogs()

	_build_workspace_toolbar(_workspace_view.call("get_toolbar_actions") as HBoxContainer)
	_build_library_panel(_workspace_view.call("get_library_host") as VBoxContainer)
	_build_editor_tabs(_workspace_view.call("get_editor_host") as VBoxContainer)
	_build_preview_window()
	_build_scene_node_delete_dialog()


func _build_scene_node_delete_dialog() -> void:
	_scene_node_delete_dialog = ConfirmationDialog.new()
	_scene_node_delete_dialog.title = "Удалить часть со связями?"
	_scene_node_delete_dialog.ok_button_text = "Удалить всё равно"
	_scene_node_delete_dialog.get_cancel_button().text = "Отмена"
	_scene_node_delete_dialog.get_cancel_button().pressed.connect(_on_scene_node_delete_cancelled)
	_scene_node_delete_dialog.confirmed.connect(_on_scene_node_delete_confirmed)
	add_child(_scene_node_delete_dialog)


func _build_workspace_toolbar(parent: HBoxContainer) -> void:
	ObjectBuilderUIFactory.add_action_button(parent, "Создать объект", _on_new_object_pressed, "Начать создание нового игрового объекта")
	ObjectBuilderUIFactory.add_action_button(parent, "Из шаблона", _on_create_from_template_pressed)
	ObjectBuilderUIFactory.add_action_button(parent, "Сохранить", _on_save_pressed, "Сохранить текущий объект и его сцену")
	_undo_toolbar_button = ObjectBuilderUIFactory.add_action_button(parent, "↶", _on_undo_toolbar_pressed, "Отменить последнее действие")
	_redo_toolbar_button = ObjectBuilderUIFactory.add_action_button(parent, "↷", _on_redo_toolbar_pressed, "Повторить отменённое действие")
	ObjectBuilderUIFactory.add_action_button(parent, "Предпросмотр", _on_preview_pressed, "Показать текущий черновик без сохранения")
	ObjectBuilderUIFactory.add_action_button(parent, "↻", _on_refresh_pressed, "Обновить библиотеку")
	var undo_manager := EditorInterface.get_editor_undo_redo()
	if not undo_manager.history_changed.is_connected(_refresh_undo_redo_toolbar):
		undo_manager.history_changed.connect(_refresh_undo_redo_toolbar)
	if not undo_manager.version_changed.is_connected(_refresh_undo_redo_toolbar):
		undo_manager.version_changed.connect(_refresh_undo_redo_toolbar)
	_refresh_undo_redo_toolbar()


func _get_active_undo_redo() -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	var edited_root := EditorInterface.get_edited_scene_root()
	var history_id := manager.get_object_history_id(edited_root) if edited_root != null else 0
	return manager.get_history_undo_redo(history_id)


func _refresh_undo_redo_toolbar() -> void:
	var history := _get_active_undo_redo()
	if _undo_toolbar_button != null:
		_undo_toolbar_button.disabled = not history.has_undo()
		_undo_toolbar_button.tooltip_text = "Отменить: " + history.get_current_action_name() if history.has_undo() else "Нет действий для отмены"
	if _redo_toolbar_button != null:
		_redo_toolbar_button.disabled = not history.has_redo()
		_redo_toolbar_button.tooltip_text = "Повторить последнее отменённое действие" if history.has_redo() else "Нет действий для повтора"


func _on_undo_toolbar_pressed() -> void:
	var history := _get_active_undo_redo()
	if history.has_undo():
		var action_name := history.get_current_action_name()
		history.undo()
		_set_status("Отменено: " + action_name, false)
	_refresh_undo_redo_toolbar()


func _on_redo_toolbar_pressed() -> void:
	var history := _get_active_undo_redo()
	if history.has_redo():
		history.redo()
		_set_status("Действие повторено.", false)
	_refresh_undo_redo_toolbar()


func _build_canvas_editor(parent: VBoxContainer) -> void:
	_canvas_view = ObjectBuilderCanvasViewScript.new()
	_canvas_view.name = "ObjectCanvasView"
	_canvas_view.call("build")
	_canvas_view.connect("part_selected", Callable(self, "_on_canvas_part_selected"))
	_canvas_view.connect("parts_selected", Callable(self, "_on_canvas_parts_selected"))
	_canvas_view.connect("part_context_action_requested", Callable(self, "_on_canvas_part_context_action_requested"))
	_canvas_view.connect("transform_committed", Callable(self, "_on_canvas_transform_committed"))
	_canvas_view.connect("batch_transform_committed", Callable(self, "_on_canvas_batch_transform_committed"))
	_canvas_view.connect("pivot_committed", Callable(self, "_on_canvas_pivot_committed"))
	_canvas_view.connect("guides_changed", Callable(self, "_on_canvas_guides_changed"))
	_canvas_view.connect("open_scene_requested", Callable(self, "_on_canvas_open_scene_requested"))
	parent.add_child(_canvas_view)

	_visual_parts_view = ObjectBuilderVisualPartsViewScript.new()
	_visual_parts_view.name = "VisualPartsView"
	_visual_parts_view.call("build")
	_visual_parts_view.connect("part_selected", Callable(self, "_on_canvas_part_selected"))
	_visual_parts_view.connect("part_visibility_changed", Callable(self, "_on_visual_part_visibility_changed"))
	_visual_parts_view.connect("duplicate_requested", Callable(self, "_on_visual_part_duplicate_requested"))
	_visual_parts_view.connect("remove_requested", Callable(self, "_on_visual_part_remove_requested"))
	_visual_parts_view.connect("visibility_batch_requested", Callable(self, "_on_visual_parts_visibility_batch_requested"))
	_visual_parts_view.connect("part_lock_changed", Callable(self, "_on_visual_part_lock_changed"))
	_visual_parts_view.connect("draw_order_change_requested", Callable(self, "_on_visual_part_draw_order_change_requested"))
	_visual_parts_view.connect("draw_order_reorder_requested", Callable(self, "_on_visual_part_draw_order_reorder_requested"))
	_visual_parts_view.connect("rename_requested", Callable(self, "_on_scene_tree_node_rename_requested"))
	_visual_parts_view.connect("resource_edit_requested", Callable(self, "_on_visual_part_resource_edit_requested"))
	_visual_parts_view.connect("sprite_frames_editor_requested", Callable(self, "_on_sprite_frames_editor_requested"))
	parent.add_child(_visual_parts_view)

	_sprite_quick_settings_view = ObjectBuilderSpriteQuickSettingsViewScript.new()
	_sprite_quick_settings_view.name = "SpriteQuickSettingsView"
	_sprite_quick_settings_view.call("build")
	_sprite_quick_settings_view.connect("property_changed", Callable(self, "_on_sprite_quick_setting_changed"))
	parent.add_child(_sprite_quick_settings_view)


func _build_preview_window() -> void:
	_preview_view = ObjectBuilderPreviewViewScript.new()
	_preview_view.name = "ObjectBuilderPreview"
	_preview_view.call("build")
	_preview_view.connect("refresh_requested", Callable(self, "_on_preview_pressed"))
	add_child(_preview_view)
	_preview_view.hide()
func _build_library_panel(parent: VBoxContainer) -> void:
	_library_view = ObjectBuilderLibraryViewScript.new()
	_library_view.name = "LibraryView"
	parent.add_child(_library_view)
	_library_view.call("build")
	_library_view.connect("search_changed", Callable(self, "_on_search_changed"))
	_library_view.connect("filter_changed", Callable(self, "_on_filter_changed"))
	_library_view.connect("object_selected", Callable(self, "_on_library_item_selected"))
	_library_view.connect("entry_action_requested", Callable(self, "_on_library_entry_action_requested"))
	_library_view.connect("collection_create_requested", Callable(self, "_on_collection_create_requested"))
	_library_view.connect("collection_management_requested", Callable(self, "_on_collection_management_requested"))

func _build_library_details(parent: VBoxContainer) -> void:
	_properties_inspector = ObjectBuilderPropertiesInspectorScript.new()
	_properties_inspector.name = "PropertiesInspector"
	parent.add_child(_properties_inspector)
	_properties_inspector.call("build")
	_library_details_view = ObjectBuilderLibraryDetailsViewScript.new()
	_library_details_view.name = "LibraryDetailsView"
	_properties_inspector.call("set_details_view", _library_details_view)
	_library_details_view.call("build")


func _build_library_action_dialogs() -> void:
	_library_action_dialogs = ObjectBuilderLibraryActionDialogsScript.new()
	_library_action_dialogs.name = "LibraryActionDialogs"
	_library_action_dialogs.connect("rename_confirmed", Callable(self, "_on_library_rename_confirmed"))
	_library_action_dialogs.connect("delete_confirmed", Callable(self, "_on_library_delete_confirmed"))
	_library_action_dialogs.connect("export_path_selected", Callable(self, "_on_library_export_path_selected"))
	_library_action_dialogs.connect("collection_create_confirmed", Callable(self, "_on_collection_create_confirmed"))
	_main_screen.add_child(_library_action_dialogs)
	_library_action_dialogs.call("build")

func _build_editor_tabs(parent: VBoxContainer) -> void:
	_editor_view = ObjectBuilderEditorViewScript.new()
	_editor_view.name = "ObjectEditorView"
	parent.add_child(_editor_view)
	_editor_view.call("build")
	_build_appearance_editor(_editor_view.get("appearance_content") as VBoxContainer)
	_build_capability_editor(_editor_view.get("capabilities_content") as VBoxContainer)
	_build_object_settings_editor(_editor_view.get("settings_content") as VBoxContainer)
	_build_advanced_editor(_editor_view.get("advanced_content") as VBoxContainer)
	_build_dialogs()


func _build_appearance_editor(parent: VBoxContainer) -> void:
	ObjectBuilderUIFactory.create_section_title(parent, "ВНЕШНИЙ ВИД ОБЪЕКТА", 18)
	var hint := Label.new()
	hint.text = "Собери внешний вид: добавляй изображения и отдельные визуальные части, перемещай их на холсте."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)
	_build_canvas_editor(parent)
	ObjectBuilderUIFactory.add_action_button(
		parent,
		"+ Добавить изображение",
		_on_simple_add_image_pressed,
		"Добавить картинку или ещё одну часть объекта"
	)


func _build_object_settings_editor(parent: VBoxContainer) -> void:
	parent.add_theme_constant_override("separation", 10)
	ObjectBuilderUIFactory.create_section_title(parent, "ОБЩИЕ НАСТРОЙКИ", 18)
	_name_edit = ObjectBuilderUIFactory.add_labeled_line_edit(parent, "Название", "Например, Волшебный сундук")

	_description_edit = TextEdit.new()
	_description_edit.custom_minimum_size = Vector2(0, 72)
	_description_edit.placeholder_text = "Что это за объект? (необязательно)"
	ObjectBuilderUIFactory.add_labeled_control(parent, "Описание", _description_edit)
	_category_edit = ObjectBuilderUIFactory.add_labeled_line_edit(parent, "Категория", "Например, Nature")

	var favorite_row := HBoxContainer.new()
	parent.add_child(favorite_row)
	_favorite_button = Button.new()
	_favorite_button.text = "☆ В избранное"
	_favorite_button.tooltip_text = "Сохраняется локально в настройках редактора этого проекта."
	_favorite_button.pressed.connect(_on_toggle_favorite_pressed)
	favorite_row.add_child(_favorite_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_status_label)

func _build_advanced_editor(parent: VBoxContainer) -> void:
	var advanced_editor := parent
	advanced_editor.add_theme_constant_override("separation", 7)
	ObjectBuilderUIFactory.create_section_title(advanced_editor, "ТЕХНИЧЕСКИЕ НАСТРОЙКИ", 16)
	
	_id_edit = ObjectBuilderUIFactory.add_labeled_line_edit(advanced_editor, "Постоянный ID", "Создаётся автоматически")
	_id_edit.editable = false
	
	_object_type_label = Label.new()
	_object_type_label.text = "Не выбран"
	ObjectBuilderUIFactory.add_labeled_control(advanced_editor, "Стартовый профиль", _object_type_label)
	
	_tags_edit = ObjectBuilderUIFactory.add_labeled_line_edit(advanced_editor, "Теги", "дерево, ресурс, лес")
	
	_root_type = OptionButton.new()
	for root_type in ROOT_TYPES:
		_root_type.add_item(root_type)
	ObjectBuilderUIFactory.add_labeled_control(advanced_editor, "Тип корневого узла", _root_type)
	
	_template_check = CheckBox.new()
	_template_check.text = "Сохранить как шаблон"
	_template_check.tooltip_text = "Сохранит новую заготовку отдельно от игровых объектов."
	advanced_editor.add_child(_template_check)
	_connect_editor_form_signals()
	
	_scene_tree_view = ObjectBuilderSceneTreeViewScript.new()
	_scene_tree_view.name = "SceneTreeView"
	_scene_tree_view.connect("add_node_requested", Callable(self, "_on_add_node_pressed"))
	_scene_tree_view.connect("remove_node_requested", Callable(self, "_on_remove_node_pressed"))
	_scene_tree_view.connect("duplicate_node_requested", Callable(self, "_on_duplicate_node_pressed"))
	_scene_tree_view.connect("node_rename_requested", Callable(self, "_on_scene_tree_node_rename_requested"))
	_scene_tree_view.connect("refresh_requested", Callable(self, "_refresh_scene_tree"))
	_scene_tree_view.connect("node_selected", Callable(self, "_on_scene_tree_item_selected"))
	_scene_tree_view.call("build")
	advanced_editor.add_child(_scene_tree_view)

	_open_scene_button = ObjectBuilderUIFactory.add_action_button(
		advanced_editor,
		"Открыть сцену в Godot",
		_on_open_scene_pressed,
		"Открыть текущую сцену объекта в штатном редакторе Godot"
	)
	_open_scene_button.disabled = true
	_build_visual_editor(advanced_editor)

	ObjectBuilderUIFactory.create_section_title(advanced_editor, "ПОЛЬЗОВАТЕЛЬСКИЕ СВОЙСТВА")
	
	var properties_hint := Label.new()
	properties_hint.text = "Расширенные типизированные свойства и их значения по умолчанию."
	properties_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advanced_editor.add_child(properties_hint)
	
	var property_list_view: VBoxContainer = ObjectBuilderPropertyListViewScript.new()
	property_list_view.connect("numeric_default_changed", Callable(self, "_on_property_default_numeric_changed"))
	property_list_view.connect("boolean_default_changed", Callable(self, "_on_property_default_boolean_changed"))
	property_list_view.connect("text_default_submitted", Callable(self, "_on_property_default_text_submitted"))
	property_list_view.connect("text_default_focus_exited", Callable(self, "_on_property_default_text_focus_exited"))
	property_list_view.connect("edit_requested", Callable(self, "_on_edit_property_pressed"))
	property_list_view.connect("remove_requested", Callable(self, "_on_remove_property_pressed"))
	_property_list = property_list_view
	advanced_editor.add_child(_property_list)
	
	ObjectBuilderUIFactory.add_action_button(
		advanced_editor,
		"+ Добавить свойство",
		_on_add_property_pressed
	)
	
	_build_component_editor(advanced_editor)

func _connect_editor_form_signals() -> void:
	_name_edit.text_changed.connect(_on_editor_name_changed)
	_description_edit.text_changed.connect(_on_editor_description_changed)
	_category_edit.text_changed.connect(_on_editor_category_changed)
	_tags_edit.text_changed.connect(_on_editor_tags_changed)
	_root_type.item_selected.connect(_on_editor_root_type_selected)
	_template_check.toggled.connect(_on_editor_template_toggled)


func _on_editor_name_changed(value: String) -> void:
	if _is_loading_editor_form or _working_definition == null:
		return
	var next_value := value.strip_edges()
	if _working_definition.display_name == next_value:
		return
	_working_definition.display_name = next_value
	_mark_editor_session_changed()


func _on_editor_description_changed() -> void:
	if _is_loading_editor_form or _working_definition == null:
		return
	if _working_definition.description == _description_edit.text:
		return
	_working_definition.description = _description_edit.text
	_mark_editor_session_changed()


func _on_editor_category_changed(value: String) -> void:
	if _is_loading_editor_form or _working_definition == null:
		return
	var next_value := value.strip_edges()
	if _working_definition.category == next_value:
		return
	_working_definition.category = next_value
	_mark_editor_session_changed()


func _on_editor_tags_changed(value: String) -> void:
	if _is_loading_editor_form or _working_definition == null:
		return
	var next_tags := PackedStringArray()
	for raw_tag in value.split(","):
		var tag := raw_tag.strip_edges()
		if not tag.is_empty():
			next_tags.append(tag)
	if _working_definition.tags == next_tags:
		return
	_working_definition.tags = next_tags
	_mark_editor_session_changed()


func _on_editor_root_type_selected(index: int) -> void:
	if _is_loading_editor_form or _working_definition == null:
		return
	if index < 0 or index >= _root_type.item_count:
		return
	var next_type := _root_type.get_item_text(index)
	if _working_definition.root_type == next_type:
		return
	_working_definition.root_type = next_type
	_mark_editor_session_changed()


func _on_editor_template_toggled(enabled: bool) -> void:
	if _is_loading_editor_form or _working_definition == null:
		return
	if _working_definition.is_template == enabled:
		return
	_working_definition.is_template = enabled
	_mark_editor_session_changed()


func _mark_editor_session_changed() -> void:
	if _is_loading_editor_form or _editor_session == null:
		return
	var was_dirty := bool(_editor_session.call("is_dirty"))
	_editor_session.call("mark_changed")
	if not was_dirty:
		_set_status("Есть несохранённые изменения. Нажми «Сохранить объект».", false)


func _build_dialogs() -> void:
	_dialog_view = ObjectBuilderDialogViewScript.new()
	_dialog_view.name = "DialogView"
	add_child(_dialog_view)

	var property_types: Array[String] = ["String", "Integer", "Float", "Boolean", "Vector2"]
	var creation_profiles: Array[Dictionary] = []
	for profile_id in ObjectCreationProfileRegistry.get_profile_ids():
		var profile := ObjectCreationProfileRegistry.get_definition(profile_id)
		if profile == null:
			continue
		creation_profiles.append({
			"id": profile.profile_id,
			"label": profile.display_name
		})

	_dialog_view.call("build", property_types, creation_profiles, CHILD_NODE_TYPES)
	_dialog_view.call("set_creation_category_options", _library_controller.call("get_category_options"), "Other")
	(_dialog_view.call("get_property_dialog") as AcceptDialog).confirmed.connect(_on_property_dialog_confirmed)
	(_dialog_view.call("get_creation_dialog") as AcceptDialog).confirmed.connect(_on_new_object_dialog_confirmed)
	(_dialog_view.call("get_node_dialog") as AcceptDialog).confirmed.connect(_on_node_dialog_confirmed)
	_dialog_view.connect("creation_profile_selected", Callable(self, "_on_new_object_type_selected"))
	_build_capability_change_dialog()

func _build_capability_editor(parent: VBoxContainer) -> void:
	var view: VBoxContainer = ObjectBuilderCapabilityListViewScript.new()
	_capability_view = view
	view.connect("search_changed", Callable(self, "_on_capability_search_changed"))
	view.connect("category_changed", Callable(self, "_on_capability_category_selected"))
	view.connect("toggle_requested", Callable(self, "_on_capability_toggled"))
	view.connect("settings_requested", Callable(self, "_on_capability_settings_pressed"))
	view.connect("focus_requested", Callable(self, "_on_capability_focus_requested"))
	view.connect("selection_toggled", Callable(self, "_on_capability_catalog_selection_toggled"))
	view.connect("batch_add_requested", Callable(self, "_on_capability_batch_add_requested"))
	view.connect("clear_selection_requested", Callable(self, "_on_capability_catalog_selection_cleared"))
	view.connect("preset_requested", Callable(self, "_on_capability_preset_requested"))
	view.connect("preset_select_all_requested", Callable(self, "_on_capability_preset_select_all_requested"))
	view.connect("preset_action_requested", Callable(self, "_on_capability_preset_action_requested"))
	view.call("build", ObjectCapabilityCatalog.get_categories())
	_build_capability_preset_dialog()
	parent.add_child(view)
	_rebuild_capability_list()


func _build_capability_change_dialog() -> void:
	_capability_change_dialog = AcceptDialog.new()
	_capability_change_dialog.title = "Подтвердить изменение объекта"
	_capability_change_dialog.ok_button_text = "Применить"
	_capability_change_dialog.confirmed.connect(_on_capability_change_confirmed)
	_capability_change_dialog.canceled.connect(_on_capability_change_canceled)
	_capability_change_dialog.add_cancel_button("Отмена")
	add_child(_capability_change_dialog)


func _build_capability_preset_dialog() -> void:
	if _capability_preset_dialog == null:
		_capability_preset_dialog = ObjectBuilderCapabilityPresetDialogScript.new()
		_capability_preset_dialog.call("build")
		_capability_preset_dialog.confirmed.connect(_on_capability_preset_dialog_confirmed)
		add_child(_capability_preset_dialog)
	if _capability_preset_delete_dialog == null:
		_capability_preset_delete_dialog = ConfirmationDialog.new()
		_capability_preset_delete_dialog.title = "Удалить пользовательский набор"
		_capability_preset_delete_dialog.dialog_text = "Удалить выбранный пользовательский набор? Это действие нельзя отменить."
		_capability_preset_delete_dialog.ok_button_text = "Удалить"
		_capability_preset_delete_dialog.add_cancel_button("Отмена")
		_capability_preset_delete_dialog.confirmed.connect(_on_capability_preset_delete_confirmed)
		add_child(_capability_preset_delete_dialog)


func _build_capability_settings_panel(parent: VBoxContainer) -> void:
	_capability_settings_panel = ObjectBuilderCapabilitySettingsPanelScript.new()
	_capability_settings_panel.name = "CapabilitySettingsPanel"
	_capability_settings_panel.call("build")
	_capability_settings_panel.connect("apply_requested", Callable(self, "_on_capability_settings_panel_apply"))
	_capability_settings_panel.connect("close_requested", Callable(self, "_on_capability_settings_panel_close"))
	if _properties_inspector != null:
		_properties_inspector.call("set_capability_settings_view", _capability_settings_panel)
	else:
		parent.add_child(_capability_settings_panel)
	_capability_settings_panel.custom_minimum_size = Vector2.ZERO
	_capability_settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _on_capability_search_changed(_query: String) -> void:
	_rebuild_capability_list()


func _on_capability_category_selected(_category_id: String) -> void:
	_rebuild_capability_list()


func _find_capability_selection(capability_id: String) -> ObjectCapabilitySelection:
	if _working_definition == null:
		return null
	for selection in _working_definition.capabilities:
		if selection != null and selection.capability_id == capability_id:
			return selection
	return null


func _rebuild_capability_list() -> void:
	if _capability_view == null:
		return
	if _working_definition == null:
		_capability_view.call(
			"show_empty_state",
			"Сначала создай объект или выбери его в библиотеке."
		)
		return

	var category_id := str(_capability_view.call("get_selected_category"))
	var query := str(_capability_view.call("get_search_query")).strip_edges()
	var capability_ids := ObjectCapabilityCatalog.get_capability_ids(category_id)
	var all_capability_ids := ObjectCapabilityCatalog.get_capability_ids("", false)
	var ready_count := int(_capability_catalog_controller.call("count_ready", all_capability_ids))
	var entries: Array[Dictionary] = _capability_catalog_controller.call(
		"build_entries",
		capability_ids,
		_working_definition.capabilities,
		query
	)

	_capability_view.call(
		"set_entries",
		entries,
		all_capability_ids.size(),
		ready_count
	)
	_capability_view.call(
		"set_selected_count",
		_capability_catalog_controller.call("get_selected_count")
	)
	var related_entries: Array[Dictionary] = _capability_catalog_controller.call("build_related_entries")
	var focused_id := str(_capability_catalog_controller.call("get_focused_capability_id"))
	var focused_definition := ObjectCapabilityCatalog.get_definition_reference(focused_id)
	var focused_name := focused_definition.display_name if focused_definition != null else ""
	_capability_view.call("set_related_entries", related_entries, focused_name, focused_definition)
	var recommended_entries: Array[Dictionary] = _capability_catalog_controller.call(
		"build_recommended_entries",
		_working_definition.capabilities,
		query,
		8,
		_working_definition.object_type,
		_working_definition.category,
		_working_definition.tags
	)
	var recommendation_context_parts := PackedStringArray()
	if not _working_definition.display_name.strip_edges().is_empty():
		recommendation_context_parts.append(_working_definition.display_name.strip_edges())
	var profile_name := ObjectCreationProfileRegistry.get_display_name(_working_definition.object_type)
	if not profile_name.is_empty() and _working_definition.object_type.strip_edges().to_lower() != "other":
		recommendation_context_parts.append(profile_name)
	elif not _working_definition.category.strip_edges().is_empty():
		var category_name := str(_library_controller.call(
			"get_category_display_name",
			_working_definition.category
		))
		recommendation_context_parts.append(
			category_name if not category_name.is_empty() else _working_definition.category.strip_edges()
		)
	_capability_view.call(
		"set_recommended_entries",
		recommended_entries,
		" · ".join(recommendation_context_parts)
	)
	var preset_summaries: Array[Dictionary] = _capability_catalog_controller.call("build_preset_summaries")
	var active_preset_details: Dictionary = _capability_catalog_controller.call(
		"build_active_preset_details",
		_working_definition.capabilities
	)
	_capability_view.call("set_preset_data", preset_summaries, active_preset_details)

func _on_capability_focus_requested(capability_id: String) -> void:
	if _working_definition == null:
		return
	_capability_catalog_controller.call("set_focused_capability", capability_id)
	_rebuild_capability_list()


func _on_capability_catalog_selection_toggled(selected: bool, capability_id: String) -> void:
	if _working_definition == null:
		return
	_capability_catalog_controller.call("set_selected", capability_id, selected)
	_rebuild_capability_list()

func _on_capability_preset_requested(preset_id: String) -> void:
	if _working_definition == null:
		return
	_capability_catalog_controller.call("set_active_preset", preset_id)
	_rebuild_capability_list()


func _on_capability_preset_select_all_requested() -> void:
	if _working_definition == null:
		return
	var added_count := int(_capability_catalog_controller.call(
		"select_all_available_from_active_preset",
		_working_definition.capabilities
	))
	_rebuild_capability_list()
	if added_count > 0:
		_set_status("В общий список выбора добавлено из набора: %d." % added_count, false)
	else:
		_set_status("В этом наборе больше нет новых совместимых возможностей для выбора.", false)


func _on_capability_preset_action_requested(action: String, preset_id: String) -> void:
	if _working_definition == null:
		return
	var source: Dictionary = _capability_catalog_controller.call("get_preset_definition", preset_id)
	var selected_ids: PackedStringArray = _capability_catalog_controller.call("get_selected_ids")
	_pending_capability_preset_action = action
	_pending_capability_preset_id = preset_id
	_pending_capability_preset_icon = str(source.get("icon", "shapes"))
	_pending_capability_preset_capability_ids = PackedStringArray()

	match action:
		"create":
			if selected_ids.is_empty():
				_set_status("Сначала отметь в каталоге хотя бы одну готовую возможность.", true)
				return
			_pending_capability_preset_capability_ids = selected_ids.duplicate()
			_capability_preset_dialog.call("configure", "Новый пользовательский набор", "Мой набор возможностей", "", "Сохранить")
			_capability_preset_dialog.popup_centered(Vector2i(480, 320))
		"update":
			if source.is_empty() or not bool(source.get("is_custom", false)):
				_set_status("Обновлять можно только пользовательские наборы.", true)
				return
			if selected_ids.is_empty():
				_set_status("Выбери в каталоге состав, которым нужно заменить текущий набор.", true)
				return
			_pending_capability_preset_capability_ids = selected_ids.duplicate()
			_capability_preset_dialog.call("configure", "Обновить пользовательский набор", str(source.get("display_name", "")), str(source.get("description", "")), "Сохранить изменения")
			_capability_preset_dialog.popup_centered(Vector2i(480, 320))
		"duplicate":
			if source.is_empty():
				_set_status("Исходный набор больше не найден.", true)
				return
			for capability_id in source.get("capability_ids", []):
				_pending_capability_preset_capability_ids.append(str(capability_id))
			_capability_preset_dialog.call("configure", "Дублировать набор", str(source.get("display_name", "")) + " — копия", str(source.get("description", "")), "Создать копию")
			_capability_preset_dialog.popup_centered(Vector2i(480, 320))
		"delete":
			if source.is_empty() or not bool(source.get("is_custom", false)):
				_set_status("Встроенные наборы нельзя удалить.", true)
				return
			_pending_capability_preset_id = preset_id
			_capability_preset_delete_dialog.dialog_text = "Удалить пользовательский набор «%s»? Это действие нельзя отменить." % str(source.get("display_name", preset_id))
			_capability_preset_delete_dialog.popup_centered(Vector2i(440, 180))
		_:
			_pending_capability_preset_action = ""


func _on_capability_preset_dialog_confirmed() -> void:
	if _working_definition == null or _pending_capability_preset_action.is_empty():
		return
	var display_name := str(_capability_preset_dialog.call("get_display_name")).strip_edges()
	var description := str(_capability_preset_dialog.call("get_description")).strip_edges()
	if display_name.is_empty():
		_set_status("Укажи название пользовательского набора.", true)
		_capability_preset_dialog.popup_centered(Vector2i(480, 320))
		return
	var preset_id := _pending_capability_preset_id
	if _pending_capability_preset_action in ["create", "duplicate"]:
		preset_id = str(_capability_catalog_controller.call("build_unique_custom_preset_id", display_name))
	var result: Dictionary = _capability_catalog_controller.call("save_custom_preset", {
		"id": preset_id,
		"display_name": display_name,
		"description": description,
		"icon": _pending_capability_preset_icon,
		"capability_ids": Array(_pending_capability_preset_capability_ids)
	})
	if not bool(result.get("ok", false)):
		var errors: PackedStringArray = result.get("errors", PackedStringArray())
		_set_status("Набор не сохранён: " + "; ".join(errors), true)
		_capability_preset_dialog.popup_centered(Vector2i(480, 320))
		return
	_capability_catalog_controller.call("set_active_preset", preset_id)
	var action_text := "создан" if _pending_capability_preset_action in ["create", "duplicate"] else "обновлён"
	_set_status("Пользовательский набор «%s» %s. Он сохранён отдельно и ещё не применён к объекту." % [display_name, action_text], false)
	_pending_capability_preset_action = ""
	_pending_capability_preset_id = ""
	_pending_capability_preset_capability_ids.clear()
	_rebuild_capability_list()


func _on_capability_preset_delete_confirmed() -> void:
	if _working_definition == null or _pending_capability_preset_id.is_empty():
		return
	var deleted_id := _pending_capability_preset_id
	var result: Dictionary = _capability_catalog_controller.call("delete_custom_preset", deleted_id)
	if not bool(result.get("ok", false)):
		var errors: PackedStringArray = result.get("errors", PackedStringArray())
		_set_status("Набор не удалён: " + "; ".join(errors), true)
		return
	_capability_catalog_controller.call("set_active_preset", "")
	_pending_capability_preset_action = ""
	_pending_capability_preset_id = ""
	_pending_capability_preset_capability_ids.clear()
	_rebuild_capability_list()
	_set_status("Пользовательский набор удалён. Встроенные наборы не затронуты.", false)


func _on_capability_catalog_selection_cleared() -> void:
	_capability_catalog_controller.call("clear_selection")
	_rebuild_capability_list()

func _on_capability_batch_add_requested() -> void:
	if _working_definition == null:
		return
	if int(_capability_catalog_controller.call("get_selected_count")) <= 0:
		return

	var batch_plan: Dictionary = _capability_catalog_controller.call(
		"build_addition_plan",
		_working_definition.capabilities
	)
	if not bool(batch_plan.get("ok", false)):
		var errors: PackedStringArray = batch_plan.get("errors", PackedStringArray())
		_set_status("Пакет не добавлен. Объект не изменён: " + "; ".join(errors), true)
		_rebuild_capability_list()
		return

	_pending_capability_values = _capability_catalog_controller.call("get_plan_selections", batch_plan)
	var application_plan: Dictionary = batch_plan.get("application_plan", {})
	if not bool(application_plan.get("changed", false)):
		_capability_catalog_controller.call("clear_selection")
		_rebuild_capability_list()
		_set_status("Выбранные возможности уже установлены. Изменений нет.", false)
		return

	_pending_capability_summary = _capability_catalog_controller.call("build_batch_summary", batch_plan)
	_pending_capability_batch = true
	_capability_change_dialog.dialog_text = "\n".join(_pending_capability_summary)
	_rebuild_capability_list()
	ObjectBuilderDialogService.popup_window_safely(_capability_change_dialog, Vector2i(600, 440), 0.84)

func _on_capability_toggled(enabled: bool, capability_id: String) -> void:
	if _working_definition == null:
		return
	_capability_catalog_controller.call("set_focused_capability", capability_id)

	var plan := ObjectCapabilityService.plan_selection_change(
		_working_definition.capabilities,
		capability_id,
		enabled
	)
	if not bool(plan.get("ok", false)):
		_rebuild_capability_list()
		var errors: PackedStringArray = plan.get("errors", PackedStringArray())
		_set_status("Изменение не применено: " + "; ".join(errors), true)
		return

	var next_values: Array[ObjectCapabilitySelection] = []
	var planned_values: Variant = plan.get("selections", [])
	if planned_values is Array:
		for value in planned_values:
			if value is ObjectCapabilitySelection:
				next_values.append(value as ObjectCapabilitySelection)

	var application_plan := ObjectCapabilityService.build_application_plan(
		_working_definition.capabilities,
		next_values
	)
	if not bool(application_plan.get("ok", false)):
		_rebuild_capability_list()
		var application_errors: PackedStringArray = application_plan.get("errors", PackedStringArray())
		_set_status("Нельзя применить изменение: " + "; ".join(application_errors), true)
		return
	if not bool(application_plan.get("changed", false)):
		_rebuild_capability_list()
		return

	_pending_capability_values = _duplicate_capability_selections(next_values)
	_pending_capability_summary = application_plan.get("summary_lines", PackedStringArray())
	_pending_capability_batch = false
	_capability_change_dialog.dialog_text = "\n".join(_pending_capability_summary)
	_rebuild_capability_list()
	ObjectBuilderDialogService.popup_window_safely(_capability_change_dialog, Vector2i(560, 360), 0.82)


func _on_capability_change_confirmed() -> void:
	if _working_definition == null or _pending_capability_values.is_empty():
		_on_capability_change_canceled()
		return
	# Revalidate immediately before committing; the scene or registry may have changed
	# while the confirmation dialog was open.
	var application_plan := ObjectCapabilityService.build_application_plan(
		_working_definition.capabilities,
		_pending_capability_values
	)
	if not bool(application_plan.get("ok", false)):
		var errors: PackedStringArray = application_plan.get("errors", PackedStringArray())
		_set_status("Изменение не применено: " + "; ".join(errors), true)
		_on_capability_change_canceled()
		return
	_commit_working_capabilities(_pending_capability_values, "Изменить возможности объекта")
	_set_status("Изменения применены. Нажми «Сохранить объект», чтобы записать их в библиотеку.", false)
	if _pending_capability_batch:
		_capability_catalog_controller.call("clear_selection")
	_pending_capability_batch = false
	_pending_capability_values.clear()
	_pending_capability_summary.clear()
	_rebuild_capability_list()


func _on_capability_change_canceled() -> void:
	_pending_capability_batch = false
	_pending_capability_values.clear()
	_pending_capability_summary.clear()
	_rebuild_capability_list()


func _duplicate_capability_selections(
	values: Array[ObjectCapabilitySelection]
) -> Array[ObjectCapabilitySelection]:
	var result: Array[ObjectCapabilitySelection] = []
	for selection in values:
		if selection != null:
			result.append(selection.duplicate(true) as ObjectCapabilitySelection)
	return result


func _commit_working_capabilities(
	next_values: Array[ObjectCapabilitySelection],
	action_name: String
) -> void:
	if _working_definition == null:
		return
	var previous_values := _duplicate_capability_selections(_working_definition.capabilities)
	var applied_values := _duplicate_capability_selections(next_values)
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: " + action_name, 0, _working_definition)
	undo_redo.add_do_method(self, "_apply_working_capabilities", applied_values)
	undo_redo.add_undo_method(self, "_apply_working_capabilities", previous_values)
	undo_redo.commit_action()


func _apply_working_capabilities(values: Array[ObjectCapabilitySelection]) -> void:
	if _working_definition == null:
		return
	var next_values := _duplicate_capability_selections(values)
	if _working_definition.capabilities == next_values:
		return
	_working_definition.capabilities = next_values
	if _capability_settings_panel != null and _capability_settings_panel.visible:
		var editing_id := str(_capability_settings_panel.call("get_capability_id"))
		var editing_selection := _find_capability_selection(editing_id)
		if editing_selection == null or not editing_selection.enabled:
			_on_capability_settings_panel_close()
		else:
			_editing_capability_selection = editing_selection
	_mark_editor_session_changed()
	_rebuild_capability_list()

func _on_capability_settings_pressed(capability_id: String) -> void:
	if _working_definition == null or _capability_settings_panel == null:
		return
	var selection := _find_capability_selection(capability_id)
	if selection == null or not selection.enabled:
		return
	var capability := ObjectCapabilityCatalog.get_definition(capability_id)
	if capability == null:
		return

	_editing_capability_selection = selection
	_capability_catalog_controller.call("set_focused_capability", capability_id)
	_rebuild_capability_list()
	_capability_settings_panel.call(
		"configure",
		capability,
		selection,
		ObjectCapabilityCatalog.get_settings_schema(capability_id)
	)
	if _properties_inspector != null:
		_properties_inspector.call("show_capability_settings")
	_workspace_view.call("set_inspector_visible", true)


func _on_capability_settings_panel_apply() -> void:
	if _working_definition == null or _capability_settings_panel == null:
		return
	var capability_id := str(_capability_settings_panel.call("get_capability_id"))
	if capability_id.is_empty():
		return
	var current_selection := _find_capability_selection(capability_id)
	if current_selection == null or not current_selection.enabled:
		_set_status("Эта возможность больше не установлена. Её настройки закрыты.", true)
		_on_capability_settings_panel_close()
		return

	var updated := current_selection.duplicate(true) as ObjectCapabilitySelection
	var setting_values: Array[Dictionary] = _capability_settings_panel.call("get_changed_values")
	for entry in setting_values:
		updated.set_component_setting(
			str(entry.get("component_id", "")),
			str(entry.get("setting_key", "")),
			entry.get("value")
		)
	if updated.settings_by_component == current_selection.settings_by_component:
		_set_status("Настройки не изменились.", false)
		return

	var next_values := _duplicate_capability_selections(_working_definition.capabilities)
	var selection_index := -1
	for index in range(next_values.size()):
		if next_values[index].capability_id == capability_id:
			selection_index = index
			break
	if selection_index < 0:
		return
	next_values[selection_index] = updated

	var application_plan := ObjectCapabilityService.build_application_plan(
		_working_definition.capabilities,
		next_values
	)
	if not bool(application_plan.get("ok", false)):
		var errors: PackedStringArray = application_plan.get("errors", PackedStringArray())
		_set_status("Настройки не применены: " + "; ".join(errors), true)
		return
	if not bool(application_plan.get("changed", false)):
		_set_status("Настройки не изменились.", false)
		return

	_commit_working_capabilities(next_values, "Изменить настройки возможности")
	_editing_capability_selection = _find_capability_selection(capability_id)
	if _editing_capability_selection != null:
		_capability_settings_panel.call(
			"configure",
			ObjectCapabilityCatalog.get_definition(capability_id),
			_editing_capability_selection,
			ObjectCapabilityCatalog.get_settings_schema(capability_id)
		)
	_set_status("Настройки обновлены. Нажми «Сохранить объект», чтобы записать изменения.", false)


func _on_capability_settings_panel_close() -> void:
	if _capability_settings_panel != null:
		_capability_settings_panel.call("clear")
	_editing_capability_selection = null
	if _properties_inspector != null:
		_properties_inspector.call("show_object_details")
		var selected_index := int(_library_view.call("get_selected_index")) if _library_view != null else -1
		var selected_definition := (
			_library_controller.call("get_visible_definition", selected_index) as ObjectDefinition
			if selected_index >= 0
			else _working_definition
		)
		_refresh_library_details(selected_definition)


func _on_simple_add_image_pressed() -> void:
	if _working_definition == null:
		_set_status("Сначала создай объект.", true)
		return
	if _visual_editor_view == null:
		_set_status("Панель настройки изображения не загружена. Перезапусти Object Builder.", true)
		return
	if _working_definition.scene_path.is_empty() or not FileAccess.file_exists(_working_definition.scene_path):
		if not _create_scene_for_definition():
			return

	EditorInterface.open_scene_from_path(_working_definition.scene_path)
	await get_tree().process_frame
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Не удалось открыть сцену объекта.", true)
		return

	var visuals := scene_root.get_node_or_null("Visuals")
	if visuals == null:
		var new_visuals := Node2D.new()
		new_visuals.name = "Visuals"
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Object Builder: добавить область внешнего вида", 0, scene_root)
		undo_redo.add_do_method(scene_root, "add_child", new_visuals)
		undo_redo.add_do_method(new_visuals, "set_owner", scene_root)
		undo_redo.add_undo_method(scene_root, "remove_child", new_visuals)
		undo_redo.add_do_reference(new_visuals)
		undo_redo.commit_action()
		visuals = new_visuals

	var sprite := Sprite2D.new()
	sprite.name = "Image"
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: добавить изображение", 0, scene_root)
	undo_redo.add_do_method(visuals, "add_child", sprite)
	undo_redo.add_do_method(sprite, "set_owner", scene_root)
	undo_redo.add_undo_method(visuals, "remove_child", sprite)
	undo_redo.add_do_reference(sprite)
	undo_redo.commit_action()

	_refresh_scene_tree()
	_sync_scene_tree_selection(sprite)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(sprite)
	EditorInterface.edit_node(sprite)
	_visual_editor_view.call("popup_texture_dialog")
	_set_status("Изображение добавлено. Его можно перемещать в 2D-редакторе Godot.", false)


func _build_component_editor(parent: VBoxContainer) -> void:
	var view: VBoxContainer = ObjectBuilderComponentEditorViewScript.new()
	_component_view = view
	view.connect("category_selected", Callable(self, "_on_component_category_selected"))
	view.connect("add_requested", Callable(self, "_on_component_add_requested"))
	view.connect("enabled_changed", Callable(self, "_on_component_enabled_toggled"))
	view.connect("settings_requested", Callable(self, "_on_component_settings_pressed"))
	view.connect("remove_requested", Callable(self, "_on_component_remove_pressed"))

	var categories := ObjectComponentCatalog.get_categories()
	var selected_category := ""
	for category in categories:
		var category_id := str(category.get("id", ""))
		if category_id == "Stats":
			selected_category = category_id
			break
	if selected_category.is_empty() and not categories.is_empty():
		selected_category = str(categories[0].get("id", ""))

	view.call("build", categories, selected_category)
	parent.add_child(view)
	_refresh_component_catalog_options()
	_rebuild_component_list()


func _refresh_component_catalog_options() -> void:
	if _component_view == null:
		return
	var category_id := str(_component_view.call("get_selected_category"))
	var options: Array[Dictionary] = []
	for component_id in ObjectComponentCatalog.get_component_ids(category_id):
		options.append({
			"id": component_id,
			"label": ObjectComponentCatalog.get_component_display_name(component_id)
		})
	_component_view.call("set_component_options", options)


func _on_component_category_selected(_category_id: String) -> void:
	_refresh_component_catalog_options()


func _on_component_add_requested(component_id: String) -> void:
	if _working_definition == null or component_id.is_empty():
		return
	for existing_component in _working_definition.components:
		if existing_component != null and existing_component.component_id.to_lower() == component_id.to_lower():
			_set_status("Компонент «%s» уже добавлен." % ObjectComponentCatalog.get_component_display_name(component_id), true)
			return

	var component_definition := ObjectComponentCatalog.create_definition(component_id)
	if component_definition == null:
		_set_status("Компонент не найден в каталоге: " + component_id, true)
		return
	_working_definition.components.append(component_definition)
	_mark_editor_session_changed()
	_rebuild_component_list()
	_set_status("Компонент «%s» добавлен. Нажми «Сохранить в библиотеку». " % component_definition.display_name, false)

func _rebuild_component_list() -> void:
	if _component_view == null:
		return
	var entries: Array[Dictionary] = []
	if _working_definition != null:
		for component_definition in _working_definition.components:
			if component_definition == null:
				continue
			entries.append({
				"definition": component_definition,
				"description": ObjectComponentCatalog.get_component_description(component_definition.component_id)
			})
	_component_view.call("set_components", entries)


func _on_component_enabled_toggled(enabled: bool, component_definition: ObjectComponentDefinition) -> void:
	if component_definition == null or component_definition.enabled == enabled:
		return
	component_definition.enabled = enabled
	_mark_editor_session_changed()
	var state_text := "включён" if enabled else "отключён"
	_set_status("Компонент %s %s. Нажми «Сохранить в библиотеку». " % [component_definition.display_name, state_text], false)

func _on_component_settings_pressed(component_definition: ObjectComponentDefinition) -> void:
	if component_definition == null:
		return
	EditorInterface.edit_resource(component_definition)
	_set_status(
		"Настройки «%s» открыты в Inspector. После изменений нажми «Сохранить в библиотеку»."
		% component_definition.display_name,
		false
	)


func _on_component_remove_pressed(component_definition: ObjectComponentDefinition) -> void:
	if _working_definition == null or component_definition == null:
		return
	if not _working_definition.components.has(component_definition):
		return
	_working_definition.components.erase(component_definition)
	_mark_editor_session_changed()
	_rebuild_component_list()
	_set_status("Компонент удалён из определения. Нажми «Сохранить в библиотеку».", false)

func _ensure_component_schemas() -> void:
	if _working_definition == null:
		return
	for component_definition in _working_definition.components:
		if component_definition == null:
			continue
		if component_definition.setting_definitions.is_empty():
			component_definition.setting_definitions = ObjectComponentDefinition.get_builtin_setting_definitions(
				component_definition.component_id
			)
		for setting_definition in component_definition.get_setting_definitions():
			var setting_key := str(setting_definition.get("key", ""))
			if not setting_key.is_empty() and not component_definition.settings.has(setting_key):
				component_definition.settings[setting_key] = setting_definition.get("default_value")
		component_definition.notify_property_list_changed()


func _on_new_object_type_selected(_profile_id: String) -> void:
	_update_new_object_type_hint()

func _update_new_object_type_hint() -> void:
	if _dialog_view == null:
		return
	var profile_id := str(_dialog_view.call("get_selected_creation_profile_id"))
	if profile_id.is_empty():
		_dialog_view.call("clear_creation_category_suggestion")
		_dialog_view.call(
			"set_creation_profile_hint",
			"Обычный объект без стартового набора параметров. После создания можно добавить любые возможности."
		)
		return
	var profile := ObjectCreationProfileRegistry.get_definition(profile_id)
	if profile == null:
		_dialog_view.call("clear_creation_category_suggestion")
		_dialog_view.call(
			"set_creation_profile_hint",
			"Этот профиль больше недоступен. Можно выбрать другой или начать без профиля."
		)
		return
	_dialog_view.call("suggest_creation_category", profile.suggested_category)
	_dialog_view.call(
		"set_creation_profile_hint",
		"%s\nПрофиль предлагает настройки, но не ограничивает возможности объекта." % profile.description
	)

func _on_new_object_dialog_confirmed() -> void:
	var values: Dictionary = _dialog_view.call("get_creation_form_values")
	var display_name := str(values.get("display_name", "")).strip_edges()
	var category := str(values.get("category", "")).strip_edges()
	if display_name.is_empty():
		_set_status("Укажи название объекта.", true)
		return
	if category.is_empty():
		_set_status("Выбери категорию объекта.", true)
		return

	var mode := str(values.get("mode", "new"))
	var result: Dictionary = {}
	match mode:
		"new":
			var profile_id := str(values.get("profile_id", ""))
			var profile := ObjectCreationProfileRegistry.get_definition(profile_id) if not profile_id.is_empty() else null
			result = ObjectBuilderObjectCreationService.create_empty_draft(values, profile)
		"template":
			var template_id := str(values.get("source_id", ""))
			var template_definition := _library_controller.call("find_template", template_id) as ObjectDefinition
			result = ObjectBuilderObjectCreationService.create_from_source(template_definition, values)
		"duplicate":
			var source_id := str(values.get("source_id", ""))
			var source_definition := _library_controller.call("find_definition", source_id) as ObjectDefinition
			result = ObjectBuilderObjectCreationService.create_from_source(source_definition, values)
		"import":
			result = ObjectBuilderObjectCreationService.import_scene_draft(
				str(values.get("import_path", "")),
				values
			)
		_:
			_set_status("Неизвестный способ создания объекта.", true)
			return

	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "Не удалось создать объект.")), true)
		return
	var definition := result.get("definition") as ObjectDefinition
	if definition == null:
		_set_status("Конструктор не вернул определение объекта.", true)
		return

	_can_save_as_template = true
	_load_definition(definition, true)
	var status_by_mode := {
		"new": "Создан обычный объект.",
		"template": "Создана независимая копия шаблона. Исходный шаблон не изменён.",
		"duplicate": "Создана независимая копия существующего объекта. Исходник не изменён.",
		"import": "Сцена импортирована в отдельную копию. Исходный файл не изменён."
	}
	var status_message := str(status_by_mode.get(mode, "Объект создан."))
	if mode == "import":
		var import_report: Dictionary = result.get("import_report", {})
		var visual_count := int(import_report.get("visual_part_count", 0))
		var advanced_count := int(import_report.get("advanced_node_count", 0))
		status_message += "\nРаспознано визуальных частей: %d. Дополнительных узлов сохранено для расширенного режима: %d." % [visual_count, advanced_count]
		var advanced_paths: Variant = import_report.get("advanced_node_paths", PackedStringArray())
		if advanced_paths is Array and not advanced_paths.is_empty():
			var examples := PackedStringArray()
			for index in range(mini(3, advanced_paths.size())):
				examples.append(str(advanced_paths[index]))
			status_message += "\nПримеры: " + "; ".join(examples)
	status_message += " Нажми «Сохранить объект», чтобы добавить определение в библиотеку."
	_set_status(status_message, false)


func _build_visual_editor(parent: VBoxContainer) -> void:
	_visual_editor_view = ObjectBuilderVisualEditorViewScript.new()
	_visual_editor_view.name = "VisualEditorView"
	_visual_editor_view.connect("texture_path_submitted", Callable(self, "_on_texture_path_submitted"))
	_visual_editor_view.connect("texture_browse_requested", Callable(self, "_on_browse_texture_pressed"))
	_visual_editor_view.connect("texture_file_selected", Callable(self, "_on_texture_file_selected"))
	_visual_editor_view.connect("sprite_grid_value_changed", Callable(self, "_on_sprite_grid_value_changed"))
	_visual_editor_view.connect("sprite_offset_changed", Callable(self, "_on_sprite_offset_changed"))
	_visual_editor_view.connect("sprite_toggle_changed", Callable(self, "_on_sprite_toggle_changed"))
	_visual_editor_view.connect("frames_path_submitted", Callable(self, "_on_sprite_frames_path_submitted"))
	_visual_editor_view.connect("frames_browse_requested", Callable(self, "_on_browse_sprite_frames_pressed"))
	_visual_editor_view.connect("frames_file_selected", Callable(self, "_on_sprite_frames_file_selected"))
	_visual_editor_view.connect("animation_selected", Callable(self, "_on_animated_animation_selected"))
	_visual_editor_view.connect("animation_frame_changed", Callable(self, "_on_animated_frame_changed"))
	_visual_editor_view.connect("animation_speed_changed", Callable(self, "_on_animated_speed_changed"))
	_visual_editor_view.connect("transform_value_changed", Callable(self, "_on_visual_transform_value_changed"))
	_visual_editor_view.connect("reset_transform_requested", Callable(self, "_on_reset_visual_transform_requested"))
	_visual_editor_view.connect("node_visibility_changed", Callable(self, "_on_visual_node_visibility_changed"))
	_visual_editor_view.call("build")
	parent.add_child(_visual_editor_view)

	_sprite_frames_editor_dialog = ObjectBuilderSpriteFramesEditorDialogScript.new()
	_sprite_frames_editor_dialog.name = "SpriteFramesEditorDialog"
	_sprite_frames_editor_dialog.connect("frames_accepted", Callable(self, "_on_sprite_frames_editor_accepted"))
	add_child(_sprite_frames_editor_dialog)

func _load_local_state() -> void:
	var settings := EditorInterface.get_editor_settings()
	var stored_favorites: Variant = settings.get_project_metadata(METADATA_SECTION, "favorites", PackedStringArray())
	var stored_recent: Variant = settings.get_project_metadata(METADATA_SECTION, "recent", PackedStringArray())
	var stored_collections: Variant = settings.get_project_metadata(METADATA_SECTION, "custom_collections", {})
	var stored_layout: Variant = settings.get_project_metadata(METADATA_SECTION, "workspace_layout", {})
	var stored_locked_parts: Variant = settings.get_project_metadata(METADATA_SECTION, "locked_visual_parts", PackedStringArray())
	var stored_vertical_guides: Variant = settings.get_project_metadata(METADATA_SECTION, "canvas_vertical_guides", [])
	var stored_horizontal_guides: Variant = settings.get_project_metadata(METADATA_SECTION, "canvas_horizontal_guides", [])
	_locked_visual_part_keys = PackedStringArray()
	if stored_locked_parts is PackedStringArray:
		_locked_visual_part_keys = stored_locked_parts.duplicate()
	elif stored_locked_parts is Array:
		for stored_key in stored_locked_parts:
			var lock_key := str(stored_key).strip_edges()
			if not lock_key.is_empty() and not _locked_visual_part_keys.has(lock_key):
				_locked_visual_part_keys.append(lock_key)
	_canvas_vertical_guides.clear()
	_canvas_horizontal_guides.clear()
	if stored_vertical_guides is Array:
		for guide_value in stored_vertical_guides:
			_canvas_vertical_guides.append(float(guide_value))
	if stored_horizontal_guides is Array:
		for guide_value in stored_horizontal_guides:
			_canvas_horizontal_guides.append(float(guide_value))
	_workspace_layout_state = stored_layout.duplicate(true) if stored_layout is Dictionary else {}
	_library_controller.call("set_local_state", stored_favorites, stored_recent, stored_collections)
func _save_local_state() -> void:
	var settings := EditorInterface.get_editor_settings()
	settings.set_project_metadata(METADATA_SECTION, "favorites", _library_controller.call("get_favorites"))
	settings.set_project_metadata(METADATA_SECTION, "recent", _library_controller.call("get_recent_ids"))
	settings.set_project_metadata(METADATA_SECTION, "custom_collections", _library_controller.call("get_collections_state"))
	settings.set_project_metadata(METADATA_SECTION, "locked_visual_parts", _locked_visual_part_keys)
	settings.set_project_metadata(METADATA_SECTION, "canvas_vertical_guides", _canvas_vertical_guides)
	settings.set_project_metadata(METADATA_SECTION, "canvas_horizontal_guides", _canvas_horizontal_guides)
	if _workspace_view != null:
		settings.set_project_metadata(METADATA_SECTION, "workspace_layout", _workspace_view.call("get_layout_state"))
func _refresh_library() -> void:
	_library_controller.call("load_library")
	_rebuild_category_filter()
	_rebuild_tag_filter()
	_rebuild_collection_filter()
	_refresh_library_list()
	_refresh_favorite_button()
	_refresh_scene_tree()
	var definition_count := int(_library_controller.call("get_definition_count"))
	var template_count := int(_library_controller.call("get_template_count"))
	if definition_count == 0 and template_count > 0:
		_library_view.call("set_selected_mode", "templates")
		_refresh_library_list()
		_set_status("Пока нет сохранённых объектов. Выбери стартовый шаблон — он откроется как отдельная копия.", false)
	elif definition_count == 0:
		_set_status("Библиотека пока пуста. Создай первый объект.", false)

func _on_refresh_pressed() -> void:
	_refresh_library()
	EditorInterface.get_resource_filesystem().scan()


func _rebuild_category_filter() -> void:
	var previous_category := str(_library_view.call("get_selected_category"))
	var options: Array[Dictionary] = _library_controller.call("get_category_options", previous_category)
	_library_view.call("set_category_options", options, previous_category)

func _rebuild_tag_filter() -> void:
	var previous_tag := str(_library_view.call("get_selected_tag"))
	var options: Array[Dictionary] = _library_controller.call("get_tag_options", previous_tag)
	_library_view.call("set_tag_options", options, previous_tag)


func _rebuild_collection_filter(selected_mode: String = "") -> void:
	var options: Array[Dictionary] = _library_controller.call("get_collection_options")
	_library_view.call("set_collection_options", options, selected_mode)

func _refresh_library_list() -> void:
	if _library_view == null or _library_controller == null:
		return
	var entries: Array[Dictionary] = _library_controller.call(
		"build_visible_entries",
		str(_library_view.call("get_search_query")).strip_edges().to_lower(),
		str(_library_view.call("get_selected_category")),
		str(_library_view.call("get_selected_tag")),
		str(_library_view.call("get_selected_mode"))
	)
	_library_view.call("set_entries", entries, "Объекты не найдены")
	var selected_index := int(_library_view.call("get_selected_index"))
	if selected_index >= 0:
		_refresh_library_details(_library_controller.call("get_visible_definition", selected_index) as ObjectDefinition)
	elif _working_definition != null:
		_refresh_library_details(_working_definition)
	else:
		_refresh_library_details(null)


func _refresh_library_details(definition: ObjectDefinition) -> void:
	if _library_details_view == null or _library_controller == null:
		return
	var details: Dictionary = _library_controller.call("build_detail_data", definition)
	_library_details_view.call("set_details", details)
	if _properties_inspector != null and _properties_inspector.call("is_showing_capability_settings"):
		return
	if _properties_inspector != null:
		_properties_inspector.call("show_object_details")


func _on_search_changed(_value: String) -> void:
	_refresh_library_list()


func _on_filter_changed(_index: int) -> void:
	_refresh_library_list()


func _on_library_item_selected(index: int) -> void:
	_on_capability_settings_panel_close()
	var definition := _library_controller.call("get_visible_definition", index) as ObjectDefinition
	if definition == null:
		return
	_refresh_library_details(definition)
	if definition.is_template:
		var template_copy := _create_definition_from_template(definition)
		if template_copy != null:
			_can_save_as_template = true
			_load_definition(template_copy, true)
			_set_status("Создана копия шаблона. Измени её и сохрани как отдельный объект.", false)
		return
	_can_save_as_template = false
	_record_recent(definition.object_id)
	_load_definition(definition)

func _on_library_entry_action_requested(action: String, index: int) -> void:
	_on_capability_settings_panel_close()
	_pending_collection_id = ""
	_pending_library_definition = null
	var definition := _library_controller.call("get_visible_definition", index) as ObjectDefinition
	if definition == null:
		return
	_refresh_library_details(definition)
	if action == "toggle_favorite":
		_library_controller.call("toggle_favorite", definition.object_id)
		_save_local_state()
		_refresh_library_list()
		_refresh_favorite_button()
		return
	if action.begins_with("add_to_collection:"):
		var collection_id := action.trim_prefix("add_to_collection:")
		if _library_controller.call("add_to_collection", collection_id, definition.object_id):
			_save_local_state()
			_refresh_library_list()
			_set_status("«%s» добавлен в коллекцию." % definition.display_name, false)
		else:
			_set_status("Объект уже находится в этой коллекции или коллекция не найдена.", false)
		return
	if action == "remove_from_collection":
		var selected_mode := str(_library_view.call("get_selected_mode"))
		if selected_mode.begins_with("collection:"):
			var current_collection_id := selected_mode.trim_prefix("collection:")
			if _library_controller.call("remove_from_collection", current_collection_id, definition.object_id):
				_save_local_state()
				_refresh_library_list()
				_set_status("«%s» удалён из коллекции." % definition.display_name, false)
		return
	if action == "open":
		_pending_library_definition = null
		_on_library_item_selected(index)
		return

	if _has_unsaved_changes_for_library_entry(definition):
		_pending_library_definition = null
		_set_status("Сначала сохрани изменения этого объекта. Действие библиотеки использует сохранённую версию.", true)
		return

	match action:
		"duplicate":
			_pending_library_definition = null
			_perform_library_copy(definition, false)
		"create_template":
			if definition.is_template:
				_pending_library_definition = null
				_set_status("Выбранная запись уже является шаблоном.", true)
				return
			_pending_library_definition = null
			_perform_library_copy(definition, true)
		"rename":
			_pending_library_definition = definition
			_library_action_dialogs.call("popup_rename", definition.display_name)
		"delete":
			if _working_definition != null and _working_definition.object_id == definition.object_id:
				_pending_library_definition = null
				_set_status("Сначала открой другой объект. Нельзя удалять запись, которая сейчас открыта в редакторе.", true)
				return
			_pending_library_definition = definition
			_library_action_dialogs.call("popup_delete", definition.display_name)
		"export":
			_pending_library_definition = definition
			_library_action_dialogs.call("popup_export", definition.object_id)


func _has_unsaved_changes_for_library_entry(definition: ObjectDefinition) -> bool:
	return (
		definition != null
		and _working_definition != null
		and _working_definition.object_id == definition.object_id
		and _editor_session != null
		and bool(_editor_session.call("is_dirty"))
	)


func _perform_library_copy(source: ObjectDefinition, as_template: bool) -> void:
	var result: Dictionary = (
		ObjectBuilderLibraryActionsService.create_template(source)
		if as_template
		else ObjectBuilderLibraryActionsService.duplicate_definition(source)
	)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "Не удалось выполнить операцию с библиотекой.")), true)
		return
	var created := result.get("definition") as ObjectDefinition
	if created == null:
		_set_status("Операция завершилась без результата.", true)
		return
	_refresh_library()
	_can_save_as_template = not created.is_template
	_load_definition(created)
	if not created.is_template:
		_library_controller.call("record_recent", created.object_id)
		_save_local_state()
		_refresh_library_list()
		_refresh_library_details(created)
	EditorInterface.get_resource_filesystem().scan()
	_set_status(
		"Создан шаблон «%s»." % created.display_name
		if as_template
		else "Создана независимая копия «%s»." % created.display_name,
		false
	)


func _on_collection_management_requested(action: String) -> void:
	var selected_mode := str(_library_view.call("get_selected_mode"))
	if not selected_mode.begins_with("collection:"):
		return
	var collection_id := selected_mode.trim_prefix("collection:")
	var display_name := collection_id
	for option in _library_controller.call("get_collection_options"):
		if str(option.get("id", "")) == collection_id:
			display_name = str(option.get("label", collection_id))
			break
	_pending_collection_id = collection_id
	_pending_library_definition = null
	if action == "rename":
		_library_action_dialogs.call("popup_rename_collection", display_name)
	elif action == "delete":
		_library_action_dialogs.call("popup_delete_collection", display_name)

func _on_collection_create_requested() -> void:
	_library_action_dialogs.call("popup_create_collection")


func _on_collection_create_confirmed(display_name: String) -> void:
	var collection_id := str(_library_controller.call("create_collection", display_name))
	if collection_id.is_empty():
		_set_status("Укажи название коллекции.", true)
		return
	_save_local_state()
	_rebuild_collection_filter("collection:" + collection_id)
	_refresh_library_list()
	_set_status("Коллекция «%s» создана. Выбери объект и добавь его через меню «Действия…»." % display_name.strip_edges(), false)


func _on_library_rename_confirmed(new_name: String) -> void:
	if not _pending_collection_id.is_empty():
		var collection_id := _pending_collection_id
		_pending_collection_id = ""
		if not _library_controller.call("rename_collection", collection_id, new_name):
			_set_status("Не удалось переименовать коллекцию. Проверь название.", true)
			return
		_save_local_state()
		_rebuild_collection_filter("collection:" + collection_id)
		_refresh_library_list()
		_set_status("Коллекция переименована.", false)
		return
	if _pending_library_definition == null:
		return
	if new_name.strip_edges().is_empty():
		_set_status("Название не может быть пустым.", true)
		return
	var definition := _pending_library_definition
	_pending_library_definition = null
	var result: Dictionary = ObjectBuilderLibraryActionsService.rename_definition(definition, new_name)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "Не удалось переименовать запись.")), true)
		return
	_refresh_library()
	if _working_definition != null and _working_definition.object_id == definition.object_id:
		_load_definition(definition)
	else:
		_refresh_library_details(definition)
	EditorInterface.get_resource_filesystem().scan()
	_set_status(str(result.get("message", "Запись переименована.")), false)


func _on_library_delete_confirmed() -> void:
	if not _pending_collection_id.is_empty():
		var collection_id := _pending_collection_id
		_pending_collection_id = ""
		if not _library_controller.call("delete_collection", collection_id):
			_set_status("Коллекция уже удалена или не найдена.", true)
			return
		_save_local_state()
		_rebuild_collection_filter("all")
		_refresh_library_list()
		_set_status("Коллекция удалена. Объекты остались в библиотеке.", false)
		return
	if _pending_library_definition == null:
		return
	var definition := _pending_library_definition
	_pending_library_definition = null
	var result: Dictionary = ObjectBuilderLibraryActionsService.delete_definition(definition)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "Не удалось удалить запись.")), true)
		return
	_library_controller.call("remove_local_entry", definition.object_id)
	_save_local_state()
	_refresh_library()
	EditorInterface.get_resource_filesystem().scan()
	_set_status(str(result.get("message", "Запись удалена.")), false)


func _on_library_export_path_selected(path: String) -> void:
	if _pending_library_definition == null:
		return
	var definition := _pending_library_definition
	_pending_library_definition = null
	var target_path := path if path.get_extension().to_lower() == "tres" else path + ".tres"
	var save_error := ObjectBuilderLibraryActionsService.export_definition(definition, target_path)
	if save_error != OK:
		_set_status("Не удалось экспортировать определение. Код ошибки: %d" % save_error, true)
		return
	_set_status(
		"Определение экспортировано: %s. Сцена и внешние ресурсы остаются ссылками на исходный проект." % target_path,
		false
	)


func _record_recent(object_id: String) -> void:
	_library_controller.call("record_recent", object_id)
	_save_local_state()
	if _library_view != null and str(_library_view.call("get_selected_mode")) == "recent":
		_refresh_library_list()

func _on_toggle_favorite_pressed() -> void:
	if _working_definition == null or _working_definition.object_id.is_empty():
		return
	_library_controller.call("toggle_favorite", _working_definition.object_id)
	_save_local_state()
	_refresh_favorite_button()
	_refresh_library_list()

func _refresh_favorite_button() -> void:
	if _favorite_button == null:
		return
	var can_toggle := _working_definition != null and not _working_definition.object_id.is_empty()
	_favorite_button.disabled = not can_toggle
	if can_toggle and bool(_library_controller.call("is_favorite", _working_definition.object_id)):
		_favorite_button.text = "★ В избранном"
	else:
		_favorite_button.text = "☆ В избранное"

func _prepare_creation_wizard(mode: String = "new") -> void:
	_library_controller.call("load_library")
	var template_options: Array[Dictionary] = _library_controller.call("get_creation_source_options", true)
	var object_options: Array[Dictionary] = _library_controller.call("get_creation_source_options", false)
	_dialog_view.call("set_creation_sources", template_options, object_options)
	_dialog_view.call("set_creation_category_options", _library_controller.call("get_category_options"), "Other")
	_dialog_view.call("reset_creation_wizard", mode)
	_update_new_object_type_hint()


func _on_new_object_pressed() -> void:
	_prepare_creation_wizard("new")
	_dialog_view.call("popup_creation_dialog")


func _on_create_from_template_pressed() -> void:
	_prepare_creation_wizard("template")
	if int(_library_controller.call("get_template_count")) == 0:
		_set_status("Шаблоны не найдены. Создай или импортируй объект, а затем сохрани его как шаблон.", true)
		return
	_dialog_view.call("popup_creation_dialog")

func _create_definition_from_template(template_definition: ObjectDefinition) -> ObjectDefinition:
	if template_definition == null:
		return null
	var values := {
		"display_name": template_definition.display_name + " — копия",
		"category": template_definition.category,
		"description": template_definition.description,
		"tags": template_definition.tags
	}
	var result: Dictionary = ObjectBuilderObjectCreationService.create_from_source(template_definition, values)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "Не удалось создать копию шаблона.")), true)
		return null
	return result.get("definition") as ObjectDefinition

func _cleanup_abandoned_new_draft(next_definition: ObjectDefinition) -> void:
	if _editor_session == null or not bool(_editor_session.call("is_new")):
		return
	var abandoned := _editor_session.call("get_working_definition") as ObjectDefinition
	if abandoned == null or abandoned.scene_path.is_empty():
		return
	if next_definition != null and next_definition.object_id == abandoned.object_id:
		return
	var managed_prefix := ObjectLibraryService.SCENES_PATH + "/"
	if not abandoned.scene_path.begins_with(managed_prefix):
		return
	if FileAccess.file_exists(abandoned.scene_path):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(abandoned.scene_path))
		if remove_error != OK:
			push_warning("Object Builder: не удалось убрать сцену несохранённого черновика: " + abandoned.scene_path)

func _load_definition(definition: ObjectDefinition, is_new: bool = false) -> void:
	var previous_object_id := _working_definition.object_id if _working_definition != null else ""
	if previous_object_id != definition.object_id:
		_on_capability_settings_panel_close()
		_capability_catalog_controller.call("clear_selection")
		_capability_catalog_controller.call("set_active_preset", "")
	_cleanup_abandoned_new_draft(definition)
	if is_new and _editor_view != null:
		_editor_view.current_tab = 0
	_is_loading_editor_form = true
	if is_new:
		_editor_session.call("begin_new", definition)
	else:
		_editor_session.call("begin_edit", definition)
	_working_definition = _editor_session.call("get_working_definition") as ObjectDefinition
	_ensure_component_schemas()
	_name_edit.text = _working_definition.display_name
	_object_type_label.text = str(_library_controller.call("get_object_type_display_name", _working_definition.object_type))
	_id_edit.text = _working_definition.object_id
	_category_edit.text = _working_definition.category
	_tags_edit.text = str(_library_controller.call("join_tags", _working_definition.tags))
	_description_edit.text = _working_definition.description
	_template_check.button_pressed = _working_definition.is_template
	_template_check.disabled = not _can_save_as_template
	_select_root_type(_working_definition.root_type)
	if _open_scene_button != null:
		_open_scene_button.disabled = _working_definition.scene_path.is_empty() or not FileAccess.file_exists(_working_definition.scene_path)
	_rebuild_property_list()
	_rebuild_component_list()
	_rebuild_capability_list()
	_refresh_favorite_button()
	_refresh_scene_tree()
	_is_loading_editor_form = false
	_refresh_workspace_document_info()
	_refresh_library_details(_working_definition)
	if _workspace_view != null:
		_workspace_view.call("set_selection_info", "", "")
func _select_root_type(type_name: String) -> void:
	var clean_type := type_name.strip_edges()
	for index in range(_root_type.item_count):
		if _root_type.get_item_text(index) == clean_type:
			_root_type.select(index)
			return
	if clean_type.is_empty():
		_root_type.select(0)
		return
	_root_type.add_item(clean_type)
	_root_type.select(_root_type.item_count - 1)


func _rebuild_property_list() -> void:
	var properties: Array[ObjectPropertyDefinition] = []
	if _working_definition != null:
		properties = _working_definition.custom_properties
	_property_list.call("set_properties", properties)


func _on_property_default_numeric_changed(value: float, property_definition: ObjectPropertyDefinition) -> void:
	if property_definition == null:
		return
	var next_value: Variant = int(round(value)) if property_definition.value_type == "Integer" else value
	if property_definition.default_value == next_value:
		return
	property_definition.default_value = next_value
	_mark_editor_session_changed()
	_set_status("Параметр изменён. Нажми «Сохранить в библиотеку», чтобы записать определение.", false)

func _on_property_default_boolean_changed(value: bool, property_definition: ObjectPropertyDefinition) -> void:
	if property_definition == null or property_definition.default_value == value:
		return
	property_definition.default_value = value
	_mark_editor_session_changed()
	_set_status("Параметр изменён. Нажми «Сохранить в библиотеку», чтобы записать определение.", false)

func _on_property_default_text_submitted(value: String, property_definition: ObjectPropertyDefinition) -> void:
	_commit_property_default_text(value, property_definition)


func _on_property_default_text_focus_exited(text_edit: LineEdit, property_definition: ObjectPropertyDefinition) -> void:
	if text_edit == null:
		return
	_commit_property_default_text(text_edit.text, property_definition)


func _commit_property_default_text(value: String, property_definition: ObjectPropertyDefinition) -> void:
	if property_definition == null:
		return
	var next_value: Variant = value
	if property_definition.value_type == "Vector2":
		var parts := value.split(",")
		if parts.size() != 2 or not parts[0].strip_edges().is_valid_float() or not parts[1].strip_edges().is_valid_float():
			_set_status("Vector2 нужно вводить в формате: X, Y.", true)
			return
		next_value = Vector2(
			float(parts[0].strip_edges()),
			float(parts[1].strip_edges())
		)
	if property_definition.default_value == next_value:
		return
	property_definition.default_value = next_value
	_mark_editor_session_changed()
	_set_status("Параметр изменён. Нажми «Сохранить в библиотеку», чтобы записать определение.", false)

func _on_add_property_pressed() -> void:
	if _working_definition == null:
		_on_new_object_pressed()
		return
	_editing_property = null
	_dialog_view.call("configure_property_form", {
		"title": "Новое пользовательское свойство",
		"display_name": "",
		"value_type": "Float",
		"default_value": "0",
		"group_name": "Основное",
		"description": "",
		"advanced": false,
		"has_range": false,
		"minimum": "0",
		"maximum": "100"
	})
	_dialog_view.call("popup_property_dialog")

func _on_edit_property_pressed(property_definition: ObjectPropertyDefinition) -> void:
	if _working_definition == null or property_definition == null:
		return
	_editing_property = property_definition
	_dialog_view.call("configure_property_form", {
		"title": "Редактировать пользовательское свойство",
		"display_name": property_definition.display_name,
		"value_type": property_definition.value_type,
		"default_value": ObjectPropertyValueCodec.format_default_value(
			property_definition.default_value,
			property_definition.value_type
		),
		"group_name": property_definition.group_name,
		"description": property_definition.description,
		"advanced": property_definition.advanced,
		"has_range": property_definition.has_range,
		"minimum": str(property_definition.minimum),
		"maximum": str(property_definition.maximum)
	})
	_dialog_view.call("popup_property_dialog")

func _on_property_dialog_confirmed() -> void:
	if _working_definition == null:
		return
	var form_values: Dictionary = _dialog_view.call("get_property_form_values")
	var display_name := str(form_values.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		_set_status("У свойства должно быть название.", true)
		return

	var value_type := str(form_values.get("value_type", "String"))
	var default_value := ObjectPropertyValueCodec.parse_default_value(
		str(form_values.get("default_value", "")),
		value_type
	)
	var supports_range := value_type in ["Integer", "Float"]
	var has_range := supports_range and bool(form_values.get("has_range", false))
	var minimum_value := str(form_values.get("minimum", "0")).to_float()
	var maximum_value := str(form_values.get("maximum", "100")).to_float()

	if has_range:
		if minimum_value > maximum_value:
			_set_status("Минимум диапазона не может быть больше максимума.", true)
			return
		var numeric_default := float(default_value)
		if numeric_default < minimum_value or numeric_default > maximum_value:
			_set_status("Значение по умолчанию должно входить в заданный диапазон.", true)
			return

	var property_definition := _editing_property
	if property_definition == null:
		property_definition = ObjectPropertyDefinition.new()
		property_definition.property_id = ObjectPropertyValueCodec.make_property_id(display_name)
		var duplicate_index := 2
		var base_id := property_definition.property_id
		while _has_property_id(property_definition.property_id):
			property_definition.property_id = base_id + "_" + str(duplicate_index)
			duplicate_index += 1
		_working_definition.custom_properties.append(property_definition)

	property_definition.display_name = display_name
	property_definition.value_type = value_type
	property_definition.default_value = default_value
	property_definition.group_name = str(form_values.get("group_name", "")).strip_edges()
	if property_definition.group_name.is_empty():
		property_definition.group_name = "Основное"
	property_definition.description = str(form_values.get("description", ""))
	property_definition.advanced = bool(form_values.get("advanced", false))
	property_definition.has_range = has_range
	property_definition.minimum = minimum_value
	property_definition.maximum = maximum_value

	_editing_property = null
	_mark_editor_session_changed()
	_rebuild_property_list()
	_set_status("Свойство обновлено. Нажми «Сохранить в библиотеку».", false)

func _has_property_id(property_id: String) -> bool:
	for property_definition in _working_definition.custom_properties:
		if property_definition != null and property_definition.property_id == property_id:
			return true
	return false


func _on_remove_property_pressed(property_definition: ObjectPropertyDefinition) -> void:
	if _working_definition == null or property_definition == null:
		return
	if not _working_definition.custom_properties.has(property_definition):
		return
	_working_definition.custom_properties.erase(property_definition)
	_mark_editor_session_changed()
	_rebuild_property_list()

func _on_preview_pressed() -> void:
	if _working_definition == null:
		_set_status("Сначала создай объект или выбери его в библиотеке.", true)
		return
	if _preview_view == null or not is_instance_valid(_preview_view):
		_set_status("Окно предпросмотра ещё не готово.", true)
		return

	var should_open_window := not _preview_view.visible
	var result: Dictionary = ObjectBuilderPreviewService.create_preview_instance(
		_working_definition,
		_get_open_object_scene_root()
	)
	if not bool(result.get("ok", false)):
		_set_status("Не удалось собрать предпросмотр: " + str(result.get("message", "неизвестная ошибка")), true)
		return

	var preview_instance := result.get("instance") as Node
	if preview_instance == null or not bool(_preview_view.call("show_preview", preview_instance, _working_definition.display_name)):
		if preview_instance != null:
			preview_instance.free()
		_set_status("Не удалось открыть предпросмотр объекта.", true)
		return

	if should_open_window:
		ObjectBuilderDialogService.popup_window_safely(_preview_view, Vector2i(820, 620), 0.86)
	_set_status("Предпросмотр собран из актуального черновика. Тестовое состояние предыдущей копии сброшено.", false)


func _on_save_pressed() -> void:
	if _working_definition == null:
		_on_new_object_pressed()
		return

	var next_name := _name_edit.text.strip_edges()
	var next_category := _category_edit.text.strip_edges()
	var next_description := _description_edit.text
	var next_root_type := _root_type.get_item_text(_root_type.selected)
	var next_is_template := _template_check.button_pressed
	var next_tags := PackedStringArray()
	for raw_tag in _tags_edit.text.split(","):
		var tag := raw_tag.strip_edges()
		if not tag.is_empty():
			next_tags.append(tag)
	var form_changed := (
		_working_definition.display_name != next_name
		or _working_definition.category != next_category
		or _working_definition.description != next_description
		or _working_definition.root_type != next_root_type
		or _working_definition.is_template != next_is_template
		or _working_definition.tags != next_tags
	)
	_working_definition.display_name = next_name
	_working_definition.category = next_category
	_working_definition.description = next_description
	_working_definition.root_type = next_root_type
	_working_definition.is_template = next_is_template
	_working_definition.tags = next_tags
	if form_changed:
		_mark_editor_session_changed()


	var open_scene_root := _get_open_object_scene_root()
	var scene_properties_synced := false
	if open_scene_root != null:
		_sync_scene_property_data(open_scene_root)
		var scene_save_error := EditorInterface.save_scene()
		if scene_save_error != OK:
			_set_status("Не удалось сохранить сцену объекта. Код ошибки: %d" % scene_save_error, true)
			return
		scene_properties_synced = true
		var refreshed_scene := ResourceLoader.load(
			_working_definition.scene_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		) as PackedScene
		if refreshed_scene != null:
			_working_definition.scene = refreshed_scene

	if _working_definition.scene_path.is_empty() or not FileAccess.file_exists(_working_definition.scene_path):
		if not _create_scene_for_definition():
			return

	var validation_errors := ObjectLibraryService.validate_definition(_working_definition)
	if not validation_errors.is_empty():
		_set_status("Нельзя сохранить: " + "; ".join(validation_errors), true)
		return

	var save_error: Error
	if _working_definition.is_template:
		save_error = ObjectLibraryService.save_template(_working_definition)
	else:
		save_error = ObjectLibraryService.save_definition(_working_definition)
	if save_error != OK:
		_set_status("Не удалось сохранить объект. Код ошибки: %d" % save_error, true)
		return

	_editor_session.call("accept_saved_state", _working_definition)
	_id_edit.text = _working_definition.object_id
	if _open_scene_button != null:
		_open_scene_button.disabled = false
	_can_save_as_template = false
	_template_check.disabled = true
	if _working_definition.is_template:
		_set_status("Шаблон сохранён. Его можно выбрать кнопкой «Из шаблона».", false)
	else:
		_set_status("Объект сохранён в библиотеку: %s" % _working_definition.display_name, false)
	if scene_properties_synced:
		_set_status("Объект и его сцена сохранены.", false)
	if not _working_definition.is_template and str(_library_view.call("get_selected_mode")) == "templates":
		_library_view.call("set_selected_mode", "all")
	_refresh_library()
	_load_definition(_working_definition)

func _create_scene_for_definition() -> bool:
	var result: Dictionary = ObjectBuilderSceneDraftService.create_scene(_working_definition)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "Не удалось создать сцену объекта.")), true)
		return false
	_mark_editor_session_changed()
	if _open_scene_button != null:
		_open_scene_button.disabled = false
	EditorInterface.get_resource_filesystem().scan()
	return true

func _sync_scene_property_data(scene_root: Node) -> void:
	if scene_root == null or _working_definition == null:
		return
	var property_data := scene_root.get_node_or_null("ObjectProperties") as ObjectPropertyData
	if property_data == null:
		property_data = ObjectPropertyData.new()
		property_data.name = "ObjectProperties"
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Object Builder: добавить узел параметров объекта", 0, scene_root)
		undo_redo.add_do_method(scene_root, "add_child", property_data)
		undo_redo.add_do_method(property_data, "set_owner", scene_root)
		undo_redo.add_undo_method(scene_root, "remove_child", property_data)
		undo_redo.add_do_reference(property_data)
		undo_redo.commit_action()

	var previous_definitions := property_data.property_definitions.duplicate(true)
	var previous_values := property_data.get_values()
	var next_definitions := _working_definition.custom_properties.duplicate(true)
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: обновить параметры объекта", 0, scene_root)
	undo_redo.add_do_method(
		property_data,
		"configure",
		next_definitions,
		previous_values,
		true
	)
	undo_redo.add_undo_method(
		property_data,
		"configure",
		previous_definitions,
		previous_values,
		false
	)
	undo_redo.commit_action()
	_refresh_scene_tree()


func _on_open_scene_pressed() -> void:
	if _working_definition == null or _working_definition.scene_path.is_empty():
		return
	if not FileAccess.file_exists(_working_definition.scene_path):
		_set_status("Файл сцены не найден. Создай его заново или восстанови из резервной копии.", true)
		return
	EditorInterface.open_scene_from_path(_working_definition.scene_path)
	_record_recent(_working_definition.object_id)
	await get_tree().process_frame
	_refresh_scene_tree()


func _get_open_object_scene_root() -> Node:
	if _working_definition == null or _working_definition.scene_path.is_empty():
		return null
	var edited_root := EditorInterface.get_edited_scene_root()
	if edited_root == null:
		return null
	if edited_root.scene_file_path != _working_definition.scene_path:
		return null
	return edited_root


func _refresh_scene_tree() -> void:
	if _scene_tree_view == null:
		return
	_update_scene_tree_connection()
	var scene_root := _get_open_object_scene_root()
	_scene_tree_view.call("set_scene_root", scene_root)
	if scene_root == null:
		_refresh_visual_editor(null)
		_refresh_canvas()
		_refresh_visual_parts()
		return

	var selected_node := _get_editor_selected_scene_node(scene_root)
	if selected_node != null:
		_sync_scene_tree_selection(selected_node)
	else:
		_refresh_visual_editor(null)
	_refresh_canvas()
	_refresh_visual_parts()

func _on_scene_tree_item_selected(_path: NodePath = NodePath()) -> void:
	var scene_root := _get_open_object_scene_root()
	var node := _get_selected_scene_tree_node()
	if node == null or scene_root == null:
		return
	if _syncing_tree_selection:
		_refresh_visual_editor(node)
		return
	var editor_selection := EditorInterface.get_selection()
	_syncing_tree_selection = true
	editor_selection.clear()
	editor_selection.add_node(node)
	_syncing_tree_selection = false
	EditorInterface.edit_node(node)
	_refresh_visual_editor(node)
	if _canvas_view != null:
		_canvas_view.call("set_selected_path", scene_root.get_path_to(node))
	if _visual_parts_view != null:
		_visual_parts_view.call("set_selected_path", scene_root.get_path_to(node))


func _refresh_visual_editor(node: Node) -> void:
	if _sprite_quick_settings_view != null:
		var scene_root := _get_open_object_scene_root()
		var selected_path := NodePath("")
		if scene_root != null and node != null and (node == scene_root or scene_root.is_ancestor_of(node)):
			selected_path = scene_root.get_path_to(node)
		_sprite_quick_settings_view.call("set_selected_node", node, selected_path)
	if _visual_editor_view == null:
		return
	if node is Sprite2D:
		var sprite := node as Sprite2D
		_visual_editor_view.call("show_sprite", sprite)
		return
	if node is AnimatedSprite2D:
		var animated_sprite := node as AnimatedSprite2D
		_visual_editor_view.call("show_animated_sprite", animated_sprite)
		return
	if node is Node2D:
		_visual_editor_view.call("show_node_2d", node)
		return
	_visual_editor_view.call("hide_editor")


func _refresh_canvas() -> void:
	if _canvas_view == null:
		return
	if _working_definition == null:
		_canvas_view.call("clear_canvas", "Создай или выбери объект, чтобы открыть холст.")
		_refresh_visual_parts()
		return
	var scene_root := _get_open_object_scene_root()
	var preview_result: Dictionary = ObjectBuilderPreviewService.create_preview_instance(
		_working_definition,
		scene_root
	)
	if not bool(preview_result.get("ok", false)):
		_canvas_view.call("clear_canvas", str(preview_result.get("message", "Не удалось собрать холст.")))
		_refresh_visual_parts()
		return
	var can_open_scene := (
		not _working_definition.scene_path.is_empty()
		and FileAccess.file_exists(_working_definition.scene_path)
	)
	var selected_path := NodePath("")
	if scene_root != null:
		var selected_node := _get_editor_selected_scene_node(scene_root)
		if selected_node != null:
			selected_path = scene_root.get_path_to(selected_node)
	_canvas_view.call("set_guides", _canvas_vertical_guides, _canvas_horizontal_guides)
	_canvas_view.call(
		"set_preview_instance",
		preview_result.get("instance") as Node,
		scene_root != null,
		can_open_scene,
		selected_path
	)
	_refresh_visual_parts()


func _refresh_visual_parts() -> void:
	if _visual_parts_view == null:
		return
	var scene_root := _get_open_object_scene_root()
	var selected_path := NodePath("")
	if scene_root != null:
		var selected_node := _get_editor_selected_scene_node(scene_root)
		if selected_node != null:
			selected_path = scene_root.get_path_to(selected_node)
	_visual_parts_view.call("set_scene_root", scene_root, selected_path)
	var locked_paths: Array[NodePath] = []
	if scene_root != null:
		var part_paths: Array[NodePath] = _visual_parts_view.call("get_part_paths")
		for part_path in part_paths:
			if _locked_visual_part_keys.has(_get_visual_part_lock_key(scene_root, part_path)):
				locked_paths.append(part_path)
	_visual_parts_view.call("set_locked_paths", locked_paths)
	_canvas_view.call("set_locked_paths", locked_paths)


func _on_canvas_part_selected(path: NodePath) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	if path.is_empty():
		EditorInterface.get_selection().clear()
		if _visual_parts_view != null:
			_visual_parts_view.call("set_selected_path", NodePath(""))
		if _workspace_view != null:
			_workspace_view.call("set_selection_info", "", "")
		return
	var node := scene_root if path == NodePath(".") else scene_root.get_node_or_null(path)
	if node == null:
		return
	var editor_selection := EditorInterface.get_selection()
	_syncing_tree_selection = true
	editor_selection.clear()
	if node != scene_root:
		editor_selection.add_node(node)
	_scene_tree_view.call("select_node", scene_root, node)
	_syncing_tree_selection = false
	EditorInterface.edit_node(node)
	_refresh_visual_editor(node)
	if _visual_parts_view != null:
		_visual_parts_view.call("set_selected_path", path)
	if _workspace_view != null:
		_workspace_view.call("set_selection_info", node.name, str(node.get_path()))


func _on_canvas_parts_selected(paths: Array[NodePath]) -> void:
	if _visual_parts_view != null:
		_visual_parts_view.call("set_selected_paths", paths)


func _on_canvas_part_context_action_requested(action: String, path: NodePath) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null or path.is_empty():
		return
	var node := scene_root.get_node_or_null(path)
	if node == null or node == scene_root:
		return
	match action:
		"rename":
			if not bool(_visual_parts_view.call("request_inline_rename", path)):
				_set_status("Не удалось открыть поле переименования этой части.", true)
		"duplicate":
			_on_visual_part_duplicate_requested(path)
		"toggle_visibility":
			var canvas_item := node as CanvasItem
			if canvas_item != null:
				_on_visual_part_visibility_changed(path, not canvas_item.visible)
		"toggle_lock":
			var lock_key := _get_visual_part_lock_key(scene_root, path)
			_on_visual_part_lock_changed(path, not _locked_visual_part_keys.has(lock_key))
		"bring_forward":
			_on_visual_part_draw_order_change_requested(path, 1)
		"send_backward":
			_on_visual_part_draw_order_change_requested(path, -1)
		"delete":
			_on_visual_part_remove_requested(path)

func _on_canvas_transform_committed(
	path: NodePath,
	property_name: String,
	new_value: Variant,
	_old_value: Variant
) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var node := scene_root.get_node_or_null(path) as Node2D
	if node == null:
		return
	_commit_visual_node_property(node, property_name, new_value, "переместить часть на холсте")
	_refresh_canvas()


func _on_canvas_batch_transform_committed(changes: Array[Dictionary]) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null or changes.is_empty():
		return
	var resolved_changes: Array[Dictionary] = []
	for change in changes:
		var path := NodePath(str(change.get("path", "")))
		var node := scene_root.get_node_or_null(path) as Node2D
		var property_name := str(change.get("property", ""))
		if node == null or property_name.is_empty():
			continue
		var old_value: Variant = node.get(property_name)
		var new_value: Variant = change.get("new")
		if old_value == new_value:
			continue
		resolved_changes.append({
			"node": node,
			"property": property_name,
			"old": old_value,
			"new": new_value
		})
	if resolved_changes.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: трансформация нескольких частей на холсте", 0, scene_root)
	for change in resolved_changes:
		var node := change.get("node") as Node2D
		var property_name := str(change.get("property", ""))
		undo_redo.add_do_property(node, property_name, change.get("new"))
		undo_redo.add_undo_property(node, property_name, change.get("old"))
	var selected_paths: Array[NodePath] = _canvas_view.call("get_selected_paths") if _canvas_view != null else []
	undo_redo.commit_action()
	_refresh_canvas()
	_refresh_visual_parts()
	if not selected_paths.is_empty() and _canvas_view != null:
		_canvas_view.call("set_selected_paths", selected_paths)
		if _visual_parts_view != null:
			_visual_parts_view.call("set_selected_paths", selected_paths)
	_set_status("Изменения применены к %d свойствам выбранных частей одним действием Undo/Redo." % resolved_changes.size(), false)


func _on_canvas_pivot_committed(path: NodePath, new_value: Vector2, old_value: Variant) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var node := scene_root.get_node_or_null(path) as Node2D
	if node == null:
		return
	var metadata_key := "object_builder_pivot"
	var current_value: Variant = node.get_meta(metadata_key) if node.has_meta(metadata_key) else null
	if current_value == new_value:
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: изменить точку Pivot", 0, scene_root)
	undo_redo.add_do_method(node, "set_meta", metadata_key, new_value)
	if current_value == null:
		undo_redo.add_undo_method(node, "remove_meta", metadata_key)
	else:
		undo_redo.add_undo_method(node, "set_meta", metadata_key, current_value)
	undo_redo.commit_action()
	_refresh_canvas()
	_set_status("Точка Pivot сохранена в сцене. Масштабирование и вращение будут выполняться вокруг неё.", false)


func _on_canvas_guides_changed(vertical_guides: Array[float], horizontal_guides: Array[float]) -> void:
	_canvas_vertical_guides = vertical_guides.duplicate()
	_canvas_horizontal_guides = horizontal_guides.duplicate()
	_save_local_state()


func _on_canvas_open_scene_requested() -> void:
	_on_open_scene_pressed()

func _get_selected_scene_tree_node() -> Node:
	if _scene_tree_view == null:
		return null
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return null
	return _scene_tree_view.call("get_selected_node", scene_root) as Node

func _on_browse_texture_pressed() -> void:
	if _get_selected_sprite_node() == null:
		_set_status("Выбери Sprite2D в дереве сцены.", true)
		return
	if _visual_editor_view != null:
		_visual_editor_view.call("popup_texture_dialog")

func _on_texture_file_selected(path: String) -> void:
	_apply_texture_path(path)


func _on_texture_path_submitted(path: String) -> void:
	_apply_texture_path(path)


func _apply_texture_path(path: String) -> void:
	var sprite := _get_selected_sprite_node()
	if sprite == null:
		_set_status("Выбранный узел больше не является Sprite2D.", true)
		return
	var clean_path := path.strip_edges()
	if clean_path.is_empty() or not clean_path.begins_with("res://"):
		_set_status("Укажи путь к текстуре внутри проекта, начиная с res://.", true)
		return
	var loaded_resource: Texture2D = ResourceLoader.load(clean_path) as Texture2D
	if loaded_resource == null:
		_set_status("Не удалось загрузить Texture2D: " + clean_path, true)
		return
	_commit_sprite_property(sprite, "texture", loaded_resource, "изменить текстуру")
	_visual_editor_view.call("set_texture_path", clean_path)
	_visual_editor_view.call("set_preview_texture", loaded_resource)
	_set_status("Текстура назначена. Для сохранения сцены нажми Ctrl+S.", false)


func _get_selected_sprite_node() -> Sprite2D:
	var selected_node := _get_selected_scene_tree_node()
	if selected_node is Sprite2D:
		return selected_node as Sprite2D
	return null


func _get_selected_animated_sprite_node() -> AnimatedSprite2D:
	var selected_node := _get_selected_scene_tree_node()
	if selected_node is AnimatedSprite2D:
		return selected_node as AnimatedSprite2D
	return null


func _on_browse_sprite_frames_pressed() -> void:
	if _get_selected_animated_sprite_node() == null:
		_set_status("Выбери AnimatedSprite2D в дереве сцены.", true)
		return
	if _visual_editor_view != null:
		_visual_editor_view.call("popup_sprite_frames_dialog")

func _on_sprite_frames_file_selected(path: String) -> void:
	_apply_sprite_frames_path(path)


func _on_sprite_frames_path_submitted(path: String) -> void:
	_apply_sprite_frames_path(path)


func _apply_sprite_frames_path(path: String) -> void:
	var sprite := _get_selected_animated_sprite_node()
	if sprite == null:
		_set_status("Выбранный узел больше не является AnimatedSprite2D.", true)
		return
	var clean_path := path.strip_edges()
	if clean_path.is_empty() or not clean_path.begins_with("res://"):
		_set_status("Укажи путь к SpriteFrames внутри проекта, начиная с res://.", true)
		return
	var loaded_frames: SpriteFrames = ResourceLoader.load(clean_path) as SpriteFrames
	if loaded_frames == null:
		_set_status("Не удалось загрузить SpriteFrames: " + clean_path, true)
		return
	_commit_visual_node_property(sprite, "sprite_frames", loaded_frames, "назначить SpriteFrames")
	_refresh_visual_editor(sprite)
	_set_status("SpriteFrames назначен. Сохрани сцену через Ctrl+S.", false)


func _on_animated_animation_selected(index: int) -> void:
	var sprite := _get_selected_animated_sprite_node()
	if sprite == null or sprite.sprite_frames == null or _visual_editor_view == null:
		return
	var animation_name := StringName(str(_visual_editor_view.call("get_animation_id", index)))
	if animation_name.is_empty():
		return
	_commit_visual_node_property(sprite, "animation", animation_name, "выбрать анимацию")
	_refresh_visual_editor(sprite)

func _on_animated_frame_changed(value: float) -> void:
	var sprite := _get_selected_animated_sprite_node()
	if sprite == null or sprite.sprite_frames == null:
		return
	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count <= 0:
		return
	var frame_index := clampi(int(round(value)), 0, frame_count - 1)
	_commit_visual_node_property(sprite, "frame", frame_index, "выбрать кадр анимации")
	_refresh_visual_editor(sprite)


func _on_animated_speed_changed(value: float) -> void:
	var sprite := _get_selected_animated_sprite_node()
	if sprite == null:
		return
	_commit_visual_node_property(sprite, "speed_scale", value, "изменить скорость анимации")


func _on_visual_transform_value_changed(value: float, property_name: String) -> void:
	var node := _get_selected_scene_tree_node() as Node2D
	if node == null:
		return
	var next_position := node.position
	var next_scale := node.scale
	match property_name:
		"position_x":
			next_position.x = value
			_commit_visual_node_property(node, "position", next_position, "изменить позицию")
		"position_y":
			next_position.y = value
			_commit_visual_node_property(node, "position", next_position, "изменить позицию")
		"rotation_degrees":
			_commit_visual_node_property(node, "rotation_degrees", value, "изменить поворот")
		"scale_x":
			next_scale.x = value
			_commit_visual_node_property(node, "scale", next_scale, "изменить размер")
		"scale_y":
			next_scale.y = value
			_commit_visual_node_property(node, "scale", next_scale, "изменить размер")
		"z_index":
			_commit_visual_node_property(node, "z_index", int(round(value)), "изменить слой отрисовки")


func _on_reset_visual_transform_requested() -> void:
	var node := _get_selected_scene_tree_node() as Node2D
	var scene_root := _get_open_object_scene_root()
	if node == null or scene_root == null:
		return
	var reset_values := {
		"position": Vector2.ZERO,
		"rotation_degrees": 0.0,
		"scale": Vector2.ONE,
		"z_index": 0
	}
	var changes: Array[Dictionary] = []
	for property_name in reset_values:
		var old_value: Variant = node.get(property_name)
		var new_value: Variant = reset_values[property_name]
		if old_value != new_value:
			changes.append({"property": property_name, "old": old_value, "new": new_value})
	if changes.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: сбросить трансформацию части", 0, scene_root)
	for change in changes:
		var property_name := str(change.get("property", ""))
		undo_redo.add_do_property(node, property_name, change.get("new"))
		undo_redo.add_undo_property(node, property_name, change.get("old"))
	undo_redo.commit_action()
	_refresh_visual_editor(node)
	_set_status("Позиция, поворот, размер и слой части сброшены. Отмена доступна через Undo.", false)


func _on_visual_node_visibility_changed(value: bool) -> void:
	var node := _get_selected_scene_tree_node() as CanvasItem
	if node == null:
		return
	_commit_visual_node_property(node, "visible", value, "изменить видимость части")


func _on_visual_part_visibility_changed(path: NodePath, value: bool) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var node := scene_root.get_node_or_null(path) as CanvasItem
	if node == null:
		return
	_commit_visual_node_property(node, "visible", value, "изменить видимость части")
	_refresh_canvas()
	_refresh_visual_parts()


func _on_visual_part_duplicate_requested(path: NodePath) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var node := scene_root.get_node_or_null(path)
	if node == null or node == scene_root:
		return
	_sync_scene_tree_selection(node)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	_on_duplicate_node_pressed()


func _on_visual_part_remove_requested(path: NodePath) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var node := scene_root.get_node_or_null(path)
	if node == null or node == scene_root:
		return
	_remove_scene_node(node)


func _on_sprite_quick_setting_changed(
	path: NodePath,
	property_name: String,
	value: Variant
) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var selected_node := scene_root.get_node_or_null(path)
	if selected_node is Sprite2D:
		var sprite := selected_node as Sprite2D
		match property_name:
			"hframes", "vframes":
				_commit_visual_node_property(
					sprite,
					property_name,
					clampi(int(value), 1, 128),
					"изменить %s" % property_name
				)
			"frame":
				var frame_limit := sprite.hframes * sprite.vframes - 1
				_commit_visual_node_property(
					sprite,
					"frame",
					clampi(int(value), 0, maxi(0, frame_limit)),
					"выбрать кадр спрайта"
				)
			"region_enabled":
				_commit_visual_node_property(sprite, "region_enabled", bool(value), "переключить область атласа")
			"region_x", "region_y", "region_width", "region_height":
				var next_region := sprite.region_rect
				match property_name:
					"region_x":
						next_region.position.x = float(value)
					"region_y":
						next_region.position.y = float(value)
					"region_width":
						next_region.size.x = maxf(0.0, float(value))
					"region_height":
						next_region.size.y = maxf(0.0, float(value))
				_commit_visual_node_property(sprite, "region_rect", next_region, "изменить область атласа")
		_refresh_visual_editor(sprite)
		return
	if selected_node is AnimatedSprite2D:
		var animated := selected_node as AnimatedSprite2D
		match property_name:
			"animation":
				var animation_name := StringName(str(value))
				if animated.sprite_frames == null or not animated.sprite_frames.has_animation(animation_name):
					return
				_commit_visual_node_property(animated, "animation", animation_name, "выбрать анимацию")
			"frame":
				if animated.sprite_frames == null:
					return
				var frame_count := animated.sprite_frames.get_frame_count(animated.animation)
				if frame_count <= 0:
					return
				_commit_visual_node_property(
					animated,
					"frame",
					clampi(int(value), 0, frame_count - 1),
					"выбрать кадр анимации"
				)
			"speed_scale":
				_commit_visual_node_property(
					animated,
					"speed_scale",
					clampf(float(value), -10.0, 10.0),
					"изменить скорость анимации"
				)
			"animation_speed", "animation_loop", "animation_loop_mode":
				_commit_sprite_frames_animation_setting(
					animated,
					property_name,
					value
				)
		_refresh_visual_editor(animated)


func _commit_sprite_frames_animation_setting(
	sprite: AnimatedSprite2D,
	setting_name: String,
	value: Variant
) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var frames := sprite.sprite_frames
	var animation_name := sprite.animation
	if not frames.has_animation(animation_name):
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	if setting_name == "animation_speed":
		var old_speed := frames.get_animation_speed(animation_name)
		var new_speed := clampf(float(value), 0.1, 120.0)
		if is_equal_approx(old_speed, new_speed):
			return
		undo_redo.create_action("Object Builder: изменить FPS анимации", 0, _get_open_object_scene_root())
		undo_redo.add_do_method(frames, "set_animation_speed", animation_name, new_speed)
		undo_redo.add_undo_method(frames, "set_animation_speed", animation_name, old_speed)
	elif setting_name == "animation_loop" or setting_name == "animation_loop_mode":
		var old_loop_mode := int(frames.get_animation_loop_mode(animation_name))
		var new_loop_mode := (
			(1 if bool(value) else 0)
			if setting_name == "animation_loop"
			else clampi(int(value), 0, 2)
		)
		if old_loop_mode == new_loop_mode:
			return
		undo_redo.create_action("Object Builder: изменить режим зацикливания анимации", 0, _get_open_object_scene_root())
		undo_redo.add_do_method(frames, "set_animation_loop_mode", animation_name, new_loop_mode)
		undo_redo.add_undo_method(frames, "set_animation_loop_mode", animation_name, old_loop_mode)
	else:
		return
	undo_redo.commit_action()
	_refresh_canvas()


func _on_visual_part_resource_edit_requested(path: NodePath) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Открой сцену объекта, чтобы изменить ресурс части.", true)
		return
	var node := scene_root.get_node_or_null(path)
	if node == null:
		return
	_sync_scene_tree_selection(node)
	EditorInterface.edit_node(node)
	if node is Sprite2D:
		_visual_editor_view.call("popup_texture_dialog")
	elif node is AnimatedSprite2D:
		_visual_editor_view.call("popup_sprite_frames_dialog")


func _on_sprite_frames_editor_requested(path: NodePath) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null or _sprite_frames_editor_dialog == null:
		return
	var sprite := scene_root.get_node_or_null(path) as AnimatedSprite2D
	if sprite == null:
		_set_status("Редактор кадров доступен только для AnimatedSprite2D.", true)
		return
	_pending_sprite_frames_editor_path = path
	_sprite_frames_editor_dialog.call("open_for_sprite_frames", sprite.sprite_frames)
	ObjectBuilderDialogService.popup_window_safely(
		_sprite_frames_editor_dialog,
		Vector2i(760, 600),
		0.88
	)


func _on_sprite_frames_editor_accepted(frames: SpriteFrames) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null or frames == null or _pending_sprite_frames_editor_path.is_empty():
		return
	var sprite := scene_root.get_node_or_null(_pending_sprite_frames_editor_path) as AnimatedSprite2D
	if sprite == null:
		return
	_commit_visual_node_property(sprite, "sprite_frames", frames, "изменить анимации и кадры")
	var animation_names := frames.get_animation_names()
	if not animation_names.is_empty() and not frames.has_animation(sprite.animation):
		_commit_visual_node_property(
			sprite,
			"animation",
			StringName(str(animation_names[0])),
			"выбрать существующую анимацию"
		)
	if frames.has_animation(sprite.animation):
		var frame_count := frames.get_frame_count(sprite.animation)
		var safe_frame := clampi(sprite.frame, 0, maxi(0, frame_count - 1))
		if safe_frame != sprite.frame:
			_commit_visual_node_property(sprite, "frame", safe_frame, "выбрать доступный кадр")
	_pending_sprite_frames_editor_path = NodePath("")
	_refresh_canvas()
	_refresh_visual_parts()
	_set_status("Анимации и кадры обновлены. Если прежняя анимация была удалена, выбрана первая доступная.", false)


func _on_visual_part_draw_order_change_requested(path: NodePath, delta: int) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var part := scene_root.get_node_or_null(path) as CanvasItem
	if part == null:
		return
	var next_z_index := clampi(part.z_index + delta, -4096, 4096)
	if next_z_index == part.z_index:
		return
	_commit_visual_node_property(part, "z_index", next_z_index, "изменить порядок отрисовки")
	_refresh_canvas()
	_set_status("Порядок отрисовки обновлён. Ctrl+Z отменяет изменение.", false)


func _on_visual_part_draw_order_reorder_requested(
	source_path: NodePath,
	target_path: NodePath,
	insert_after: bool = false
) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var source := scene_root.get_node_or_null(source_path) as CanvasItem
	var target := scene_root.get_node_or_null(target_path) as CanvasItem
	if source == null or target == null or source == target or source.get_parent() != target.get_parent():
		_set_status("Перетаскивать можно только части с одним родителем.", true)
		return
	var parent := source.get_parent()
	var ordered: Array[CanvasItem] = []
	for child in parent.get_children():
		if child is CanvasItem:
			ordered.append(child as CanvasItem)
	ordered.sort_custom(func(a: CanvasItem, b: CanvasItem) -> bool:
		if a.z_index == b.z_index:
			return a.get_index() < b.get_index()
		return a.z_index < b.z_index
	)
	var sorted_z_indices: Array[int] = []
	for sibling in ordered:
		sorted_z_indices.append(sibling.z_index)
	var requires_unique_z := false
	for index in range(1, sorted_z_indices.size()):
		if sorted_z_indices[index] <= sorted_z_indices[index - 1]:
			requires_unique_z = true
			break
	var source_index := ordered.find(source)
	var target_index := ordered.find(target)
	if source_index < 0 or target_index < 0:
		return
	var insertion_index := target_index + (1 if insert_after else 0)
	if source_index < insertion_index:
		insertion_index -= 1
	ordered.remove_at(source_index)
	ordered.insert(clampi(insertion_index, 0, ordered.size()), source)
	var minimum_z := 0
	if not sorted_z_indices.is_empty():
		minimum_z = sorted_z_indices[0]
	var start_z := clampi(minimum_z, -4096, 4096 - ordered.size() + 1)
	var changes: Array[Dictionary] = []
	for index in range(ordered.size()):
		var node := ordered[index]
		var next_z := start_z + index if requires_unique_z else sorted_z_indices[index]
		if node.z_index != next_z:
			changes.append({"node": node, "old": node.z_index, "new": next_z})
	if changes.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: изменить порядок частей перетаскиванием", 0, scene_root)
	for change in changes:
		var node := change.get("node") as CanvasItem
		undo_redo.add_do_property(node, "z_index", int(change.get("new", 0)))
		undo_redo.add_undo_property(node, "z_index", int(change.get("old", 0)))
	undo_redo.commit_action()
	_refresh_canvas()
	_refresh_visual_parts()
	_set_status("Порядок отрисовки изменён перетаскиванием. Ctrl+Z отменяет перестановку.", false)


func _on_visual_part_lock_changed(path: NodePath, locked: bool) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var lock_key := _get_visual_part_lock_key(scene_root, path)
	if locked:
		if not _locked_visual_part_keys.has(lock_key):
			_locked_visual_part_keys.append(lock_key)
	else:
		_locked_visual_part_keys.erase(lock_key)
	_save_local_state()
	_refresh_visual_parts()
	_set_status("Часть зафиксирована на холсте." if locked else "Блокировка части снята.", false)


func _get_visual_part_lock_key(scene_root: Node, path: NodePath) -> String:
	var scene_path := scene_root.scene_file_path
	if scene_path.is_empty() and _working_definition != null:
		scene_path = _working_definition.scene_path
	return scene_path + "::" + str(path)


func _on_visual_parts_visibility_batch_requested(visible: bool) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null or _visual_parts_view == null:
		return
	var changes: Array[Dictionary] = []
	var part_paths: Array[NodePath] = _visual_parts_view.call("get_part_paths")
	for part_path in part_paths:
		var part := scene_root.get_node_or_null(part_path) as CanvasItem
		if part == null or part.visible == visible:
			continue
		changes.append({"node": part, "old": part.visible})
	if changes.is_empty():
		_set_status("Видимость частей уже соответствует выбранному действию.", false)
		return
	var action_name := "показать все визуальные части" if visible else "скрыть все визуальные части"
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: " + action_name, 0, scene_root)
	for change in changes:
		var part := change.get("node") as CanvasItem
		undo_redo.add_do_property(part, "visible", visible)
		undo_redo.add_undo_property(part, "visible", bool(change.get("old", true)))
	undo_redo.commit_action()
	_refresh_canvas()
	_set_status("Видимость обновлена для %d частей. Ctrl+Z отменяет действие." % changes.size(), false)


func _on_sprite_grid_value_changed(value: float, property_name: String) -> void:
	var sprite := _get_selected_sprite_node()
	if sprite == null:
		return
	var next_value := int(round(value))
	if property_name == "frame":
		var frame_limit := sprite.hframes * sprite.vframes - 1
		next_value = clampi(next_value, 0, maxi(0, frame_limit))
	_commit_sprite_property(sprite, property_name, next_value, "изменить %s" % property_name)
	_refresh_visual_editor(sprite)


func _on_sprite_offset_changed(value: float, axis: String) -> void:
	var sprite := _get_selected_sprite_node()
	if sprite == null:
		return
	var next_offset := sprite.offset
	if axis == "x":
		next_offset.x = value
	else:
		next_offset.y = value
	_commit_sprite_property(sprite, "offset", next_offset, "изменить Offset")


func _on_sprite_toggle_changed(value: bool, property_name: String) -> void:
	var sprite := _get_selected_sprite_node()
	if sprite == null:
		return
	_commit_sprite_property(sprite, property_name, value, "изменить %s" % property_name)


func _commit_sprite_property(
	sprite: Sprite2D,
	property_name: String,
	new_value: Variant,
	action_label: String
) -> void:
	_commit_visual_node_property(sprite, property_name, new_value, action_label)


func _commit_visual_node_property(
	node: Node,
	property_name: String,
	new_value: Variant,
	action_label: String
) -> void:
	if node == null or not is_instance_valid(node):
		return
	var old_value: Variant = node.get(property_name)
	if old_value == new_value:
		return
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Сначала открой сцену выбранного объекта.", true)
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: " + action_label, 0, scene_root)
	undo_redo.add_do_property(node, property_name, new_value)
	undo_redo.add_undo_property(node, property_name, old_value)
	undo_redo.commit_action()
	_refresh_visual_editor(node)
	_refresh_canvas()


func _on_add_node_pressed() -> void:
	if _working_definition == null:
		_set_status("Сначала выбери или создай объект.", true)
		return
	if _get_open_object_scene_root() == null:
		_set_status("Сначала открой сцену этого объекта.", true)
		return
	_dialog_view.call("reset_node_dialog", "Sprite2D")
	_dialog_view.call("popup_node_dialog")

func _on_node_dialog_confirmed() -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Открытая сцена больше не совпадает с выбранным объектом.", true)
		return

	var parent_node := _get_selected_scene_tree_node()
	if parent_node == null:
		parent_node = scene_root

	var node_type := str(_dialog_view.call("get_selected_node_type"))
	if node_type.is_empty() or not CHILD_NODE_TYPES.has(node_type):
		_set_status("Выбери допустимый тип дочернего узла.", true)
		return
	var created_object: Object = ClassDB.instantiate(node_type)
	if not created_object is Node:
		_set_status("Godot не смог создать узел типа " + node_type, true)
		return

	var new_node := created_object as Node
	var entered_name := str(_dialog_view.call("get_node_name")).strip_edges()
	if entered_name.is_empty():
		entered_name = node_type
	new_node.name = entered_name.validate_node_name()

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: добавить узел", 0, scene_root)
	undo_redo.add_do_method(parent_node, "add_child", new_node)
	undo_redo.add_do_method(new_node, "set_owner", scene_root)
	undo_redo.add_undo_method(parent_node, "remove_child", new_node)
	undo_redo.add_do_reference(new_node)
	undo_redo.commit_action()

	EditorInterface.edit_node(new_node)
	_refresh_scene_tree()
	_set_status("Добавлен узел %s. Для сохранения сцены нажми Ctrl+S." % new_node.name, false)

func _on_duplicate_node_pressed() -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Открой сцену выбранного объекта.", true)
		return
	var source_node := _get_selected_scene_tree_node()
	if source_node == null or source_node == scene_root:
		_set_status("Выбери дочернюю часть, которую нужно дублировать.", true)
		return
	var parent_node := source_node.get_parent()
	if parent_node == null:
		return
	var duplicate_node := source_node.duplicate()
	if duplicate_node == null:
		_set_status("Не удалось создать копию выбранной части.", true)
		return
	duplicate_node.name = _get_unique_child_name(parent_node, source_node.name + "_copy")
	var insert_index := source_node.get_index() + 1
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: дублировать часть", 0, scene_root)
	undo_redo.add_do_method(parent_node, "add_child", duplicate_node)
	undo_redo.add_do_method(parent_node, "move_child", duplicate_node, insert_index)
	undo_redo.add_do_method(duplicate_node, "set_owner", scene_root)
	for child in duplicate_node.get_children():
		_add_owner_do_methods(undo_redo, child, scene_root)
	undo_redo.add_undo_method(parent_node, "remove_child", duplicate_node)
	undo_redo.add_do_reference(duplicate_node)
	undo_redo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(duplicate_node)
	EditorInterface.edit_node(duplicate_node)
	_refresh_scene_tree()
	_sync_scene_tree_selection(duplicate_node)
	_set_status("Создана копия «%s». Измени её независимо от оригинала и сохрани сцену через Ctrl+S." % duplicate_node.name, false)


func _add_owner_do_methods(undo_redo: EditorUndoRedoManager, node: Node, scene_root: Node) -> void:
	undo_redo.add_do_method(node, "set_owner", scene_root)
	for child in node.get_children():
		_add_owner_do_methods(undo_redo, child, scene_root)


func _get_unique_child_name(parent_node: Node, base_name: String) -> String:
	var safe_base := base_name.strip_edges().validate_node_name()
	if safe_base.is_empty():
		safe_base = "Part"
	var candidate := safe_base
	var suffix := 2
	while parent_node.get_node_or_null(NodePath(candidate)) != null:
		candidate = "%s%d" % [safe_base, suffix]
		suffix += 1
	return candidate


func _on_scene_tree_node_rename_requested(path: NodePath, requested_name: String) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return
	var node := scene_root.get_node_or_null(path)
	if node == null or node == scene_root:
		return
	var parent_node := node.get_parent()
	if parent_node == null:
		return
	var clean_name := requested_name.strip_edges().validate_node_name()
	if clean_name.is_empty():
		_refresh_scene_tree()
		_set_status("Имя части не может быть пустым.", true)
		return
	var next_name := clean_name
	var suffix := 2
	while true:
		var sibling := parent_node.get_node_or_null(NodePath(next_name))
		if sibling == null or sibling == node:
			break
		next_name = "%s%d" % [clean_name, suffix]
		suffix += 1
	if next_name == node.name:
		_refresh_scene_tree()
		return
	var old_name := str(node.name)
	var was_locked := _locked_visual_part_keys.has(_get_visual_part_lock_key(scene_root, path))
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: переименовать часть", 0, scene_root)
	undo_redo.add_do_property(node, "name", next_name)
	undo_redo.add_undo_property(node, "name", old_name)
	undo_redo.commit_action()
	if was_locked:
		# Keep the previous key as well, so Undo can restore the original name
		# without losing this editor-only lock preference.
		var parent_path := scene_root.get_path_to(parent_node)
		var next_path := (
			NodePath(next_name)
			if parent_path == NodePath(".")
			else NodePath(str(parent_path) + "/" + next_name)
		)
		var next_lock_key := _get_visual_part_lock_key(scene_root, next_path)
		if not _locked_visual_part_keys.has(next_lock_key):
			_locked_visual_part_keys.append(next_lock_key)
		_save_local_state()
	EditorInterface.edit_node(node)
	_refresh_scene_tree()
	_refresh_canvas()
	_refresh_visual_parts()
	_sync_scene_tree_selection(node)
	_set_status("Часть переименована в «%s». Ctrl+Z отменяет изменение." % next_name, false)


func _on_remove_node_pressed() -> void:
	var selected_node := _get_selected_scene_tree_node()
	if selected_node == null:
		_set_status("Выбери дочернюю часть для удаления.", true)
		return
	_remove_scene_node(selected_node)


func _remove_scene_node(selected_node: Node) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Открой сцену выбранного объекта.", true)
		return
	if selected_node == scene_root:
		_set_status("Нельзя удалить корневой узел объекта.", true)
		return
	if selected_node == null or not is_instance_valid(selected_node) or not scene_root.is_ancestor_of(selected_node):
		_set_status("Выбранная часть больше не находится в открытой сцене.", true)
		return
	var dependencies: Array[Dictionary] = ObjectBuilderSceneNodeDependencyService.inspect(
		scene_root, selected_node, _working_definition
	)
	if not dependencies.is_empty():
		_pending_scene_node_removal = selected_node
		_scene_node_delete_dialog.dialog_text = _build_scene_node_dependency_warning(selected_node, dependencies)
		ObjectBuilderDialogService.popup_window_safely(
			_scene_node_delete_dialog, Vector2i(620, 420), 0.84
		)
		return
	_perform_scene_node_removal(selected_node)


func _build_scene_node_dependency_warning(selected_node: Node, dependencies: Array[Dictionary]) -> String:
	var lines := PackedStringArray()
	lines.append("У части «%s» найдены связи, которые могут перестать работать после удаления:" % selected_node.name)
	lines.append("")
	var visible_reference_count := mini(dependencies.size(), 8)
	for index in range(visible_reference_count):
		var dependency: Dictionary = dependencies[index]
		var kind := str(dependency.get("kind", "Связь"))
		var source_path := str(dependency.get("source_path", ""))
		var details := str(dependency.get("details", ""))
		lines.append("• %s — %s" % [kind, source_path])
		if not details.is_empty():
			lines.append("  %s" % details)
	if dependencies.size() > visible_reference_count:
		lines.append("…и ещё %d связей." % (dependencies.size() - visible_reference_count))
	lines.append("")
	lines.append("Удаление затронет перечисленные связи. Исходные данные не изменятся до подтверждения.")
	lines.append("Отдельной модели сокетов в текущей версии Object System пока нет.")
	return "\n".join(lines)


func _on_scene_node_delete_cancelled() -> void:
	_pending_scene_node_removal = null


func _on_scene_node_delete_confirmed() -> void:
	var selected_node := _pending_scene_node_removal
	_pending_scene_node_removal = null
	if selected_node == null or not is_instance_valid(selected_node):
		return
	var scene_root := _get_open_object_scene_root()
	if scene_root == null or (selected_node != scene_root and not scene_root.is_ancestor_of(selected_node)):
		_set_status("Сцена изменилась. Удаление отменено.", true)
		return
	_perform_scene_node_removal(selected_node)


func _perform_scene_node_removal(selected_node: Node) -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null or selected_node == null or not is_instance_valid(selected_node):
		return
	if selected_node == scene_root:
		return
	var parent_node := selected_node.get_parent()
	if parent_node == null:
		return
	var original_index := selected_node.get_index()
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: удалить узел", 0, scene_root)
	undo_redo.add_do_method(parent_node, "remove_child", selected_node)
	undo_redo.add_undo_method(parent_node, "add_child", selected_node)
	undo_redo.add_undo_method(parent_node, "move_child", selected_node, original_index)
	undo_redo.add_undo_reference(selected_node)
	undo_redo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(parent_node)
	_refresh_scene_tree()
	_sync_scene_tree_selection(parent_node)
	_set_status("Часть удалена. Ctrl+Z отменяет удаление.", false)


func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)


func _set_status(message: String, is_error: bool) -> void:
	if _status_label != null:
		_status_label.text = message
		if is_error:
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		else:
			_status_label.remove_theme_color_override("font_color")
	if _workspace_view != null:
		_refresh_workspace_document_info()
		_workspace_view.call("set_status", message, is_error)


func _refresh_workspace_document_info() -> void:
	if _workspace_view == null:
		return
	if _working_definition == null:
		_workspace_view.call("set_document_info", "", "", false, false)
		return
	var is_dirty := bool(_editor_session.call("is_dirty")) if _editor_session != null else false
	_workspace_view.call(
		"set_document_info",
		_working_definition.display_name,
		_working_definition.category,
		_working_definition.is_template,
		is_dirty
	)
