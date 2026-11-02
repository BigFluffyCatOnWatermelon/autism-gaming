@tool
extends CanvasLayer

const InventorySlotScript = preload("res://scripts/inventory_slot.gd")
const InventoryDropZoneScript = preload("res://scripts/inventory_drop_zone.gd")

signal slot_selected(index: int)
signal backpack_expand_requested
signal settings_changed(screen_shake: bool, camera_zoom: float)
signal debug_value_changed(path: String, value: float)
signal debug_mode_requested(enabled: bool)
signal inventory_slot_dropped(from_index: int, to_index: int)
signal debug_object_selected(object_id: String)
signal debug_clone_requested
signal debug_delete_requested
signal debug_reset_requested
signal debug_cheats_changed(infinite_stamina: bool, invulnerable: bool)

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
var settings_debug: CheckBox
var resource_icon_cache: Dictionary = {}
var debug_target_text: Label
var debug_walk_speed: SpinBox
var debug_strength: SpinBox
var logs_text: TextEdit
var log_lines: Array[String] = []
var debug_filter: OptionButton
var debug_object_list: ItemList
var debug_properties: VBoxContainer
var debug_stats: Label
var debug_infinite_stamina: CheckBox
var debug_invulnerable: CheckBox
var debug_delete_dialog: ConfirmationDialog
var debug_objects: Array[Dictionary] = []
var backpack_slots := 12
var max_backpack_slots := 24

const HOTBAR_ITEMS := ["sword", "pickaxe", "axe", "bow", "arrows", "", "", "", ""]
const ITEM_LABELS := {
	"sword": "Меч",
	"pickaxe": "Кирка",
	"axe": "Топор",
	"bow": "Лук",
	"arrows": "Стрелы · боеприпас",
}
const ITEM_TEXTURE_PATHS := {
	"sword": "res://Assets/Weapons/sword.svg",
	"pickaxe": "res://Assets/Tools/pickaxe.png",
	"axe": "res://Assets/Tools/axe.png",
	"bow": "res://Assets/Weapons/bow.png",
	"arrows": "res://Assets/Items/arrows.png",
}

func _ready() -> void:
	layer = 10
	if has_node("Root"):
		_bind_existing_ui()
	else:
		_build_ui()
	_create_world_drop_zone()
	if Engine.is_editor_hint() and get_tree().edited_scene_root == self:
		_claim_editor_ownership(root, self)
	_wire_controls()
	_refresh_item_icons()
	set_player_data(100.0, 100.0, 100.0, 100.0, 30)
	set_hotbar_selection(0)
	if Engine.is_editor_hint():
		var inventory_panel := panels.get("inventory") as Control
		if inventory_panel != null:
			inventory_panel.visible = true
			current_panel = "inventory"
	else:
		close_panels()
	add_log("Интерфейс загружен.")

func _create_world_drop_zone() -> void:
	if root == null or root.get_node_or_null("WorldDropZone") != null:
		return
	var zone := InventoryDropZoneScript.new() as Control
	zone.name = "WorldDropZone"
	zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.z_index = -10
	zone.drop_requested.connect(_on_world_drop_requested)
	root.add_child(zone)
	root.move_child(zone, 0)

func _on_world_drop_requested(from_index: int) -> void:
	inventory_slot_dropped.emit(from_index, -1)

func _build_ui() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_create_hud()
	_create_hotbar()
	_create_inventory()
	_create_settings()
	_create_debug()
	_create_logs()

