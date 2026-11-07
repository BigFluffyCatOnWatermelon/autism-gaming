@tool
extends VBoxContainer
## Displays capability catalog entries and forwards user actions to the editor controller.

signal search_changed(query: String)
signal category_changed(category_id: String)
signal toggle_requested(enabled: bool, capability_id: String)
signal settings_requested(capability_id: String)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")
const PAGE_SIZE := 20

var search_input: LineEdit
var category_option: OptionButton
var entries_container: VBoxContainer
var _pagination_row: HBoxContainer
var _previous_page_button: Button
var _next_page_button: Button
var _page_label: Label
var _entries: Array[Dictionary] = []
var _page_index := 0
var _total_count := 0
var _ready_count := 0


func build(categories: Array[Dictionary]) -> void:
	if search_input != null:
		return
	UIFactory.create_section_title(self, "ЧТО ДОЛЖЕН УМЕТЬ ОБЪЕКТ?", 16)

	var hint := Label.new()
	hint.text = "Выбирай возможности обычными словами. Нужные игровые системы плагин подключит сам."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Найти возможность…"
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

	entries_container = VBoxContainer.new()
	entries_container.add_theme_constant_override("separation", 6)
	add_child(entries_container)

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


func get_search_query() -> String:
	return search_input.text if search_input != null else ""


func get_selected_category() -> String:
	if category_option == null or category_option.selected < 0:
		return ""
	return str(category_option.get_item_metadata(category_option.selected))


func show_empty_state(message: String) -> void:
	_entries.clear()
	_page_index = 0
	_pagination_row.visible = false
	UIFactory.clear_children(entries_container)
	UIFactory.add_empty_state(entries_container, message)


func set_entries(
	entries: Array[Dictionary],
	total_count: int,
	ready_count: int
) -> void:
	_entries = entries.duplicate()
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

	var is_implemented := capability.is_ready()
	var is_enabled := bool(entry.get("enabled", false))
	var is_automatic := bool(entry.get("automatically_added", false))
	var enabled_check := CheckBox.new()
	enabled_check.text = capability.display_name
	if is_automatic:
		enabled_check.text += " · автоматически"
		enabled_check.tooltip_text = "Эта возможность нужна другой выбранной возможности. Её нельзя отключить, пока она используется."
	elif not is_implemented:
		enabled_check.tooltip_text = "Возможность есть в каталоге, но её реализация ещё не готова для использования."
	enabled_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enabled_check.button_pressed = is_enabled
	enabled_check.disabled = not bool(entry.get("can_toggle", is_implemented))
	if not enabled_check.disabled:
		enabled_check.toggled.connect(_on_toggle_requested.bind(capability.capability_id))
	card_header.add_child(enabled_check)

	var state_label := Label.new()
	state_label.text = "Готово" if is_implemented else "В разработке"
	state_label.tooltip_text = capability.implementation_note
	card_header.add_child(state_label)

	var settings_button := Button.new()
	settings_button.text = "Настроить"
	settings_button.disabled = not bool(entry.get("can_configure", is_enabled and is_implemented))
	settings_button.pressed.connect(_on_settings_requested.bind(capability.capability_id))
	card_header.add_child(settings_button)

	var description := Label.new()
	description.text = capability.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color(0.78, 0.78, 0.78)
	card_content.add_child(description)
	return card


func _on_search_changed(query: String) -> void:
	search_changed.emit(query)


func _on_category_selected(_index: int) -> void:
	category_changed.emit(get_selected_category())


func _on_toggle_requested(enabled: bool, capability_id: String) -> void:
	toggle_requested.emit(enabled, capability_id)


func _on_settings_requested(capability_id: String) -> void:
	settings_requested.emit(capability_id)
