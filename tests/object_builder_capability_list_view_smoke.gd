extends SceneTree

const ViewScript = preload("res://addons/object_builder/ui/capability_list_view.gd")
const DefinitionScript = preload("res://scripts/object_system/object_capability_definition.gd")
const PresetDialogScript = preload("res://addons/object_builder/ui/capability_preset_dialog.gd")

var failures: Array[String] = []
var search_events: Array[String] = []
var category_events: Array[String] = []
var toggle_events: Array[String] = []
var settings_events: Array[String] = []
var focus_events: Array[String] = []
var selection_events: Array[String] = []
var batch_add_count := 0
var clear_selection_count := 0
var preset_events: Array[String] = []
var preset_select_all_count := 0
var preset_action_events: Array[String] = []


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
	_expect(not (view.get("_related_section") as PanelContainer).visible, "related suggestions stay hidden until a capability is focused")
	_expect(not (view.get("_recommendation_section") as PanelContainer).visible, "contextual recommendations stay hidden until an object capability is active")
	_expect(not (view.get("_preset_section") as PanelContainer).visible, "preset area stays hidden until the catalog provides its preset list")
	view.connect("search_changed", Callable(self, "_on_search_changed"))
	view.connect("category_changed", Callable(self, "_on_category_changed"))
	view.connect("toggle_requested", Callable(self, "_on_toggle_requested"))
	view.connect("settings_requested", Callable(self, "_on_settings_requested"))
	view.connect("focus_requested", Callable(self, "_on_focus_requested"))
	view.connect("selection_toggled", Callable(self, "_on_selection_toggled"))
	view.connect("batch_add_requested", Callable(self, "_on_batch_add_requested"))
	view.connect("clear_selection_requested", Callable(self, "_on_clear_selection_requested"))
	view.connect("preset_requested", Callable(self, "_on_preset_requested"))
	view.connect("preset_select_all_requested", Callable(self, "_on_preset_select_all_requested"))
	view.connect("preset_action_requested", Callable(self, "_on_preset_action_requested"))

	_expect(view.get_child_count() == 10, "capability view owns title, hint, search, filter, selection, relation/recommendation/preset panels, entries and pagination")
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
	var recommended = DefinitionScript.new()
	recommended.capability_id = "can_swim"
	recommended.display_name = "Плавание"
	recommended.description = "Позволяет двигаться в воде."
	recommended.runtime_status = "Implemented"
	var entries: Array[Dictionary] = [
		{
			"definition": implemented,
			"installed": true,
			"enabled": true,
			"automatically_added": false,
			"can_toggle": true,
			"can_configure": true,
			"has_relations": true
		},
		{
			"definition": selectable,
			"installed": false,
			"enabled": false,
			"selected_in_catalog": false,
			"automatically_added": false,
			"can_toggle": true,
			"can_configure": false,
			"has_relations": true,
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
			"can_configure": false,
			"has_relations": true
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
	var relations_button := implemented_header.get_child(3) as Button
	var settings_button := implemented_header.get_child(4) as Button
	_expect(icon_slot != null and icon_slot.get_child_count() == 1, "every capability card owns a dedicated icon slot")
	_expect(enabled_check.button_pressed and not enabled_check.disabled, "implemented capabilities can be toggled")
	_expect(not settings_button.disabled, "enabled implemented capability can open settings")
	_expect(not relations_button.disabled, "capability with a relationship can open its relation view")
	enabled_check.toggled.emit(false)
	settings_button.pressed.emit()
	relations_button.pressed.emit()
	_expect(focus_events == ["can_attack"], "relationship action focuses an installed capability")
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
	_expect(
		selection_events == ["true:can_dig"],
		"capability card adds its ID to the shared catalog selection"
	)
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
	var planned_relations := planned_header.get_child(3) as Button
	var planned_settings := planned_header.get_child(4) as Button
	_expect(planned_check.disabled and planned_state.text == "В разработке", "planned capabilities remain clearly unavailable")
	_expect(planned_settings.disabled, "planned capabilities cannot be configured")
	_expect(not planned_relations.disabled, "planned capabilities can still be explored through their relationships")
	planned_relations.pressed.emit()
	_expect(focus_events == ["can_attack", "can_fly"], "planned relationship browsing does not enable the mechanic")

	var recommendation_entries: Array[Dictionary] = [{
		"definition": recommended,
		"capability_id": "can_swim",
		"relation_type": "recommends",
		"explanation": "Это дополнит движение объекта.",
		"score": 90,
		"ready": true
	}]
	view.call("set_recommended_entries", recommendation_entries)
	_expect((view.get("_recommendation_section") as PanelContainer).visible, "context-aware suggestions appear in a dedicated panel")
	_expect(view.call("get_recommendation_card_count") == 1, "recommendation panel shows each ranked suggestion as a card")
	var recommendation_container := view.get("_recommendation_container") as HFlowContainer
	var recommendation_card := recommendation_container.get_child(0) as PanelContainer
	var recommendation_content := recommendation_card.get_child(0) as VBoxContainer
	_expect(recommendation_content.get_child_count() == 4, "recommendation card contains title, type, explanation and action")
	var recommendation_header := recommendation_content.get_child(0) as HBoxContainer
	var recommendation_name := recommendation_header.get_child(1) as Label
	var recommendation_type := recommendation_content.get_child(1) as Label
	var recommendation_reason := recommendation_content.get_child(2) as Label
	var recommendation_button := recommendation_content.get_child(3) as Button
	_expect(recommendation_name.text == "Плавание", "recommendation card shows the capability name")
	_expect(recommendation_type.text == "Рекомендуется вместе", "recommendation card identifies the typed relation")
	_expect(recommendation_reason.text.contains("движение объекта"), "recommendation explains why it fits without requiring a tooltip")
	_expect(recommendation_button.text == "Выбрать", "recommendation action only selects the capability")
	var batch_count_before_recommendation := batch_add_count
	recommendation_button.pressed.emit()
	_expect(
		selection_events == ["true:can_dig", "true:can_swim"],
		"recommendation joins the same multi-selection session as ordinary catalogue cards"
	)
	_expect(
		batch_add_count == batch_count_before_recommendation,
		"choosing a recommendation does not apply the batch automatically"
	)
	view.call("set_recommended_entries", [])
	_expect(not (view.get("_recommendation_section") as PanelContainer).visible, "recommendation strip hides when no candidates remain")

	var related_entries: Array[Dictionary] = [{
		"definition": planned,
		"relation_type": "recommends",
		"explanation": "Проверь связанное поведение.",
		"is_reverse": true,
		"ready": false
	}]
	view.call("set_related_entries", related_entries, "Атака", implemented)
	_expect((view.get("_related_map_button") as Button).visible, "focused relationships expose the interactive graph map")
	_expect((view.get("_related_section") as PanelContainer).visible, "related capabilities appear in a dedicated compact strip")
	_expect(view.call("get_related_button_count") == 1, "related strip contains one button per connected capability")
	var related_container := view.get("_related_container") as HFlowContainer
	var related_button := related_container.get_child(0) as Button
	_expect(related_button.text == "Полёт" and related_button.tooltip_text.contains("Проверь"), "related strip displays the mechanic name and relation explanation")
	related_button.pressed.emit()
	_expect(focus_events == ["can_attack", "can_fly", "can_fly"], "following a related suggestion moves focus without enabling it")
	view.call("set_related_entries", [])
	_expect(not (view.get("_related_map_button") as Button).visible, "relation map action hides when there is no focused relationship")
	_expect(not (view.get("_related_section") as PanelContainer).visible, "related strip hides when the focused capability has no links")

	var profile_recommendation_entries: Array[Dictionary] = [{
		"capability_id": "can_dig",
		"definition": selectable,
		"score": 86,
		"relation_type": "profile",
		"explanation": "Подходит профилю «Ресурс»: объект можно добывать.",
		"automatic_dependencies": PackedStringArray(["Здоровье"])
	}]
	view.call("set_recommended_entries", profile_recommendation_entries, "Дерево · Ресурс")
	var recommendation_section := view.get("_recommendation_section") as PanelContainer
	var profile_recommendation_container := view.get("_recommendation_container") as HFlowContainer
	_expect(recommendation_section.visible, "contextual recommendations appear when the controller provides compatible candidates")
	_expect(view.call("get_recommendation_card_count") == 1, "each recommendation has its own explanatory card")
	var profile_recommendation_card := profile_recommendation_container.get_child(0) as PanelContainer
	var profile_recommendation_content := profile_recommendation_card.get_child(0) as VBoxContainer
	_expect(profile_recommendation_content.get_child_count() == 5, "profile recommendation card contains title, type, explanation, dependency and action")
	var profile_recommendation_header := profile_recommendation_content.get_child(0) as HBoxContainer
	var profile_recommendation_name := profile_recommendation_header.get_child(1) as Label
	var profile_recommendation_type := profile_recommendation_content.get_child(1) as Label
	var profile_recommendation_reason := profile_recommendation_content.get_child(2) as Label
	var profile_recommendation_dependency := profile_recommendation_content.get_child(3) as Label
	var profile_recommendation_action := profile_recommendation_content.get_child(4) as Button
	_expect(profile_recommendation_name.text == "Можно копать", "recommendation card displays the capability name")
	_expect(profile_recommendation_type.text == "Для этого профиля", "recommendation card distinguishes profile suggestions from mechanic relations")
	_expect(profile_recommendation_reason.text.contains("Ресурс"), "recommendation reason is visible without opening a tooltip")
	_expect(profile_recommendation_dependency.text.contains("Здоровье"), "automatic dependency is visible before selection")
	_expect(profile_recommendation_action.text == "Выбрать", "recommendation action only selects the mechanic")
	profile_recommendation_action.pressed.emit()
	_expect(
		selection_events.back() == "true:can_dig",
		"choosing a recommendation adds it to the global selection session instead of the object immediately"
	)
	view.call("set_recommended_entries", [])
	_expect(not recommendation_section.visible, "recommendation section hides when there are no compatible suggestions")

	var preset_summaries: Array[Dictionary] = [{
		"id": "breakable_resource",
		"display_name": "Разрушаемый ресурс",
		"description": "Прочность, разрушение и добыча.",
		"ready_count": 3,
		"total_count": 3,
		"selected_count": 0,
		"is_custom": false
	}]
	view.call("set_preset_data", preset_summaries, {})
	var preset_section := view.get("_preset_section") as PanelContainer
	_expect(preset_section.visible, "catalog shows curated presets when they are available")
	_expect(view.call("get_preset_button_count") == 1, "preset panel creates one card per preset definition")
	var preset_container := view.get("_preset_container") as HFlowContainer
	var preset_button := preset_container.get_child(0) as Button
	_expect(preset_button.text.contains("Разрушаемый ресурс") and preset_button.text.contains("3/3"), "preset card shows its name and ready capability count")
	preset_button.toggled.emit(true)
	_expect(preset_events == ["breakable_resource"], "opening a preset requests its editable composition")

	var preset_detail: Dictionary = {
		"id": "breakable_resource",
		"display_name": "Разрушаемый ресурс",
		"description": "Прочность, разрушение и добыча.",
		"is_custom": false,
		"available_count": 1,
		"entries": [
			{
				"capability_id": "has_health",
				"display_name": "Здоровье",
				"description": "Запас прочности.",
				"ready": true,
				"installed": false,
				"selected": false,
				"can_select": true,
				"automatic_dependencies": PackedStringArray()
			},
			{
				"capability_id": "can_attack",
				"display_name": "Атака",
				"description": "Уже установлено.",
				"ready": true,
				"installed": true,
				"selected": false,
				"can_select": false,
				"blocked_reason": "Уже установлена."
			},
			{
				"capability_id": "can_be_harvested",
				"display_name": "Можно добывать",
				"description": "Будущая механика добычи.",
				"ready": false,
				"installed": false,
				"selected": false,
				"can_select": false,
				"blocked_reason": "Возможность ещё разрабатывается."
			}
		]
	}
	view.call("set_preset_data", preset_summaries, preset_detail)
	var preset_detail_panel := view.get("_preset_detail_panel") as PanelContainer
	var preset_detail_items := view.get("_preset_detail_items") as VBoxContainer
	_expect(preset_detail_panel.visible and preset_detail_items.get_child_count() == 3, "active preset exposes every capability for editing")
	var available_preset_row := preset_detail_items.get_child(0) as VBoxContainer
	var available_preset_check := available_preset_row.get_child(0) as CheckBox
	_expect(not available_preset_check.disabled and not available_preset_check.button_pressed, "ready preset item can be individually selected")
	available_preset_check.toggled.emit(true)
	_expect(selection_events.back() == "true:has_health", "preset checkbox uses the shared catalog selection session")
	var installed_preset_check := (preset_detail_items.get_child(1) as VBoxContainer).get_child(0) as CheckBox
	_expect(installed_preset_check.button_pressed and installed_preset_check.disabled, "installed preset item is visible but cannot be added twice")
	var planned_preset_check := (preset_detail_items.get_child(2) as VBoxContainer).get_child(0) as CheckBox
	_expect(planned_preset_check.disabled and not planned_preset_check.button_pressed, "unfinished preset item is visible but cannot be selected")
	var preset_select_all_button := view.get("_preset_select_all_button") as Button
	_expect(preset_select_all_button.text == "Отметить все доступные (1)" and not preset_select_all_button.disabled, "preset footer reports the number of compatible additions")
	preset_select_all_button.pressed.emit()
	_expect(preset_select_all_count == 1, "preset bulk selection is separate from final batch application")
	var duplicate_button := view.get("_preset_duplicate_button") as Button
	var update_button := view.get("_preset_update_button") as Button
	var delete_button := view.get("_preset_delete_button") as Button
	_expect(duplicate_button.visible and not update_button.visible and not delete_button.visible, "built-in presets can be duplicated but not overwritten or deleted")
	duplicate_button.pressed.emit()
	_expect(preset_action_events.back() == "duplicate:breakable_resource", "duplicate action targets the active built-in preset")

	var custom_summary: Array[Dictionary] = [{
		"id": "my_custom_bundle",
		"display_name": "Мой набор",
		"description": "Личный состав.",
		"ready_count": 2,
		"total_count": 2,
		"selected_count": 1,
		"is_custom": true
	}]
	var custom_detail: Dictionary = {
		"id": "my_custom_bundle",
		"display_name": "Мой набор",
		"description": "Личный состав.",
		"is_custom": true,
		"available_count": 1,
		"entries": []
	}
	view.call("set_preset_data", custom_summary, custom_detail)
	view.call("set_selected_count", 1)
	var create_button := view.get("_preset_create_button") as Button
	_expect(not create_button.disabled, "selected catalogue mechanics can be saved as a new preset")
	create_button.pressed.emit()
	_expect(preset_action_events.back() == "create:", "create action does not depend on the active preset")
	_expect(update_button.visible and not update_button.disabled and delete_button.visible, "custom presets can be updated and removed")
	update_button.pressed.emit()
	_expect(preset_action_events.back() == "update:my_custom_bundle", "update action targets the active custom preset")
	delete_button.pressed.emit()
	_expect(preset_action_events.back() == "delete:my_custom_bundle", "delete action targets the active custom preset")

	var preset_dialog = PresetDialogScript.new()
	root.add_child(preset_dialog)
	preset_dialog.call("configure", "Тестовый набор", "Мой набор", "Описание набора", "Создать")
	_expect(preset_dialog.call("get_display_name") == "Мой набор", "preset dialog restores the entered name")
	_expect(preset_dialog.call("get_description") == "Описание набора", "preset dialog restores the entered description")
	_expect(preset_dialog.get_ok_button().text == "Создать", "preset dialog shows a context-specific confirmation action")
	preset_dialog.queue_free()

	view.call("set_selected_count", 0)
	view.call("set_preset_data", [], {})
	_expect(not preset_section.visible and not preset_detail_panel.visible, "preset cards and detail panel hide when the catalog has no presets")

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


func _on_focus_requested(capability_id: String) -> void:
	focus_events.append(capability_id)


func _on_selection_toggled(selected: bool, capability_id: String) -> void:
	selection_events.append("%s:%s" % [str(selected).to_lower(), capability_id])


func _on_batch_add_requested() -> void:
	batch_add_count += 1


func _on_clear_selection_requested() -> void:
	clear_selection_count += 1


func _on_preset_requested(preset_id: String) -> void:
	preset_events.append(preset_id)


func _on_preset_select_all_requested() -> void:
	preset_select_all_count += 1


func _on_preset_action_requested(action: String, preset_id: String) -> void:
	preset_action_events.append("%s:%s" % [action, preset_id])


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