func _bind_existing_ui() -> void:
	root = get_node("Root") as Control
	health_bar = _find_node("HealthBar") as ProgressBar
	stamina_bar = _find_node("StaminaBar") as ProgressBar
	health_text = _find_node("HealthValue") as Label
	stamina_text = _find_node("StaminaValue") as Label
	arrow_text = _find_node("ArrowText") as Label
	fps_text = _find_node("FPSText") as Label
	inventory_grid = _find_node("BackpackGrid") as GridContainer
	backpack_text = _find_node("BackpackText") as Label
	settings_shake = _find_node("ScreenShake") as CheckBox
	settings_zoom = _find_node("CameraZoom") as HSlider
	settings_debug = _find_node("DebugMode") as CheckBox
	debug_target_text = _find_node("DebugTarget") as Label
	debug_stats = _find_node("DebugStats") as Label
	debug_filter = _find_node("DebugFilter") as OptionButton
	debug_object_list = _find_node("DebugObjectList") as ItemList
	debug_properties = _find_node("DebugProperties") as VBoxContainer
	debug_infinite_stamina = _find_node("InfiniteStamina") as CheckBox
	debug_invulnerable = _find_node("Invulnerable") as CheckBox
	debug_delete_dialog = _find_node("DebugDeleteDialog") as ConfirmationDialog
	debug_walk_speed = _find_node("WalkSpeed") as SpinBox
	debug_strength = _find_node("Strength") as SpinBox
	logs_text = _find_node("LogText") as TextEdit

	panels = {
		"inventory": _find_node("InventoryPanel"),
		"settings": _find_node("SettingsPanel"),
		"debug": _find_node("DebugPanel"),
		"logs": _find_node("LogsPanel"),
	}
	hotbar_buttons.clear()
	var row := _find_node("HotbarRow") as HBoxContainer
	if row != null:
		for index in range(row.get_child_count()):
			var child := row.get_child(index)
			if child is Button:
				var button := child as Button
				if button.get_script() != InventorySlotScript:
					button.set_script(InventorySlotScript)
				button.set_meta("slot_index", index)
				if not button.has_meta("item_id"):
					button.set_meta("item_id", "")
				hotbar_buttons.append(button)

func _find_node(node_name: String) -> Node:
	return root.find_child(node_name, true, false) if root != null else null

