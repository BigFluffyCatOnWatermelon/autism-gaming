@tool
extends VBoxContainer
## Owns object-library controls. Filtering and definition selection remain in the plugin.

const ObjectBuilderUIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

signal search_changed(query: String)
signal refresh_requested
signal filter_changed(index: int)
signal object_selected(index: int)
signal entry_action_requested(action: String, index: int)
signal collection_create_requested
signal collection_management_requested(action: String)

var search_input: LineEdit
var _refresh_button: Button
var mode_filter: OptionButton
var category_filter: OptionButton
var tag_filter: OptionButton
var object_list: ItemList
var _cards_scroll: ScrollContainer
var _cards_flow: HFlowContainer
var _card_mode_button: Button
var _list_mode_button: Button
var _entry_actions_button: Button
var _entry_actions_menu: PopupMenu
var _collection_management_menu: PopupMenu
var _collection_management_button: Button
var _collection_options: Array[Dictionary] = []
var _display_mode := "cards"
var _entries: Array[Dictionary] = []
var _selected_index := -1
var _empty_message := "Объекты не найдены"


func build() -> void:
	if search_input != null:
		return
	custom_minimum_size = Vector2(210, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 4)
	add_child(search_row)
	search_input = LineEdit.new()
	search_input.placeholder_text = "Найти объект…"
	search_input.clear_button_enabled = true
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_changed.connect(_on_search_changed)
	search_row.add_child(search_input)
	_refresh_button = Button.new()
	_refresh_button.text = "↻"
	_refresh_button.tooltip_text = "Пересканировать файлы проекта Godot и перечитать библиотеку"
	_refresh_button.custom_minimum_size = Vector2(34, 0)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	search_row.add_child(_refresh_button)
	mode_filter = OptionButton.new()
	mode_filter.add_item("Все объекты")
	mode_filter.set_item_metadata(0, "all")
	mode_filter.add_item("Избранное")
	mode_filter.set_item_metadata(1, "favorites")
	mode_filter.add_item("Недавние")
	mode_filter.set_item_metadata(2, "recent")
	mode_filter.add_item("Шаблоны")
	mode_filter.set_item_metadata(3, "templates")
	mode_filter.item_selected.connect(_on_filter_changed)
	add_child(mode_filter)
	category_filter = OptionButton.new()
	category_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_filter.item_selected.connect(_on_filter_changed)
	add_child(category_filter)
	tag_filter = OptionButton.new()
	tag_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_filter.item_selected.connect(_on_filter_changed)
	add_child(tag_filter)
	_build_view_mode_controls()
	_build_card_view()
	_build_list_view()
	set_display_mode("cards")
	set_category_options([], "")
	set_tag_options([], "")


func set_refreshing(is_refreshing: bool) -> void:
	if _refresh_button == null:
		return
	_refresh_button.disabled = is_refreshing
	_refresh_button.text = "…" if is_refreshing else "↻"


func _on_refresh_pressed() -> void:
	refresh_requested.emit()


func _build_view_mode_controls() -> void:
	var view_mode_row := HBoxContainer.new()
	view_mode_row.add_theme_constant_override("separation", 4)
	add_child(view_mode_row)
	_card_mode_button = Button.new()
	_card_mode_button.text = "Карточки"
	_card_mode_button.tooltip_text = "Показывать объекты с миниатюрами"
	_card_mode_button.toggle_mode = true
	_card_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_mode_button.pressed.connect(_on_card_mode_pressed)
	view_mode_row.add_child(_card_mode_button)
	_list_mode_button = Button.new()
	_list_mode_button.text = "Список"
	_list_mode_button.tooltip_text = "Показывать компактный список объектов"
	_list_mode_button.toggle_mode = true
	_list_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_mode_button.pressed.connect(_on_list_mode_pressed)
	view_mode_row.add_child(_list_mode_button)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(action_row)
	_entry_actions_button = Button.new()
	_entry_actions_button.text = "Действия…"
	_entry_actions_button.tooltip_text = "Действия над выбранной записью"
	_entry_actions_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_actions_button.disabled = true
	_entry_actions_button.pressed.connect(_show_entry_actions_menu)
	action_row.add_child(_entry_actions_button)

	var create_collection_button := Button.new()
	create_collection_button.text = "+ Коллекция"
	create_collection_button.tooltip_text = "Создать собственную подборку объектов"
	create_collection_button.pressed.connect(func() -> void:
		collection_create_requested.emit()
	)
	action_row.add_child(create_collection_button)

	_collection_management_button = Button.new()
	_collection_management_button.text = "⋯"
	_collection_management_button.tooltip_text = "Переименовать или удалить выбранную коллекцию"
	_collection_management_button.disabled = true
	_collection_management_button.pressed.connect(_show_collection_management_menu)
	action_row.add_child(_collection_management_button)
	_collection_management_menu = PopupMenu.new()
	_collection_management_menu.add_item("Переименовать коллекцию", 0)
	_collection_management_menu.add_item("Удалить коллекцию…", 1)
	_collection_management_menu.id_pressed.connect(_on_collection_management_item_selected)
	add_child(_collection_management_menu)

	_entry_actions_menu = PopupMenu.new()
	_entry_actions_menu.id_pressed.connect(_on_entry_action_selected)
	add_child(_entry_actions_menu)
	set_collection_options([], "all")


