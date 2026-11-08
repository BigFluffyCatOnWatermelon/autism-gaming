@tool
extends VBoxContainer
## Displays capability catalog entries and forwards all state changes to the controller.

signal search_changed(query: String)
signal category_changed(category_id: String)
signal toggle_requested(enabled: bool, capability_id: String)
signal settings_requested(capability_id: String)
signal focus_requested(capability_id: String)
signal selection_toggled(selected: bool, capability_id: String)
signal batch_add_requested
signal clear_selection_requested
signal preset_requested(preset_id: String)
signal preset_select_all_requested
signal preset_action_requested(action: String, preset_id: String)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")
const CapabilityIconRegistryScript = preload("res://addons/object_builder/services/capability_icon_registry.gd")
const RelationMapViewScript = preload("res://addons/object_builder/ui/capability_relation_map_view.gd")
const PAGE_SIZE := 20

var search_input: LineEdit
var category_option: OptionButton
var status_option: OptionButton
var sort_option: OptionButton
var _full_map_button: Button
var entries_container: VBoxContainer
var _entries_scroll: ScrollContainer
var _pagination_row: HBoxContainer
var _previous_page_button: Button
var _next_page_button: Button
var _page_label: Label
var _selection_bar: PanelContainer
var _related_section: PanelContainer
var _related_title: Label
var _focused_description: Label
var _focused_meta: Label
var _focused_requirements: Label
var _related_container: HFlowContainer
var _related_map_button: Button
var _related_entries: Array[Dictionary] = []
var _related_focused_definition: ObjectCapabilityDefinition
var _active_relation_map: RefCounted
var _recommendation_section: PanelContainer
var _recommendation_title: Label
var _recommendation_container: HFlowContainer
var _preset_section: PanelContainer
var _preset_container: HFlowContainer
var _preset_detail_panel: PanelContainer
var _preset_detail_title: Label
var _preset_detail_description: Label
var _preset_detail_items: VBoxContainer
var _preset_select_all_button: Button
var _preset_create_button: Button
var _preset_update_button: Button
var _preset_duplicate_button: Button
var _preset_delete_button: Button
var _active_preset_id := ""
var _selection_summary: Label
var _add_selected_button: Button
var _clear_selection_button: Button
var _entries: Array[Dictionary] = []
var _source_entries: Array[Dictionary] = []
var _page_index := 0
var _total_count := 0
var _ready_count := 0
var _selected_count := 0


func build(categories: Array[Dictionary]) -> void:
	if search_input != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIFactory.create_section_title(self, "КАТАЛОГ ВОЗМОЖНОСТЕЙ", 16)

	var hint := Label.new()
	hint.text = "Выбирай несколько возможностей подряд. Выбор не пропадёт при поиске и смене категорий."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Что должен уметь объект?"
	search_input.text_changed.connect(_on_search_changed)
	add_child(search_input)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 5)
	add_child(filter_row)

	category_option = OptionButton.new()
	category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_option.add_item("Все категории")
	category_option.set_item_metadata(0, "")
	for category in categories:
		category_option.add_item(str(category.get("display_name", "")))
		category_option.set_item_metadata(
			category_option.item_count - 1,
			str(category.get("id", ""))
		)
	category_option.select(0)
	category_option.item_selected.connect(_on_category_selected)
	category_option.tooltip_text = "Ограничить каталог выбранной категорией."
	filter_row.add_child(category_option)

	status_option = OptionButton.new()
	status_option.add_item("Любой статус", 0)
	status_option.add_item("Можно добавить", 1)
	status_option.add_item("Установлено", 2)
	status_option.add_item("Отключено", 3)
	status_option.add_item("В разработке", 4)
	status_option.add_item("Выбрано", 5)
	status_option.tooltip_text = "Показать только механики с выбранным состоянием."
	status_option.item_selected.connect(_on_status_filter_selected)
	filter_row.add_child(status_option)

	sort_option = OptionButton.new()
	sort_option.add_item("По релевантности", 0)
	sort_option.add_item("По алфавиту", 1)
	sort_option.add_item("Сначала готовые", 2)
	sort_option.tooltip_text = "Изменить порядок карточек, не меняя данные каталога."
	sort_option.item_selected.connect(_on_sort_selected)
	filter_row.add_child(sort_option)

	_full_map_button = Button.new()
	_full_map_button.text = "Открыть полную карту механик (200)"
	_full_map_button.tooltip_text = "Показать все механики, их категории и связи в одном графе. Поиск работает прямо на карте."
	_full_map_button.pressed.connect(_on_full_map_pressed)
	add_child(_full_map_button)

	_build_selection_bar()
	_build_related_section()
	_build_recommendation_section()
	_build_preset_section()

	_entries_scroll = ScrollContainer.new()
	_entries_scroll.custom_minimum_size = Vector2(0, 420)
	_entries_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entries_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_entries_scroll)

	entries_container = VBoxContainer.new()
	entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_container.add_theme_constant_override("separation", 6)
	_entries_scroll.add_child(entries_container)

	_pagination_row = HBoxContainer.new()
	_pagination_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pagination_row.visible = false
	_previous_page_button = Button.new()
	_previous_page_button.text = "← Назад"
	_previous_page_button.pressed.connect(_on_previous_page_pressed)
	_pagination_row.add_child(_previous_page_button)
	_page_label = Label.new()
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pagination_row.add_child(_page_label)
	_next_page_button = Button.new()
	_next_page_button.text = "Дальше →"
	_next_page_button.pressed.connect(_on_next_page_pressed)
	_pagination_row.add_child(_next_page_button)
	add_child(_pagination_row)