func _claim_editor_ownership(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		_claim_editor_ownership(child, scene_root)

func _wire_controls() -> void:
	for index in range(hotbar_buttons.size()):
		var callback := Callable(self, "_on_hotbar_pressed").bind(index)
		if not hotbar_buttons[index].pressed.is_connected(callback):
			hotbar_buttons[index].pressed.connect(callback)
		var hotbar_slot := hotbar_buttons[index]
		if hotbar_slot.has_signal("drop_requested") and not hotbar_slot.is_connected("drop_requested", _on_inventory_slot_dropped):
			hotbar_slot.connect("drop_requested", _on_inventory_slot_dropped)
	if inventory_grid != null:
		for index in range(inventory_grid.get_child_count()):
			var child := inventory_grid.get_child(index)
			if child is Button:
				var backpack_slot := child as Button
				if backpack_slot.get_script() != InventorySlotScript:
					backpack_slot.set_script(InventorySlotScript)
				backpack_slot.set_meta("slot_index", 9 + index)
				if not backpack_slot.has_meta("item_id"):
					backpack_slot.set_meta("item_id", "")
				if backpack_slot.has_signal("drop_requested") and not backpack_slot.is_connected("drop_requested", _on_inventory_slot_dropped):
					backpack_slot.connect("drop_requested", _on_inventory_slot_dropped)

	var expand_button := _find_node("ExpandBackpack") as Button
	if expand_button != null and not expand_button.pressed.is_connected(_on_expand_pressed):
		expand_button.pressed.connect(_on_expand_pressed)

	if settings_shake != null and not settings_shake.toggled.is_connected(_on_settings_toggled):
		settings_shake.toggled.connect(_on_settings_toggled)
	if settings_zoom != null and not settings_zoom.value_changed.is_connected(_on_camera_zoom_changed):
		settings_zoom.value_changed.connect(_on_camera_zoom_changed)
	if settings_debug != null and not settings_debug.toggled.is_connected(_on_settings_debug_toggled):
		settings_debug.toggled.connect(_on_settings_debug_toggled)
	if debug_walk_speed != null and not debug_walk_speed.value_changed.is_connected(_on_walk_speed_changed):
		debug_walk_speed.value_changed.connect(_on_walk_speed_changed)
	if debug_strength != null and not debug_strength.value_changed.is_connected(_on_strength_changed):
		debug_strength.value_changed.connect(_on_strength_changed)
	if debug_filter != null and not debug_filter.item_selected.is_connected(_on_debug_filter_changed):
		debug_filter.item_selected.connect(_on_debug_filter_changed)
	if debug_object_list != null and not debug_object_list.item_selected.is_connected(_on_debug_object_selected):
		debug_object_list.item_selected.connect(_on_debug_object_selected)
	if debug_infinite_stamina != null and not debug_infinite_stamina.toggled.is_connected(_on_debug_cheat_toggled):
		debug_infinite_stamina.toggled.connect(_on_debug_cheat_toggled)
	if debug_invulnerable != null and not debug_invulnerable.toggled.is_connected(_on_debug_cheat_toggled):
		debug_invulnerable.toggled.connect(_on_debug_cheat_toggled)
	if debug_delete_dialog != null and not debug_delete_dialog.confirmed.is_connected(_on_debug_delete_confirmed):
		debug_delete_dialog.confirmed.connect(_on_debug_delete_confirmed)
	var clone_button := _find_node("DebugClone") as Button
	if clone_button != null and not clone_button.pressed.is_connected(_on_debug_clone_pressed):
		clone_button.pressed.connect(_on_debug_clone_pressed)
	var reset_button := _find_node("DebugReset") as Button
	if reset_button != null and not reset_button.pressed.is_connected(_on_debug_reset_pressed):
		reset_button.pressed.connect(_on_debug_reset_pressed)
	var delete_button := _find_node("DebugDelete") as Button
	if delete_button != null and not delete_button.pressed.is_connected(_ask_debug_delete):
		delete_button.pressed.connect(_ask_debug_delete)

	var clear_button := _find_node("ClearLogs") as Button
	if clear_button != null and not clear_button.pressed.is_connected(_on_clear_logs):
		clear_button.pressed.connect(_on_clear_logs)
	for panel_value in panels.values():
		var panel := panel_value as Control
		if panel == null:
			continue
		var close_button := panel.find_child("CloseButton", true, false) as Button
		if close_button != null and not close_button.pressed.is_connected(close_panels):
			close_button.pressed.connect(close_panels)

func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#272b30")
	style.border_color = Color("#8b9299")
	style.set_border_width_all(3)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _style_slot(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#343940")
	normal.border_color = Color("#858d96")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#444c55")
	hover.border_color = Color("#c4ccd3")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#5b654e")
	pressed.border_color = Color("#d8e7bd")
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#202328")
	disabled.border_color = Color("#41464c")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _make_label(text_value: String, size: int = 14, color: Color = Color("#e5ecd9")) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _create_slot_visuals(button: Button, key_text: String = "") -> void:
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 8
	icon_rect.offset_top = 8
	icon_rect.offset_right = -8
	icon_rect.offset_bottom = -8
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon_rect)

	var key_label := Label.new()
	key_label.name = "KeyNumber"
	key_label.text = key_text
	key_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	key_label.offset_left = 4
	key_label.offset_top = 1
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", Color("#e1e5e9"))
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(key_label)

	var count_label := Label.new()
	count_label.name = "StackCount"
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_left = -30
	count_label.offset_top = -19
	count_label.offset_right = -3
	count_label.offset_bottom = -2
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_label.add_theme_constant_override("shadow_offset_x", 1)
	count_label.add_theme_constant_override("shadow_offset_y", 1)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count_label)

	var lock_label := Label.new()
	lock_label.name = "LockMark"
	lock_label.text = "×"
	lock_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_label.add_theme_font_size_override("font_size", 20)
	lock_label.add_theme_color_override("font_color", Color("#8d949b"))
	lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_label.visible = false
	button.add_child(lock_label)

func _style_hud_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#141a1b")
	background.border_color = Color("#46534a")
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.border_color = fill_color.lightened(0.12)
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

