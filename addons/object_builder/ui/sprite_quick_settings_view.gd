@tool
extends VBoxContainer
## Contextual visual settings for static and animated sprites in the simple workflow.

signal property_changed(path: NodePath, property_name: String, value: Variant)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

var _panel: VBoxContainer
var _sprite_controls: VBoxContainer
var _animated_controls: VBoxContainer
var _hframes: SpinBox
var _vframes: SpinBox
var _frame: SpinBox
var _region_enabled: CheckBox
var _region_controls: VBoxContainer
var _region_x: SpinBox
var _region_y: SpinBox
var _region_width: SpinBox
var _region_height: SpinBox
var _animation_option: OptionButton
var _animated_frame: SpinBox
var _animated_speed: SpinBox
var _animation_hint: Label
var _animation_fps: SpinBox
var _animation_loop_mode: OptionButton
var _selected_path := NodePath("")


func build() -> void:
	if _panel != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	_panel = VBoxContainer.new()
	_panel.visible = false
	_panel.add_theme_constant_override("separation", 4)
	add_child(_panel)

	var heading := Label.new()
	heading.text = "ВНЕШНИЙ ВИД ЧАСТИ"
	heading.add_theme_font_size_override("font_size", 13)
	_panel.add_child(heading)

	_build_static_sprite_controls()
	_build_animated_sprite_controls()


func _build_static_sprite_controls() -> void:
	_sprite_controls = VBoxContainer.new()
	_sprite_controls.add_theme_constant_override("separation", 4)
	_panel.add_child(_sprite_controls)

	var subheading := Label.new()
	subheading.text = "КАДР И АТЛАС"
	_sprite_controls.add_child(subheading)

	var grid_row := HBoxContainer.new()
	_sprite_controls.add_child(grid_row)
	_hframes = UIFactory.make_spin_box(1.0, 128.0, 1.0)
	_hframes.value_changed.connect(_on_grid_value_changed.bind("hframes"))
	UIFactory.add_labeled_control(grid_row, "Колонки", _hframes, 92.0)
	_vframes = UIFactory.make_spin_box(1.0, 128.0, 1.0)
	_vframes.value_changed.connect(_on_grid_value_changed.bind("vframes"))
	UIFactory.add_labeled_control(grid_row, "Строки", _vframes, 92.0)
	_frame = UIFactory.make_spin_box(0.0, 16383.0, 1.0)
	_frame.value_changed.connect(_on_grid_value_changed.bind("frame"))
	UIFactory.add_labeled_control(grid_row, "Кадр", _frame, 78.0)

	_region_enabled = CheckBox.new()
	_region_enabled.text = "Использовать область атласа"
	_region_enabled.toggled.connect(_on_region_enabled_toggled)
	_sprite_controls.add_child(_region_enabled)

	_region_controls = VBoxContainer.new()
	_region_controls.add_theme_constant_override("separation", 3)
	_sprite_controls.add_child(_region_controls)

	var position_row := HBoxContainer.new()
	_region_controls.add_child(position_row)
	_region_x = UIFactory.make_spin_box(-16384.0, 16384.0, 1.0)
	_region_x.value_changed.connect(_on_region_value_changed.bind("region_x"))
	UIFactory.add_labeled_control(position_row, "Область X", _region_x, 92.0)
	_region_y = UIFactory.make_spin_box(-16384.0, 16384.0, 1.0)
	_region_y.value_changed.connect(_on_region_value_changed.bind("region_y"))
	UIFactory.add_labeled_control(position_row, "Y", _region_y, 72.0)

	var size_row := HBoxContainer.new()
	_region_controls.add_child(size_row)
	_region_width = UIFactory.make_spin_box(0.0, 16384.0, 1.0)
	_region_width.value_changed.connect(_on_region_value_changed.bind("region_width"))
	UIFactory.add_labeled_control(size_row, "Ширина", _region_width, 92.0)
	_region_height = UIFactory.make_spin_box(0.0, 16384.0, 1.0)
	_region_height.value_changed.connect(_on_region_value_changed.bind("region_height"))
	UIFactory.add_labeled_control(size_row, "Высота", _region_height, 92.0)

	var hint := Label.new()
	hint.text = "Изменения сохраняются вместе со сценой."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	_sprite_controls.add_child(hint)


