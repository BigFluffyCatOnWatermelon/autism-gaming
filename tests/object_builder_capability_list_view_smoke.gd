extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/capability_list_view.gd")
const DefinitionScript = preload("res://scripts/object_system/object_capability_definition.gd")

var failures: Array[String] = []
var search_events: Array[String] = []
var category_events: Array[String] = []
var toggle_events: Array[String] = []
var settings_events: Array[String] = []
var selection_events: Array[String] = []
var batch_add_count := 0
var clear_selection_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = ViewScript.new()
	root.add_child(view)
	var categories: Array[Dictionary] = [
		{"id": "nature", "display_name": "Природа"},
		{"id": "combat", "display_name": "Бой"}
	]
	view.call("build", categories)
	view.connect("search_changed", Callable(self, "_on_search_changed"))
	view.connect("category_changed", Callable(self, "_on_category_changed"))
	view.connect("toggle_requested", Callable(self, "_on_toggle_requested"))
	view.connect("settings_requested", Callable(self, "_on_settings_requested"))
	view.connect("selection_toggled", Callable(self, "_on_selection_toggled"))
	view.connect("batch_add_requested", Callable(self, "_on_batch_add_requested"))
	view.connect("clear_selection_requested", Callable(self, "_on_clear_selection_requested"))

	_expect(view.get_child_count() == 7, "capability view owns title, hint, search, filter, entries, pagination and selection bar")
	_expect(str(view.call("get_selected_category")) == "", "capability filter starts with all categories")
	var search_input := view.get("search_input") as LineEdit
	search_input.text_changed.emit("tree")
	_expect(search_events == ["tree"], "search input emits its new query")
	var category_option := view.get("category_option") as OptionButton
	category_option.select(2)
	category_option.item_selected.emit(2)
	_expect(category_events == ["combat"], "category filter emits its stable ID")

	var implemented = DefinitionScript.new()
	implemented.capability_id = "can_attack"
	implemented.display_name = "Атака"
	implemented.description = "Позволяет атаковать."
	implemented.runtime_status = "Implemented"
	implemented.implementation_note = "Готовая возможность."
	var selectable = DefinitionScript.new()
	selectable.capability_id = "can_dig"
	selectable.display_name = "Можно копать"
	selectable.description = "Позволяет копать землю."
	selectable.runtime_status = "Implemented"
	var planned = DefinitionScript.new()
	planned.capability_id = "can_fly"
	planned.display_name = "Полёт"
	planned.description = "Позволяет летать."
	planned.runtime_status = "Planned"
	planned.implementation_note = "Ещё разрабатывается."
	var entries: Array[Dictionary] = [
		{
			"definition": implemented,
			"installed": true,
			"enabled": true,
			"automatically_added": false,
			"can_toggle": true,
			"can_configure": true
		},
		{
			"definition": selectable,
			"installed": false,
			"enabled": false,
			"selected_in_catalog": false,
			"automatically_added": false,
			"can_toggle": true,
			"can_configure": false,
			"relation_highlight": {
				"type": "requires",
				"explanation": "Для этой механики требуется основная способность.",
				"is_reverse": false
			}
		},
		{
			"definition": planned,
			"installed": false,
			"enabled": false,
			"automatically_added": false,
			"can_toggle": false,
			"can_configure": false
		}
	]
	view.call("set_entries", entries, 200, 42)
	var entries_container := view.get("entries_container") as VBoxContainer
	_expect(entries_container.get_child_count() == 4, "summary and three capability cards are displayed")
	_expect((entries_container.get_child(0) as Label).text == "Механик в библиотеке: 200 · доступно сейчас: 42", "summary counts are supplied by the controller")

	var implemented_card := entries_container.get_child(1) as PanelContainer
	var implemented_content := implemented_card.get_child(0) as VBoxContainer
	var implemented_header := implemented_content.get_child(0) as HBoxContainer
	var icon_slot := implemented_header.get_child(0) as PanelContainer
	var enabled_check := implemented_header.get_child(1) as CheckBox
	var settings_button := implemented_header.get_child(3) as Button
	_expect(icon_slot != null and icon_slot.get_child_count() == 1, "every capability card owns a dedicated icon slot")
	_expect(enabled_check.button_pressed and not enabled_check.disabled, "implemented capabilities can be toggled")
	_expect(not settings_button.disabled, "enabled implemented capability can open settings")
	enabled_check.toggled.emit(false)
	settings_button.pressed.emit()
	_expect(toggle_events == ["false:can_attack"], "toggle action forwards state and capability ID")
	_expect(settings_events == ["can_attack"], "settings action forwards capability ID")

	var selectable_card := entries_container.get_child(2) as PanelContainer
	var selectable_content := selectable_card.get_child(0) as VBoxContainer
	var selectable_header := selectable_content.get_child(0) as HBoxContainer
	var selectable_check := selectable_header.get_child(1) as CheckBox
	_expect(not selectable_check.disabled and not selectable_check.button_pressed, "ready uninstalled capabilities can be selected without being applied immediately")
	var relation_chip := selectable_content.get_child(1) as Label
	_expect(
		relation_chip.text == "Обязательная зависимость" and relation_chip.tooltip_text.contains("требуется"),
		"related card exposes a typed relationship and its explanation"
	)
	selectable_check.toggled.emit(true)
	_expect(selection_events == ["true:can_dig"], "uninstalled capability checkbox adds the ID to the catalog selection")
	view.call("set_selected_count", 2)
	var selection_bar := view.get("_selection_bar") as PanelContainer
	var selection_summary := view.get("_selection_summary") as Label
	var add_selected_button := view.get("_add_selected_button") as Button
	var clear_selection_button := view.get("_clear_selection_button") as Button
	_expect(selection_bar.visible and selection_summary.text == "Выбрано в разных разделах: 2", "selection panel shows the global selection count")
	_expect(add_selected_button.text == "Добавить выбранные (2)" and not add_selected_button.disabled, "batch action displays the exact selection count")
	add_selected_button.pressed.emit()
	clear_selection_button.pressed.emit()
	_expect(batch_add_count == 1 and clear_selection_count == 1, "selection bar forwards batch and clear actions")
	view.call("set_selected_count", 0)

	var planned_card := entries_container.get_child(3) as PanelContainer
	var planned_content := planned_card.get_child(0) as VBoxContainer
	var planned_header := planned_content.get_child(0) as HBoxContainer
	var planned_check := planned_header.get_child(1) as CheckBox
	var planned_state := planned_header.get_child(2) as Label
	var planned_settings := planned_header.get_child(3) as Button
	_expect(planned_check.disabled and planned_state.text == "В разработке", "planned capabilities remain clearly unavailable")
	_expect(planned_settings.disabled, "planned capabilities cannot be configured")

	var many_entries: Array[Dictionary] = []
	for index in range(45):
		many_entries.append({
			"definition": implemented,
			"enabled": false,
			"automatically_added": false,
			"can_toggle": true,
			"can_configure": false
		})
	view.call("set_entries", many_entries, 200, 42)
	_expect(entries_container.get_child_count() == 21, "only one page of 20 capability cards is created at a time")
	var previous_page := view.get("_previous_page_button") as Button
	var next_page := view.get("_next_page_button") as Button
	var page_label := view.get("_page_label") as Label
	_expect(previous_page.disabled and not next_page.disabled, "first page only enables forward navigation")
	_expect(page_label.text == "Страница 1 из 3 · 45 возможностей", "pagination displays the current page and total")
	next_page.pressed.emit()
	_expect(entries_container.get_child_count() == 21, "next page still creates no more than 20 capability cards")
	_expect(page_label.text == "Страница 2 из 3 · 45 возможностей", "next page advances the page label")
	_expect(not previous_page.disabled and not next_page.disabled, "middle page enables navigation in both directions")
	previous_page.pressed.emit()
	_expect(page_label.text == "Страница 1 из 3 · 45 возможностей", "previous page returns to the first page")

	var empty_entries: Array[Dictionary] = []
	view.call("set_entries", empty_entries, 200, 42)
	_expect(entries_container.get_child_count() == 2, "empty search still preserves library summary")
	view.call("show_empty_state", "Сначала выбери объект")
	_expect(entries_container.get_child_count() == 1, "no selected object displays a single empty state")

	root.remove_child(view)
	view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder capability list view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_search_changed(value: String) -> void:
	search_events.append(value)


func _on_category_changed(value: String) -> void:
	category_events.append(value)


func _on_toggle_requested(enabled: bool, capability_id: String) -> void:
	toggle_events.append("%s:%s" % [str(enabled).to_lower(), capability_id])


func _on_settings_requested(capability_id: String) -> void:
	settings_events.append(capability_id)


func _on_selection_toggled(selected: bool, capability_id: String) -> void:
	selection_events.append("%s:%s" % [str(selected).to_lower(), capability_id])


func _on_batch_add_requested() -> void:
	batch_add_count += 1


func _on_clear_selection_requested() -> void:
	clear_selection_count += 1


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
