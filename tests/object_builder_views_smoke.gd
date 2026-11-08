extends SceneTree

const LibraryViewScript = preload("res://addons/object_builder/ui/library_view.gd")
const EditorViewScript = preload("res://addons/object_builder/ui/object_editor_view.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const InstalledCapabilitiesViewScript = preload("res://addons/object_builder/ui/installed_capabilities_view.gd")

var failures: Array[String] = []
var search_events: Array[String] = []
var filter_events: Array[int] = []
var selection_events: Array[int] = []
var action_events: Array[String] = []
var collection_management_events: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var library = LibraryViewScript.new()
	root.add_child(library)
	library.call("build")
	_expect(library.get_child_count() >= 8, "library view owns search, three filters, mode controls and both result views")
	_expect(is_equal_approx(library.custom_minimum_size.x, 210.0), "library view preserves its minimum workspace width")
	_expect(library.size_flags_vertical == Control.SIZE_EXPAND_FILL, "library view expands vertically to fill the workspace panel")
	_expect((library.get("_cards_scroll") as ScrollContainer).custom_minimum_size.y >= 120.0, "card viewport keeps a usable minimum height when the panel is constrained")
	_expect(str(library.call("get_selected_mode")) == "all", "library view starts in the all-objects filter")
	library.connect("search_changed", Callable(self, "_on_search_changed"))
	library.connect("filter_changed", Callable(self, "_on_filter_changed"))
	library.connect("object_selected", Callable(self, "_on_object_selected"))
	library.connect("entry_action_requested", Callable(self, "_on_entry_action_requested"))
	library.connect("collection_management_requested", Callable(self, "_on_collection_management_requested"))

	var search_input := library.get("search_input") as LineEdit
	search_input.text_changed.emit("oak")
	_expect(search_events.size() == 1 and search_events[0] == "oak", "search changes emit a single query signal")

	var category_options: Array[Dictionary] = [
		{"id": "nature", "label": "Природа"},
		{"id": "items", "label": "Предметы"}
	]
	library.call("set_category_options", category_options, "items")
	_expect(str(library.call("get_selected_category")) == "items", "category filter preserves a selected ID")
	var category_filter := library.get("category_filter") as OptionButton
	category_filter.item_selected.emit(2)
	_expect(filter_events.size() == 1 and filter_events[0] == 2, "filter changes emit their selected index")

	var tag_options: Array[Dictionary] = [{"id": "tree", "label": "#tree"}]
	library.call("set_tag_options", tag_options, "tree")
	_expect(str(library.call("get_selected_tag")) == "tree", "tag filter preserves a selected ID")

	var oak := DefinitionScript.new()
	oak.object_id = "tree_oak"
	oak.display_name = "Oak"
	oak.category = "Nature"
	var pine := DefinitionScript.new()
	pine.object_id = "tree_pine"
	pine.display_name = "Pine"
	pine.category = "Nature"
	var entries: Array[Dictionary] = [
		{"title": "Oak", "tooltip": "Tree object", "definition": oak},
		{"title": "Pine", "tooltip": "Another tree", "definition": pine}
	]
	library.call("set_entries", entries, "Nothing found")
	var object_list := library.get("object_list") as ItemList
	_expect(str(library.call("get_display_mode")) == "cards", "library starts in card mode")
	_expect(int(library.call("get_card_count")) == 2, "library renders one card per object")
	library.call("_on_card_pressed", 0)
	_expect(selection_events.size() == 1 and selection_events[0] == 0, "card selection emits the matching object index")
	_expect(int(library.call("get_selected_index")) == 0, "selected library entry remains available for actions")
	library.call("_on_entry_action_selected", 1)
	_expect(action_events.size() == 1 and action_events[0] == "duplicate:0", "selected-entry action emits its stable action ID and index")
	var custom_collection_options: Array[Dictionary] = [{"id": "collection_forest", "label": "Лес"}]
	library.call("set_collection_options", custom_collection_options, "collection:collection_forest")
	_expect(str(library.call("get_selected_mode")) == "collection:collection_forest", "collection navigation restores the selected custom collection")
	_expect(not (library.get("_collection_management_button") as Button).disabled, "collection management is enabled for a selected collection")
	library.call("_on_collection_management_item_selected", 0)
	_expect(collection_management_events == ["rename"], "collection management emits the requested rename action")
	library.call("_on_entry_action_selected", 1000)
	_expect(action_events.size() == 2 and action_events[1] == "add_to_collection:collection_forest:0", "selected object can be added to a custom collection")
	library.call("_on_entry_action_selected", 6)
	_expect(action_events.size() == 3 and action_events[2] == "remove_from_collection:0", "selected object can be removed from the active collection")
	library.call("_on_entry_action_selected", 7)
	_expect(action_events.size() == 4 and action_events[3] == "toggle_favorite:0", "favorite can be toggled from the selected library entry")
	library.call("set_display_mode", "list")
	_expect(not (library.get("_cards_scroll") as ScrollContainer).visible and object_list.visible, "list mode swaps the visible result view")
	_expect(object_list.item_count == 2, "compact list renders the same entries")
	_expect(object_list.get_item_tooltip(0) == "Tree object", "compact list retains object tooltips")
	object_list.item_selected.emit(1)
	_expect(selection_events.size() == 2 and selection_events[1] == 1, "list selection emits its index")
	library.call("set_display_mode", "cards")
	_expect((library.get("_cards_scroll") as ScrollContainer).visible and not object_list.visible, "card mode restores the thumbnail grid")
	var empty_entries: Array[Dictionary] = []
	library.call("set_entries", empty_entries, "No objects")
	_expect(object_list.item_count == 1 and object_list.is_item_disabled(0), "empty compact list uses a disabled empty-state row")
	_expect(int(library.call("get_card_count")) == 0, "empty card view has no selectable object cards")

	var editor = EditorViewScript.new()
	root.add_child(editor)
	editor.call("build")
	_expect(editor.get_child_count() == 4, "editor view owns appearance, capabilities, settings and advanced tabs")
	var appearance_content := editor.get("appearance_content") as VBoxContainer
	var capabilities_content := editor.get("capabilities_content") as VBoxContainer
	var settings_content := editor.get("settings_content") as VBoxContainer
	var advanced_content := editor.get("advanced_content") as VBoxContainer
	_expect(
		appearance_content != null and capabilities_content != null
		and settings_content != null and advanced_content != null,
		"editor view exposes all constructor content roots"
	)
	_expect(editor.get_tab_title(0) == "Внешний вид", "appearance has the first and default tab")
	_expect(editor.get_tab_title(1) == "Возможности", "capabilities have a dedicated tab")
	_expect(editor.get_tab_title(2) == "Настройки", "object settings have a dedicated tab")
	_expect(editor.get_tab_title(3) == "Расширенный режим", "advanced tools remain available separately")
	_expect(appearance_content.get_parent() is ScrollContainer, "appearance uses its own scroll container")
	_expect(capabilities_content.get_parent() is ScrollContainer, "capabilities use their own scroll container")
	_expect(settings_content.get_parent() is ScrollContainer, "settings use their own scroll container")
	_expect(advanced_content.get_parent() is ScrollContainer, "advanced mode uses its own scroll container")
	_expect(editor.current_tab == 0, "new objects open on the appearance workspace")

	var installed_view = InstalledCapabilitiesViewScript.new()
	root.add_child(installed_view)
	installed_view.call("build")
	var configure_events: Array[String] = []
	var focus_events: Array[String] = []
	installed_view.connect("configure_requested", func(capability_id: String) -> void: configure_events.append(capability_id))
	installed_view.connect("focus_requested", func(capability_id: String) -> void: focus_events.append(capability_id))
	var installed_entries: Array[Dictionary] = [
		{"capability_id": "has_health", "display_name": "Здоровье", "description": "Параметры здоровья", "category_id": "stats", "category_name": "Характеристики"},
		{"capability_id": "damageable", "display_name": "Разрушаемость", "description": "Получение урона", "category_id": "destruction", "category_name": "Разрушение"}
	]
	installed_view.call("set_entries", installed_entries)
	_expect(str((installed_view.get("_count_label") as Label).text) == "Включено: 2", "installed mechanics view reports the enabled count")
	_expect((installed_view.get("_list") as VBoxContainer).get_child_count() == 2, "installed mechanics are grouped by category")
	(installed_view.get("_search") as LineEdit).text = "здоров"
	(installed_view.get("_search") as LineEdit).text_changed.emit("здоров")
	_expect((installed_view.get("_list") as VBoxContainer).get_child_count() == 1, "installed mechanics search filters the grouped list")
	var configure_button := (((installed_view.get("_list") as VBoxContainer).get_child(0) as VBoxContainer).get_child(1) as PanelContainer).get_child(0).get_child(2).get_child(0) as Button
	var deferred_rebuild_state := {"requested": false}
	installed_view.connect("configure_requested", func(_capability_id: String) -> void:
		deferred_rebuild_state["requested"] = true
		installed_view.call_deferred("set_entries", installed_entries)
	)
	configure_button.pressed.emit()
	_expect(is_instance_valid(configure_button), "configure button remains alive until its pressed signal finishes")
	_expect(bool(deferred_rebuild_state["requested"]), "configure action can schedule a list refresh without freeing its signal source")
	await process_frame
	installed_view.call("_on_focus_pressed", "has_health")
	_expect(configure_events == ["has_health"], "configure action targets the selected installed capability")
	_expect(focus_events == ["has_health"], "catalog action targets the selected installed capability")
	(installed_view.get("_search") as LineEdit).text = ""
	(installed_view.get("_search") as LineEdit).text_changed.emit("")
	var no_installed_entries: Array[Dictionary] = []
	installed_view.call("set_entries", no_installed_entries, "Сначала выбери объект.")
	_expect((installed_view.get("_empty_label") as Label).visible, "empty installed mechanics state is visible")
	_expect(str((installed_view.get("_empty_label") as Label).text) == "Сначала выбери объект.", "empty state explains why no mechanics are listed")

	root.remove_child(library)
	library.free()
	root.remove_child(editor)
	editor.free()
	root.remove_child(installed_view)
	installed_view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder view component tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_search_changed(value: String) -> void:
	search_events.append(value)


func _on_filter_changed(index: int) -> void:
	filter_events.append(index)


func _on_object_selected(index: int) -> void:
	selection_events.append(index)


func _on_entry_action_requested(action: String, index: int) -> void:
	action_events.append(action + ":" + str(index))


func _on_collection_management_requested(action: String) -> void:
	collection_management_events.append(action)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
