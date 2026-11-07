@tool
extends VBoxContainer
## Owns the Object Builder workspace layout and panel visibility.
## Document data and editor actions remain in the plugin/controller layer.

signal layout_changed

const DEFAULT_LIBRARY_SPLIT := -260
const DEFAULT_INSPECTOR_SPLIT := -340
const MIN_INSPECTOR_WIDTH := 300

var _toolbar_actions: HBoxContainer
var _library_host: VBoxContainer
var _editor_host: VBoxContainer
var _inspector_host: VBoxContainer
var _library_panel: PanelContainer
var _inspector_panel: PanelContainer
var _diagnostics_panel: PanelContainer
var _library_split: HSplitContainer
var _content_split: HSplitContainer
var _library_toggle: Button
var _inspector_toggle: Button
var _diagnostics_toggle: Button
var _document_title: Label
var _document_name: Label
var _document_category: Label
var _document_kind: Label
var _document_state: Label
var _selection_name: Label
var _selection_path: Label
var _diagnostics_message: Label
var _diagnostics_severity: Label


func build() -> void:
	if _toolbar_actions != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(560, 280)
	add_theme_constant_override("separation", 6)
	_build_toolbar()
	_build_workspace_panels()
	_build_diagnostics_panel()


func _build_toolbar() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(toolbar)

	var brand := Label.new()
	brand.text = "Object Builder"
	brand.add_theme_font_size_override("font_size", 15)
	toolbar.add_child(brand)

	_document_title = Label.new()
	_document_title.text = "Библиотека объектов"
	_document_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_document_title.clip_text = true
	toolbar.add_child(_document_title)

	_toolbar_actions = HBoxContainer.new()
	_toolbar_actions.add_theme_constant_override("separation", 4)
	toolbar.add_child(_toolbar_actions)

	_library_toggle = _make_toggle_button("Библиотека", "Показать или скрыть список объектов")
	_library_toggle.button_pressed = true
	_library_toggle.pressed.connect(_on_library_toggle_pressed)
	toolbar.add_child(_library_toggle)

	_inspector_toggle = _make_toggle_button("Свойства", "Показать или скрыть контекстную панель")
	_inspector_toggle.button_pressed = true
	_inspector_toggle.pressed.connect(_on_inspector_toggle_pressed)
	toolbar.add_child(_inspector_toggle)

	_diagnostics_toggle = _make_toggle_button("Диагностика", "Показать или скрыть сообщения и ошибки")
	_diagnostics_toggle.button_pressed = false
	_diagnostics_toggle.pressed.connect(_on_diagnostics_toggle_pressed)
	toolbar.add_child(_diagnostics_toggle)


func _make_toggle_button(label_text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.tooltip_text = tooltip
	button.toggle_mode = true
	return button


func _build_workspace_panels() -> void:
	_library_split = HSplitContainer.new()
	_library_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_library_split.split_offset = DEFAULT_LIBRARY_SPLIT
	_library_split.dragged.connect(_on_split_dragged)
	add_child(_library_split)

	var library_parts := _create_panel(_library_split, "ОБЪЕКТЫ", 210.0)
	_library_panel = library_parts.get("panel") as PanelContainer
	_library_host = library_parts.get("host") as VBoxContainer

	_content_split = HSplitContainer.new()
	_content_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_split.split_offset = DEFAULT_INSPECTOR_SPLIT
	_content_split.dragged.connect(_on_split_dragged)
	_library_split.add_child(_content_split)

	var editor_parts := _create_panel(_content_split, "РЕДАКТОР", 180.0)
	_editor_host = editor_parts.get("host") as VBoxContainer
	var inspector_parts := _create_panel(_content_split, "СВОЙСТВА", MIN_INSPECTOR_WIDTH)
	_inspector_panel = inspector_parts.get("panel") as PanelContainer
	_inspector_host = inspector_parts.get("host") as VBoxContainer
	_build_inspector(_inspector_host)


func _create_panel(parent: Container, title_text: String, minimum_width: float) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minimum_width, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 11)
	content.add_child(title)
	content.add_child(HSeparator.new())

	var host := VBoxContainer.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(host)
	return {"panel": panel, "host": host}


func _build_inspector(host: VBoxContainer) -> void:
	host.add_theme_constant_override("separation", 5)
	_add_section(host, "ТЕКУЩИЙ ОБЪЕКТ")
	_document_name = _add_info_label(host, "Объект не выбран")
	_document_category = _add_info_label(host, "Категория: —")
	_document_kind = _add_info_label(host, "Тип: —")
	_document_state = _add_info_label(host, "Состояние: —")

	host.add_child(HSeparator.new())
	_add_section(host, "ВЫБРАННАЯ ЧАСТЬ")
	_selection_name = _add_info_label(host, "Ничего не выбрано")
	_selection_path = _add_info_label(host, "")
	_selection_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_path.add_theme_font_size_override("font_size", 10)

	host.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "Точные параметры выбранного узла доступны в штатном Inspector Godot и в расширенном режиме."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.75, 0.75, 0.75)
	host.add_child(hint)


func _add_section(parent: Container, section_title: String) -> void:
	var label := Label.new()
	label.text = section_title
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)