func _build_selection_bar() -> void:
	_selection_bar = PanelContainer.new()
	_selection_bar.visible = false
	add_child(_selection_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_selection_bar.add_child(row)

	_selection_summary = Label.new()
	_selection_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_selection_summary)

	_clear_selection_button = Button.new()
	_clear_selection_button.text = "Снять всё"
	_clear_selection_button.pressed.connect(_on_clear_selection_pressed)
	row.add_child(_clear_selection_button)

	_add_selected_button = Button.new()
	_add_selected_button.text = "Добавить выбранные (0)"
	_add_selected_button.disabled = true
	_add_selected_button.pressed.connect(_on_batch_add_pressed)
	row.add_child(_add_selected_button)


func _build_related_section() -> void:
	_related_section = PanelContainer.new()
	_related_section.visible = false
	add_child(_related_section)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_related_section.add_child(content)

	_related_title = Label.new()
	_related_title.text = "ПОДРОБНОСТИ МЕХАНИКИ"
	_related_title.add_theme_font_size_override("font_size", 10)
	content.add_child(_related_title)

	_focused_description = Label.new()
	_focused_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_focused_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_focused_description)

	_focused_meta = Label.new()
	_focused_meta.add_theme_font_size_override("font_size", 10)
	_focused_meta.modulate = Color(0.72, 0.76, 0.82)
	content.add_child(_focused_meta)

	_focused_requirements = Label.new()
	_focused_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_focused_requirements.add_theme_font_size_override("font_size", 10)
	content.add_child(_focused_requirements)

	_related_container = HFlowContainer.new()
	_related_container.add_theme_constant_override("h_separation", 5)
	_related_container.add_theme_constant_override("v_separation", 4)
	content.add_child(_related_container)

	_related_map_button = Button.new()
	_related_map_button.text = "Открыть интерактивную карту"
	_related_map_button.visible = false
	_related_map_button.pressed.connect(_on_relation_map_pressed)
	content.add_child(_related_map_button)


func _build_recommendation_section() -> void:
	_recommendation_section = PanelContainer.new()
	_recommendation_section.visible = false
	add_child(_recommendation_section)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_recommendation_section.add_child(content)

	_recommendation_title = Label.new()
	_recommendation_title.text = "ПОДХОДИТ ЭТОМУ ОБЪЕКТУ"
	_recommendation_title.add_theme_font_size_override("font_size", 10)
	content.add_child(_recommendation_title)

	_recommendation_container = HFlowContainer.new()
	_recommendation_container.add_theme_constant_override("h_separation", 5)
	_recommendation_container.add_theme_constant_override("v_separation", 4)
	content.add_child(_recommendation_container)