func _build_card_view() -> void:
	_cards_scroll = ScrollContainer.new()
	_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_scroll.custom_minimum_size = Vector2(0, 120)
	_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_cards_scroll)
	_cards_flow = HFlowContainer.new()
	_cards_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_cards_flow.add_theme_constant_override("h_separation", 6)
	_cards_flow.add_theme_constant_override("v_separation", 6)
	_cards_scroll.add_child(_cards_flow)


func _build_list_view() -> void:
	object_list = ItemList.new()
	object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	object_list.icon_mode = ItemList.ICON_MODE_LEFT
	object_list.fixed_icon_size = Vector2i(32, 32)
	object_list.max_text_lines = 2
	object_list.max_columns = 1
	object_list.item_selected.connect(_on_object_selected)
	object_list.item_clicked.connect(_on_list_item_clicked)
	add_child(object_list)


func get_search_query() -> String:
	return search_input.text if search_input != null else ""


func get_selected_mode() -> String:
	return _get_selected_metadata(mode_filter, "all")


func set_selected_mode(mode_id: String) -> void:
	_select_option_metadata(mode_filter, mode_id)


func get_selected_category() -> String:
	return _get_selected_metadata(category_filter, "")


func get_selected_tag() -> String:
	return _get_selected_metadata(tag_filter, "")


func get_display_mode() -> String:
	return _display_mode


func get_card_count() -> int:
	return _entries.size()


func get_selected_index() -> int:
	return _selected_index


func get_card_button(index: int) -> Button:
	if _cards_flow == null or index < 0 or index >= _cards_flow.get_child_count():
		return null
	return _cards_flow.get_child(index) as Button


func set_display_mode(mode: String) -> void:
	if mode not in ["cards", "list"]:
		return
	_display_mode = mode
	if _cards_scroll != null:
		_cards_scroll.visible = mode == "cards"
	if object_list != null:
		object_list.visible = mode == "list"
	if _card_mode_button != null:
		_card_mode_button.set_pressed_no_signal(mode == "cards")
	if _list_mode_button != null:
		_list_mode_button.set_pressed_no_signal(mode == "list")


func set_category_options(options: Array[Dictionary], selected_value: String) -> void:
	_set_filter_options(category_filter, "Все категории", options, selected_value)


func set_tag_options(options: Array[Dictionary], selected_value: String) -> void:
	_set_filter_options(tag_filter, "Все теги", options, selected_value)


func set_collection_options(options: Array[Dictionary], selected_value: String = "") -> void:
	var previous_mode := get_selected_mode() if selected_value.is_empty() else selected_value
	_collection_options = options.duplicate(true)
	mode_filter.clear()
	var base_modes := [
		{"label": "Все объекты", "id": "all"},
		{"label": "Избранное", "id": "favorites"},
		{"label": "Недавние", "id": "recent"},
		{"label": "Шаблоны", "id": "templates"}
	]
	for mode in base_modes:
		mode_filter.add_item(str(mode.label))
		mode_filter.set_item_metadata(mode_filter.item_count - 1, str(mode.id))
	for collection in _collection_options:
		mode_filter.add_item("Коллекция: " + str(collection.get("label", "Без названия")))
		mode_filter.set_item_metadata(mode_filter.item_count - 1, "collection:" + str(collection.get("id", "")))
	_select_option_metadata(mode_filter, previous_mode)
	_update_collection_management_state()


