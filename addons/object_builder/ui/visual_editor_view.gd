@tool
extends VBoxContainer
## Displays Sprite2D and AnimatedSprite2D settings and forwards edits to the editor controller.

signal texture_path_submitted(path: String)
signal texture_browse_requested
signal texture_file_selected(path: String)
signal sprite_grid_value_changed(value: float, property_name: String)
signal sprite_offset_changed(value: float, axis: String)
signal sprite_toggle_changed(value: bool, property_name: String)
signal frames_path_submitted(path: String)
signal frames_browse_requested
signal frames_file_selected(path: String)
signal animation_selected(index: int)
signal animation_frame_changed(value: float)
signal animation_speed_changed(value: float)
signal transform_value_changed(value: float, property_name: String)
signal reset_transform_requested
signal node_visibility_changed(value: bool)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")
const DialogService = preload("res://addons/object_builder/services/dialog_service.gd")

var _visual_panel: VBoxContainer
var _visual_type_label: Label
var _visual_preview: TextureRect
var _sprite_visual_controls: VBoxContainer
var _animated_visual_controls: VBoxContainer
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
var _frames_path_edit: LineEdit
var _frames_dialog: FileDialog
var _resource_picker_mode := "texture"
var _animation_option: OptionButton
var _animated_frame: SpinBox
var _animated_speed: SpinBox
var _transform_controls: VBoxContainer
var _position_x: SpinBox
var _position_y: SpinBox
var _rotation_degrees: SpinBox
var _scale_x: SpinBox
var _scale_y: SpinBox
var _z_index: SpinBox
var _node_visible: CheckBox


func build() -> void:
	if _visual_panel != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual_panel = VBoxContainer.new()
	_visual_panel.visible = false
	_visual_panel.add_theme_constant_override("separation", 5)
	add_child(_visual_panel)

	var title := Label.new()
	title.text = "ВНЕШНИЙ ВИД · РАСШИРЕННЫЕ НАСТРОЙКИ"
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

	_build_node_transform_controls()
	_build_static_sprite_controls()
	_build_animated_sprite_controls()
	_build_file_dialogs()


func _build_node_transform_controls() -> void:
	_transform_controls = VBoxContainer.new()
	_transform_controls.visible = false
	_transform_controls.add_theme_constant_override("separation", 4)
	_visual_panel.add_child(_transform_controls)
	UIFactory.create_section_title(_transform_controls, "ПОЛОЖЕНИЕ И СЛОЙ", 13)

	var position_row := HBoxContainer.new()
	_transform_controls.add_child(position_row)
	_position_x = UIFactory.make_spin_box(-16384.0, 16384.0, 1.0)
	_position_x.value_changed.connect(_on_transform_value_changed.bind("position_x"))
	UIFactory.add_labeled_control(position_row, "X", _position_x, 72.0)
	_position_y = UIFactory.make_spin_box(-16384.0, 16384.0, 1.0)
	_position_y.value_changed.connect(_on_transform_value_changed.bind("position_y"))
	UIFactory.add_labeled_control(position_row, "Y", _position_y, 72.0)

	var rotation_scale_row := HBoxContainer.new()
	_transform_controls.add_child(rotation_scale_row)
	_rotation_degrees = UIFactory.make_spin_box(-3600.0, 3600.0, 1.0)
	_rotation_degrees.suffix = "°"
	_rotation_degrees.value_changed.connect(_on_transform_value_changed.bind("rotation_degrees"))
	UIFactory.add_labeled_control(rotation_scale_row, "Поворот", _rotation_degrees, 96.0)

	var scale_row := HBoxContainer.new()
	_transform_controls.add_child(scale_row)
	_scale_x = UIFactory.make_spin_box(-100.0, 100.0, 0.05)
	_scale_x.value_changed.connect(_on_transform_value_changed.bind("scale_x"))
	UIFactory.add_labeled_control(scale_row, "Размер X", _scale_x, 84.0)
	_scale_y = UIFactory.make_spin_box(-100.0, 100.0, 0.05)
	_scale_y.value_changed.connect(_on_transform_value_changed.bind("scale_y"))
	UIFactory.add_labeled_control(scale_row, "Y", _scale_y, 72.0)

	var layer_row := HBoxContainer.new()
	_transform_controls.add_child(layer_row)
	_node_visible = CheckBox.new()
	_node_visible.text = "Видимый"
	_node_visible.toggled.connect(_on_node_visibility_toggled)
	layer_row.add_child(_node_visible)
	_z_index = UIFactory.make_spin_box(-4096.0, 4096.0, 1.0)
	_z_index.value_changed.connect(_on_transform_value_changed.bind("z_index"))
	UIFactory.add_labeled_control(layer_row, "Слой отрисовки", _z_index, 110.0)
	var reset_button := Button.new()
	reset_button.text = "Сбросить"
	reset_button.tooltip_text = "Вернуть позицию, поворот, размер и слой к исходным значениям."
	reset_button.pressed.connect(_on_reset_transform_pressed)
	layer_row.add_child(reset_button)