func _create_hud() -> void:
	var panel := PanelContainer.new()
	panel.name = "HUD"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 18
	panel.offset_top = -132
	panel.offset_right = 238
	panel.offset_bottom = -14
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.075, 0.07, 0.94)
	panel_style.border_color = Color("#586b59")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 11
	panel_style.content_margin_right = 11
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "HUDContent"
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var title := _make_label("СОСТОЯНИЕ", 10, Color("#b7d29c"))
	title.name = "GameTitle"
	box.add_child(title)
	var health_row := HBoxContainer.new()
	health_row.name = "HealthRow"
	health_row.add_child(_make_label("ЗДОРОВЬЕ", 11, Color("#f0c8c0")))
	var health_spacer := Control.new()
	health_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(health_spacer)
	health_text = _make_label("100 / 100", 11, Color("#f2c7bd"))
	health_text.name = "HealthValue"
	health_row.add_child(health_text)
	box.add_child(health_row)
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(190, 12)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.max_value = 100
	health_bar.show_percentage = false
	_style_hud_bar(health_bar, Color("#c95d54"))
	box.add_child(health_bar)
	var stamina_row := HBoxContainer.new()
	stamina_row.name = "StaminaRow"
	stamina_row.add_child(_make_label("ВЫНОСЛИВОСТЬ", 11, Color("#cce0ae")))
	var stamina_spacer := Control.new()
	stamina_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_row.add_child(stamina_spacer)
	stamina_text = _make_label("100 / 100", 11, Color("#d0e5ad"))
	stamina_text.name = "StaminaValue"
	stamina_row.add_child(stamina_text)
	box.add_child(stamina_row)
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.custom_minimum_size = Vector2(190, 12)
	stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_bar.max_value = 100
	stamina_bar.show_percentage = false
	_style_hud_bar(stamina_bar, Color("#8cab58"))
	box.add_child(stamina_bar)
	arrow_text = _make_label("СТРЕЛЫ  ·  30", 10, Color("#ddc88f"))
	arrow_text.name = "ArrowText"
	box.add_child(arrow_text)
	fps_text = _make_label("FPS: 60", 12, Color("#d1d8c8"))
	fps_text.name = "FPSText"
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
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -78
	panel.offset_bottom = -10
	_style_panel(panel)
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.name = "HotbarRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	for index in range(9):
		var button := InventorySlotScript.new() as InventorySlot
		button.slot_index = index
		button.name = "Slot%d" % (index + 1)
		button.custom_minimum_size = Vector2(50, 50)
		button.toggle_mode = true
		button.text = ""
		button.tooltip_text = ITEM_LABELS.get(HOTBAR_ITEMS[index], "Пустой слот")
		_style_slot(button)
		_create_slot_visuals(button, str(index + 1))
		row.add_child(button)
		hotbar_buttons.append(button)