func _build_animated_sprite_controls() -> void:
	_animated_controls = VBoxContainer.new()
	_animated_controls.visible = false
	_animated_controls.add_theme_constant_override("separation", 4)
	_panel.add_child(_animated_controls)

	var subheading := Label.new()
	subheading.text = "АНИМАЦИЯ"
	_animated_controls.add_child(subheading)

	_animation_option = OptionButton.new()
	_animation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_option.item_selected.connect(_on_animation_selected)
	UIFactory.add_labeled_control(_animated_controls, "Анимация", _animation_option)

	var animation_row := HBoxContainer.new()
	_animated_controls.add_child(animation_row)
	_animated_frame = UIFactory.make_spin_box(0.0, 16383.0, 1.0)
	_animated_frame.value_changed.connect(_on_animated_frame_changed)
	UIFactory.add_labeled_control(animation_row, "Кадр", _animated_frame, 78.0)
	_animated_speed = UIFactory.make_spin_box(-10.0, 10.0, 0.1)
	_animated_speed.value_changed.connect(_on_animated_speed_changed)
	UIFactory.add_labeled_control(animation_row, "Скорость", _animated_speed, 92.0)

	var settings_row := HBoxContainer.new()
	_animated_controls.add_child(settings_row)
	_animation_fps = UIFactory.make_spin_box(0.1, 120.0, 0.1)
	_animation_fps.value_changed.connect(_on_animation_fps_changed)
	UIFactory.add_labeled_control(settings_row, "FPS", _animation_fps, 90.0)
	_animation_loop_mode = OptionButton.new()
	_animation_loop_mode.add_item("Без цикла")
	_animation_loop_mode.set_item_metadata(0, 0)
	_animation_loop_mode.add_item("Цикл")
	_animation_loop_mode.set_item_metadata(1, 1)
	_animation_loop_mode.add_item("Пинг-понг")
	_animation_loop_mode.set_item_metadata(2, 2)
	_animation_loop_mode.item_selected.connect(_on_animation_loop_mode_selected)
	UIFactory.add_labeled_control(settings_row, "Режим", _animation_loop_mode)

	_animation_hint = Label.new()
	_animation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_animation_hint.add_theme_font_size_override("font_size", 10)
	_animated_controls.add_child(_animation_hint)


func set_selected_node(node: Node, path: NodePath) -> void:
	_selected_path = path
	if _panel == null:
		return
	var sprite := node as Sprite2D
	var animated := node as AnimatedSprite2D
	_panel.visible = sprite != null or animated != null
	_sprite_controls.visible = sprite != null
	_animated_controls.visible = animated != null
	if sprite != null:
		_hframes.set_value_no_signal(float(sprite.hframes))
		_vframes.set_value_no_signal(float(sprite.vframes))
		_frame.max_value = maxf(0.0, float(sprite.hframes * sprite.vframes - 1))
		_frame.set_value_no_signal(float(sprite.frame))
		_region_enabled.set_pressed_no_signal(sprite.region_enabled)
		_region_controls.visible = sprite.region_enabled
		_region_x.set_value_no_signal(sprite.region_rect.position.x)
		_region_y.set_value_no_signal(sprite.region_rect.position.y)
		_region_width.set_value_no_signal(sprite.region_rect.size.x)
		_region_height.set_value_no_signal(sprite.region_rect.size.y)
	elif animated != null:
		_refresh_animated_controls(animated)