func show_node_2d(node: Node2D) -> void:
	if node == null or _visual_panel == null:
		return
	_visual_panel.visible = true
	_transform_controls.visible = true
	_sprite_visual_controls.visible = false
	_animated_visual_controls.visible = false
	_visual_type_label.text = "Выбрана часть: %s <%s>" % [node.name, node.get_class()]
	_visual_preview.texture = null
	_position_x.set_value_no_signal(node.position.x)
	_position_y.set_value_no_signal(node.position.y)
	_rotation_degrees.set_value_no_signal(node.rotation_degrees)
	_scale_x.set_value_no_signal(node.scale.x)
	_scale_y.set_value_no_signal(node.scale.y)
	_z_index.set_value_no_signal(node.z_index)
	_node_visible.set_pressed_no_signal(node.visible)


func _build_static_sprite_controls() -> void:
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
	browse_button.pressed.connect(_on_texture_browse_pressed)
	texture_row.add_child(browse_button)

	var grid_row := HBoxContainer.new()
	_sprite_visual_controls.add_child(grid_row)
	_sprite_hframes = UIFactory.make_spin_box(1.0, 128.0, 1.0)
	_sprite_hframes.value_changed.connect(_on_sprite_grid_changed.bind("hframes"))
	UIFactory.add_labeled_control(grid_row, "H", _sprite_hframes, 72.0)
	_sprite_vframes = UIFactory.make_spin_box(1.0, 128.0, 1.0)
	_sprite_vframes.value_changed.connect(_on_sprite_grid_changed.bind("vframes"))
	UIFactory.add_labeled_control(grid_row, "V", _sprite_vframes, 72.0)
	_sprite_frame = UIFactory.make_spin_box(0.0, 16383.0, 1.0)
	_sprite_frame.value_changed.connect(_on_sprite_grid_changed.bind("frame"))
	UIFactory.add_labeled_control(grid_row, "Кадр", _sprite_frame, 72.0)

	var offset_row := HBoxContainer.new()
	_sprite_visual_controls.add_child(offset_row)
	_sprite_offset_x = UIFactory.make_spin_box(-4096.0, 4096.0, 1.0)
	_sprite_offset_x.value_changed.connect(_on_sprite_offset_changed.bind("x"))
	UIFactory.add_labeled_control(offset_row, "Offset X", _sprite_offset_x, 72.0)
	_sprite_offset_y = UIFactory.make_spin_box(-4096.0, 4096.0, 1.0)
	_sprite_offset_y.value_changed.connect(_on_sprite_offset_changed.bind("y"))
	UIFactory.add_labeled_control(offset_row, "Y", _sprite_offset_y, 72.0)

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


func _build_animated_sprite_controls() -> void:
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
	_frames_path_edit.text_submitted.connect(_on_frames_path_submitted)
	frames_row.add_child(_frames_path_edit)

	var frames_browse_button := Button.new()
	frames_browse_button.text = "SpriteFrames…"
	frames_browse_button.pressed.connect(_on_frames_browse_pressed)
	frames_row.add_child(frames_browse_button)

	_animation_option = OptionButton.new()
	_animation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_option.item_selected.connect(_on_animation_selected)
	UIFactory.add_labeled_control(_animated_visual_controls, "Анимация", _animation_option)

	var animation_row := HBoxContainer.new()
	_animated_visual_controls.add_child(animation_row)
	_animated_frame = UIFactory.make_spin_box(0.0, 16383.0, 1.0)
	_animated_frame.value_changed.connect(_on_animation_frame_changed)
	UIFactory.add_labeled_control(animation_row, "Кадр", _animated_frame, 72.0)
	_animated_speed = UIFactory.make_spin_box(-10.0, 10.0, 0.1)
	_animated_speed.value_changed.connect(_on_animation_speed_changed)
	UIFactory.add_labeled_control(animation_row, "Скорость", _animated_speed, 72.0)

	var animated_hint := Label.new()
	animated_hint.text = "Здесь можно выбрать анимацию и кадр для проверки. Для автоматического воспроизведения настрой Autoplay в Inspector."
	animated_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_animated_visual_controls.add_child(animated_hint)


