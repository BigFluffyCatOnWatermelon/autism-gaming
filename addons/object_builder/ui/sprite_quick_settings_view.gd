@tool
extends VBoxContainer
## Small, contextual Sprite2D controls for the Object Builder simple workflow.

signal property_changed(path: NodePath, property_name: String, value: Variant)

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

var _panel: VBoxContainer
var _heading: Label
var _hframes: SpinBox
var _vframes: SpinBox
var _frame: SpinBox
var _region_enabled: CheckBox
var _region_controls: VBoxContainer
var _region_x: SpinBox
var _region_y: SpinBox
var _region_width: SpinBox
var _region_height: SpinBox
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

	_heading = Label.new()
	_heading.text = "КАДР И АТЛАС"
	_heading.add_theme_font_size_override("font_size", 13)
	_panel.add_child(_heading)

	var grid_row := HBoxContainer.new()
	_panel.add_child(grid_row)
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
	_panel.add_child(_region_enabled)

	_region_controls = VBoxContainer.new()
	_region_controls.add_theme_constant_override("separation", 3)
	_panel.add_child(_region_controls)

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
	hint.text = "Настройки применяются к выбранному Sprite2D и сохраняются вместе со сценой."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	_panel.add_child(hint)


func set_selected_node(node: Node, path: NodePath) -> void:
	_selected_path = path
	var sprite := node as Sprite2D
	if _panel == null:
		return
	_panel.visible = sprite != null
	if sprite == null:
		return
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
