@tool
extends EditorPlugin

const METADATA_SECTION := "ObjectBuilder"
const RECENT_LIMIT := 20
const CATEGORY_LABELS := {
	"Nature": "Природа",
	"Buildings": "Здания",
	"Items": "Предметы",
	"Equipment": "Экипировка",
	"Furniture": "Мебель",
	"Characters": "Персонажи",
	"Animals": "Животные",
	"Interactive": "Интерактивные",
	"Effects": "Эффекты",
	"Transport": "Транспорт",
	"Decorations": "Декорации",
	"Other": "Другое"
}
const ROOT_TYPES := [
	"Node2D",
	"StaticBody2D",
	"Area2D",
	"CharacterBody2D",
	"RigidBody2D",
	"AnimatableBody2D"
]
const CHILD_NODE_TYPES := [
	"Node",
	"Node2D",
	"Sprite2D",
	"AnimatedSprite2D",
	"Polygon2D",
	"Line2D",
	"Marker2D",
	"Area2D",
	"StaticBody2D",
	"CollisionShape2D",
	"CollisionPolygon2D",
	"AudioStreamPlayer2D",
	"AnimationPlayer"
]

var _dock: MarginContainer
var _search: LineEdit
var _mode_filter: OptionButton
var _category_filter: OptionButton
var _tag_filter: OptionButton
var _object_list: ItemList
var _name_edit: LineEdit
var _id_edit: LineEdit
var _category_edit: LineEdit
var _root_type: OptionButton
var _tags_edit: LineEdit
var _description_edit: TextEdit
var _template_check: CheckBox
var _favorite_button: Button
var _property_list: VBoxContainer
var _property_dialog: AcceptDialog
var _property_name_edit: LineEdit
var _property_type_option: OptionButton
var _property_default_edit: LineEdit
var _property_group_edit: LineEdit
var _property_description_edit: TextEdit
var _property_advanced_check: CheckBox
var _property_range_check: CheckBox
var _property_minimum_edit: LineEdit
var _property_maximum_edit: LineEdit
var _editing_property: ObjectPropertyDefinition
var _template_dialog: AcceptDialog
var _template_option: OptionButton
var _node_dialog: AcceptDialog
var _node_type_option: OptionButton
var _node_name_edit: LineEdit
var _scene_tree: Tree
var _scene_tree_status: Label
var _visual_panel: VBoxContainer
var _sprite_visual_controls: VBoxContainer
var _animated_visual_controls: VBoxContainer
var _visual_type_label: Label
var _visual_preview: TextureRect
var _texture_path_edit: LineEdit
var _sprite_hframes: SpinBox
var _sprite_vframes: SpinBox
var _sprite_frame: SpinBox
var _sprite_offset_x: SpinBox
var _sprite_offset_y: SpinBox
var _sprite_centered: CheckBox
var _sprite_flip_h: CheckBox
var _sprite_flip_v: CheckBox
var _texture_dialog: FileDialog
var _frames_dialog: FileDialog
var _frames_path_edit: LineEdit
var _animation_option: OptionButton
var _animated_frame: SpinBox
var _animated_speed: SpinBox
var _status_label: Label
var _open_scene_button: Button
var _definitions: Array[ObjectDefinition] = []
var _visible_definitions: Array[ObjectDefinition] = []
var _templates: Array[ObjectDefinition] = []
var _favorites := PackedStringArray()
var _recent_ids := PackedStringArray()
var _working_definition: ObjectDefinition
var _can_save_as_template := true


func _enter_tree() -> void:
	_load_local_state()
	_build_ui()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_refresh_library()


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()