func _build_preset_section() -> void:
	_preset_section = PanelContainer.new()
	_preset_section.visible = false
	add_child(_preset_section)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_preset_section.add_child(content)

	var title := Label.new()
	title.text = "ГОТОВЫЕ НАБОРЫ"
	title.add_theme_font_size_override("font_size", 10)
	content.add_child(title)

	var hint := Label.new()
	hint.text = "Набор — это редактируемый список механик. Он ничего не добавляет в объект сам по себе."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	content.add_child(hint)

	_preset_create_button = Button.new()
	_preset_create_button.text = "Сохранить выбранное как набор"
	_preset_create_button.tooltip_text = "Создать пользовательский набор из отмеченных в каталоге возможностей."
	_preset_create_button.disabled = true
	_preset_create_button.pressed.connect(_on_preset_management_action_pressed.bind("create"))
	content.add_child(_preset_create_button)

	_preset_container = HFlowContainer.new()
	_preset_container.add_theme_constant_override("h_separation", 5)
	_preset_container.add_theme_constant_override("v_separation", 4)
	content.add_child(_preset_container)

	_preset_detail_panel = PanelContainer.new()
	_preset_detail_panel.visible = false
	content.add_child(_preset_detail_panel)

	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 4)
	_preset_detail_panel.add_child(detail_content)

	_preset_detail_title = Label.new()
	_preset_detail_title.add_theme_font_size_override("font_size", 12)
	detail_content.add_child(_preset_detail_title)

	_preset_detail_description = Label.new()
	_preset_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preset_detail_description.add_theme_font_size_override("font_size", 10)
	detail_content.add_child(_preset_detail_description)

	_preset_detail_items = VBoxContainer.new()
	_preset_detail_items.add_theme_constant_override("separation", 3)
	detail_content.add_child(_preset_detail_items)

	_preset_select_all_button = Button.new()
	_preset_select_all_button.text = "Отметить все доступные"
	_preset_select_all_button.pressed.connect(_on_preset_select_all_pressed)
	detail_content.add_child(_preset_select_all_button)

	var management_row := HFlowContainer.new()
	management_row.add_theme_constant_override("h_separation", 5)
	management_row.add_theme_constant_override("v_separation", 4)
	detail_content.add_child(management_row)

	_preset_update_button = Button.new()
	_preset_update_button.text = "Обновить состав"
	_preset_update_button.tooltip_text = "Заменить состав пользовательского набора текущим выделением в каталоге."
	_preset_update_button.visible = false
	_preset_update_button.pressed.connect(_on_preset_management_action_pressed.bind("update"))
	management_row.add_child(_preset_update_button)

	_preset_duplicate_button = Button.new()
	_preset_duplicate_button.text = "Дублировать"
	_preset_duplicate_button.tooltip_text = "Создать собственный набор на основе выбранного встроенного или пользовательского набора."
	_preset_duplicate_button.visible = false
	_preset_duplicate_button.pressed.connect(_on_preset_management_action_pressed.bind("duplicate"))
	management_row.add_child(_preset_duplicate_button)

	_preset_delete_button = Button.new()
	_preset_delete_button.text = "Удалить"
	_preset_delete_button.tooltip_text = "Удалить только пользовательский набор. Встроенные наборы защищены."
	_preset_delete_button.visible = false
	_preset_delete_button.pressed.connect(_on_preset_management_action_pressed.bind("delete"))
	management_row.add_child(_preset_delete_button)


