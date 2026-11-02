extends CanvasLayer

signal slot_selected(index: int)
signal backpack_expand_requested
signal settings_changed(screen_shake: bool, camera_zoom: float)
signal debug_value_changed(path: String, value: float)

var root: Control
var panels: Dictionary = {}
var current_panel := ""
var hotbar_buttons: Array[Button] = []
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_text: Label
var stamina_text: Label
var arrow_text: Label
var fps_text: Label
var inventory_grid: GridContainer
var backpack_text: Label
var settings_shake: CheckBox
var settings_zoom: HSlider
var debug_target_text: Label
var debug_walk_speed: SpinBox
var debug_strength: SpinBox
var logs_text: TextEdit
var log_lines: Array[String] = []
var backpack_slots := 12
var max_backpack_slots := 24

const SLOT_NAMES := ["МЕЧ", "КИРКА", "ТОПОР", "ЛУК", "СТРЕЛЫ", "—", "—", "—", "—"]
const SLOT_MARKS := ["⚔", "⛏", "🪓", "➶", "↗", "·", "·", "·", "·"]

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_create_hud()
	_create_hotbar()
	_create_inventory()
	_create_settings()
	_create_debug()
	_create_logs()
	set_player_data(100.0, 100.0, 100.0, 100.0, 30)
	set_hotbar_selection(0)
	add_log("Интерфейс загружен.")