func _build_ui() -> void:
	_dock = MarginContainer.new()
	_dock.name = "Object Builder"
	_dock.custom_minimum_size = Vector2(580, 390)
	for margin_name in ["left", "top", "right", "bottom"]:
		_dock.add_theme_constant_override("margin_" + margin_name, 8)

	var layout := VBoxContainer.new()
	_dock.add_child(layout)

	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	var title := Label.new()
	title.text = "Object Builder"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)

	var new_button := Button.new()
	new_button.text = "Новый"
	new_button.tooltip_text = "Создать пустой объект"
	new_button.pressed.connect(_on_new_object_pressed)
	toolbar.add_child(new_button)

	var template_button := Button.new()
	template_button.text = "Из шаблона"
	template_button.pressed.connect(_on_create_from_template_pressed)
	toolbar.add_child(template_button)

	var refresh_button := Button.new()
	refresh_button.text = "↻"
	refresh_button.tooltip_text = "Обновить библиотеку и дерево сцены"
	refresh_button.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(split)

	var library_panel := VBoxContainer.new()
	library_panel.custom_minimum_size = Vector2(190, 0)
	split.add_child(library_panel)

	_search = LineEdit.new()
	_search.placeholder_text = "Поиск по имени, ID, описанию…"
	_search.text_changed.connect(_on_search_changed)
	library_panel.add_child(_search)

	_mode_filter = OptionButton.new()
	_mode_filter.add_item("Все объекты")
	_mode_filter.set_item_metadata(0, "all")
	_mode_filter.add_item("Избранное")
	_mode_filter.set_item_metadata(1, "favorites")
	_mode_filter.add_item("Недавние")
	_mode_filter.set_item_metadata(2, "recent")
	_mode_filter.item_selected.connect(_on_filter_changed)
	library_panel.add_child(_mode_filter)

	_category_filter = OptionButton.new()
	_category_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_filter.item_selected.connect(_on_filter_changed)
	library_panel.add_child(_category_filter)

	_tag_filter = OptionButton.new()
	_tag_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag_filter.item_selected.connect(_on_filter_changed)
	library_panel.add_child(_tag_filter)

	_object_list = ItemList.new()
	_object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_object_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_object_list.item_selected.connect(_on_library_item_selected)
	library_panel.add_child(_object_list)

	var editor_scroll := ScrollContainer.new()
	editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(editor_scroll)

	var editor := VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 7)
	editor_scroll.add_child(editor)

	var basics_title := Label.new()
	basics_title.text = "ОСНОВНОЕ"
	editor.add_child(basics_title)

	_name_edit = _add_labeled_line_edit(editor, "Название", "Например, Дуб")
	_id_edit = _add_labeled_line_edit(editor, "Постоянный ID", "Создаётся автоматически")
	_id_edit.editable = false

	var favorite_row := HBoxContainer.new()
	editor.add_child(favorite_row)
	_favorite_button = Button.new()
	_favorite_button.text = "☆ В избранное"
	_favorite_button.tooltip_text = "Сохраняется локально в настройках редактора этого проекта."
	_favorite_button.pressed.connect(_on_toggle_favorite_pressed)
	favorite_row.add_child(_favorite_button)

	_category_edit = _add_labeled_line_edit(editor, "Категория", "Например, Nature")
	_tags_edit = _add_labeled_line_edit(editor, "Теги", "дерево, ресурс, лес")

	_root_type = OptionButton.new()
	for root_type in ROOT_TYPES:
		_root_type.add_item(root_type)
	_add_labeled_control(editor, "Тип корневого узла", _root_type)

	_template_check = CheckBox.new()
	_template_check.text = "Сохранить как шаблон"
	_template_check.tooltip_text = "Сохранит новую заготовку отдельно от игровых объектов."
	editor.add_child(_template_check)

	_description_edit = TextEdit.new()
	_description_edit.custom_minimum_size = Vector2(0, 68)
	_description_edit.placeholder_text = "Краткое описание объекта…"
	_add_labeled_control(editor, "Описание", _description_edit)

	var scene_title := Label.new()
	scene_title.text = "СТРУКТУРА СЦЕНЫ"
	editor.add_child(scene_title)

	var scene_toolbar := HBoxContainer.new()
	editor.add_child(scene_toolbar)
	var add_node_button := Button.new()
	add_node_button.text = "+ Дочерний узел"
	add_node_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_node_button.pressed.connect(_on_add_node_pressed)
	scene_toolbar.add_child(add_node_button)

	var remove_node_button := Button.new()
	remove_node_button.text = "Удалить"
	remove_node_button.tooltip_text = "Удаляет выбранный дочерний узел через Undo/Redo."
	remove_node_button.pressed.connect(_on_remove_node_pressed)
	scene_toolbar.add_child(remove_node_button)

	var refresh_tree_button := Button.new()
	refresh_tree_button.text = "↻"
	refresh_tree_button.tooltip_text = "Обновить дерево открытой сцены объекта."
	refresh_tree_button.pressed.connect(_refresh_scene_tree)
	scene_toolbar.add_child(refresh_tree_button)

	_scene_tree = Tree.new()
	_scene_tree.custom_minimum_size = Vector2(0, 190)
	_scene_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene_tree.hide_root = false
	_scene_tree.select_mode = Tree.SELECT_SINGLE
	_scene_tree.item_selected.connect(_on_scene_tree_item_selected)
	editor.add_child(_scene_tree)

	_scene_tree_status = Label.new()
	_scene_tree_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(_scene_tree_status)

	_build_visual_editor(editor)

	var open_scene_row := HBoxContainer.new()
	editor.add_child(open_scene_row)
	_open_scene_button = Button.new()
	_open_scene_button.text = "Открыть сцену"
	_open_scene_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_scene_button.disabled = true
	_open_scene_button.pressed.connect(_on_open_scene_pressed)
	open_scene_row.add_child(_open_scene_button)

	var properties_title := Label.new()
	properties_title.text = "ПОЛЬЗОВАТЕЛЬСКИЕ СВОЙСТВА"
	editor.add_child(properties_title)

	var properties_hint := Label.new()
	properties_hint.text = "Свойства хранятся отдельно от скриптов и группируются по назначению."
	properties_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(properties_hint)

	_property_list = VBoxContainer.new()
	editor.add_child(_property_list)

	var add_property_button := Button.new()
	add_property_button.text = "+ Добавить свойство"
	add_property_button.pressed.connect(_on_add_property_pressed)
	editor.add_child(add_property_button)

	var component_note := Label.new()
	component_note.text = "Редактор компонентов и их настроек — следующий этап."
	component_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(component_note)

	var save_button := Button.new()
	save_button.text = "Сохранить в библиотеку"
	save_button.pressed.connect(_on_save_pressed)
	editor.add_child(save_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(_status_label)

	_build_property_dialog()
	_build_template_dialog()
	_build_node_dialog()


func _add_labeled_line_edit(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	_add_labeled_control(parent, label_text, edit)
	return edit


func _add_labeled_control(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)


func _build_property_dialog() -> void:
	_property_dialog = AcceptDialog.new()
	_property_dialog.title = "Новое пользовательское свойство"
	add_child(_property_dialog)

	var form := VBoxContainer.new()
	_property_dialog.add_child(form)

	_property_name_edit = LineEdit.new()
	_property_name_edit.placeholder_text = "Например, Максимальное здоровье"
	_add_labeled_control(form, "Название", _property_name_edit)

	_property_type_option = OptionButton.new()
	for type_name in ["String", "Integer", "Float", "Boolean", "Vector2"]:
		_property_type_option.add_item(type_name)
	_property_type_option.item_selected.connect(_on_property_type_changed)
	_add_labeled_control(form, "Тип", _property_type_option)

	_property_default_edit = LineEdit.new()
	_property_default_edit.text = "0"
	_add_labeled_control(form, "Значение по умолчанию", _property_default_edit)

	_property_group_edit = LineEdit.new()
	_property_group_edit.text = "Основное"
	_add_labeled_control(form, "Группа инспектора", _property_group_edit)

	_property_description_edit = TextEdit.new()
	_property_description_edit.custom_minimum_size = Vector2(0, 54)
	_property_description_edit.placeholder_text = "Подсказка о назначении свойства…"
	_add_labeled_control(form, "Описание", _property_description_edit)

	_property_advanced_check = CheckBox.new()
	_property_advanced_check.text = "Дополнительный параметр"
	_property_advanced_check.tooltip_text = "Отмечает настройку как редко используемую."
	form.add_child(_property_advanced_check)

	_property_range_check = CheckBox.new()
	_property_range_check.text = "Ограничить числовой диапазон"
	_property_range_check.toggled.connect(_on_property_range_toggled)
	form.add_child(_property_range_check)

	var range_row := HBoxContainer.new()
	form.add_child(range_row)
	var minimum_label := Label.new()
	minimum_label.text = "Мин."
	range_row.add_child(minimum_label)
	_property_minimum_edit = LineEdit.new()
	_property_minimum_edit.text = "0"
	_property_minimum_edit.custom_minimum_size = Vector2(75, 0)
	_property_minimum_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_row.add_child(_property_minimum_edit)

	var maximum_label := Label.new()
	maximum_label.text = "Макс."
	range_row.add_child(maximum_label)
	_property_maximum_edit = LineEdit.new()
	_property_maximum_edit.text = "100"
	_property_maximum_edit.custom_minimum_size = Vector2(75, 0)
	_property_maximum_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_row.add_child(_property_maximum_edit)

	_property_dialog.confirmed.connect(_on_property_dialog_confirmed)
	_update_property_range_controls()


func _on_property_type_changed(_index: int) -> void:
	var type_name := _property_type_option.get_item_text(_property_type_option.selected)
	var supports_range := type_name in ["Integer", "Float"]
	_property_range_check.disabled = not supports_range
	if not supports_range:
		_property_range_check.button_pressed = false
	_update_property_range_controls()


func _on_property_range_toggled(_enabled: bool) -> void:
	_update_property_range_controls()


func _update_property_range_controls() -> void:
	if _property_minimum_edit == null or _property_maximum_edit == null:
		return
	var range_enabled := _property_range_check.button_pressed and not _property_range_check.disabled
	_property_minimum_edit.editable = range_enabled
	_property_maximum_edit.editable = range_enabled


func _build_template_dialog() -> void:
	_template_dialog = AcceptDialog.new()
	_template_dialog.title = "Создать объект из шаблона"
	add_child(_template_dialog)

	var form := VBoxContainer.new()
	_template_dialog.add_child(form)
	_template_option = OptionButton.new()
	_add_labeled_control(form, "Шаблон", _template_option)

	var hint := Label.new()
	hint.text = "Будет создана независимая копия определения и сцены."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(hint)
	_template_dialog.confirmed.connect(_on_template_dialog_confirmed)


func _build_visual_editor(parent: VBoxContainer) -> void:
	_visual_panel = VBoxContainer.new()
	_visual_panel.visible = false
	_visual_panel.add_theme_constant_override("separation", 5)
	parent.add_child(_visual_panel)

	var title := Label.new()
	title.text = "ВИЗУАЛЬНЫЙ ЭЛЕМЕНТ · SPRITE2D"
	_visual_panel.add_child(title)

	_visual_type_label = Label.new()
	_visual_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_visual_panel.add_child(_visual_type_label)

	_visual_preview = TextureRect.new()
	_visual_preview.custom_minimum_size = Vector2(0, 136)
	_visual_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_visual_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_visual_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_visual_panel.add_child(_visual_preview)

	_sprite_visual_controls = VBoxContainer.new()
	_visual_panel.add_child(_sprite_visual_controls)

	var texture_row := HBoxContainer.new()
	_sprite_visual_controls.add_child(texture_row)
	_texture_path_edit = LineEdit.new()
	_texture_path_edit.placeholder_text = "res://путь/к/текстуре.png"
	_texture_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texture_path_edit.text_submitted.connect(_on_texture_path_submitted)
	texture_row.add_child(_texture_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Обзор…"
	browse_button.pressed.connect(_on_browse_texture_pressed)
	texture_row.add_child(browse_button)

	var grid_row := HBoxContainer.new()
	_sprite_visual_controls.add_child(grid_row)
	_sprite_hframes = _make_visual_spin_box(1.0, 128.0, 1.0)
	_sprite_hframes.value_changed.connect(_on_sprite_grid_value_changed.bind("hframes"))
	_add_compact_labeled_control(grid_row, "H", _sprite_hframes)
	_sprite_vframes = _make_visual_spin_box(1.0, 128.0, 1.0)
	_sprite_vframes.value_changed.connect(_on_sprite_grid_value_changed.bind("vframes"))
	_add_compact_labeled_control(grid_row, "V", _sprite_vframes)
	_sprite_frame = _make_visual_spin_box(0.0, 16383.0, 1.0)
	_sprite_frame.value_changed.connect(_on_sprite_grid_value_changed.bind("frame"))
	_add_compact_labeled_control(grid_row, "Кадр", _sprite_frame)

	var offset_row := HBoxContainer.new()
	_sprite_visual_controls.add_child(offset_row)
	_sprite_offset_x = _make_visual_spin_box(-4096.0, 4096.0, 1.0)
	_sprite_offset_x.value_changed.connect(_on_sprite_offset_changed.bind("x"))
	_add_compact_labeled_control(offset_row, "Offset X", _sprite_offset_x)
	_sprite_offset_y = _make_visual_spin_box(-4096.0, 4096.0, 1.0)
	_sprite_offset_y.value_changed.connect(_on_sprite_offset_changed.bind("y"))
	_add_compact_labeled_control(offset_row, "Y", _sprite_offset_y)

	var toggles_row := HBoxContainer.new()
	_sprite_visual_controls.add_child(toggles_row)
	_sprite_centered = CheckBox.new()
	_sprite_centered.text = "По центру"
	_sprite_centered.toggled.connect(_on_sprite_toggle_changed.bind("centered"))
	toggles_row.add_child(_sprite_centered)
	_sprite_flip_h = CheckBox.new()
	_sprite_flip_h.text = "Flip H"
	_sprite_flip_h.toggled.connect(_on_sprite_toggle_changed.bind("flip_h"))
	toggles_row.add_child(_sprite_flip_h)
	_sprite_flip_v = CheckBox.new()
	_sprite_flip_v.text = "Flip V"
	_sprite_flip_v.toggled.connect(_on_sprite_toggle_changed.bind("flip_v"))
	toggles_row.add_child(_sprite_flip_v)

	var hint := Label.new()
	hint.text = "Изменения проходят через Undo/Redo. Для записи сцены нажми Ctrl+S."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sprite_visual_controls.add_child(hint)

	_animated_visual_controls = VBoxContainer.new()
	_animated_visual_controls.visible = false
	_animated_visual_controls.add_theme_constant_override("separation", 5)
	_visual_panel.add_child(_animated_visual_controls)

	var frames_title := Label.new()
	frames_title.text = "КАДРЫ АНИМАЦИИ"
	_animated_visual_controls.add_child(frames_title)

	var frames_row := HBoxContainer.new()
	_animated_visual_controls.add_child(frames_row)
	_frames_path_edit = LineEdit.new()
	_frames_path_edit.placeholder_text = "res://путь/к/sprite_frames.tres"
	_frames_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frames_path_edit.text_submitted.connect(_on_sprite_frames_path_submitted)
	frames_row.add_child(_frames_path_edit)

	var frames_browse_button := Button.new()
	frames_browse_button.text = "SpriteFrames…"
	frames_browse_button.pressed.connect(_on_browse_sprite_frames_pressed)
	frames_row.add_child(frames_browse_button)

	_animation_option = OptionButton.new()
	_animation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_option.item_selected.connect(_on_animated_animation_selected)
	_add_labeled_control(_animated_visual_controls, "Анимация", _animation_option)

	var animation_row := HBoxContainer.new()
	_animated_visual_controls.add_child(animation_row)
	_animated_frame = _make_visual_spin_box(0.0, 16383.0, 1.0)
	_animated_frame.value_changed.connect(_on_animated_frame_changed)
	_add_compact_labeled_control(animation_row, "Кадр", _animated_frame)
	_animated_speed = _make_visual_spin_box(-10.0, 10.0, 0.1)
	_animated_speed.value_changed.connect(_on_animated_speed_changed)
	_add_compact_labeled_control(animation_row, "Скорость", _animated_speed)

	var animated_hint := Label.new()
	animated_hint.text = "Здесь можно выбрать анимацию и кадр для проверки. Для автоматического воспроизведения настрой Autoplay в Inspector."
	animated_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_animated_visual_controls.add_child(animated_hint)

	_texture_dialog = FileDialog.new()
	_texture_dialog.title = "Выбрать текстуру"
	_texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_texture_dialog.access = FileDialog.ACCESS_RESOURCES
	_texture_dialog.filters = PackedStringArray([
		"*.png, *.webp, *.jpg, *.jpeg, *.svg, *.bmp, *.tga ; Файлы изображений"
	])
	_texture_dialog.file_selected.connect(_on_texture_file_selected)
	add_child(_texture_dialog)

	_frames_dialog = FileDialog.new()
	_frames_dialog.title = "Выбрать ресурс SpriteFrames"
	_frames_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_frames_dialog.access = FileDialog.ACCESS_RESOURCES
	_frames_dialog.filters = PackedStringArray([
		"*.tres, *.res ; Ресурсы Godot"
	])
	_frames_dialog.file_selected.connect(_on_sprite_frames_file_selected)
	add_child(_frames_dialog)


func _make_visual_spin_box(minimum: float, maximum: float, step_value: float) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step_value
	control.allow_greater = false
	control.allow_lesser = false
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


func _add_compact_labeled_control(parent: HBoxContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	control.custom_minimum_size = Vector2(72, 0)
	parent.add_child(control)


func _build_node_dialog() -> void:
	_node_dialog = AcceptDialog.new()
	_node_dialog.title = "Добавить дочерний узел"
	add_child(_node_dialog)

	var form := VBoxContainer.new()
	_node_dialog.add_child(form)

	_node_type_option = OptionButton.new()
	for type_name in CHILD_NODE_TYPES:
		_node_type_option.add_item(type_name)
	_add_labeled_control(form, "Тип узла", _node_type_option)

	_node_name_edit = LineEdit.new()
	_node_name_edit.placeholder_text = "Имя создаваемого узла"
	_add_labeled_control(form, "Название", _node_name_edit)

	var hint := Label.new()
	hint.text = "Узел будет добавлен в открытую сцену объекта. Операцию можно отменить через Ctrl+Z."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(hint)
	_node_dialog.confirmed.connect(_on_node_dialog_confirmed)


func _load_local_state() -> void:
	var settings := EditorInterface.get_editor_settings()
	var stored_favorites: Variant = settings.get_project_metadata(
		METADATA_SECTION,
		"favorites",
		PackedStringArray()
	)
	var stored_recent: Variant = settings.get_project_metadata(
		METADATA_SECTION,
		"recent",
		PackedStringArray()
	)
	_favorites = _to_packed_string_array(stored_favorites)
	_recent_ids = _to_packed_string_array(stored_recent)


func _to_packed_string_array(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is PackedStringArray:
		return value
	if value is Array:
		for entry in value:
			if entry is String and not entry.is_empty() and not result.has(entry):
				result.append(entry)
	return result


func _save_local_state() -> void:
	var settings := EditorInterface.get_editor_settings()
	settings.set_project_metadata(METADATA_SECTION, "favorites", _favorites)
	settings.set_project_metadata(METADATA_SECTION, "recent", _recent_ids)


func _refresh_library() -> void:
	_definitions = ObjectLibraryService.load_definitions()
	_templates = ObjectLibraryService.load_templates()
	_rebuild_category_filter()
	_rebuild_tag_filter()
	_refresh_library_list()
	_refresh_favorite_button()
	_refresh_scene_tree()
	if _definitions.is_empty():
		_set_status("Библиотека пока пуста. Создай объект или начни с шаблона.", false)


func _on_refresh_pressed() -> void:
	_refresh_library()
	EditorInterface.get_resource_filesystem().scan()


func _rebuild_category_filter() -> void:
	var previous_category := ""
	if _category_filter.selected >= 0:
		previous_category = str(_category_filter.get_item_metadata(_category_filter.selected))

	var categories: Array[String] = []
	for category_key in CATEGORY_LABELS.keys():
		categories.append(str(category_key))
	for definition in _definitions:
		if definition != null and not definition.category.is_empty() and not categories.has(definition.category):
			categories.append(definition.category)
	categories.sort()

	_category_filter.clear()
	_category_filter.add_item("Все категории")
	_category_filter.set_item_metadata(0, "")
	for category_name in categories:
		var label_text := str(CATEGORY_LABELS.get(category_name, category_name))
		_category_filter.add_item(label_text)
		_category_filter.set_item_metadata(_category_filter.item_count - 1, category_name)

	_select_option_metadata(_category_filter, previous_category)


func _rebuild_tag_filter() -> void:
	var previous_tag := ""
	if _tag_filter.selected >= 0:
		previous_tag = str(_tag_filter.get_item_metadata(_tag_filter.selected))

	var tags := PackedStringArray()
	for definition in _definitions:
		if definition == null:
			continue
		for tag in definition.tags:
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
	tags.sort()

	_tag_filter.clear()
	_tag_filter.add_item("Все теги")
	_tag_filter.set_item_metadata(0, "")
	for tag in tags:
		_tag_filter.add_item("#" + tag)
		_tag_filter.set_item_metadata(_tag_filter.item_count - 1, tag)
	_select_option_metadata(_tag_filter, previous_tag)


func _select_option_metadata(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.select(0)


func _refresh_library_list() -> void:
	if _object_list == null:
		return
	_object_list.clear()
	_visible_definitions.clear()

	var query := _search.text.strip_edges().to_lower()
	var selected_category := ""
	var selected_tag := ""
	var selected_mode := "all"
	if _category_filter.selected >= 0:
		selected_category = str(_category_filter.get_item_metadata(_category_filter.selected))
	if _tag_filter.selected >= 0:
		selected_tag = str(_tag_filter.get_item_metadata(_tag_filter.selected))
	if _mode_filter.selected >= 0:
		selected_mode = str(_mode_filter.get_item_metadata(_mode_filter.selected))

	var candidates: Array[ObjectDefinition] = []
	if selected_mode == "recent":
		for object_id in _recent_ids:
			var recent_definition := _find_definition(object_id)
			if recent_definition != null:
				candidates.append(recent_definition)
	else:
		for definition in _definitions:
			if definition == null:
				continue
			if selected_mode == "favorites" and not _favorites.has(definition.object_id):
				continue
			candidates.append(definition)

	for definition in candidates:
		if not selected_category.is_empty() and definition.category != selected_category:
			continue
		if not selected_tag.is_empty() and not definition.tags.has(selected_tag):
			continue
		var searchable_text := (
			definition.display_name + " " + definition.object_id + " "
			+ definition.description + " " + _join_tags(definition.tags)
		).to_lower()
		if not query.is_empty() and not searchable_text.contains(query):
			continue

		_visible_definitions.append(definition)
		var title_prefix := "★ " if _favorites.has(definition.object_id) else ""
		_object_list.add_item(title_prefix + definition.display_name)
		_object_list.set_item_tooltip(
			_object_list.item_count - 1,
			"%s\nID: %s\nТеги: %s" % [
				definition.description,
				definition.object_id,
				_join_tags(definition.tags)
			]
		)

	if _visible_definitions.is_empty():
		_object_list.add_item("Объекты не найдены")
		_object_list.set_item_disabled(0, true)


func _find_definition(object_id: String) -> ObjectDefinition:
	for definition in _definitions:
		if definition != null and definition.object_id == object_id:
			return definition
	return null


func _join_tags(tags: PackedStringArray) -> String:
	var values := PackedStringArray()
	for tag in tags:
		values.append(tag)
	return " ".join(values)


func _on_search_changed(_value: String) -> void:
	_refresh_library_list()


func _on_filter_changed(_index: int) -> void:
	_refresh_library_list()


func _on_library_item_selected(index: int) -> void:
	if index < 0 or index >= _visible_definitions.size():
		return
	_can_save_as_template = false
	var definition := _visible_definitions[index]
	_record_recent(definition.object_id)
	_load_definition(definition)


func _record_recent(object_id: String) -> void:
	if object_id.is_empty():
		return
	_recent_ids.erase(object_id)
	_recent_ids.insert(0, object_id)
	while _recent_ids.size() > RECENT_LIMIT:
		_recent_ids.remove_at(_recent_ids.size() - 1)
	_save_local_state()
	if _mode_filter.selected >= 0 and str(_mode_filter.get_item_metadata(_mode_filter.selected)) == "recent":
		_refresh_library_list()


func _on_toggle_favorite_pressed() -> void:
	if _working_definition == null or _working_definition.object_id.is_empty():
		return
	var object_id := _working_definition.object_id
	if _favorites.has(object_id):
		_favorites.erase(object_id)
	else:
		_favorites.append(object_id)
	_save_local_state()
	_refresh_favorite_button()
	_refresh_library_list()


func _refresh_favorite_button() -> void:
	if _favorite_button == null:
		return
	var can_toggle := _working_definition != null and not _working_definition.object_id.is_empty()
	_favorite_button.disabled = not can_toggle
	if can_toggle and _favorites.has(_working_definition.object_id):
		_favorite_button.text = "★ В избранном"
	else:
		_favorite_button.text = "☆ В избранное"


func _on_new_object_pressed() -> void:
	var definition := ObjectDefinition.new()
	definition.object_id = "object_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	definition.display_name = "Новый объект"
	definition.category = "Nature"
	definition.root_type = "Node2D"
	definition.is_template = false
	_can_save_as_template = true
	_load_definition(definition)
	_set_status("Новый объект ещё не сохранён.", false)


func _on_create_from_template_pressed() -> void:
	_templates = ObjectLibraryService.load_templates()
	_template_option.clear()
	if _templates.is_empty():
		_set_status("Шаблоны не найдены.", true)
		return
	for template_definition in _templates:
		_template_option.add_item(template_definition.display_name)
	_template_option.select(0)
	_template_dialog.popup_centered(Vector2i(440, 170))


func _on_template_dialog_confirmed() -> void:
	if _template_option.selected < 0 or _template_option.selected >= _templates.size():
		return
	var template_definition := _templates[_template_option.selected]
	var definition := template_definition.duplicate(true) as ObjectDefinition
	definition.object_id = "object_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	definition.display_name = template_definition.display_name + " — копия"
	definition.is_template = false
	definition.template_id = template_definition.object_id
	definition.scene = null
	definition.scene_path = ""
	_clone_template_scene(template_definition, definition)
	_can_save_as_template = true
	_load_definition(definition)
	_set_status("Создана копия шаблона. Измени параметры и сохрани объект.", false)


func _clone_template_scene(template_definition: ObjectDefinition, target_definition: ObjectDefinition) -> void:
	var source_scene: PackedScene = template_definition.scene
	if not template_definition.scene_path.is_empty() and FileAccess.file_exists(template_definition.scene_path):
		var loaded_scene := ResourceLoader.load(
			template_definition.scene_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		)
		if loaded_scene is PackedScene:
			source_scene = loaded_scene as PackedScene
	if source_scene == null:
		return

	var scene_root := source_scene.instantiate()
	scene_root.set_meta("object_definition_id", target_definition.object_id)
	scene_root.set_meta("object_category", target_definition.category)
	var copied_scene := PackedScene.new()
	_set_owner_recursive(scene_root, scene_root)
	var pack_error := copied_scene.pack(scene_root)
	scene_root.free()
	if pack_error != OK:
		push_warning("Object Builder: не удалось скопировать сцену шаблона.")
		return

	ObjectLibraryService.ensure_directories()
	var target_path := ObjectLibraryService.get_scene_path(target_definition.object_id)
	var save_error := ResourceSaver.save(copied_scene, target_path)
	if save_error != OK:
		push_warning("Object Builder: не удалось сохранить копию сцены шаблона.")
		return
	target_definition.scene = copied_scene
	target_definition.scene_path = target_path


func _load_definition(definition: ObjectDefinition) -> void:
	_working_definition = definition.duplicate(true) as ObjectDefinition
	_name_edit.text = _working_definition.display_name
	_id_edit.text = _working_definition.object_id
	_category_edit.text = _working_definition.category
	_tags_edit.text = _join_tags(_working_definition.tags)
	_description_edit.text = _working_definition.description
	_template_check.button_pressed = _working_definition.is_template
	_template_check.disabled = not _can_save_as_template
	_select_root_type(_working_definition.root_type)
	_open_scene_button.disabled = _working_definition.scene_path.is_empty() or not FileAccess.file_exists(_working_definition.scene_path)
	_rebuild_property_list()
	_refresh_favorite_button()
	_refresh_scene_tree()


func _select_root_type(type_name: String) -> void:
	for index in range(_root_type.item_count):
		if _root_type.get_item_text(index) == type_name:
			_root_type.select(index)
			return
	_root_type.select(0)


func _rebuild_property_list() -> void:
	for child in _property_list.get_children():
		child.queue_free()
	if _working_definition == null:
		return

	if _working_definition.custom_properties.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Пока нет пользовательских свойств."
		_property_list.add_child(empty_label)
		return

	var groups: Dictionary = {}
	var group_order := PackedStringArray()
	for property_definition in _working_definition.custom_properties:
		if property_definition == null:
			continue
		var group_name := property_definition.group_name.strip_edges()
		if group_name.is_empty():
			group_name = "Основное"
		if not groups.has(group_name):
			groups[group_name] = []
			group_order.append(group_name)
		groups[group_name].append(property_definition)

	for group_name in group_order:
		var group_label := Label.new()
		group_label.text = group_name
		_property_list.add_child(group_label)
		for property_definition in groups[group_name]:
			var row := HBoxContainer.new()
			var description_label := Label.new()
			description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var property_suffix := " · Доп." if property_definition.advanced else ""
			if property_definition.has_range:
				property_suffix += " · [%s…%s]" % [
					str(property_definition.minimum),
					str(property_definition.maximum)
				]
			description_label.text = "%s  ·  %s  ·  %s%s" % [
				property_definition.display_name,
				property_definition.value_type,
				str(property_definition.default_value),
				property_suffix
			]
			description_label.clip_text = true
			description_label.tooltip_text = property_definition.description
			row.add_child(description_label)

			var edit_button := Button.new()
			edit_button.text = "✎"
			edit_button.tooltip_text = "Изменить определение свойства"
			edit_button.pressed.connect(_on_edit_property_pressed.bind(property_definition))
			row.add_child(edit_button)

			var remove_button := Button.new()
			remove_button.text = "×"
			remove_button.tooltip_text = "Удалить свойство из определения"
			remove_button.pressed.connect(_on_remove_property_pressed.bind(property_definition))
			row.add_child(remove_button)
			_property_list.add_child(row)


func _on_add_property_pressed() -> void:
	if _working_definition == null:
		_on_new_object_pressed()
	_editing_property = null
	_property_dialog.title = "Новое пользовательское свойство"
	_property_name_edit.text = ""
	_property_type_option.select(2)
	_property_default_edit.text = "0"
	_property_group_edit.text = "Основное"
	_property_description_edit.text = ""
	_property_advanced_check.button_pressed = false
	_property_range_check.disabled = false
	_property_range_check.button_pressed = false
	_property_minimum_edit.text = "0"
	_property_maximum_edit.text = "100"
	_update_property_range_controls()
	_property_dialog.popup_centered(Vector2i(470, 430))


func _on_edit_property_pressed(property_definition: ObjectPropertyDefinition) -> void:
	if _working_definition == null or property_definition == null:
		return
	_editing_property = property_definition
	_property_dialog.title = "Редактировать пользовательское свойство"
	_property_name_edit.text = property_definition.display_name
	_select_property_type(property_definition.value_type)
	_property_default_edit.text = _format_property_default_value(
		property_definition.default_value,
		property_definition.value_type
	)
	_property_group_edit.text = property_definition.group_name
	_property_description_edit.text = property_definition.description
	_property_advanced_check.button_pressed = property_definition.advanced
	_property_range_check.disabled = property_definition.value_type != "Integer" and property_definition.value_type != "Float"
	_property_range_check.button_pressed = property_definition.has_range
	_property_minimum_edit.text = str(property_definition.minimum)
	_property_maximum_edit.text = str(property_definition.maximum)
	_update_property_range_controls()
	_property_dialog.popup_centered(Vector2i(470, 430))


func _select_property_type(type_name: String) -> void:
	for index in range(_property_type_option.item_count):
		if _property_type_option.get_item_text(index) == type_name:
			_property_type_option.select(index)
			_on_property_type_changed(index)
			return
	_property_type_option.select(0)
	_on_property_type_changed(0)


func _format_property_default_value(value: Variant, type_name: String) -> String:
	if type_name == "Vector2" and value is Vector2:
		var vector_value: Vector2 = value
		return "%s, %s" % [str(vector_value.x), str(vector_value.y)]
	return str(value)


func _on_property_dialog_confirmed() -> void:
	if _working_definition == null:
		return
	var display_name := _property_name_edit.text.strip_edges()
	if display_name.is_empty():
		_set_status("У свойства должно быть название.", true)
		return

	var value_type := _property_type_option.get_item_text(_property_type_option.selected)
	var default_value := _parse_default_value(_property_default_edit.text, value_type)
	var supports_range := value_type in ["Integer", "Float"]
	var has_range := supports_range and _property_range_check.button_pressed
	var minimum_value := _property_minimum_edit.text.to_float()
	var maximum_value := _property_maximum_edit.text.to_float()

	if has_range:
		if minimum_value > maximum_value:
			_set_status("Минимум диапазона не может быть больше максимума.", true)
			return
		var numeric_default := float(default_value)
		if numeric_default < minimum_value or numeric_default > maximum_value:
			_set_status("Значение по умолчанию должно входить в заданный диапазон.", true)
			return

	var property_definition := _editing_property
	if property_definition == null:
		property_definition = ObjectPropertyDefinition.new()
		property_definition.property_id = _make_property_id(display_name)
		var duplicate_index := 2
		var base_id := property_definition.property_id
		while _has_property_id(property_definition.property_id):
			property_definition.property_id = base_id + "_" + str(duplicate_index)
			duplicate_index += 1
		_working_definition.custom_properties.append(property_definition)

	property_definition.display_name = display_name
	property_definition.value_type = value_type
	property_definition.default_value = default_value
	property_definition.group_name = _property_group_edit.text.strip_edges()
	if property_definition.group_name.is_empty():
		property_definition.group_name = "Основное"
	property_definition.description = _property_description_edit.text
	property_definition.advanced = _property_advanced_check.button_pressed
	property_definition.has_range = has_range
	property_definition.minimum = minimum_value
	property_definition.maximum = maximum_value

	_editing_property = null
	_rebuild_property_list()
	_set_status("Свойство обновлено. Нажми «Сохранить в библиотеку».", false)


func _has_property_id(property_id: String) -> bool:
	for property_definition in _working_definition.custom_properties:
		if property_definition != null and property_definition.property_id == property_id:
			return true
	return false


func _make_property_id(value: String) -> String:
	var result := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	result = result.validate_filename()
	if result.is_empty():
		result = "property"
	return result


func _parse_default_value(value: String, type_name: String) -> Variant:
	match type_name:
		"Integer":
			return value.to_int()
		"Float":
			return value.to_float()
		"Boolean":
			return value.strip_edges().to_lower() in ["true", "1", "yes", "да"]
		"Vector2":
			var parts := value.split(",")
			if parts.size() == 2:
				return Vector2(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float())
			return Vector2.ZERO
		_:
			return value


func _on_remove_property_pressed(property_definition: ObjectPropertyDefinition) -> void:
	if _working_definition == null:
		return
	_working_definition.custom_properties.erase(property_definition)
	_rebuild_property_list()


func _on_save_pressed() -> void:
	if _working_definition == null:
		_on_new_object_pressed()
	_working_definition.display_name = _name_edit.text.strip_edges()
	_working_definition.category = _category_edit.text.strip_edges()
	_working_definition.description = _description_edit.text
	_working_definition.root_type = _root_type.get_item_text(_root_type.selected)
	_working_definition.is_template = _template_check.button_pressed

	var tags := PackedStringArray()
	for raw_tag in _tags_edit.text.split(","):
		var tag := raw_tag.strip_edges()
		if not tag.is_empty():
			tags.append(tag)
	_working_definition.tags = tags

	var validation_errors := ObjectLibraryService.validate_definition(_working_definition)
	if not validation_errors.is_empty():
		_set_status("Нельзя сохранить: " + "; ".join(validation_errors), true)
		return

	if _working_definition.scene_path.is_empty() or not FileAccess.file_exists(_working_definition.scene_path):
		if not _create_scene_for_definition():
			return

	var save_error: Error
	if _working_definition.is_template:
		save_error = ObjectLibraryService.save_template(_working_definition)
	else:
		save_error = ObjectLibraryService.save_definition(_working_definition)
	if save_error != OK:
		_set_status("Не удалось сохранить объект. Код ошибки: %d" % save_error, true)
		return

	_id_edit.text = _working_definition.object_id
	_open_scene_button.disabled = false
	_can_save_as_template = false
	_template_check.disabled = true
	if _working_definition.is_template:
		_set_status("Шаблон сохранён. Его можно выбрать кнопкой «Из шаблона».", false)
	else:
		_set_status("Объект сохранён в библиотеку: %s" % _working_definition.display_name, false)
	_refresh_library()
	_load_definition(_working_definition)


func _create_scene_for_definition() -> bool:
	ObjectLibraryService.ensure_directories()
	var created_object: Object = ClassDB.instantiate(_working_definition.root_type)
	if not created_object is Node:
		_set_status("Не удалось создать корневой узел типа " + _working_definition.root_type, true)
		return false

	var scene_root := created_object as Node
	scene_root.name = "Object"
	scene_root.set_meta("object_definition_id", _working_definition.object_id)
	scene_root.set_meta("object_category", _working_definition.category)

	var visuals := Node2D.new()
	visuals.name = "Visuals"
	scene_root.add_child(visuals)
	visuals.owner = scene_root

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(scene_root)
	scene_root.free()
	if pack_error != OK:
		_set_status("Не удалось собрать PackedScene. Код ошибки: %d" % pack_error, true)
		return false

	var scene_path := ObjectLibraryService.get_scene_path(_working_definition.object_id)
	var save_error := ResourceSaver.save(packed_scene, scene_path)
	if save_error != OK:
		_set_status("Не удалось сохранить сцену. Код ошибки: %d" % save_error, true)
		return false

	_working_definition.scene = packed_scene
	_working_definition.scene_path = scene_path
	EditorInterface.get_resource_filesystem().scan()
	return true


func _on_open_scene_pressed() -> void:
	if _working_definition == null or _working_definition.scene_path.is_empty():
		return
	if not FileAccess.file_exists(_working_definition.scene_path):
		_set_status("Файл сцены не найден. Создай его заново или восстанови из резервной копии.", true)
		return
	EditorInterface.open_scene_from_path(_working_definition.scene_path)
	_record_recent(_working_definition.object_id)
	await get_tree().process_frame
	_refresh_scene_tree()


func _get_open_object_scene_root() -> Node:
	if _working_definition == null or _working_definition.scene_path.is_empty():
		return null
	var edited_root := EditorInterface.get_edited_scene_root()
	if edited_root == null:
		return null
	if edited_root.scene_file_path != _working_definition.scene_path:
		return null
	return edited_root


func _refresh_scene_tree() -> void:
	if _scene_tree == null:
		return
	_scene_tree.clear()
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_refresh_visual_editor(null)
		_scene_tree_status.text = "Открой сцену выбранного объекта, чтобы редактировать её структуру."
		var placeholder := _scene_tree.create_item()
		placeholder.set_text(0, "Сцена объекта не открыта")
		placeholder.set_selectable(0, false)
		return

	var root_item := _scene_tree.create_item()
	root_item.set_text(0, "%s  <%s>" % [scene_root.name, scene_root.get_class()])
	root_item.set_metadata(0, NodePath("."))
	root_item.set_tooltip_text(0, scene_root.get_path())
	for child in scene_root.get_children():
		_add_scene_tree_item(child, root_item, scene_root)
	_scene_tree_status.text = "Изменения дерева используют Undo/Redo Godot. Сохраняй сцену обычным Ctrl+S."


func _add_scene_tree_item(node: Node, parent_item: TreeItem, scene_root: Node) -> void:
	var item := _scene_tree.create_item(parent_item)
	item.set_text(0, "%s  <%s>" % [node.name, node.get_class()])
	item.set_metadata(0, scene_root.get_path_to(node))
	item.set_tooltip_text(0, str(node.get_path()))
	for child in node.get_children():
		_add_scene_tree_item(child, item, scene_root)


func _on_scene_tree_item_selected() -> void:
	var node := _get_selected_scene_tree_node()
	if node != null:
		EditorInterface.edit_node(node)
	_refresh_visual_editor(node)


func _refresh_visual_editor(node: Node) -> void:
	if _visual_panel == null:
		return
	if node is Sprite2D:
		_refresh_static_sprite_editor(node as Sprite2D)
		return
	if node is AnimatedSprite2D:
		_refresh_animated_sprite_editor(node as AnimatedSprite2D)
		return
	_visual_panel.visible = false


func _refresh_static_sprite_editor(sprite: Sprite2D) -> void:
	_visual_panel.visible = true
	_sprite_visual_controls.visible = true
	_animated_visual_controls.visible = false
	_visual_type_label.text = "Sprite2D · %s" % str(sprite.get_path())
	_texture_path_edit.text = sprite.texture.resource_path if sprite.texture != null else ""
	_visual_preview.texture = sprite.texture
	_sprite_hframes.set_value_no_signal(float(sprite.hframes))
	_sprite_vframes.set_value_no_signal(float(sprite.vframes))
	_sprite_frame.max_value = maxf(0.0, float(sprite.hframes * sprite.vframes - 1))
	_sprite_frame.set_value_no_signal(float(sprite.frame))
	_sprite_offset_x.set_value_no_signal(sprite.offset.x)
	_sprite_offset_y.set_value_no_signal(sprite.offset.y)
	_sprite_centered.set_pressed_no_signal(sprite.centered)
	_sprite_flip_h.set_pressed_no_signal(sprite.flip_h)
	_sprite_flip_v.set_pressed_no_signal(sprite.flip_v)


func _refresh_animated_sprite_editor(sprite: AnimatedSprite2D) -> void:
	_visual_panel.visible = true
	_sprite_visual_controls.visible = false
	_animated_visual_controls.visible = true
	_visual_type_label.text = "AnimatedSprite2D · %s" % str(sprite.get_path())

	var frames := sprite.sprite_frames
	_frames_path_edit.text = frames.resource_path if frames != null else ""
	_animation_option.clear()
	if frames == null:
		_animation_option.disabled = true
		_animated_frame.editable = false
		_visual_preview.texture = null
		return

	var animation_names := frames.get_animation_names()
	for animation_name in animation_names:
		_animation_option.add_item(str(animation_name))
		_animation_option.set_item_metadata(
			_animation_option.item_count - 1,
			str(animation_name)
		)
	_animation_option.disabled = animation_names.is_empty()
	if animation_names.is_empty():
		_animated_frame.editable = false
		_visual_preview.texture = null
		return

	var selected_animation := str(sprite.animation)
	var selected_index := 0
	for index in range(_animation_option.item_count):
		if str(_animation_option.get_item_metadata(index)) == selected_animation:
			selected_index = index
			break
	_animation_option.select(selected_index)

	var resolved_animation := StringName(str(_animation_option.get_item_metadata(selected_index)))
	var frame_count := frames.get_frame_count(resolved_animation)
	_animated_frame.editable = frame_count > 0
	_animated_frame.max_value = maxf(0.0, float(frame_count - 1))
	var frame_index := clampi(sprite.frame, 0, maxi(0, frame_count - 1))
	_animated_frame.set_value_no_signal(float(frame_index))
	_animated_speed.set_value_no_signal(sprite.speed_scale)
	if frame_count > 0:
		_visual_preview.texture = frames.get_frame_texture(resolved_animation, frame_index)
	else:
		_visual_preview.texture = null


func _get_selected_scene_tree_node() -> Node:
	var selected_item := _scene_tree.get_selected()
	if selected_item == null:
		return null
	var path_value: Variant = selected_item.get_metadata(0)
	if path_value == null:
		return null
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		return null
	return scene_root.get_node_or_null(NodePath(str(path_value)))


func _on_browse_texture_pressed() -> void:
	if _get_selected_sprite_node() == null:
		_set_status("Выбери Sprite2D в дереве сцены.", true)
		return
	_texture_dialog.popup_centered(Vector2i(820, 620))


func _on_texture_file_selected(path: String) -> void:
	_apply_texture_path(path)


func _on_texture_path_submitted(path: String) -> void:
	_apply_texture_path(path)


func _apply_texture_path(path: String) -> void:
	var sprite := _get_selected_sprite_node()
	if sprite == null:
		_set_status("Выбранный узел больше не является Sprite2D.", true)
		return
	var clean_path := path.strip_edges()
	if clean_path.is_empty() or not clean_path.begins_with("res://"):
		_set_status("Укажи путь к текстуре внутри проекта, начиная с res://.", true)
		return
	var loaded_resource: Texture2D = ResourceLoader.load(clean_path) as Texture2D
	if loaded_resource == null:
		_set_status("Не удалось загрузить Texture2D: " + clean_path, true)
		return
	_commit_sprite_property(sprite, "texture", loaded_resource, "изменить текстуру")
	_texture_path_edit.text = clean_path
	_visual_preview.texture = loaded_resource
	_set_status("Текстура назначена. Для сохранения сцены нажми Ctrl+S.", false)


func _get_selected_sprite_node() -> Sprite2D:
	var selected_node := _get_selected_scene_tree_node()
	if selected_node is Sprite2D:
		return selected_node as Sprite2D
	return null


func _get_selected_animated_sprite_node() -> AnimatedSprite2D:
	var selected_node := _get_selected_scene_tree_node()
	if selected_node is AnimatedSprite2D:
		return selected_node as AnimatedSprite2D
	return null


func _on_browse_sprite_frames_pressed() -> void:
	if _get_selected_animated_sprite_node() == null:
		_set_status("Выбери AnimatedSprite2D в дереве сцены.", true)
		return
	_frames_dialog.popup_centered(Vector2i(820, 620))


func _on_sprite_frames_file_selected(path: String) -> void:
	_apply_sprite_frames_path(path)


func _on_sprite_frames_path_submitted(path: String) -> void:
	_apply_sprite_frames_path(path)


func _apply_sprite_frames_path(path: String) -> void:
	var sprite := _get_selected_animated_sprite_node()
	if sprite == null:
		_set_status("Выбранный узел больше не является AnimatedSprite2D.", true)
		return
	var clean_path := path.strip_edges()
	if clean_path.is_empty() or not clean_path.begins_with("res://"):
		_set_status("Укажи путь к SpriteFrames внутри проекта, начиная с res://.", true)
		return
	var loaded_frames: SpriteFrames = ResourceLoader.load(clean_path) as SpriteFrames
	if loaded_frames == null:
		_set_status("Не удалось загрузить SpriteFrames: " + clean_path, true)
		return
	_commit_visual_node_property(sprite, "sprite_frames", loaded_frames, "назначить SpriteFrames")
	_refresh_visual_editor(sprite)
	_set_status("SpriteFrames назначен. Сохрани сцену через Ctrl+S.", false)


func _on_animated_animation_selected(index: int) -> void:
	var sprite := _get_selected_animated_sprite_node()
	if sprite == null or sprite.sprite_frames == null:
		return
	if index < 0 or index >= _animation_option.item_count:
		return
	var animation_name := StringName(str(_animation_option.get_item_metadata(index)))
	_commit_visual_node_property(sprite, "animation", animation_name, "выбрать анимацию")
	_refresh_visual_editor(sprite)


func _on_animated_frame_changed(value: float) -> void:
	var sprite := _get_selected_animated_sprite_node()
	if sprite == null or sprite.sprite_frames == null:
		return
	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count <= 0:
		return
	var frame_index := clampi(int(round(value)), 0, frame_count - 1)
	_commit_visual_node_property(sprite, "frame", frame_index, "выбрать кадр анимации")
	_refresh_visual_editor(sprite)


func _on_animated_speed_changed(value: float) -> void:
	var sprite := _get_selected_animated_sprite_node()
	if sprite == null:
		return
	_commit_visual_node_property(sprite, "speed_scale", value, "изменить скорость анимации")


func _on_sprite_grid_value_changed(value: float, property_name: String) -> void:
	var sprite := _get_selected_sprite_node()
	if sprite == null:
		return
	var next_value := int(round(value))
	if property_name == "frame":
		var frame_limit := sprite.hframes * sprite.vframes - 1
		next_value = clampi(next_value, 0, maxi(0, frame_limit))
	_commit_sprite_property(sprite, property_name, next_value, "изменить %s" % property_name)
	_refresh_visual_editor(sprite)


func _on_sprite_offset_changed(value: float, axis: String) -> void:
	var sprite := _get_selected_sprite_node()
	if sprite == null:
		return
	var next_offset := sprite.offset
	if axis == "x":
		next_offset.x = value
	else:
		next_offset.y = value
	_commit_sprite_property(sprite, "offset", next_offset, "изменить Offset")


func _on_sprite_toggle_changed(value: bool, property_name: String) -> void:
	var sprite := _get_selected_sprite_node()
	if sprite == null:
		return
	_commit_sprite_property(sprite, property_name, value, "изменить %s" % property_name)


func _commit_sprite_property(
	sprite: Sprite2D,
	property_name: String,
	new_value: Variant,
	action_label: String
) -> void:
	_commit_visual_node_property(sprite, property_name, new_value, action_label)


func _commit_visual_node_property(
	node: Node,
	property_name: String,
	new_value: Variant,
	action_label: String
) -> void:
	if node == null or not is_instance_valid(node):
		return
	var old_value: Variant = node.get(property_name)
	if old_value == new_value:
		return
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Сначала открой сцену выбранного объекта.", true)
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: " + action_label, 0, scene_root)
	undo_redo.add_do_property(node, property_name, new_value)
	undo_redo.add_undo_property(node, property_name, old_value)
	undo_redo.commit_action()
	if node is Sprite2D and (property_name == "hframes" or property_name == "vframes"):
		_refresh_visual_editor(node)


func _on_add_node_pressed() -> void:
	if _working_definition == null:
		_set_status("Сначала выбери или создай объект.", true)
		return
	if _get_open_object_scene_root() == null:
		_set_status("Сначала открой сцену этого объекта.", true)
		return
	_node_type_option.select(1)
	_node_name_edit.text = ""
	_node_dialog.popup_centered(Vector2i(430, 190))


func _on_node_dialog_confirmed() -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Открытая сцена больше не совпадает с выбранным объектом.", true)
		return

	var parent_node := _get_selected_scene_tree_node()
	if parent_node == null:
		parent_node = scene_root

	var node_type := _node_type_option.get_item_text(_node_type_option.selected)
	var created_object: Object = ClassDB.instantiate(node_type)
	if not created_object is Node:
		_set_status("Godot не смог создать узел типа " + node_type, true)
		return

	var new_node := created_object as Node
	var entered_name := _node_name_edit.text.strip_edges()
	if entered_name.is_empty():
		entered_name = node_type
	new_node.name = entered_name.validate_node_name()

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: добавить узел", 0, scene_root)
	undo_redo.add_do_method(parent_node, "add_child", new_node)
	undo_redo.add_do_method(new_node, "set_owner", scene_root)
	undo_redo.add_undo_method(parent_node, "remove_child", new_node)
	undo_redo.add_do_reference(new_node)
	undo_redo.commit_action()

	EditorInterface.edit_node(new_node)
	_refresh_scene_tree()
	_set_status("Добавлен узел %s. Для сохранения сцены нажми Ctrl+S." % new_node.name, false)


func _on_remove_node_pressed() -> void:
	var scene_root := _get_open_object_scene_root()
	if scene_root == null:
		_set_status("Открой сцену выбранного объекта.", true)
		return

	var selected_node := _get_selected_scene_tree_node()
	if selected_node == null or selected_node == scene_root:
		_set_status("Нельзя удалить корневой узел объекта.", true)
		return

	var parent_node := selected_node.get_parent()
	if parent_node == null:
		return
	var original_index := selected_node.get_index()
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Object Builder: удалить узел", 0, scene_root)
	undo_redo.add_do_method(parent_node, "remove_child", selected_node)
	undo_redo.add_undo_method(parent_node, "add_child", selected_node)
	undo_redo.add_undo_method(parent_node, "move_child", selected_node, original_index)
	undo_redo.add_undo_reference(selected_node)
	undo_redo.commit_action()

	_refresh_scene_tree()
	_set_status("Узел удалён. Ctrl+Z отменяет удаление.", false)


func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)


func _set_status(message: String, is_error: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	if is_error:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	else:
		_status_label.remove_theme_color_override("font_color")