func set_preset_data(
	presets: Array[Dictionary],
	active_preset: Dictionary = {}
) -> void:
	if _preset_container == null:
		return
	UIFactory.clear_children(_preset_container)
	_preset_section.visible = not presets.is_empty()
	var active_id := str(active_preset.get("id", ""))
	_active_preset_id = active_id
	for preset in presets:
		var preset_id := str(preset.get("id", ""))
		var display_name := str(preset.get("display_name", preset_id))
		if bool(preset.get("is_custom", false)):
			display_name = "Мой набор · " + display_name
		var ready_count := int(preset.get("ready_count", 0))
		var total_count := int(preset.get("total_count", 0))
		var selected_count := int(preset.get("selected_count", 0))
		var preset_button := Button.new()
		preset_button.text = "%s · %d/%d" % [display_name, ready_count, total_count]
		if selected_count > 0:
			preset_button.text += " · отмечено %d" % selected_count
		preset_button.tooltip_text = str(preset.get("description", ""))
		preset_button.toggle_mode = true
		preset_button.button_pressed = preset_id == active_id
		preset_button.toggled.connect(_on_preset_toggled.bind(preset_id))
		_preset_container.add_child(preset_button)

	_preset_detail_panel.visible = not active_preset.is_empty()
	if active_preset.is_empty():
		_active_preset_id = ""
		UIFactory.clear_children(_preset_detail_items)
		_preset_select_all_button.disabled = true
		_preset_update_button.visible = false
		_preset_duplicate_button.visible = false
		_preset_delete_button.visible = false
		return

	var is_custom := bool(active_preset.get("is_custom", false))
	_preset_update_button.visible = is_custom
	_preset_update_button.disabled = _selected_count <= 0
	_preset_duplicate_button.visible = true
	_preset_duplicate_button.disabled = false
	_preset_delete_button.visible = is_custom
	_preset_delete_button.disabled = false
	_preset_detail_title.text = str(active_preset.get("display_name", "Набор"))
	_preset_detail_description.text = str(active_preset.get("description", ""))
	UIFactory.clear_children(_preset_detail_items)
	var entries: Array = active_preset.get("entries", [])
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		_preset_detail_items.add_child(row)

		var choice := CheckBox.new()
		choice.text = str(entry.get("display_name", entry.get("capability_id", "")))
		choice.button_pressed = bool(entry.get("selected", false)) or bool(entry.get("installed", false))
		choice.disabled = (
			bool(entry.get("installed", false))
			or not bool(entry.get("can_select", false))
			and not bool(entry.get("selected", false))
		)
		var capability_id := str(entry.get("capability_id", ""))
		choice.tooltip_text = str(entry.get("description", ""))
		if not str(entry.get("blocked_reason", "")).is_empty():
			choice.tooltip_text = str(entry.get("blocked_reason", ""))
		var dependencies: PackedStringArray = entry.get("automatic_dependencies", PackedStringArray())
		if not dependencies.is_empty():
			choice.tooltip_text += "\nПотребуется также: " + ", ".join(dependencies)
		choice.toggled.connect(_on_selection_toggled.bind(capability_id))
		row.add_child(choice)

		var status_text := ""
		if bool(entry.get("installed", false)):
			status_text = "Уже установлено"
		elif bool(entry.get("selected", false)):
			status_text = "Выбрано в каталоге"
		elif not bool(entry.get("ready", false)):
			status_text = str(entry.get("blocked_reason", "Ещё в разработке"))
		elif not bool(entry.get("can_select", false)):
			status_text = str(entry.get("blocked_reason", "Недоступно в текущем сочетании"))
		elif not dependencies.is_empty():
			status_text = "Добавится вместе с: " + ", ".join(dependencies)
		if not status_text.is_empty():
			var status := Label.new()
			status.text = status_text
			status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			status.add_theme_font_size_override("font_size", 10)
			status.modulate = Color(0.72, 0.76, 0.82)
			row.add_child(status)

	_preset_select_all_button.text = "Отметить все доступные (%d)" % int(active_preset.get("available_count", 0))
	_preset_select_all_button.disabled = int(active_preset.get("available_count", 0)) <= 0


func get_preset_button_count() -> int:
	return _preset_container.get_child_count() if _preset_container != null else 0


func get_preset_item_count() -> int:
	return _preset_detail_items.get_child_count() if _preset_detail_items != null else 0


func set_recommended_entries(
	entries: Array[Dictionary],
	context_title: String = ""
) -> void:
	if _recommendation_container == null:
		return
	UIFactory.clear_children(_recommendation_container)
	_recommendation_section.visible = not entries.is_empty()
	if entries.is_empty():
		return

	_recommendation_title.text = (
		"ПОДХОДИТ: " + context_title.to_upper()
		if not context_title.is_empty()
		else "ПОДХОДИТ ЭТОМУ ОБЪЕКТУ"
	)
	for entry in entries:
		var capability := entry.get("definition") as ObjectCapabilityDefinition
		if capability == null:
			continue

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(224, 0)
		_recommendation_container.add_child(card)

		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		card.add_child(content)

		var header := HBoxContainer.new()
		content.add_child(header)

		var icon_texture := TextureRect.new()
		icon_texture.custom_minimum_size = Vector2(32, 32)
		icon_texture.custom_maximum_size = Vector2(32, 32)
		icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture.texture = CapabilityIconRegistryScript.get_icon(capability)
		header.add_child(icon_texture)

		var name_label := Label.new()
		name_label.text = capability.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(name_label)

		var relation_type := str(entry.get("relation_type", "related"))
		var type_label := Label.new()
		type_label.text = _get_relation_caption(relation_type)
		type_label.modulate = _get_relation_color(relation_type)
		type_label.add_theme_font_size_override("font_size", 10)
		content.add_child(type_label)

		var explanation := str(entry.get("explanation", "")).strip_edges()
		var explanation_label := Label.new()
		explanation_label.text = explanation if not explanation.is_empty() else "Подходит к текущему набору возможностей."
		explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		explanation_label.custom_minimum_size = Vector2(0, 36)
		explanation_label.add_theme_font_size_override("font_size", 11)
		content.add_child(explanation_label)

		var dependency_names: PackedStringArray = entry.get("automatic_dependencies", PackedStringArray())
		if not dependency_names.is_empty():
			var dependency_label := Label.new()
			dependency_label.text = "Понадобится также: " + ", ".join(dependency_names)
			dependency_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dependency_label.add_theme_font_size_override("font_size", 10)
			dependency_label.modulate = Color(0.8, 0.78, 0.66)
			content.add_child(dependency_label)

		var select_button := Button.new()
		select_button.text = "Выбрать"
		select_button.tooltip_text = explanation_label.text + "\nМеханика попадёт в общий список выбора, но не добавится в объект сразу."
		select_button.pressed.connect(_on_selection_toggled.bind(true, capability.capability_id))
		content.add_child(select_button)