func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.055, 0.94)
	style.border_color = Color(0.35, 0.48, 0.35, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _make_label(text_value: String, size: int = 14, color: Color = Color("#e5ecd9")) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _create_hud() -> void:
	var panel := PanelContainer.new()
	panel.name = "HUD"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 250
	panel.offset_bottom = 142
	_style_panel(panel)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	box.add_child(_make_label("AUTISM GAMING  ·  ТЕСТОВЫЙ МИР", 12, Color("#b7d29c")))

	var health_row := HBoxContainer.new()
	health_row.add_child(_make_label("Здоровье", 13))
	health_text = _make_label("100 / 100", 12, Color("#f2c7bd"))
	health_row.add_child(health_text)
	box.add_child(health_row)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(200, 14)
	health_bar.max_value = 100
	health_bar.show_percentage = false
	box.add_child(health_bar)

	var stamina_row := HBoxContainer.new()
	stamina_row.add_child(_make_label("Выносливость", 13))
	stamina_text = _make_label("100 / 100", 12, Color("#c8e6ad"))
	stamina_row.add_child(stamina_text)
	box.add_child(stamina_row)
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(200, 14)
	stamina_bar.max_value = 100
	stamina_bar.show_percentage = false
	box.add_child(stamina_bar)
	arrow_text = _make_label("Стрелы: 30", 12, Color("#d7c99d"))
	box.add_child(arrow_text)

	fps_text = _make_label("", 12, Color("#d1d8c8"))
	fps_text.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_text.offset_left = -100
	fps_text.offset_top = 18
	fps_text.offset_right = -16
	fps_text.offset_bottom = 42
	fps_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(fps_text)

func _create_hotbar() -> void:
	var panel := PanelContainer.new()
	panel.name = "Hotbar"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -276
	panel.offset_right = 276
	panel.offset_top = -78
	panel.offset_bottom = -12
	_style_panel(panel)
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	for index in range(9):
		var button := Button.new()
		button.custom_minimum_size = Vector2(54, 52)
		button.toggle_mode = true
		button.text = str(index + 1) + "\n" + SLOT_MARKS[index] + " " + SLOT_NAMES[index]
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = SLOT_NAMES[index]
		button.pressed.connect(func() -> void: slot_selected.emit(index))
		row.add_child(button)
		hotbar_buttons.append(button)

func _create_center_panel(panel_name: String, title_text: String, rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = rect.position.x
	panel.offset_top = rect.position.y
	panel.offset_right = rect.position.x + rect.size.x
	panel.offset_bottom = rect.position.y + rect.size.y
	_style_panel(panel)
	panel.visible = false
	root.add_child(panel)
	panels[panel_name] = panel

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_child(_make_label(title_text, 19, Color("#e0edce")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(34, 30)
	close.pressed.connect(close_panels)
	header.add_child(close)
	box.add_child(header)
	box.add_child(HSeparator.new())
	return box

func _create_inventory() -> void:
	var box := _create_center_panel("inventory", "Инвентарь", Rect2(-270, -220, 540, 440))
	box.add_child(_make_label("Экипировка", 14, Color("#b8d49f")))
	var equipment := HFlowContainer.new()
	equipment.add_theme_constant_override("h_separation", 6)
	equipment.add_theme_constant_override("v_separation", 4)
	for item in ["Шлем", "Нагрудник", "Перчатки", "Поножи", "Сапоги"]:
		var slot := Button.new()
		slot.text = item + "\n—"
		slot.custom_minimum_size = Vector2(94, 48)
		slot.disabled = true
		equipment.add_child(slot)
	box.add_child(equipment)
	box.add_child(_make_label("Слоты рюкзака", 14, Color("#b8d49f")))
	backpack_text = _make_label("12 / 24 открыто", 12, Color("#d4dec8"))
	box.add_child(backpack_text)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	box.add_child(inventory_grid)
	for index in range(24):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(70, 42)
		slot.text = "·" if index < backpack_slots else "ЗАКР."
		slot.disabled = index >= backpack_slots
		inventory_grid.add_child(slot)
	var expand := Button.new()
	expand.text = "Расширить рюкзак (+3 ячейки) · заглушка"
	expand.pressed.connect(func() -> void: backpack_expand_requested.emit())
	box.add_child(expand)
	box.add_child(_make_label("Броня, магазин и перенос предметов пока находятся в разработке.", 11, Color("#9eaa93")))

func _create_settings() -> void:
	var box := _create_center_panel("settings", "Настройки", Rect2(-220, -150, 440, 300))
	box.add_child(_make_label("Эффекты камеры", 14, Color("#b8d49f")))
	settings_shake = CheckBox.new()
	settings_shake.text = "Тряска камеры при ударах"
	settings_shake.toggled.connect(func(_pressed: bool) -> void: _emit_settings())
	box.add_child(settings_shake)
	box.add_child(_make_label("Базовый масштаб камеры", 13))
	settings_zoom = HSlider.new()
	settings_zoom.min_value = 0.8
	settings_zoom.max_value = 3.0
	settings_zoom.step = 0.05
	settings_zoom.value = 1.85
	settings_zoom.value_changed.connect(func(_value: float) -> void: _emit_settings())
	box.add_child(settings_zoom)
	box.add_child(_make_label("Настройки сохраняются в локальном файле Godot.", 11, Color("#9eaa93")))

func _create_debug() -> void:
	var box := _create_center_panel("debug", "Отладчик · F3", Rect2(-250, -190, 500, 380))
	debug_target_text = _make_label("Выбран объект: Игрок", 13, Color("#e5d6a6"))
	box.add_child(debug_target_text)
	box.add_child(_make_label("Скорость ходьбы", 12))
	debug_walk_speed = SpinBox.new()
	debug_walk_speed.min_value = 20
	debug_walk_speed.max_value = 600
	debug_walk_speed.step = 5
	debug_walk_speed.value = 155
	debug_walk_speed.value_changed.connect(func(value: float) -> void: debug_value_changed.emit("player.walk_speed", value))
	box.add_child(debug_walk_speed)
	box.add_child(_make_label("Сила персонажа", 12))
	debug_strength = SpinBox.new()
	debug_strength.min_value = 0
	debug_strength.max_value = 100
	debug_strength.step = 1
	debug_strength.value = 10
	debug_strength.value_changed.connect(func(value: float) -> void: debug_value_changed.emit("player.strength", value))
	box.add_child(debug_strength)
	box.add_child(_make_label("Клик по игроку, дереву или камню в мире выбирает объект.", 11, Color("#9eaa93")))
	box.add_child(_make_label("Изменения чисел применяются сразу.", 11, Color("#9eaa93")))

func _create_logs() -> void:
	var box := _create_center_panel("logs", "Журнал событий · F2", Rect2(-300, -205, 600, 410))
	logs_text = TextEdit.new()
	logs_text.custom_minimum_size = Vector2(570, 325)
	logs_text.editable = false
	logs_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(logs_text)
	var clear := Button.new()
	clear.text = "Очистить журнал"
	clear.pressed.connect(func() -> void:
		log_lines.clear()
		_render_logs()
	)
	box.add_child(clear)

func _emit_settings() -> void:
	if settings_shake == null or settings_zoom == null:
		return
	settings_changed.emit(settings_shake.button_pressed, settings_zoom.value)

func set_settings(screen_shake: bool, camera_zoom: float) -> void:
	if settings_shake != null:
		settings_shake.set_pressed_no_signal(screen_shake)
	if settings_zoom != null:
		settings_zoom.set_value_no_signal(camera_zoom)

func set_player_data(health: float, max_health: float, stamina: float, max_stamina: float, arrows: int) -> void:
	if health_bar == null:
		return
	health_bar.max_value = max_health
	health_bar.value = health
	health_text.text = "%d / %d" % [roundi(health), roundi(max_health)]
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	stamina_text.text = "%d / %d" % [roundi(stamina), roundi(max_stamina)]
	arrow_text.text = "Стрелы: %d" % arrows
	fps_text.text = "FPS: %d" % Engine.get_frames_per_second()

func set_hotbar_selection(index: int) -> void:
	for i in range(hotbar_buttons.size()):
		hotbar_buttons[i].set_pressed_no_signal(i == index)

func toggle_panel(panel_name: String) -> void:
	if current_panel == panel_name:
		close_panels()
		return
	close_panels()
	var panel: Control = panels.get(panel_name)
	if panel != null:
		panel.visible = true
		current_panel = panel_name

func close_panels() -> void:
	for panel in panels.values():
		(panel as Control).visible = false
	current_panel = ""

func has_modal_open() -> bool:
	return current_panel != ""

func set_backpack_slots(open_slots: int, maximum: int) -> void:
	backpack_slots = open_slots
	max_backpack_slots = maximum
	if backpack_text == null or inventory_grid == null:
		return
	backpack_text.text = "%d / %d открыто" % [backpack_slots, max_backpack_slots]
	for index in range(inventory_grid.get_child_count()):
		var slot := inventory_grid.get_child(index) as Button
		var unlocked := index < backpack_slots
		slot.disabled = not unlocked
		slot.text = "·" if unlocked else "ЗАКР."

func set_debug_values(walk_speed: float, strength: float) -> void:
	if debug_walk_speed != null:
		debug_walk_speed.set_value_no_signal(walk_speed)
	if debug_strength != null:
		debug_strength.set_value_no_signal(strength)

func set_debug_target(label: String, health: float = 0.0, maximum: float = 0.0) -> void:
	if debug_target_text != null:
		if maximum > 0.0:
			debug_target_text.text = "Выбран объект: %s · HP %.0f / %.0f" % [label, health, maximum]
		else:
			debug_target_text.text = "Выбран объект: " + label

func add_log(message: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	log_lines.push_front("[%s] %s" % [timestamp, message])
	while log_lines.size() > 60:
		log_lines.pop_back()
	_render_logs()

func _render_logs() -> void:
	if logs_text == null:
		return
	var lines := PackedStringArray()
	for line in log_lines:
		lines.append(line)
	logs_text.text = "\n".join(lines)