func _update_collection_management_state() -> void:
	if _collection_management_button != null:
		_collection_management_button.disabled = not get_selected_mode().begins_with("collection:")


func _show_collection_management_menu() -> void:
	if _collection_management_menu == null or _collection_management_button == null or _collection_management_button.disabled:
		return
	_collection_management_menu.position = DisplayServer.mouse_get_position()
	_collection_management_menu.reset_size()
	_collection_management_menu.popup()


func _on_collection_management_item_selected(action_id: int) -> void:
	if action_id == 0:
		collection_management_requested.emit("rename")
	elif action_id == 1:
		collection_management_requested.emit("delete")

func set_entries(entries: Array[Dictionary], empty_message: String) -> void:
	var previous_id := _get_selected_entry_id()
	_entries = entries.duplicate()
	_empty_message = empty_message
	_selected_index = -1
	if not previous_id.is_empty():
		for index in range(_entries.size()):
			if _get_entry_id(_entries[index]) == previous_id:
				_selected_index = index
				break
	_render_card_entries()
	_render_list_entries()
	if _selected_index >= 0 and _selected_index < object_list.item_count:
		object_list.select(_selected_index)
	_update_entry_actions_state()


func _render_card_entries() -> void:
	ObjectBuilderUIFactory.clear_children(_cards_flow)
	if _entries.is_empty():
		ObjectBuilderUIFactory.add_empty_state(_cards_flow, _empty_message)
		return
	for index in range(_entries.size()):
		var entry := _entries[index]
		var definition := entry.get("definition") as ObjectDefinition
		var card := Button.new()
		card.custom_minimum_size = Vector2(142, 156)
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.toggle_mode = true
		card.tooltip_text = str(entry.get("tooltip", ""))
		card.pressed.connect(_on_card_pressed.bind(index))
		card.gui_input.connect(_on_card_gui_input.bind(index))
		_cards_flow.add_child(card)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for margin_name in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + margin_name, 6)
		card.add_child(margin)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 4)
		margin.add_child(content)
		var image_host := CenterContainer.new()
		image_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image_host.custom_minimum_size = Vector2(0, 86)
		image_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(image_host)
		var preview: Texture2D = definition.preview_texture if definition != null else null
		if preview != null:
			var image := TextureRect.new()
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			image.texture = preview
			image.custom_minimum_size = Vector2(76, 76)
			image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image_host.add_child(image)
		else:
			var placeholder := Label.new()
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			placeholder.text = "Нет изображения"
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			image_host.add_child(placeholder)
		var title := Label.new()
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.text = str(entry.get("title", ""))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(title)
		var secondary := Label.new()
		secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if definition == null:
			secondary.text = ""
		elif definition.is_template:
			secondary.text = "Шаблон"
		else:
			secondary.text = str(entry.get("category_label", definition.category)) if not definition.category.is_empty() else "Объект"
		secondary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		secondary.add_theme_font_size_override("font_size", 10)
		secondary.modulate = Color(0.75, 0.75, 0.75)
		content.add_child(secondary)
	_update_card_selection()


func _render_list_entries() -> void:
	object_list.clear()
	for entry in _entries:
		var definition := entry.get("definition") as ObjectDefinition
		var preview: Texture2D = definition.preview_texture if definition != null else null
		var title := str(entry.get("title", ""))
		if definition != null and not definition.category.is_empty():
			title += "\n" + ("Шаблон" if definition.is_template else str(entry.get("category_label", definition.category)))
		object_list.add_item(title, preview)
		object_list.set_item_tooltip(object_list.item_count - 1, str(entry.get("tooltip", "")))
	if _entries.is_empty():
		object_list.add_item(_empty_message)
		object_list.set_item_disabled(0, true)


func _update_card_selection() -> void:
	if _cards_flow == null:
		return
	for index in range(_cards_flow.get_child_count()):
		var card := _cards_flow.get_child(index) as Button
		if card != null:
			card.set_pressed_no_signal(index == _selected_index)


func _set_filter_options(option: OptionButton, placeholder: String, options: Array[Dictionary], selected_value: String) -> void:
	if option == null:
		return
	option.clear()
	option.add_item(placeholder)
	option.set_item_metadata(0, "")
	for entry in options:
		option.add_item(str(entry.get("label", "")))
		option.set_item_metadata(option.item_count - 1, str(entry.get("id", "")))
	_select_option_metadata(option, selected_value)


