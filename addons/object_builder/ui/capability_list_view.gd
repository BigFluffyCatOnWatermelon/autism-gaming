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

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")
const CapabilityIconRegistryScript = preload("res://addons/object_builder/services/capability_icon_registry.gd")
const PAGE_SIZE := 20

var search_input: LineEdit
var category_option: OptionButton
var entries_container: VBoxContainer
var _entries_scroll: ScrollContainer
var _pagination_row: HBoxContainer
var _previous_page_button: Button
var _next_page_button: Button
var _page_label: Label
var _selection_bar: PanelContainer
var _related_section: PanelContainer
var _related_title: Label
var _related_container: HFlowContainer
var _selection_summary: Label
var _add_selected_button: Button
var _clear_selection_button: Button
var _entries: Array[Dictionary] = []
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

	category_option = OptionButton.new()
	category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_option.add_item("Все возможности")
	category_option.set_item_metadata(0, "")
	for category in categories:
		category_option.add_item(str(category.get("display_name", "")))
		category_option.set_item_metadata(
			category_option.item_count - 1,
			str(category.get("id", ""))
		)
	category_option.select(0)
	category_option.item_selected.connect(_on_category_selected)
	add_child(category_option)

	_build_selection_bar()
	_build_related_section()

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
	_related_title.text = "СВЯЗАННЫЕ ВОЗМОЖНОСТИ"
	_related_title.add_theme_font_size_override("font_size", 10)
	content.add_child(_related_title)

	_related_container = HFlowContainer.new()
	_related_container.add_theme_constant_override("h_separation", 5)
	_related_container.add_theme_constant_override("v_separation", 4)
	content.add_child(_related_container)


func set_related_entries(entries: Array[Dictionary], focused_name: String = "") -> void:
	if _related_container == null:
		return
	UIFactory.clear_children(_related_container)
	_related_section.visible = not entries.is_empty()
	if entries.is_empty():
		return
	_related_title.text = (
		"СВЯЗАНО С: " + focused_name.to_upper()
		if not focused_name.is_empty()
		else "СВЯЗАННЫЕ ВОЗМОЖНОСТИ"
	)
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


func get_related_button_count() -> int:
	return _related_container.get_child_count() if _related_container != null else 0


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
	_selection_summary.text = "Выбрано в разных разделах: %d" % _selected_count
	_add_selected_button.text = "Добавить выбранные (%d)" % _selected_count
	_add_selected_button.disabled = _selected_count <= 0
	_clear_selection_button.disabled = _selected_count <= 0


func get_selected_count() -> int:
	return _selected_count


func show_empty_state(message: String) -> void:
	_entries.clear()
	_page_index = 0
	_pagination_row.visible = false
	UIFactory.clear_children(entries_container)
	UIFactory.add_empty_state(entries_container, message)
	_entries_scroll.scroll_vertical = 0
	set_related_entries([])
	set_selected_count(_selected_count)


func set_entries(
	entries: Array[Dictionary],
	total_count: int,
	ready_count: int
) -> void:
	_entries = entries.duplicate()
	_entries_scroll.scroll_vertical = 0
	_total_count = total_count
	_ready_count = ready_count
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
	relations_button.text = "Связи"
	var has_relations := bool(entry.get("has_relations", false))
	relations_button.disabled = not has_relations
	relations_button.tooltip_text = (
		"Показать обязательные, рекомендуемые и другие связанные возможности"
		if has_relations
		else "Для этой возможности связи пока не заполнены."
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
