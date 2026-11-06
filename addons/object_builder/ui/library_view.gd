@tool
extends VBoxContainer
## Owns object-library controls. Filtering and definition selection remain in the plugin.

signal search_changed(query: String)
signal filter_changed(index: int)
signal object_selected(index: int)

var search_input: LineEdit
var mode_filter: OptionButton
var category_filter: OptionButton
var tag_filter: OptionButton
var object_list: ItemList


func build() -> void:
	if search_input != null:
		return
	custom_minimum_size = Vector2(210, 0)
	add_theme_constant_override("separation", 6)
	search_input = LineEdit.new()
	search_input.placeholder_text = "Найти объект…"
	search_input.clear_button_enabled = true
	search_input.text_changed.connect(_on_search_changed)
	add_child(search_input)
	mode_filter = OptionButton.new()
	mode_filter.add_item("Все объекты")
	mode_filter.set_item_metadata(0, "all")
	mode_filter.add_item("Избранное")
	mode_filter.set_item_metadata(1, "favorites")
	mode_filter.add_item("Недавние")
	mode_filter.set_item_metadata(2, "recent")
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
	object_list = ItemList.new()
	object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	object_list.item_selected.connect(_on_object_selected)
	add_child(object_list)
	set_category_options([], "")
	set_tag_options([], "")


func get_search_query() -> String:
	return search_input.text if search_input != null else ""


func get_selected_mode() -> String:
	return _get_selected_metadata(mode_filter, "all")


func get_selected_category() -> String:
	return _get_selected_metadata(category_filter, "")


func get_selected_tag() -> String:
	return _get_selected_metadata(tag_filter, "")


func set_category_options(options: Array[Dictionary], selected_value: String) -> void:
	_set_filter_options(category_filter, "Все категории", options, selected_value)


func set_tag_options(options: Array[Dictionary], selected_value: String) -> void:
	_set_filter_options(tag_filter, "Все теги", options, selected_value)


func set_entries(entries: Array[Dictionary], empty_message: String) -> void:
	object_list.clear()
	for entry in entries:
		object_list.add_item(str(entry.get("title", "")))
		object_list.set_item_tooltip(object_list.item_count - 1, str(entry.get("tooltip", "")))
	if entries.is_empty():
		object_list.add_item(empty_message)
		object_list.set_item_disabled(0, true)


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
	filter_changed.emit(index)


func _on_object_selected(index: int) -> void:
	object_selected.emit(index)