func _add_info_label(parent: Container, initial_text: String) -> Label:
	var label := Label.new()
	label.text = initial_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _build_diagnostics_panel() -> void:
	_diagnostics_panel = PanelContainer.new()
	_diagnostics_panel.custom_minimum_size = Vector2(0, 88)
	_diagnostics_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diagnostics_panel.visible = false
	add_child(_diagnostics_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	_diagnostics_panel.add_child(content)

	_diagnostics_severity = Label.new()
	_diagnostics_severity.text = "СООБЩЕНИЯ"
	_diagnostics_severity.add_theme_font_size_override("font_size", 11)
	content.add_child(_diagnostics_severity)

	_diagnostics_message = Label.new()
	_diagnostics_message.text = "Пока нет сообщений."
	_diagnostics_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_diagnostics_message)


func set_document_info(display_name: String, category: String, is_template: bool, is_dirty: bool) -> void:
	if _document_name == null:
		return
	if display_name.is_empty():
		_document_name.text = "Объект не выбран"
		_document_category.text = "Категория: —"
		_document_kind.text = "Тип: —"
		_document_state.text = "Состояние: —"
		_document_title.text = "Библиотека объектов"
		return
	_document_name.text = display_name
	_document_category.text = "Категория: " + (category if not category.is_empty() else "Без категории")
	_document_kind.text = "Тип: Шаблон" if is_template else "Тип: Игровой объект"
	_document_state.text = "Состояние: Есть изменения" if is_dirty else "Состояние: Сохранено"
	_document_title.text = display_name


func set_selection_info(node_name: String, node_path: String) -> void:
	if _selection_name == null:
		return
	_selection_name.text = node_name if not node_name.is_empty() else "Ничего не выбрано"
	_selection_path.text = node_path


func set_status(message: String, is_error: bool) -> void:
	if _diagnostics_message == null:
		return
	_diagnostics_message.text = message if not message.is_empty() else "Пока нет сообщений."
	_diagnostics_severity.text = "ОШИБКА" if is_error else "СООБЩЕНИЕ"
	if is_error:
		_diagnostics_severity.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		set_diagnostics_visible(true)
	else:
		_diagnostics_severity.remove_theme_color_override("font_color")


func set_library_visible(visible: bool, notify_layout: bool = true) -> void:
	if _library_panel == null:
		return
	_library_panel.visible = visible
	_library_toggle.set_pressed_no_signal(visible)
	if notify_layout:
		layout_changed.emit()


func set_inspector_visible(visible: bool, notify_layout: bool = true) -> void:
	if _inspector_panel == null:
		return
	_inspector_panel.visible = visible
	_inspector_toggle.set_pressed_no_signal(visible)
	if notify_layout:
		layout_changed.emit()


func set_diagnostics_visible(visible: bool, notify_layout: bool = true) -> void:
	if _diagnostics_panel == null:
		return
	_diagnostics_panel.visible = visible
	_diagnostics_toggle.set_pressed_no_signal(visible)
	if notify_layout:
		layout_changed.emit()


func get_layout_state() -> Dictionary:
	return {
		"library_visible": _library_panel.visible if _library_panel != null else true,
		"inspector_visible": _inspector_panel.visible if _inspector_panel != null else true,
		"diagnostics_visible": _diagnostics_panel.visible if _diagnostics_panel != null else false,
		"library_split_offset": _library_split.split_offset if _library_split != null else DEFAULT_LIBRARY_SPLIT,
		"inspector_split_offset": _content_split.split_offset if _content_split != null else DEFAULT_INSPECTOR_SPLIT
	}


func apply_layout_state(state: Dictionary) -> void:
	set_library_visible(bool(state.get("library_visible", true)), false)
	set_inspector_visible(bool(state.get("inspector_visible", true)), false)
	set_diagnostics_visible(bool(state.get("diagnostics_visible", false)), false)
	if _library_split != null:
		_library_split.split_offset = int(state.get("library_split_offset", DEFAULT_LIBRARY_SPLIT))
	if _content_split != null:
		_content_split.split_offset = int(state.get("inspector_split_offset", DEFAULT_INSPECTOR_SPLIT))


func get_toolbar_actions() -> HBoxContainer:
	return _toolbar_actions


func get_library_host() -> VBoxContainer:
	return _library_host


func get_editor_host() -> VBoxContainer:
	return _editor_host


func get_inspector_host() -> VBoxContainer:
	return _inspector_host


func get_inspector_minimum_width() -> float:
	return MIN_INSPECTOR_WIDTH


func get_diagnostics_message() -> String:
	return _diagnostics_message.text if _diagnostics_message != null else ""


func get_document_name_text() -> String:
	return _document_name.text if _document_name != null else ""


func get_selection_name_text() -> String:
	return _selection_name.text if _selection_name != null else ""


func is_library_visible() -> bool:
	return _library_panel.visible if _library_panel != null else false


func is_inspector_visible() -> bool:
	return _inspector_panel.visible if _inspector_panel != null else false


func is_diagnostics_visible() -> bool:
	return _diagnostics_panel.visible if _diagnostics_panel != null else false


func _on_library_toggle_pressed() -> void:
	set_library_visible(_library_toggle.button_pressed)


func _on_inspector_toggle_pressed() -> void:
	set_inspector_visible(_inspector_toggle.button_pressed)


func _on_diagnostics_toggle_pressed() -> void:
	set_diagnostics_visible(_diagnostics_toggle.button_pressed)


func _on_split_dragged(_offset: int) -> void:
	layout_changed.emit()