func _build_file_dialogs() -> void:
	_texture_dialog = FileDialog.new()
	_texture_dialog.title = "Выбрать ресурс"
	_texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_texture_dialog.access = FileDialog.ACCESS_RESOURCES
	_texture_dialog.file_selected.connect(_on_resource_file_selected)
	add_child(_texture_dialog)
	# Both resource types use the same picker window and navigation state.
	_frames_dialog = _texture_dialog


func _on_resource_file_selected(path: String) -> void:
	if _resource_picker_mode == "sprite_frames":
		frames_file_selected.emit(path)
	else:
		texture_file_selected.emit(path)


func show_sprite(sprite: Sprite2D) -> void:
	if sprite == null or _visual_panel == null:
		return
	show_node_2d(sprite)
	_sprite_visual_controls.visible = true
	_animated_visual_controls.visible = false
	_visual_type_label.text = "Выбрано изображение: %s" % sprite.name
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


func show_animated_sprite(sprite: AnimatedSprite2D) -> void:
	if sprite == null or _visual_panel == null:
		return
	show_node_2d(sprite)
	_sprite_visual_controls.visible = false
	_animated_visual_controls.visible = true
	_visual_type_label.text = "Выбрана анимация: %s" % sprite.name

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


func hide_editor() -> void:
	if _visual_panel != null:
		_visual_panel.visible = false


func get_animation_id(index: int) -> StringName:
	if _animation_option == null or index < 0 or index >= _animation_option.item_count:
		return StringName()
	return StringName(str(_animation_option.get_item_metadata(index)))


func get_preview_texture() -> Texture2D:
	return _visual_preview.texture if _visual_preview != null else null


func set_texture_path(path: String) -> void:
	if _texture_path_edit != null:
		_texture_path_edit.text = path


func set_frames_path(path: String) -> void:
	if _frames_path_edit != null:
		_frames_path_edit.text = path


func set_preview_texture(texture: Texture2D) -> void:
	if _visual_preview != null:
		_visual_preview.texture = texture


func popup_texture_dialog() -> void:
	_resource_picker_mode = "texture"
	_texture_dialog.title = "Выбрать текстуру Texture2D"
	_texture_dialog.filters = PackedStringArray([
		"*.png, *.webp, *.jpg, *.jpeg, *.svg, *.bmp, *.tga ; Файлы изображений"
	])
	DialogService.popup_window_safely(_texture_dialog, Vector2i(820, 620), 0.88)


func popup_sprite_frames_dialog() -> void:
	_resource_picker_mode = "sprite_frames"
	_texture_dialog.title = "Выбрать ресурс SpriteFrames"
	_texture_dialog.filters = PackedStringArray(["*.tres, *.res ; Ресурсы Godot"])
	DialogService.popup_window_safely(_texture_dialog, Vector2i(820, 620), 0.88)


func _on_texture_path_submitted(path: String) -> void:
	texture_path_submitted.emit(path)


func _on_texture_browse_pressed() -> void:
	texture_browse_requested.emit()


func _on_texture_file_selected(path: String) -> void:
	texture_file_selected.emit(path)


func _on_sprite_grid_changed(value: float, property_name: String) -> void:
	sprite_grid_value_changed.emit(value, property_name)


func _on_sprite_offset_changed(value: float, axis: String) -> void:
	sprite_offset_changed.emit(value, axis)


func _on_sprite_toggle_changed(value: bool, property_name: String) -> void:
	sprite_toggle_changed.emit(value, property_name)


func _on_frames_path_submitted(path: String) -> void:
	frames_path_submitted.emit(path)


func _on_frames_browse_pressed() -> void:
	frames_browse_requested.emit()


func _on_frames_file_selected(path: String) -> void:
	frames_file_selected.emit(path)


func _on_animation_selected(index: int) -> void:
	animation_selected.emit(index)


func _on_animation_frame_changed(value: float) -> void:
	animation_frame_changed.emit(value)


func _on_animation_speed_changed(value: float) -> void:
	animation_speed_changed.emit(value)


func _on_transform_value_changed(value: float, property_name: String) -> void:
	transform_value_changed.emit(value, property_name)


func _on_reset_transform_pressed() -> void:
	reset_transform_requested.emit()


func _on_node_visibility_toggled(value: bool) -> void:
	node_visibility_changed.emit(value)