func _refresh_animated_controls(sprite: AnimatedSprite2D) -> void:
	_animation_option.clear()
	_animated_speed.set_value_no_signal(sprite.speed_scale)
	var frames := sprite.sprite_frames
	if frames == null:
		_animation_option.disabled = true
		_animated_frame.editable = false
		_animation_fps.editable = false
		_animation_loop_mode.disabled = true
		_animation_fps.set_value_no_signal(8.0)
		_animation_loop_mode.select(1)
		_animation_hint.text = "Назначь SpriteFrames через кнопку «Кадры…» в списке частей."
		return

	var names := frames.get_animation_names()
	for animation_name in names:
		_animation_option.add_item(str(animation_name))
		_animation_option.set_item_metadata(_animation_option.item_count - 1, str(animation_name))
	var selected_index := -1
	for index in range(_animation_option.item_count):
		if str(_animation_option.get_item_metadata(index)) == str(sprite.animation):
			selected_index = index
			break
	if selected_index >= 0:
		_animation_option.select(selected_index)
	_animation_option.disabled = names.is_empty()
	_animation_loop_mode.disabled = names.is_empty()
	if not frames.has_animation(sprite.animation):
		_animated_frame.editable = false
		_animation_fps.editable = false
		_animation_fps.set_value_no_signal(8.0)
		_animation_loop_mode.disabled = true
		_animation_loop_mode.select(1)
		_animation_hint.text = "Выбери анимацию из списка."
		return

	var frame_count := frames.get_frame_count(sprite.animation)
	_animated_frame.editable = frame_count > 0
	_animated_frame.max_value = maxf(0.0, float(frame_count - 1))
	_animated_frame.set_value_no_signal(float(clampi(sprite.frame, 0, maxi(0, frame_count - 1))))
	_animation_fps.editable = true
	_animation_fps.set_value_no_signal(maxf(0.1, frames.get_animation_speed(sprite.animation)))
	var loop_mode := int(frames.get_animation_loop_mode(sprite.animation))
	_animation_loop_mode.select(clampi(loop_mode, 0, 2))
	_animation_hint.text = (
		"▶ Анимация на холсте запускает изолированный предпросмотр. "
		+ "Игровая логика объекта остаётся выключенной."
	)


func _on_animation_fps_changed(value: float) -> void:
	if not _selected_path.is_empty():
		property_changed.emit(_selected_path, "animation_speed", clampf(value, 0.1, 120.0))


func _on_animation_loop_mode_selected(index: int) -> void:
	if not _selected_path.is_empty() and index >= 0 and index < _animation_loop_mode.item_count:
		property_changed.emit(
			_selected_path,
			"animation_loop_mode",
			int(_animation_loop_mode.get_item_metadata(index))
		)


func is_visible_for_selection() -> bool:
	return _panel != null and _panel.visible


func _on_grid_value_changed(value: float, property_name: String) -> void:
	if _selected_path.is_empty():
		return
	var next_value := int(round(value))
	if property_name == "frame":
		var frame_limit := int(_hframes.value * _vframes.value) - 1
		next_value = clampi(next_value, 0, maxi(0, frame_limit))
	property_changed.emit(_selected_path, property_name, next_value)


func _on_region_enabled_toggled(enabled: bool) -> void:
	_region_controls.visible = enabled
	if not _selected_path.is_empty():
		property_changed.emit(_selected_path, "region_enabled", enabled)


func _on_region_value_changed(value: float, property_name: String) -> void:
	if not _selected_path.is_empty():
		property_changed.emit(_selected_path, property_name, value)


func _on_animation_selected(index: int) -> void:
	if _selected_path.is_empty() or index < 0 or index >= _animation_option.item_count:
		return
	var animation_name := StringName(str(_animation_option.get_item_metadata(index)))
	property_changed.emit(_selected_path, "animation", animation_name)


func _on_animated_frame_changed(value: float) -> void:
	if _selected_path.is_empty():
		return
	property_changed.emit(_selected_path, "frame", int(round(value)))


func _on_animated_speed_changed(value: float) -> void:
	if not _selected_path.is_empty():
		property_changed.emit(_selected_path, "speed_scale", value)