func get_recommendation_button_count() -> int:
	if _recommendation_container == null:
		return 0
	var count := 0
	for child in _recommendation_container.get_children():
		if child is PanelContainer:
			count += 1
	return count


func get_recommendation_card_count() -> int:
	return get_recommendation_button_count()


func set_related_entries(
	entries: Array[Dictionary],
	focused_name: String = "",
	focused_definition: ObjectCapabilityDefinition = null
) -> void:
	if _related_container == null:
		return
	_related_entries = entries.duplicate()
	_related_focused_definition = focused_definition
	UIFactory.clear_children(_related_container)
	var has_focus := focused_definition != null
	_related_section.visible = has_focus or not entries.is_empty()
	_related_map_button.visible = not entries.is_empty() and has_focus
	_focused_description.visible = has_focus
	_focused_meta.visible = has_focus
	_focused_requirements.visible = has_focus
	if has_focus:
		_related_title.text = "ПОДРОБНОСТИ: " + focused_name.to_upper()
		_focused_description.text = focused_definition.description
		_focused_meta.text = "%s · %s · %d связей" % [
			"Готова к использованию" if focused_definition.is_ready() else "В разработке",
			focused_definition.category_name,
			focused_definition.relations.size()
		]
		var requirement_names := _get_capability_names(focused_definition.required_capability_ids)
		var conflict_names := _get_capability_names(focused_definition.incompatible_capability_ids)
		var relation_requirements := PackedStringArray()
		var relation_conflicts := PackedStringArray()
		for relation in focused_definition.relations:
			var relation_type := str(relation.get("type", "")).to_lower()
			var target_id := str(relation.get("target_id", ""))
			if relation_type == "requires" and not relation_requirements.has(target_id):
				relation_requirements.append(target_id)
			elif relation_type == "conflicts" and not relation_conflicts.has(target_id):
				relation_conflicts.append(target_id)
		for name in _get_capability_names(relation_requirements):
			if not requirement_names.has(name):
				requirement_names.append(name)
		for name in _get_capability_names(relation_conflicts):
			if not conflict_names.has(name):
				conflict_names.append(name)
		var requirement_text := "Требуется: " + ", ".join(requirement_names) if not requirement_names.is_empty() else ""
		var conflict_text := "Конфликтует: " + ", ".join(conflict_names) if not conflict_names.is_empty() else ""
		_focused_requirements.text = "\n".join(PackedStringArray([requirement_text, conflict_text]).filter(func(value: String) -> bool: return not value.is_empty()))
	else:
		_related_title.text = "СВЯЗАННЫЕ ВОЗМОЖНОСТИ"
		_focused_description.text = ""
		_focused_meta.text = ""
		_focused_requirements.text = ""
	if entries.is_empty():
		return
	for entry in entries:
		var capability := entry.get("definition") as ObjectCapabilityDefinition
		if capability == null:
			continue
		var relation_button := Button.new()
		relation_button.text = capability.display_name
		relation_button.custom_minimum_size = Vector2(130, 30)
		relation_button.icon = CapabilityIconRegistryScript.get_icon(capability)
		var relation_type := str(entry.get("relation_type", "related"))
		var tooltip := _get_relation_caption(relation_type)
		var explanation := str(entry.get("explanation", ""))
		if bool(entry.get("is_reverse", false)):
			tooltip += "\nСвязано с выбранной механикой."
		if not explanation.is_empty():
			tooltip += "\n" + explanation
		if not bool(entry.get("ready", capability.is_ready())):
			tooltip += "\nМеханика ещё в разработке, можно изучить её связь."
		relation_button.tooltip_text = tooltip
		relation_button.pressed.connect(_on_focus_requested.bind(capability.capability_id))
		_related_container.add_child(relation_button)


