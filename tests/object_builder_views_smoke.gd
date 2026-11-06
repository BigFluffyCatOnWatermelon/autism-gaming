extends SceneTree

const LibraryViewScript = preload("res://addons/object_builder/ui/library_view.gd")
const EditorViewScript = preload("res://addons/object_builder/ui/object_editor_view.gd")

var failures: Array[String] = []
var search_events: Array[String] = []
var filter_events: Array[int] = []
var selection_events: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var library = LibraryViewScript.new()
	root.add_child(library)
	library.call("build")
	_expect(library.get_child_count() == 5, "library view owns search, three filters and result list")
	_expect(is_equal_approx(library.custom_minimum_size.x, 210.0), "library view preserves its minimum workspace width")
	_expect(str(library.call("get_selected_mode")) == "all", "library view starts in the all-objects filter")
	library.connect("search_changed", Callable(self, "_on_search_changed"))
	library.connect("filter_changed", Callable(self, "_on_filter_changed"))
	library.connect("object_selected", Callable(self, "_on_object_selected"))

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

	var entries: Array[Dictionary] = [
		{"title": "Oak", "tooltip": "Tree object"},
		{"title": "Pine", "tooltip": "Another tree"}
	]
	library.call("set_entries", entries, "Nothing found")
	var object_list := library.get("object_list") as ItemList
	_expect(object_list.item_count == 2, "library view renders object entries")
	_expect(object_list.get_item_tooltip(0) == "Tree object", "library view retains object tooltips")
	object_list.item_selected.emit(1)
	_expect(selection_events.size() == 1 and selection_events[0] == 1, "object selection emits its index")
	var empty_entries: Array[Dictionary] = []
	library.call("set_entries", empty_entries, "No objects")
	_expect(object_list.item_count == 1 and object_list.is_item_disabled(0), "empty library uses a disabled empty-state row")

	var editor = EditorViewScript.new()
	root.add_child(editor)
	editor.call("build")
	_expect(editor.get_child_count() == 2, "editor view owns two mode tabs")
	var simple_content := editor.get("simple_content") as VBoxContainer
	var advanced_content := editor.get("advanced_content") as VBoxContainer
	_expect(simple_content != null and advanced_content != null, "editor view exposes both content roots")
	_expect(editor.get_tab_title(0) == "Простой режим", "simple mode has the expected title")
	_expect(editor.get_tab_title(1) == "Расширенный режим", "advanced mode has the expected title")
	_expect(simple_content.get_parent() is ScrollContainer, "simple mode uses a shared scroll container")
	_expect(advanced_content.get_parent() is ScrollContainer, "advanced mode uses a shared scroll container")

	root.remove_child(library)
	library.free()
	root.remove_child(editor)
	editor.free()
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


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
