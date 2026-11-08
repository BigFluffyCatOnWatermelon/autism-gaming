@tool
extends VBoxContainer
## Shows only enabled capabilities on the object's Settings tab.

signal configure_requested(capability_id: String)
signal focus_requested(capability_id: String)
signal map_requested(capability_ids: Array[String])

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

var _search: LineEdit
var _category: OptionButton
var _count_label: Label
var _map_button: Button
var _list: VBoxContainer
var _empty_label: Label
var _entries: Array[Dictionary] = []
var _empty_message := "У объекта пока нет включённых механик."


func build() -> void:
	if _list != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 7)
	UIFactory.create_section_title(self, "ВКЛЮЧЁННЫЕ МЕХАНИКИ", 16)

	var intro := Label.new()
	intro.text = "Здесь собраны только механики, уже подключённые к этому объекту. Открой настройки нужной механики или перейди к ней в каталоге."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.modulate = Color(0.78, 0.81, 0.86)
	add_child(intro)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 5)
	add_child(toolbar)

	_search = LineEdit.new()
	_search.placeholder_text = "Найти включённую механику…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_filter_changed)
	toolbar.add_child(_search)

	_category = OptionButton.new()
	_category.custom_minimum_size.x = 125
	_category.add_item("Все категории")
	_category.set_item_metadata(0, "")
	_category.item_selected.connect(_on_filter_changed)
	toolbar.add_child(_category)

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 8)
	add_child(summary_row)
	_count_label = Label.new()
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.vertical_alignment = Control.VERTICAL_ALIGNMENT_CENTER
	_count_label.modulate = Color(0.72, 0.77, 0.84)
	summary_row.add_child(_count_label)
	_map_button = Button.new()
	_map_button.text = "Карта включённых"
	_map_button.tooltip_text = "Открыть граф только тех механик, которые включены у текущего объекта."
	_map_button.disabled = true
	_map_button.pressed.connect(_on_map_pressed)
	summary_row.add_child(_map_button)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)

	_empty_label = Label.new()
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.modulate = Color(0.72, 0.77, 0.84)
	_empty_label.custom_minimum_size.y = 64
	_empty_label.visible = false
	add_child(_empty_label)


func set_entries(entries: Array[Dictionary], empty_message: String = "У объекта пока нет включённых механик.") -> void:
	build()
	_entries = entries.duplicate()
	_empty_message = empty_message
	_map_button.disabled = _entries.is_empty()
	_rebuild_category_options()
	_rebuild_list()


func _rebuild_category_options() -> void:
	var selected_id := ""
	if _category.selected >= 0:
		selected_id = str(_category.get_item_metadata(_category.selected))
	_category.clear()
	_category.add_item("Все категории")
	_category.set_item_metadata(0, "")
	var categories: Dictionary = {}
	for entry in _entries:
		var category_id := str(entry.get("category_id", "general"))
		var category_name := str(entry.get("category_name", "Основное"))
		categories[category_id] = category_name
	var category_ids: Array = categories.keys()
	category_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(categories[a]).naturalnocasecmp_to(str(categories[b])) < 0
	)
	for category_id in category_ids:
		_category.add_item(str(categories[category_id]))
		_category.set_item_metadata(_category.item_count - 1, str(category_id))
	for index in range(_category.item_count):
		if str(_category.get_item_metadata(index)) == selected_id:
			_category.select(index)
			return
	_category.select(0)


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.free()

	var query := _search.text.strip_edges().to_lower()
	var category_id := str(_category.get_item_metadata(_category.selected)) if _category.selected >= 0 else ""
	var grouped: Dictionary = {}
	var visible_count := 0
	for entry in _entries:
		var entry_category := str(entry.get("category_id", "general"))
		if not category_id.is_empty() and entry_category != category_id:
			continue
		var searchable := (
			str(entry.get("display_name", "")) + " " +
			str(entry.get("description", "")) + " " +
			str(entry.get("capability_id", ""))
		).to_lower()
		if not query.is_empty() and not searchable.contains(query):
			continue
		var category_name := str(entry.get("category_name", "Основное"))
		if not grouped.has(category_name):
			grouped[category_name] = []
		grouped[category_name].append(entry)
		visible_count += 1

	_count_label.text = "Включено: %d" % _entries.size()
	_empty_label.visible = visible_count == 0
	if _entries.is_empty():
		_empty_label.text = _empty_message
	elif visible_count == 0:
		_empty_label.text = "По этому запросу ничего не найдено. Измени поиск или категорию."

	if visible_count == 0:
		return

	var category_names: Array = grouped.keys()
	category_names.sort()
	for category_name in category_names:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 5)
		_list.add_child(section)
		var heading := Label.new()
		heading.text = str(category_name)
		heading.add_theme_font_size_override("font_size", 12)
		heading.modulate = Color(0.78, 0.84, 0.94)
		section.add_child(heading)
		var category_entries: Array = grouped[category_name]
		category_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
		)
		for entry in category_entries:
			_add_capability_row(section, entry)


func _add_capability_row(parent: Control, entry: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_value: Variant = entry.get("icon", null)
	if icon_value is Texture2D:
		icon_rect.texture = icon_value
	row.add_child(icon_rect)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)

	var title := Label.new()
	title.text = str(entry.get("display_name", entry.get("capability_id", "Механика")))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_column.add_child(title)

	var description := Label.new()
	description.text = str(entry.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 10)
	description.modulate = Color(0.72, 0.77, 0.84)
	description.max_lines_visible = 2
	text_column.add_child(description)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 3)
	row.add_child(actions)

	var configure_button := Button.new()
	configure_button.text = "Настроить"
	configure_button.tooltip_text = "Открыть параметры этой механики в Inspector."
	configure_button.pressed.connect(_on_configure_pressed.bind(str(entry.get("capability_id", ""))))
	actions.add_child(configure_button)

	var focus_button := Button.new()
	focus_button.text = "В каталоге"
	focus_button.flat = true
	focus_button.tooltip_text = "Перейти к этой механике в каталоге возможностей."
	focus_button.pressed.connect(_on_focus_pressed.bind(str(entry.get("capability_id", ""))))
	actions.add_child(focus_button)


func _on_filter_changed(_value: Variant = null) -> void:
	_rebuild_list()


func _on_map_pressed() -> void:
	var capability_ids: Array[String] = []
	for entry in _entries:
		var capability_id := str(entry.get("capability_id", "")).strip_edges().to_lower()
		if not capability_id.is_empty() and not capability_ids.has(capability_id):
			capability_ids.append(capability_id)
	map_requested.emit(capability_ids)


func _on_configure_pressed(capability_id: String) -> void:
	if not capability_id.is_empty():
		configure_requested.emit(capability_id)


func _on_focus_pressed(capability_id: String) -> void:
	if not capability_id.is_empty():
		focus_requested.emit(capability_id)