func _get_capability_names(capability_ids: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for capability_id in capability_ids:
		var definition := ObjectCapabilityCatalog.get_definition_reference(str(capability_id))
		if definition != null and not result.has(definition.display_name):
			result.append(definition.display_name)
	return result


func get_related_button_count() -> int:
	return _related_container.get_child_count() if _related_container != null else 0


func _on_full_map_pressed() -> void:
	if _active_relation_map == null:
		_active_relation_map = RelationMapViewScript.new()
	var focus_callback := Callable(self, "_on_focus_requested")
	if not _active_relation_map.is_connected("focus_requested", focus_callback):
		_active_relation_map.connect("focus_requested", focus_callback)
	var focused_id := (
		_related_focused_definition.capability_id
		if _related_focused_definition != null
		else ""
	)
	_active_relation_map.call("open_full", self, focused_id)


func _on_relation_map_pressed() -> void:
	if _related_focused_definition == null or _related_entries.is_empty():
		return
	if _active_relation_map == null:
		_active_relation_map = RelationMapViewScript.new()
	var focus_callback := Callable(self, "_on_focus_requested")
	if not _active_relation_map.is_connected("focus_requested", focus_callback):
		_active_relation_map.connect("focus_requested", focus_callback)
	_active_relation_map.call("open", self, _related_focused_definition, _related_entries)


func get_search_query() -> String:
	return search_input.text if search_input != null else ""


func get_selected_category() -> String:
	if category_option == null or category_option.selected < 0:
		return ""
	return str(category_option.get_item_metadata(category_option.selected))


func set_selected_count(count: int) -> void:
	_selected_count = maxi(0, count)
	if _selection_bar == null:
		return
	_selection_bar.visible = _selected_count > 0
	if _preset_create_button != null:
		_preset_create_button.disabled = _selected_count <= 0
	if _preset_update_button != null:
		_preset_update_button.disabled = _selected_count <= 0
	_selection_summary.text = "Выбрано в разных разделах: %d" % _selected_count
	_add_selected_button.text = "Добавить выбранные (%d)" % _selected_count
	_add_selected_button.disabled = _selected_count <= 0
	_clear_selection_button.disabled = _selected_count <= 0


func get_selected_count() -> int:
	return _selected_count


func show_empty_state(message: String) -> void:
	_entries.clear()
	_source_entries.clear()
	_page_index = 0
	_pagination_row.visible = false
	UIFactory.clear_children(entries_container)
	UIFactory.add_empty_state(entries_container, message)
	_entries_scroll.scroll_vertical = 0
	set_related_entries([])
	set_recommended_entries([])
	set_preset_data([])
	set_selected_count(_selected_count)


func set_entries(
	entries: Array[Dictionary],
	total_count: int,
	ready_count: int
) -> void:
	_source_entries = entries.duplicate()
	_total_count = total_count
	_ready_count = ready_count
	_apply_view_filters()
	_entries_scroll.scroll_vertical = 0
	_page_index = 0
	_render_current_page()


func _apply_view_filters() -> void:
	_entries.clear()
	for entry in _source_entries:
		var capability := entry.get("definition") as ObjectCapabilityDefinition
		if capability == null:
			continue
		var enabled := bool(entry.get("enabled", false))
		var installed := bool(entry.get("installed", enabled))
		var selected := bool(entry.get("selected_in_catalog", false))
		var ready := capability.is_ready()
		var matches := true
		var status_filter := status_option.selected if status_option != null else 0
		match status_filter:
			1:
				matches = ready and not installed
			2:
				matches = installed and enabled
			3:
				matches = installed and not enabled
			4:
				matches = not ready
			5:
				matches = selected
		if matches:
			_entries.append(entry)

	if sort_option != null and sort_option.selected == 1:
		_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var left := a.get("definition") as ObjectCapabilityDefinition
			var right := b.get("definition") as ObjectCapabilityDefinition
			return left.display_name.naturalnocasecmp_to(right.display_name) < 0
		)
	elif sort_option != null and sort_option.selected == 2:
		_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var left := a.get("definition") as ObjectCapabilityDefinition
			var right := b.get("definition") as ObjectCapabilityDefinition
			if left.is_ready() != right.is_ready():
				return left.is_ready()
			return left.display_name.naturalnocasecmp_to(right.display_name) < 0
		)


