@tool
extends VBoxContainer
## Displays the selected object summary inside the unified Properties inspector.

var _scroll: ScrollContainer
var _content: VBoxContainer
var _preview: TextureRect
var _name_label: Label
var _kind_label: Label
var _category_label: Label
var _id_label: Label
var _description_label: Label
var _tags_label: Label
var _capabilities_label: Label
var _dependencies_label: Label


func build() -> void:
	if _scroll != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# The workspace owns the single «СВОЙСТВА» header; do not duplicate it here.

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 5)
	_scroll.add_child(_content)

	var preview_host := CenterContainer.new()
	preview_host.custom_minimum_size = Vector2(0, 112)
	_content.add_child(preview_host)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(104, 104)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_host.add_child(_preview)

	_name_label = _make_label(16, true)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_name_label)
	_kind_label = _make_label(10)
	_content.add_child(_kind_label)
	_category_label = _make_label(10)
	_content.add_child(_category_label)
	_id_label = _make_label(10)
	_id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_id_label)

	_content.add_child(HSeparator.new())
	_add_section("ОПИСАНИЕ")
	_description_label = _make_label(11)
	_content.add_child(_description_label)
	_add_section("ТЕГИ")
	_tags_label = _make_label(10)
	_content.add_child(_tags_label)
	_add_section("ВОЗМОЖНОСТИ")
	_capabilities_label = _make_label(10)
	_content.add_child(_capabilities_label)
	_add_section("ЗАВИСИМОСТИ")
	_dependencies_label = _make_label(10)
	_content.add_child(_dependencies_label)
	set_details({})


func _make_label(font_size: int, strong: bool = false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if strong:
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	return label


func _add_section(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.86))
	_content.add_child(label)


func set_details(details: Dictionary) -> void:
	if _name_label == null:
		return
	var has_entry := not details.is_empty()
	visible = true
	if not has_entry:
		_preview.texture = null
		_name_label.text = "Объект не выбран"
		_kind_label.text = ""
		_category_label.text = ""
		_id_label.text = ""
		_description_label.text = "Выбери объект в библиотеке, чтобы увидеть его свойства."
		_tags_label.text = "—"
		_capabilities_label.text = "—"
		_dependencies_label.text = "—"
		return

	_preview.texture = details.get("preview_texture") as Texture2D
	_name_label.text = str(details.get("display_name", "Без названия"))
	_kind_label.text = "Шаблон" if bool(details.get("is_template", false)) else "Игровой объект"
	_category_label.text = "Категория: " + str(details.get("category", "—"))
	_id_label.text = "ID: " + str(details.get("object_id", "—"))
	_description_label.text = str(details.get("description", "")).strip_edges()
	if _description_label.text.is_empty():
		_description_label.text = "Описание не добавлено."
	_tags_label.text = str(details.get("tags_text", "—"))
	_capabilities_label.text = str(details.get("capabilities_text", "Пока не выбраны."))
	_dependencies_label.text = str(details.get("dependencies_text", "Нет обязательных зависимостей."))


func get_display_name_text() -> String:
	return _name_label.text if _name_label != null else ""


func get_capabilities_text() -> String:
	return _capabilities_label.text if _capabilities_label != null else ""


func get_dependencies_text() -> String:
	return _dependencies_label.text if _dependencies_label != null else ""