func _get_selected_metadata(option: OptionButton, fallback: String) -> String:
	if option == null or option.selected < 0:
		return fallback
	return str(option.get_item_metadata(option.selected))


func _select_option_metadata(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.select(0)


func _on_search_changed(value: String) -> void:
	search_changed.emit(value)


func _on_filter_changed(index: int) -> void:
	_update_collection_management_state()
	filter_changed.emit(index)


func _on_object_selected(index: int) -> void:
	_selected_index = index
	_update_card_selection()
	_update_entry_actions_state()
	object_selected.emit(index)


func _on_card_pressed(index: int) -> void:
	_select_entry(index)
	object_selected.emit(index)


func _select_entry(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_selected_index = index
	_update_card_selection()
	if index < object_list.item_count:
		object_list.select(index)
	_update_entry_actions_state()


func _get_entry_id(entry: Dictionary) -> String:
	var definition := entry.get("definition") as ObjectDefinition
	return definition.object_id if definition != null else ""


func _get_selected_entry_id() -> String:
	if _selected_index < 0 or _selected_index >= _entries.size():
		return ""
	return _get_entry_id(_entries[_selected_index])


func _update_entry_actions_state() -> void:
	if _entry_actions_button != null:
		_entry_actions_button.disabled = _selected_index < 0 or _selected_index >= _entries.size()


func _show_entry_actions_menu() -> void:
	if _selected_index < 0 or _selected_index >= _entries.size() or _entry_actions_menu == null:
		return
	_rebuild_entry_actions_menu()
	_entry_actions_menu.position = DisplayServer.mouse_get_position()
	_entry_actions_menu.reset_size()
	_entry_actions_menu.popup()


func _rebuild_entry_actions_menu() -> void:
	_entry_actions_menu.clear()
	var selected_definition := _entries[_selected_index].get("definition") as ObjectDefinition
	_entry_actions_menu.add_item("Открыть", 0)
	_entry_actions_menu.add_item("Создать копию", 1)
	_entry_actions_menu.add_item("Создать шаблон из объекта", 2)
	_entry_actions_menu.set_item_disabled(_entry_actions_menu.get_item_index(2), selected_definition != null and selected_definition.is_template)
	_entry_actions_menu.add_separator()
	_entry_actions_menu.add_item("Переименовать", 3)
	_entry_actions_menu.add_item("Удалить…", 4)
	_entry_actions_menu.add_separator()
	_entry_actions_menu.add_item("Экспортировать .tres…", 5)
	_entry_actions_menu.add_item(
		"Убрать из избранного" if str(_entries[_selected_index].get("title", "")).begins_with("★ ") else "В избранное",
		7
	)
	if selected_definition != null and not selected_definition.is_template and not _collection_options.is_empty():
		_entry_actions_menu.add_separator()
		for index in range(_collection_options.size()):
			var collection: Dictionary = _collection_options[index]
			_entry_actions_menu.add_item("В коллекцию: " + str(collection.get("label", "Без названия")), 1000 + index)
	if selected_definition != null and not selected_definition.is_template and get_selected_mode().begins_with("collection:"):
		_entry_actions_menu.add_separator()
		_entry_actions_menu.add_item("Убрать из этой коллекции", 6)

func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_select_entry(index)
			_show_entry_actions_menu()


func _on_list_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_select_entry(index)
		_show_entry_actions_menu()


func _on_entry_action_selected(action_id: int) -> void:
	if _selected_index < 0 or _selected_index >= _entries.size():
		return
	var actions := {
		0: "open",
		1: "duplicate",
		2: "create_template",
		3: "rename",
		4: "delete",
		5: "export",
		6: "remove_from_collection",
		7: "toggle_favorite"
	}
	if action_id >= 1000:
		var collection_index := action_id - 1000
		if collection_index >= 0 and collection_index < _collection_options.size():
			var collection_id := str(_collection_options[collection_index].get("id", ""))
			entry_action_requested.emit("add_to_collection:" + collection_id, _selected_index)
		return
	if actions.has(action_id):
		entry_action_requested.emit(str(actions[action_id]), _selected_index)


func _on_card_mode_pressed() -> void:
	set_display_mode("cards")


func _on_list_mode_pressed() -> void:
	set_display_mode("list")