func _on_status_filter_selected(_index: int) -> void:
	_apply_view_filters()
	_page_index = 0
	_render_current_page()


func _on_sort_selected(_index: int) -> void:
	_apply_view_filters()
	_page_index = 0
	_render_current_page()


func _render_current_page() -> void:
	UIFactory.clear_children(entries_container)
	var summary := Label.new()
	summary.text = "Механик в библиотеке: %d · доступно сейчас: %d" % [_total_count, _ready_count]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entries_container.add_child(summary)

	if _entries.is_empty():
		UIFactory.add_empty_state(
			entries_container,
			"Ничего не найдено. Измени запрос или выбери другую категорию."
		)
		_pagination_row.visible = false
		set_selected_count(_selected_count)
		return

	var page_count := maxi(1, ceili(float(_entries.size()) / float(PAGE_SIZE)))
	_page_index = clampi(_page_index, 0, page_count - 1)
	var start_index := _page_index * PAGE_SIZE
	var end_index := mini(start_index + PAGE_SIZE, _entries.size())
	for index in range(start_index, end_index):
		var entry := _entries[index]
		var capability := entry.get("definition") as ObjectCapabilityDefinition
		if capability == null:
			continue
		entries_container.add_child(_create_capability_card(capability, entry))

	_pagination_row.visible = page_count > 1
	_previous_page_button.disabled = _page_index <= 0
	_next_page_button.disabled = _page_index >= page_count - 1
	_page_label.text = "Страница %d из %d · %d возможностей" % [
		_page_index + 1,
		page_count,
		_entries.size()
	]
	set_selected_count(_selected_count)


func _on_previous_page_pressed() -> void:
	if _page_index <= 0:
		return
	_page_index -= 1
	_render_current_page()


func _on_next_page_pressed() -> void:
	var page_count := maxi(1, ceili(float(_entries.size()) / float(PAGE_SIZE)))
	if _page_index >= page_count - 1:
		return
	_page_index += 1
	_render_current_page()


func _create_capability_card(
	capability: ObjectCapabilityDefinition,
	entry: Dictionary
) -> PanelContainer:
	var card := PanelContainer.new()
	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 3)
	card.add_child(card_content)

	var card_header := HBoxContainer.new()
	card_content.add_child(card_header)

	var icon_slot := PanelContainer.new()
	icon_slot.custom_minimum_size = Vector2(40, 40)
	var icon_texture := TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(36, 36)
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.texture = CapabilityIconRegistryScript.get_icon(capability)
	if icon_texture.texture == null:
		var fallback_label := Label.new()
		fallback_label.text = capability.display_name.left(1).to_upper()
		fallback_label.add_theme_font_size_override("font_size", 18)
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_slot.add_child(fallback_label)
	else:
		icon_slot.add_child(icon_texture)
	card_header.add_child(icon_slot)

	var is_ready := capability.is_ready()
	var is_enabled := bool(entry.get("enabled", false))
	var is_installed := bool(entry.get("installed", is_enabled))
	var is_automatic := bool(entry.get("automatically_added", false))
	var is_selected := bool(entry.get("selected_in_catalog", false))
	var choice_check := CheckBox.new()
	choice_check.text = capability.display_name
	choice_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if is_enabled:
		choice_check.button_pressed = true
		choice_check.disabled = not bool(entry.get("can_toggle", false))
		if is_automatic:
			choice_check.tooltip_text = "Эта возможность нужна другой выбранной возможности. Сначала отключи зависящие от неё возможности."
		elif not choice_check.disabled:
			choice_check.tooltip_text = "Уже установлена. Сними отметку, чтобы отключить её."
		if not choice_check.disabled:
			choice_check.toggled.connect(_on_toggle_requested.bind(capability.capability_id))
	else:
		choice_check.button_pressed = is_selected
		choice_check.disabled = not is_ready
		if not is_ready:
			choice_check.tooltip_text = "Возможность видна в каталоге, но её реализация ещё не готова."
		else:
			choice_check.tooltip_text = "Отметь несколько возможностей, затем добавь весь набор одной командой."
			choice_check.toggled.connect(_on_selection_toggled.bind(capability.capability_id))
	card_header.add_child(choice_check)

	var state_label := Label.new()
	if is_enabled:
		state_label.text = "Установлено"
	elif is_installed:
		state_label.text = "Отключено"
	elif is_selected:
		state_label.text = "Выбрано"
	else:
		state_label.text = "Готово" if is_ready else "В разработке"
	state_label.tooltip_text = capability.implementation_note
	card_header.add_child(state_label)

	var relations_button := Button.new()
	relations_button.text = "Подробнее"
	var has_relations := bool(entry.get("has_relations", false))
	relations_button.disabled = false
	relations_button.tooltip_text = (
		"Открыть описание, готовность, зависимости и связи механики"
		if has_relations
		else "Открыть описание и сведения о механике."
	)
	relations_button.pressed.connect(_on_focus_requested.bind(capability.capability_id))
	card_header.add_child(relations_button)

	var relation_value: Variant = entry.get("relation_highlight", {})
	if relation_value is Dictionary and not relation_value.is_empty():
		var relation: Dictionary = relation_value
		var relation_type := str(relation.get("type", "related"))
		var relation_label := Label.new()
		relation_label.text = _get_relation_caption(relation_type)
		if bool(relation.get("is_reverse", false)):
			relation_label.text += " · связано с выбранной"
		relation_label.tooltip_text = str(relation.get("explanation", ""))
		relation_label.add_theme_font_size_override("font_size", 10)
		relation_label.modulate = _get_relation_color(relation_type)
		card_content.add_child(relation_label)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.12, 0.15, 0.2, 0.92)
		card_style.border_width_left = 3
		card_style.border_color = _get_relation_color(relation_type)
		card_style.corner_radius_top_left = 5
		card_style.corner_radius_top_right = 5
		card_style.corner_radius_bottom_left = 5
		card_style.corner_radius_bottom_right = 5
		card.add_theme_stylebox_override("panel", card_style)

	var settings_button := Button.new()
	settings_button.text = "Настроить"
	settings_button.disabled = not bool(entry.get("can_configure", is_enabled and is_ready))
	settings_button.pressed.connect(_on_settings_requested.bind(capability.capability_id))
	card_header.add_child(settings_button)

	var description := Label.new()
	description.text = capability.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color(0.78, 0.78, 0.78)
	card_content.add_child(description)
	return card