func _create_center_panel(panel_name: String, title_text: String, rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name.capitalize() + "Panel"
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
	box.name = "Content"
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.name = "Header"
	var heading := _make_label(title_text, 19, Color("#e0edce"))
	heading.name = "Heading"
	header.add_child(heading)
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "×"
	close.custom_minimum_size = Vector2(34, 30)
	header.add_child(close)
	box.add_child(header)
	box.add_child(HSeparator.new())
	return box

func _create_inventory() -> void:
	var box := _create_center_panel("inventory", "Инвентарь", Rect2(-370, -195, 740, 390))
	var layout := HBoxContainer.new()
	layout.name = "InventoryLayout"
	layout.add_theme_constant_override("separation", 14)
	box.add_child(layout)

	var equipment_column := VBoxContainer.new()
	equipment_column.name = "EquipmentColumn"
	equipment_column.custom_minimum_size.x = 142
	equipment_column.add_theme_constant_override("separation", 5)
	layout.add_child(equipment_column)
	equipment_column.add_child(_make_label("Экипировка", 14, Color("#b8d49f")))
	for item_name in ["Шлем", "Нагрудник", "Перчатки", "Поножи", "Сапоги"]:
		var slot := Button.new()
		slot.name = "Equipment_" + item_name
		slot.text = item_name + "\n—"
		slot.custom_minimum_size = Vector2(132, 48)
		slot.disabled = true
		_style_slot(slot)
		equipment_column.add_child(slot)

	var backpack_column := VBoxContainer.new()
	backpack_column.name = "BackpackColumn"
	backpack_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_column.add_theme_constant_override("separation", 5)
	layout.add_child(backpack_column)
	backpack_column.add_child(_make_label("Рюкзак · 9 × 3", 14, Color("#b8d49f")))
	backpack_text = _make_label("12 / 24 ячеек открыто", 12, Color("#d4dec8"))
	backpack_text.name = "BackpackText"
	backpack_column.add_child(backpack_text)

	inventory_grid = GridContainer.new()
	inventory_grid.name = "BackpackGrid"
	inventory_grid.columns = 9
	inventory_grid.add_theme_constant_override("h_separation", 4)
	inventory_grid.add_theme_constant_override("v_separation", 4)
	backpack_column.add_child(inventory_grid)
	for index in range(27):
		var slot := InventorySlotScript.new() as InventorySlot
		slot.slot_index = 9 + index
		slot.name = "BackpackSlot%02d" % index
		slot.custom_minimum_size = Vector2(48, 48)
		slot.text = ""
		slot.tooltip_text = "Пустая ячейка"
		_style_slot(slot)
		_create_slot_visuals(slot)
		inventory_grid.add_child(slot)

	var expand := Button.new()
	expand.name = "ExpandBackpack"
	expand.text = "Увеличить рюкзак (+3)"
	expand.custom_minimum_size.y = 28
	backpack_column.add_child(expand)
	box.add_child(_make_label("Предметы и экипировка отображаются отдельными ячейками, как в Minecraft.", 11, Color("#9eaa93")))

func _create_settings() -> void:
	var box := _create_center_panel("settings", "Настройки", Rect2(-240, -190, 480, 380))
	box.add_child(_make_label("Эффекты камеры", 14, Color("#b8d49f")))
	settings_shake = CheckBox.new()
	settings_shake.name = "ScreenShake"
	settings_shake.text = "Тряска камеры при ударах"
	box.add_child(settings_shake)
	box.add_child(_make_label("Базовый масштаб камеры", 13))
	settings_zoom = HSlider.new()
	settings_zoom.name = "CameraZoom"
	settings_zoom.min_value = 0.8
	settings_zoom.max_value = 3.0
	settings_zoom.step = 0.05
	settings_zoom.value = 1.85
	box.add_child(settings_zoom)
	box.add_child(HSeparator.new())
	box.add_child(_make_label("Отладка", 14, Color("#b8d49f")))
	settings_debug = CheckBox.new()
	settings_debug.name = "DebugMode"
	settings_debug.text = "Режим выделения объектов (Debug Inspector)"
	box.add_child(settings_debug)
	box.add_child(_make_label("Включи режим, затем нажимай на объекты мира, чтобы открыть и менять их параметры. F3 — быстрый переключатель.", 11, Color("#9eaa93")))
	box.add_child(_make_label("Настройки сохраняются в локальном файле Godot.", 11, Color("#9eaa93")))

func _create_debug() -> void:
	var box := _create_center_panel("debug", "Debug Inspector · F3", Rect2(70, -250, 430, 500))
	debug_stats = _make_label("FPS: — · Позиция: — · Бег: —", 11, Color("#b8d49f"))
	debug_stats.name = "DebugStats"
	box.add_child(debug_stats)
	debug_target_text = _make_label("Выбран объект: Игрок", 12, Color("#e5d6a6"))
	debug_target_text.name = "DebugTarget"
	box.add_child(debug_target_text)

	var filter_row := HBoxContainer.new()
	filter_row.add_child(_make_label("Фильтр объектов:", 12))
	debug_filter = OptionButton.new()
	debug_filter.name = "DebugFilter"
	debug_filter.add_item("Все объекты")
	debug_filter.select(0)
	debug_filter.set_item_metadata(0, "all")
	debug_filter.add_item("Игрок")
	debug_filter.set_item_metadata(1, "player")
	debug_filter.add_item("Деревья")
	debug_filter.set_item_metadata(2, "tree")
	debug_filter.add_item("Камни")
	debug_filter.set_item_metadata(3, "rock")
	debug_filter.add_item("Предметы")
	debug_filter.set_item_metadata(4, "drop")
	debug_filter.add_item("Оружие")
	debug_filter.set_item_metadata(5, "weapon")
	filter_row.add_child(debug_filter)
	box.add_child(filter_row)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	debug_object_list = ItemList.new()
	debug_object_list.name = "DebugObjectList"
	debug_object_list.custom_minimum_size = Vector2(145, 300)
	debug_object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug_object_list.allow_reselect = true
	body.add_child(debug_object_list)

	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(inspector_scroll)
	debug_properties = VBoxContainer.new()
	debug_properties.name = "DebugProperties"
	debug_properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.add_child(debug_properties)
	debug_properties.add_child(_make_label("Выбери объект в списке или кликни по нему в мире.", 12, Color("#d4dec8")))

	var cheat_row := HBoxContainer.new()
	debug_infinite_stamina = CheckBox.new()
	debug_infinite_stamina.name = "InfiniteStamina"
	debug_infinite_stamina.text = "Бесконечная выносливость"
	cheat_row.add_child(debug_infinite_stamina)
	debug_invulnerable = CheckBox.new()
	debug_invulnerable.name = "Invulnerable"
	debug_invulnerable.text = "Неуязвимость"
	cheat_row.add_child(debug_invulnerable)
	box.add_child(cheat_row)

	var actions := HBoxContainer.new()
	var clone_button := Button.new()
	clone_button.name = "DebugClone"
	clone_button.text = "Копировать объект"
	actions.add_child(clone_button)
	var reset_button := Button.new()
	reset_button.name = "DebugReset"
	reset_button.text = "Сбросить параметры"
	actions.add_child(reset_button)
	var delete_button := Button.new()
	delete_button.name = "DebugDelete"
	delete_button.text = "Удалить…"
	actions.add_child(delete_button)
	box.add_child(actions)

	debug_delete_dialog = ConfirmationDialog.new()
	debug_delete_dialog.name = "DebugDeleteDialog"
	debug_delete_dialog.title = "Удаление объекта"
	debug_delete_dialog.dialog_text = "Удалить выбранный объект из текущей игровой сессии?"
	root.add_child(debug_delete_dialog)

func _on_debug_filter_changed(_index: int) -> void:
	_render_debug_object_list()

func _on_debug_object_selected(index: int) -> void:
	if index < 0 or index >= debug_object_list.item_count:
		return
	var object_id := str(debug_object_list.get_item_metadata(index))
	debug_object_selected.emit(object_id)

func _on_debug_cheat_toggled(_enabled: bool) -> void:
	debug_cheats_changed.emit(
		debug_infinite_stamina.button_pressed if debug_infinite_stamina != null else false,
		debug_invulnerable.button_pressed if debug_invulnerable != null else false
	)

func _ask_debug_delete() -> void:
	if debug_delete_dialog != null:
		debug_delete_dialog.popup_centered()

func _on_debug_clone_pressed() -> void:
	debug_clone_requested.emit()

func _on_debug_reset_pressed() -> void:
	debug_reset_requested.emit()

func _on_debug_delete_confirmed() -> void:
	debug_delete_requested.emit()

func _render_debug_object_list() -> void:
	if debug_object_list == null:
		return
	debug_object_list.clear()
	var filter_value := "all"
	if debug_filter != null and debug_filter.selected >= 0:
		filter_value = str(debug_filter.get_item_metadata(debug_filter.selected))
	for entry in debug_objects:
		var kind := str(entry.get("kind", "other"))
		if filter_value != "all":
			if filter_value == "tree" and kind != "tree" and kind != "stump":
				continue
			elif filter_value == "rock" and kind != "rock":
				continue
			elif filter_value == "drop" and kind != "drop":
				continue
			elif filter_value == "weapon" and kind != "weapon":
				continue
			elif filter_value == "player" and kind != "player":
				continue
		debug_object_list.add_item(str(entry.get("label", "Объект")))
		var item_index := debug_object_list.item_count - 1
		debug_object_list.set_item_metadata(item_index, str(entry.get("id", "")))
		if str(entry.get("id", "")) == str(entry.get("selected_id", "")):
			debug_object_list.select(item_index)

func set_debug_objects(entries: Array[Dictionary], selected_id: String = "") -> void:
	debug_objects.clear()
	for entry in entries:
		var copied_entry: Dictionary = entry.duplicate(true)
		copied_entry["selected_id"] = selected_id
		debug_objects.append(copied_entry)
	_render_debug_object_list()

func set_debug_properties(properties: Array[Dictionary]) -> void:
	if debug_properties == null:
		return
	for child in debug_properties.get_children():
		child.queue_free()
	for property_data in properties:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := _make_label(str(property_data.get("label", property_data.get("path", "Параметр"))), 11)
		title.custom_minimum_size.x = 142
		row.add_child(title)
		var property_path := str(property_data.get("path", ""))
		if property_data.has("options"):
			var editor := OptionButton.new()
			var options: Array = property_data["options"]
			for option in options:
				editor.add_item(str(option))
			editor.select(clampi(roundi(float(property_data.get("value", 0.0))), 0, maxi(0, options.size() - 1)))
			editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			editor.item_selected.connect(_on_inspector_option_changed.bind(property_path))
			row.add_child(editor)
		else:
			var editor := SpinBox.new()
			editor.min_value = float(property_data.get("min", -100000.0))
			editor.max_value = float(property_data.get("max", 100000.0))
			editor.step = float(property_data.get("step", 0.1))
			editor.value = float(property_data.get("value", 0.0))
			editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			editor.value_changed.connect(_on_inspector_value_changed.bind(property_path))
			row.add_child(editor)
		debug_properties.add_child(row)

func _on_inspector_value_changed(value: float, property_path: String) -> void:
	debug_value_changed.emit(property_path, value)

func _on_inspector_option_changed(index: int, property_path: String) -> void:
	debug_value_changed.emit(property_path, float(index))

func set_debug_stats(value: String) -> void:
	if debug_stats != null:
		debug_stats.text = value

func set_debug_mode_enabled(enabled: bool) -> void:
	if settings_debug != null:
		settings_debug.set_pressed_no_signal(enabled)

func set_debug_cheats(infinite_stamina: bool, invulnerable: bool) -> void:
	if debug_infinite_stamina != null:
		debug_infinite_stamina.set_pressed_no_signal(infinite_stamina)
	if debug_invulnerable != null:
		debug_invulnerable.set_pressed_no_signal(invulnerable)

func _create_logs() -> void:
	var box := _create_center_panel("logs", "Журнал событий · F2", Rect2(-300, -205, 600, 410))
	logs_text = TextEdit.new()
	logs_text.name = "LogText"
	logs_text.custom_minimum_size = Vector2(570, 325)
	logs_text.editable = false
	logs_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(logs_text)
	var clear := Button.new()
	clear.name = "ClearLogs"
	clear.text = "Очистить журнал"
	box.add_child(clear)

func _refresh_item_icons() -> void:
	for index in range(hotbar_buttons.size()):
		var item_id := str(HOTBAR_ITEMS[index])
		_set_slot_icon(hotbar_buttons[index], item_id, 30 if item_id == "arrows" else 0)
	if inventory_grid != null:
		var backpack_items := ["sword", "pickaxe", "axe", "bow", "arrows"]
		for index in range(inventory_grid.get_child_count()):
			var item_id := str(backpack_items[index]) if index < backpack_items.size() else ""
			var count := 30 if item_id == "arrows" else 0
			_set_slot_icon(inventory_grid.get_child(index) as Button, item_id, count)

func _get_resource_icon(item_id: String) -> Texture2D:
	if resource_icon_cache.has(item_id):
		return resource_icon_cache[item_id] as Texture2D
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if item_id == "wood":
		image.fill_rect(Rect2i(5, 9, 22, 14), Color("#82512f"))
		image.fill_rect(Rect2i(4, 12, 24, 8), Color("#a96f3e"))
		image.fill_rect(Rect2i(6, 8, 20, 3), Color("#c28b54"))
		image.fill_rect(Rect2i(7, 21, 18, 3), Color("#5b3926"))
		image.fill_rect(Rect2i(8, 12, 3, 8), Color("#d5a36a"))
		image.fill_rect(Rect2i(20, 12, 2, 8), Color("#6e452b"))
		image.fill_rect(Rect2i(4, 11, 3, 10), Color("#d1a06a"))
		image.fill_rect(Rect2i(25, 11, 3, 10), Color("#5b3926"))
	else:
		image.fill_rect(Rect2i(9, 5, 14, 3), Color("#aebbb1"))
		image.fill_rect(Rect2i(5, 8, 22, 4), Color("#8c9992"))
		image.fill_rect(Rect2i(3, 12, 26, 11), Color("#697874"))
		image.fill_rect(Rect2i(7, 23, 17, 4), Color("#4d5d59"))
		image.fill_rect(Rect2i(6, 12, 5, 3), Color("#c0c9bd"))
		image.fill_rect(Rect2i(16, 9, 5, 3), Color("#bdc7ba"))
		image.fill_rect(Rect2i(13, 17, 4, 3), Color("#4c5a57"))
		image.fill_rect(Rect2i(22, 14, 4, 5), Color("#899891"))
	var texture := ImageTexture.create_from_image(image)
	resource_icon_cache[item_id] = texture
	return texture

func _set_slot_icon(button: Button, item_id: String, count: int, tooltip: String = "") -> void:
	if button == null:
		return
	var icon_rect := button.get_node_or_null("Icon") as TextureRect
	var count_label := button.get_node_or_null("StackCount") as Label
	if icon_rect != null:
		if ITEM_TEXTURE_PATHS.has(item_id):
			icon_rect.texture = load(ITEM_TEXTURE_PATHS[item_id]) as Texture2D
			icon_rect.visible = true
			button.text = ""
		elif item_id == "wood" or item_id == "stone":
			icon_rect.texture = _get_resource_icon(item_id)
			icon_rect.visible = true
			button.text = ""
		else:
			icon_rect.texture = null
			icon_rect.visible = false
			button.text = ""
	button.set_meta("item_id", item_id)
	if count_label != null:
		count_label.text = str(count) if count > 1 else ""
	if tooltip != "":
		button.tooltip_text = tooltip
	else:
		button.tooltip_text = str(ITEM_LABELS.get(item_id, "Пустая ячейка"))

func set_inventory_data(items: Array[Dictionary], open_slots: int, maximum_slots: int, definitions: Dictionary) -> void:
	set_backpack_slots(open_slots, maximum_slots)
	for index in range(hotbar_buttons.size()):
		var stack: Dictionary = items[index] if index < items.size() else {}
		var item_id := str(stack.get("id", ""))
		var amount := int(stack.get("amount", 0))
		_set_slot_icon(hotbar_buttons[index], item_id, amount, _build_item_tooltip(item_id, definitions))
	if inventory_grid != null:
		for index in range(inventory_grid.get_child_count()):
			var source_index := index + 9
			var stack: Dictionary = items[source_index] if source_index < items.size() else {}
			var item_id := str(stack.get("id", ""))
			var amount := int(stack.get("amount", 0))
			_set_slot_icon(inventory_grid.get_child(index) as Button, item_id, amount, _build_item_tooltip(item_id, definitions))
	# Reapply lock state after tooltip refresh so closed cells remain clearly marked.
	set_backpack_slots(open_slots, maximum_slots)

func _build_item_tooltip(item_id: String, definitions: Dictionary) -> String:
	if item_id.is_empty():
		return "Пустая ячейка"
	var definition: Dictionary = definitions.get(item_id, {})
	var lines := PackedStringArray()
	lines.append(str(definition.get("label", ITEM_LABELS.get(item_id, item_id.capitalize()))))
	if definition.has("damage"):
		lines.append("Урон: %s" % str(definition["damage"]))
	if definition.has("damage_type"):
		lines.append("Тип урона: %s" % str(definition["damage_type"]))
	if definition.has("attack_type"):
		lines.append("Тип атаки: %s" % str(definition["attack_type"]))
	if definition.has("stamina_cost"):
		lines.append("Расход выносливости: %s" % str(definition["stamina_cost"]))
	if definition.has("efficiency"):
		lines.append("Эффективность: %s" % str(definition["efficiency"]))
	return "\n".join(lines)

func _on_inventory_slot_dropped(from_index: int, to_index: int) -> void:
	inventory_slot_dropped.emit(from_index, to_index)

func _on_hotbar_pressed(index: int) -> void:
	slot_selected.emit(index)

func _on_expand_pressed() -> void:
	backpack_expand_requested.emit()

func _on_settings_toggled(_pressed: bool) -> void:
	_emit_settings()

func _on_settings_debug_toggled(enabled: bool) -> void:
	debug_mode_requested.emit(enabled)

func _on_camera_zoom_changed(_value: float) -> void:
	_emit_settings()

func _on_walk_speed_changed(value: float) -> void:
	debug_value_changed.emit("player.walk_speed", value)

func _on_strength_changed(value: float) -> void:
	debug_value_changed.emit("player.strength", value)

func _on_clear_logs() -> void:
	log_lines.clear()
	_render_logs()

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
	var closing_debug := current_panel == "debug"
	for panel in panels.values():
		if panel is Control:
			(panel as Control).visible = false
	current_panel = ""
	if closing_debug:
		set_debug_mode_enabled(false)
		debug_mode_requested.emit(false)

func has_modal_open() -> bool:
	return current_panel != ""

func set_backpack_slots(open_slots: int, maximum: int) -> void:
	backpack_slots = open_slots
	max_backpack_slots = maximum
	if backpack_text == null or inventory_grid == null:
		return
	backpack_text.text = "%d / %d ячеек открыто" % [backpack_slots, max_backpack_slots]
	for index in range(inventory_grid.get_child_count()):
		var slot := inventory_grid.get_child(index) as Button
		var unlocked := index < backpack_slots
		slot.disabled = not unlocked
		slot.tooltip_text = "Пустая ячейка" if unlocked else "Ячейка закрыта"
		var lock_mark := slot.get_node_or_null("LockMark") as Label
		if lock_mark != null:
			lock_mark.visible = not unlocked

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