func _get_relation_caption(relation_type: String) -> String:
	match relation_type:
		"profile":
			return "Для этого профиля"
		"requires":
			return "Обязательная зависимость"
		"recommends":
			return "Рекомендуется вместе"
		"extends":
			return "Расширяет поведение"
		"alternative":
			return "Альтернативный вариант"
		"conflicts":
			return "Несовместимая возможность"
		_:
			return "Связанная возможность"


func _get_relation_color(relation_type: String) -> Color:
	match relation_type:
		"profile":
			return Color(0.78, 0.72, 0.5)
		"requires":
			return Color(0.55, 0.75, 1.0)
		"recommends":
			return Color(0.55, 0.85, 0.65)
		"extends":
			return Color(0.78, 0.66, 0.95)
		"alternative":
			return Color(0.55, 0.82, 0.85)
		"conflicts":
			return Color(1.0, 0.54, 0.5)
		_:
			return Color(0.85, 0.78, 0.52)


func _on_preset_toggled(pressed: bool, preset_id: String) -> void:
	preset_requested.emit(preset_id if pressed else "")


func _on_preset_select_all_pressed() -> void:
	if not _preset_select_all_button.disabled:
		preset_select_all_requested.emit()


func _on_preset_management_action_pressed(action: String) -> void:
	if action == "create" or not _active_preset_id.is_empty():
		preset_action_requested.emit(action, _active_preset_id)


func _on_search_changed(query: String) -> void:
	search_changed.emit(query)


func _on_category_selected(_index: int) -> void:
	category_changed.emit(get_selected_category())


func _on_toggle_requested(enabled: bool, capability_id: String) -> void:
	toggle_requested.emit(enabled, capability_id)


func _on_selection_toggled(selected: bool, capability_id: String) -> void:
	selection_toggled.emit(selected, capability_id)


func _on_batch_add_pressed() -> void:
	if _selected_count > 0:
		batch_add_requested.emit()


func _on_clear_selection_pressed() -> void:
	if _selected_count > 0:
		clear_selection_requested.emit()


func _on_settings_requested(capability_id: String) -> void:
	settings_requested.emit(capability_id)


func _on_focus_requested(capability_id: String) -> void:
	focus_requested.emit(capability_id)
