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
signal debug_default_requested(path: String, value: Variant)
signal debug_item_save_requested
signal debug_inventory_item_selected(slot_index: int)
signal debug_spawn_item_requested(item_id: String, amount: int)

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
var item_definitions_cache: Dictionary = {}
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
var debug_panel_size := Vector2(880.0, 620.0)
var debug_panel_position := Vector2(-1.0, -1.0)
var debug_panel_opacity := 0.92
var debug_panel_scale := 1.0
var debug_panel_dragging := false
var debug_panel_drag_offset := Vector2.ZERO
var debug_window_settings: VBoxContainer
var debug_panel_settings_button: Button
var debug_item_save_button: Button
var debug_nearby_toggle: CheckBox
var debug_inventory_option: OptionButton
var debug_inventory_items_signature := ""
var debug_panel_width_slider: HSlider
var debug_panel_height_slider: HSlider
var debug_panel_opacity_slider: HSlider
var debug_panel_scale_slider: HSlider
var debug_panel_scale_label: Label
var debug_panel_reset_position_button: Button
var debug_spawn_toggle: Button
var debug_spawn_menu: VBoxContainer
var debug_spawn_category: OptionButton
var debug_spawn_option: OptionButton
var debug_spawn_amount: SpinBox
var debug_spawn_confirm: Button
var debug_spawn_catalog: Dictionary = {}
var debug_spawn_categories: Dictionary = {}
var settings_hud_scale := 1.0
var settings_hotbar_scale := 1.0
var settings_windows_scale := 1.0
var settings_hud_scale_slider: HSlider
var settings_hotbar_scale_slider: HSlider
var settings_windows_scale_slider: HSlider
var settings_hud_scale_label: Label
var settings_hotbar_scale_label: Label
var settings_windows_scale_label: Label
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
	"sword": "res://Assets/CozyVillageFarm/06_Farming/Tools/basic/sword_basic.png",
	"pickaxe": "res://Assets/CozyVillageFarm/06_Farming/Tools/basic/pickaxe_basic.png",
	"axe": "res://Assets/CozyVillageFarm/06_Farming/Tools/basic/axe_basic.png",
	"bow": "res://Assets/Weapons/bow.png",
	"arrows": "res://Assets/Items/arrows.png",
	"wood": "res://Assets/CozyVillageFarm/10_Items/Resources/wood.png",
	"stone": "res://Assets/CozyVillageFarm/10_Items/Resources/stone.png",
}

func _ready() -> void:
	layer = 10
	if has_node("Root"):
		_bind_existing_ui()
	else:
		_build_ui()
	_create_world_drop_zone()
	_ensure_debug_panel_features()
	_ensure_ui_scale_settings()
	if Engine.is_editor_hint() and get_tree().edited_scene_root == self:
		_claim_editor_ownership(root, self)
	_wire_controls()
	_load_debug_panel_settings()
	_load_ui_scale_settings()
	_refresh_item_icons()
	if not get_viewport().size_changed.is_connected(_fit_debug_panel_to_viewport):
		get_viewport().size_changed.connect(_fit_debug_panel_to_viewport)
	get_viewport().size_changed.connect(_apply_ui_element_scales)
	call_deferred("_fit_debug_panel_to_viewport")
	call_deferred("_apply_ui_element_scales")
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
	if debug_nearby_toggle != null and not debug_nearby_toggle.toggled.is_connected(_on_debug_nearby_toggled):
		debug_nearby_toggle.toggled.connect(_on_debug_nearby_toggled)
	if debug_inventory_option != null and not debug_inventory_option.item_selected.is_connected(_on_debug_inventory_option_selected):
		debug_inventory_option.item_selected.connect(_on_debug_inventory_option_selected)
	if settings_hud_scale_slider != null and not settings_hud_scale_slider.value_changed.is_connected(_on_ui_scale_changed):
		settings_hud_scale_slider.value_changed.connect(_on_ui_scale_changed)
	if settings_hotbar_scale_slider != null and not settings_hotbar_scale_slider.value_changed.is_connected(_on_ui_scale_changed):
		settings_hotbar_scale_slider.value_changed.connect(_on_ui_scale_changed)
	if settings_windows_scale_slider != null and not settings_windows_scale_slider.value_changed.is_connected(_on_ui_scale_changed):
		settings_windows_scale_slider.value_changed.connect(_on_ui_scale_changed)
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
	if debug_panel_settings_button != null and not debug_panel_settings_button.pressed.is_connected(_toggle_debug_window_settings):
		debug_panel_settings_button.pressed.connect(_toggle_debug_window_settings)
	if debug_item_save_button != null and not debug_item_save_button.pressed.is_connected(_on_debug_item_save_pressed):
		debug_item_save_button.pressed.connect(_on_debug_item_save_pressed)
	if debug_panel_width_slider != null and not debug_panel_width_slider.value_changed.is_connected(_on_debug_panel_dimension_changed):
		debug_panel_width_slider.value_changed.connect(_on_debug_panel_dimension_changed)
	if debug_panel_height_slider != null and not debug_panel_height_slider.value_changed.is_connected(_on_debug_panel_dimension_changed):
		debug_panel_height_slider.value_changed.connect(_on_debug_panel_dimension_changed)
	if debug_panel_opacity_slider != null and not debug_panel_opacity_slider.value_changed.is_connected(_on_debug_panel_opacity_changed):
		debug_panel_opacity_slider.value_changed.connect(_on_debug_panel_opacity_changed)
	if debug_panel_scale_slider != null and not debug_panel_scale_slider.value_changed.is_connected(_on_debug_panel_scale_changed):
		debug_panel_scale_slider.value_changed.connect(_on_debug_panel_scale_changed)
	if debug_panel_reset_position_button != null and not debug_panel_reset_position_button.pressed.is_connected(_reset_debug_panel_position):
		debug_panel_reset_position_button.pressed.connect(_reset_debug_panel_position)
	if debug_spawn_toggle != null and not debug_spawn_toggle.pressed.is_connected(_toggle_debug_spawn_menu):
		debug_spawn_toggle.pressed.connect(_toggle_debug_spawn_menu)
	if debug_spawn_category != null and not debug_spawn_category.item_selected.is_connected(_on_debug_spawn_category_changed):
		debug_spawn_category.item_selected.connect(_on_debug_spawn_category_changed)
	if debug_spawn_confirm != null and not debug_spawn_confirm.pressed.is_connected(_on_debug_spawn_confirmed):
		debug_spawn_confirm.pressed.connect(_on_debug_spawn_confirmed)
	for panel_value in panels.values():
		var panel := panel_value as Control
		if panel == null:
			continue
		var close_button := panel.find_child("CloseButton", true, false) as Button
		if close_button != null and not close_button.pressed.is_connected(close_panels):
			close_button.pressed.connect(close_panels)

func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20272d")
	style.border_color = Color("#52675a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
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
	var box := _create_center_panel("settings", "Настройки", Rect2(-270, -250, 540, 500))
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
	box.add_child(_make_label("Включи режим и нажимай на объекты мира. F3 — быстрый переключатель.", 11, Color("#9eaa93")))
	box.add_child(_make_label("Настройки сохраняются локально.", 11, Color("#9eaa93")))
func _create_debug() -> void:
	var box := _create_center_panel("debug", "DEBUG · ИНСПЕКТОР", Rect2(-440, -310, 880, 620))
	debug_stats = _make_label("FPS: — · Позиция: — · Объекты рядом: —", 11, Color("#a9bd9e"))
	debug_stats.name = "DebugStats"
	debug_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(debug_stats)

	debug_target_text = _make_label("Выбран объект: Игрок", 12, Color("#e5d6a6"))
	debug_target_text.name = "DebugTarget"
	var selection_row := HBoxContainer.new()
	selection_row.name = "DebugSelectionRow"
	selection_row.add_theme_constant_override("separation", 8)
	debug_target_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_child(debug_target_text)
	debug_inventory_option = OptionButton.new()
	debug_inventory_option.name = "DebugInventorySlot"
	debug_inventory_option.custom_minimum_size = Vector2(240, 30)
	debug_inventory_option.size_flags_horizontal = Control.SIZE_SHRINK_END
	debug_inventory_option.add_item("— Предмет из инвентаря / хотбара —")
	debug_inventory_option.set_item_metadata(0, -1)
	selection_row.add_child(debug_inventory_option)
	box.add_child(selection_row)

	var filter_row := HBoxContainer.new()
	filter_row.name = "DebugFilterRow"
	filter_row.add_theme_constant_override("separation", 8)
	filter_row.add_child(_make_label("Фильтр:", 11))
	debug_filter = OptionButton.new()
	debug_filter.name = "DebugFilter"
	debug_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	debug_filter.set_item_metadata(5, "weapons")
	debug_filter.add_item("Инструменты")
	debug_filter.set_item_metadata(6, "tools")
	debug_filter.add_item("Еда")
	debug_filter.set_item_metadata(7, "food")
	debug_filter.add_item("Материалы")
	debug_filter.set_item_metadata(8, "materials")
	debug_filter.add_item("Боеприпасы")
	debug_filter.set_item_metadata(9, "ammunition")
	filter_row.add_child(debug_filter)
	debug_nearby_toggle = CheckBox.new()
	debug_nearby_toggle.name = "DebugNearbyOnly"
	debug_nearby_toggle.text = "Рядом · 600 px"
	debug_nearby_toggle.button_pressed = true
	debug_nearby_toggle.tooltip_text = "Показывать ближайшие объекты и сортировать их по расстоянию до игрока"
	filter_row.add_child(debug_nearby_toggle)
	box.add_child(filter_row)

	var body := HBoxContainer.new()
	body.name = "DebugBody"
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	var object_column := VBoxContainer.new()
	object_column.name = "DebugObjectColumn"
	object_column.custom_minimum_size.x = 220
	object_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_column.add_theme_constant_override("separation", 4)
	body.add_child(object_column)
	object_column.add_child(_make_label("ОБЪЕКТЫ", 10, Color("#a9bd9e")))
	debug_object_list = ItemList.new()
	debug_object_list.name = "DebugObjectList"
	debug_object_list.custom_minimum_size = Vector2(220, 220)
	debug_object_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug_object_list.allow_reselect = true
	object_column.add_child(debug_object_list)

	var inspector_column := VBoxContainer.new()
	inspector_column.name = "DebugInspectorColumn"
	inspector_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_column.add_child(_make_label("ПАРАМЕТРЫ", 10, Color("#a9bd9e")))
	body.add_child(inspector_column)
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.name = "DebugInspectorScroll"
	inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inspector_column.add_child(inspector_scroll)
	debug_properties = VBoxContainer.new()
	debug_properties.name = "DebugProperties"
	debug_properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_properties.add_theme_constant_override("separation", 4)
	inspector_scroll.add_child(debug_properties)
	debug_properties.add_child(_make_label("Выбери объект слева или предмет из списка слотов выше.", 12, Color("#c3cfb8")))

	var cheat_row := HBoxContainer.new()
	cheat_row.name = "DebugCheatsRow"
	cheat_row.add_theme_constant_override("separation", 14)
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
	actions.name = "DebugActions"
	actions.add_theme_constant_override("separation", 6)
	var clone_button := Button.new()
	clone_button.name = "DebugClone"
	clone_button.text = "Копировать"
	clone_button.custom_minimum_size.y = 28
	actions.add_child(clone_button)
	var reset_button := Button.new()
	reset_button.name = "DebugReset"
	reset_button.text = "Сбросить"
	reset_button.custom_minimum_size.y = 28
	actions.add_child(reset_button)
	var delete_button := Button.new()
	delete_button.name = "DebugDelete"
	delete_button.text = "Удалить…"
	delete_button.custom_minimum_size.y = 28
	actions.add_child(delete_button)
	box.add_child(actions)

	debug_delete_dialog = ConfirmationDialog.new()
	debug_delete_dialog.name = "DebugDeleteDialog"
	debug_delete_dialog.title = "Удаление объекта"
	debug_delete_dialog.dialog_text = "Удалить выбранный объект из текущей игровой сессии?"
	root.add_child(debug_delete_dialog)
func _ensure_debug_panel_features() -> void:
	var panel := panels.get("debug") as PanelContainer
	if panel == null:
		return
	var content := panel.get_node_or_null("Content") as VBoxContainer
	if content == null:
		return

	# Keep the title row fixed while the complete inspector body scrolls.
	if not panel.has_meta("debug_scroll_layout_ready"):
		var header := content.get_node_or_null("Header") as HBoxContainer
		var separator: Control
		for child in content.get_children():
			if child is HSeparator:
				separator = child as Control
				break
		if header != null:
			content.remove_child(header)
		if separator != null:
			content.remove_child(separator)
		panel.remove_child(content)
		var outer := VBoxContainer.new()
		outer.name = "DebugPanelLayout"
		outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer.add_theme_constant_override("separation", 4)
		panel.add_child(outer)
		if header != null:
			outer.add_child(header)
		if separator != null:
			outer.add_child(separator)
		var scroll := ScrollContainer.new()
		scroll.name = "DebugContentViewport"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		outer.add_child(scroll)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.custom_minimum_size = Vector2.ZERO
		scroll.add_child(content)
		panel.set_meta("debug_scroll_layout_ready", true)
	panel.custom_minimum_size = Vector2.ZERO
	panel.clip_contents = true

	var header_row := panel.find_child("Header", true, false) as HBoxContainer
	if header_row != null:
		var heading := header_row.get_node_or_null("Heading") as Label
		var spacer := header_row.get_node_or_null("Spacer")
		if spacer != null:
			header_row.remove_child(spacer)
			spacer.queue_free()
		if heading != null:
			heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			heading.mouse_filter = Control.MOUSE_FILTER_STOP
			heading.mouse_default_cursor_shape = Control.CURSOR_MOVE
			if not heading.gui_input.is_connected(_on_debug_title_gui_input):
				heading.gui_input.connect(_on_debug_title_gui_input)
		var close_button := header_row.get_node_or_null("CloseButton") as Button
		if debug_panel_settings_button == null:
			debug_panel_settings_button = Button.new()
			debug_panel_settings_button.name = "DebugWindowSettingsButton"
			debug_panel_settings_button.text = "⚙"
			debug_panel_settings_button.tooltip_text = "Настройки окна дебага"
			debug_panel_settings_button.custom_minimum_size = Vector2(34, 30)
			if close_button != null:
				header_row.add_child(debug_panel_settings_button)
				header_row.move_child(debug_panel_settings_button, close_button.get_index())
			else:
				header_row.add_child(debug_panel_settings_button)

	var debug_filter_row := _find_node("DebugFilterRow") as HBoxContainer
	if debug_filter_row == null and debug_filter != null:
		debug_filter_row = debug_filter.get_parent() as HBoxContainer
	if debug_nearby_toggle == null and debug_filter_row != null:
		debug_nearby_toggle = CheckBox.new()
		debug_nearby_toggle.name = "DebugNearbyOnly"
		debug_nearby_toggle.text = "Рядом · 600 px"
		debug_nearby_toggle.button_pressed = true
		debug_nearby_toggle.tooltip_text = "Показывать ближайшие объекты и сортировать их по расстоянию до игрока"
		debug_filter_row.add_child(debug_nearby_toggle)

	var selection_row := panel.find_child("DebugSelectionRow", true, false) as HBoxContainer
	if selection_row == null:
		selection_row = HBoxContainer.new()
		selection_row.name = "DebugSelectionRow"
		selection_row.add_theme_constant_override("separation", 8)
		var target_label := _find_node("DebugTarget") as Label
		var target_index := 0
		if target_label != null:
			target_index = target_label.get_index()
			var target_parent := target_label.get_parent()
			target_parent.remove_child(target_label)
			selection_row.add_child(target_label)
			target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(selection_row)
		content.move_child(selection_row, clampi(target_index, 0, content.get_child_count() - 1))
	if debug_inventory_option == null:
		debug_inventory_option = OptionButton.new()
		debug_inventory_option.name = "DebugInventorySlot"
		debug_inventory_option.custom_minimum_size = Vector2(240, 30)
		debug_inventory_option.size_flags_horizontal = Control.SIZE_SHRINK_END
		debug_inventory_option.add_item("— Предмет из инвентаря / хотбара —")
		debug_inventory_option.set_item_metadata(0, -1)
		selection_row.add_child(debug_inventory_option)
	if debug_item_save_button == null:
		debug_item_save_button = Button.new()
		debug_item_save_button.name = "DebugSaveItemToCode"
		debug_item_save_button.text = "Сохранить в базу"
		debug_item_save_button.tooltip_text = "Сохранить текущие характеристики предмета в его файл каталога .tres"
		debug_item_save_button.custom_minimum_size = Vector2(142, 30)
		debug_item_save_button.visible = false
		selection_row.add_child(debug_item_save_button)

	if debug_window_settings == null:
		debug_window_settings = VBoxContainer.new()
		debug_window_settings.name = "DebugWindowSettings"
		debug_window_settings.visible = false
		debug_window_settings.add_theme_constant_override("separation", 3)
		debug_window_settings.add_child(_make_label("Размер и прозрачность окна", 12, Color("#b8d49f")))

		var width_row := HBoxContainer.new()
		width_row.add_child(_make_label("Ширина", 11))
		debug_panel_width_slider = HSlider.new()
		debug_panel_width_slider.name = "DebugPanelWidth"
		debug_panel_width_slider.min_value = 620.0
		debug_panel_width_slider.max_value = 1200.0
		debug_panel_width_slider.step = 20.0
		debug_panel_width_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		width_row.add_child(debug_panel_width_slider)
		debug_window_settings.add_child(width_row)

		var height_row := HBoxContainer.new()
		height_row.add_child(_make_label("Высота", 11))
		debug_panel_height_slider = HSlider.new()
		debug_panel_height_slider.name = "DebugPanelHeight"
		debug_panel_height_slider.min_value = 420.0
		debug_panel_height_slider.max_value = 1000.0
		debug_panel_height_slider.step = 20.0
		debug_panel_height_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		height_row.add_child(debug_panel_height_slider)
		debug_window_settings.add_child(height_row)

		var opacity_row := HBoxContainer.new()
		opacity_row.add_child(_make_label("Непрозрачность", 11))
		debug_panel_opacity_slider = HSlider.new()
		debug_panel_opacity_slider.name = "DebugPanelOpacity"
		debug_panel_opacity_slider.min_value = 0.25
		debug_panel_opacity_slider.max_value = 1.0
		debug_panel_opacity_slider.step = 0.05
		debug_panel_opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opacity_row.add_child(debug_panel_opacity_slider)
		debug_window_settings.add_child(opacity_row)

		var scale_row := HBoxContainer.new()
		scale_row.add_child(_make_label("Масштаб", 11))
		debug_panel_scale_slider = HSlider.new()
		debug_panel_scale_slider.name = "DebugPanelScale"
		debug_panel_scale_slider.min_value = 50.0
		debug_panel_scale_slider.max_value = 150.0
		debug_panel_scale_slider.step = 5.0
		debug_panel_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scale_row.add_child(debug_panel_scale_slider)
		debug_panel_scale_label = _make_label("100%", 11, Color("#d4dec8"))
		debug_panel_scale_label.custom_minimum_size.x = 42
		debug_panel_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		scale_row.add_child(debug_panel_scale_label)
		debug_window_settings.add_child(scale_row)

		debug_panel_reset_position_button = Button.new()
		debug_panel_reset_position_button.name = "DebugPanelResetPosition"
		debug_panel_reset_position_button.text = "Вернуть окно по центру"
		debug_window_settings.add_child(debug_panel_reset_position_button)
		content.add_child(debug_window_settings)
		content.move_child(debug_window_settings, 0)

	var filter := _find_node("DebugFilter") as OptionButton
	if filter != null:
		filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var legacy_filter_ids := ["all", "player", "tree", "rock", "drop", "weapons"]
		for legacy_index in range(mini(filter.item_count, legacy_filter_ids.size())):
			filter.set_item_metadata(legacy_index, legacy_filter_ids[legacy_index])
		var extra_filters := [
			["Инструменты", "tools"],
			["Еда", "food"],
			["Материалы", "materials"],
			["Боеприпасы", "ammunition"]
		]
		for filter_data in extra_filters:
			var found := false
			for filter_index in range(filter.item_count):
				if str(filter.get_item_metadata(filter_index)) == str(filter_data[1]):
					found = true
					break
			if not found:
				filter.add_item(str(filter_data[0]))
				filter.set_item_metadata(filter.item_count - 1, str(filter_data[1]))
	var filter_row := filter.get_parent() as HBoxContainer if filter != null else null
	if filter_row != null and debug_spawn_toggle == null:
		debug_spawn_toggle = Button.new()
		debug_spawn_toggle.name = "DebugSpawnToggle"
		debug_spawn_toggle.text = "+ Предмет"
		debug_spawn_toggle.tooltip_text = "Открыть меню создания предметов в мире"
		filter_row.add_child(debug_spawn_toggle)

	if debug_spawn_menu == null:
		debug_spawn_menu = VBoxContainer.new()
		debug_spawn_menu.name = "DebugSpawnMenu"
		debug_spawn_menu.visible = false
		debug_spawn_menu.add_theme_constant_override("separation", 4)
		debug_spawn_menu.add_child(_make_label("Добавление предмета в мир", 12, Color("#b8d49f")))
		var spawn_row := HBoxContainer.new()
		spawn_row.add_child(_make_label("Тип", 11))
		debug_spawn_category = OptionButton.new()
		debug_spawn_category.name = "DebugSpawnCategory"
		debug_spawn_category.add_item("Все типы")
		debug_spawn_category.set_item_metadata(0, "all")
		debug_spawn_category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spawn_row.add_child(debug_spawn_category)
		spawn_row.add_child(_make_label("Предмет", 11))
		debug_spawn_option = OptionButton.new()
		debug_spawn_option.name = "DebugSpawnItem"
		debug_spawn_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spawn_row.add_child(debug_spawn_option)
		spawn_row.add_child(_make_label("Кол-во", 11))
		debug_spawn_amount = SpinBox.new()
		debug_spawn_amount.name = "DebugSpawnAmount"
		debug_spawn_amount.min_value = 1
		debug_spawn_amount.max_value = 9999
		debug_spawn_amount.value = 1
		debug_spawn_amount.custom_minimum_size.x = 82
		spawn_row.add_child(debug_spawn_amount)
		debug_spawn_menu.add_child(spawn_row)
		debug_spawn_confirm = Button.new()
		debug_spawn_confirm.name = "DebugSpawnConfirm"
		debug_spawn_confirm.text = "Создать возле курсора"
		debug_spawn_menu.add_child(debug_spawn_confirm)
		if filter_row != null:
			content.add_child(debug_spawn_menu)
			content.move_child(debug_spawn_menu, filter_row.get_index() + 1)
		else:
			content.add_child(debug_spawn_menu)

	if debug_object_list != null:
		debug_object_list.custom_minimum_size = Vector2(220, 220)
	_apply_debug_panel_appearance()


func _load_debug_panel_settings() -> void:
	var save := ConfigFile.new()
	if save.load("user://debug_panel.cfg") == OK:
		debug_panel_size.x = maxf(820.0, float(save.get_value("window", "width", debug_panel_size.x)))
		debug_panel_size.y = maxf(520.0, float(save.get_value("window", "height", debug_panel_size.y)))
		debug_panel_opacity = clampf(float(save.get_value("window", "opacity", debug_panel_opacity)), 0.25, 1.0)
		debug_panel_scale = clampf(float(save.get_value("window", "scale", debug_panel_scale)), 0.5, 1.5)
		debug_panel_position = Vector2(float(save.get_value("window", "x", -1.0)), float(save.get_value("window", "y", -1.0)))
	if debug_panel_width_slider != null:
		debug_panel_width_slider.set_value_no_signal(debug_panel_size.x)
	if debug_panel_height_slider != null:
		debug_panel_height_slider.set_value_no_signal(debug_panel_size.y)
	if debug_panel_opacity_slider != null:
		debug_panel_opacity_slider.set_value_no_signal(debug_panel_opacity)
	if debug_panel_scale_slider != null:
		debug_panel_scale_slider.set_value_no_signal(debug_panel_scale * 100.0)
	if debug_panel_scale_label != null:
		debug_panel_scale_label.text = "%d%%" % roundi(debug_panel_scale * 100.0)
	_apply_debug_panel_appearance()
	_fit_debug_panel_to_viewport()


func _ensure_ui_scale_settings() -> void:
	var panel := panels.get("settings") as PanelContainer
	if panel == null:
		return
	var content := panel.get_node_or_null("Content") as VBoxContainer
	if content == null or content.get_node_or_null("InterfaceScaleSettings") != null:
		return
	var section := VBoxContainer.new()
	section.name = "InterfaceScaleSettings"
	section.add_theme_constant_override("separation", 4)
	section.add_child(HSeparator.new())
	section.add_child(_make_label("МАСШТАБ ЭЛЕМЕНТОВ ИНТЕРФЕЙСА", 11, Color("#b8d49f")))
	settings_hud_scale_slider = _add_ui_scale_row(section, "HUD", "HudScale", settings_hud_scale)
	settings_hotbar_scale_slider = _add_ui_scale_row(section, "Быстрые слоты", "HotbarScale", settings_hotbar_scale)
	settings_windows_scale_slider = _add_ui_scale_row(section, "Окна", "WindowsScale", settings_windows_scale)
	content.add_child(section)
	settings_hud_scale_label = _find_node("HudScaleValue") as Label
	settings_hotbar_scale_label = _find_node("HotbarScaleValue") as Label
	settings_windows_scale_label = _find_node("WindowsScaleValue") as Label
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = -250
	panel.offset_bottom = 250

func _add_ui_scale_row(parent: VBoxContainer, row_label: String, control_name: String, initial_value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var title := _make_label(row_label, 11)
	title.custom_minimum_size.x = 112
	row.add_child(title)
	var slider := HSlider.new()
	slider.name = control_name
	slider.min_value = 70.0
	slider.max_value = 140.0
	slider.step = 5.0
	slider.value = initial_value * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := _make_label("%d%%" % roundi(initial_value * 100.0), 11, Color("#d4dec8"))
	value_label.name = control_name + "Value"
	value_label.custom_minimum_size.x = 42
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	parent.add_child(row)
	return slider

func _load_ui_scale_settings() -> void:
	var save := ConfigFile.new()
	if save.load("user://ui_scale.cfg") == OK:
		settings_hud_scale = clampf(float(save.get_value("ui", "hud", settings_hud_scale)), 0.7, 1.4)
		settings_hotbar_scale = clampf(float(save.get_value("ui", "hotbar", settings_hotbar_scale)), 0.7, 1.4)
		settings_windows_scale = clampf(float(save.get_value("ui", "windows", settings_windows_scale)), 0.7, 1.4)
	if settings_hud_scale_slider != null:
		settings_hud_scale_slider.set_value_no_signal(settings_hud_scale * 100.0)
	if settings_hotbar_scale_slider != null:
		settings_hotbar_scale_slider.set_value_no_signal(settings_hotbar_scale * 100.0)
	if settings_windows_scale_slider != null:
		settings_windows_scale_slider.set_value_no_signal(settings_windows_scale * 100.0)
	_update_ui_scale_labels()
	_apply_ui_element_scales()

func _save_ui_scale_settings() -> void:
	var save := ConfigFile.new()
	save.set_value("ui", "hud", settings_hud_scale)
	save.set_value("ui", "hotbar", settings_hotbar_scale)
	save.set_value("ui", "windows", settings_windows_scale)
	var error := save.save("user://ui_scale.cfg")
	if error != OK:
		add_log("Не удалось сохранить масштаб интерфейса: %s" % error)

func _on_ui_scale_changed(_value: float) -> void:
	if settings_hud_scale_slider != null:
		settings_hud_scale = clampf(settings_hud_scale_slider.value / 100.0, 0.7, 1.4)
	if settings_hotbar_scale_slider != null:
		settings_hotbar_scale = clampf(settings_hotbar_scale_slider.value / 100.0, 0.7, 1.4)
	if settings_windows_scale_slider != null:
		settings_windows_scale = clampf(settings_windows_scale_slider.value / 100.0, 0.7, 1.4)
	_update_ui_scale_labels()
	_apply_ui_element_scales()
	_save_ui_scale_settings()

func _update_ui_scale_labels() -> void:
	var labels: Array[Label] = [settings_hud_scale_label, settings_hotbar_scale_label, settings_windows_scale_label]
	var values: Array[float] = [settings_hud_scale, settings_hotbar_scale, settings_windows_scale]
	for index in range(labels.size()):
		if labels[index] != null:
			labels[index].text = "%d%%" % roundi(values[index] * 100.0)

func _apply_ui_element_scales() -> void:
	if root == null:
		return
	var hud := _find_node("HUD") as Control
	if hud != null:
		hud.pivot_offset = Vector2(0.0, hud.size.y)
		hud.scale = Vector2.ONE * settings_hud_scale
	var hotbar := _find_node("Hotbar") as Control
	if hotbar != null:
		hotbar.pivot_offset = Vector2(hotbar.size.x * 0.5, hotbar.size.y)
		hotbar.scale = Vector2.ONE * settings_hotbar_scale
	for panel_name in ["inventory", "settings", "logs"]:
		var panel := panels.get(panel_name) as Control
		if panel != null:
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2.ONE * settings_windows_scale

func _save_debug_panel_settings() -> void:
	var save := ConfigFile.new()
	save.set_value("window", "width", debug_panel_size.x)
	save.set_value("window", "height", debug_panel_size.y)
	save.set_value("window", "opacity", debug_panel_opacity)
	save.set_value("window", "scale", debug_panel_scale)
	save.set_value("window", "x", debug_panel_position.x)
	save.set_value("window", "y", debug_panel_position.y)
	var error := save.save("user://debug_panel.cfg")
	if error != OK:
		add_log("Не удалось сохранить настройки окна отладки: %s" % error)


func _apply_debug_panel_appearance() -> void:
	var panel := panels.get("debug") as PanelContainer
	if panel == null:
		return
	var source_style := panel.get_theme_stylebox("panel")
	if source_style is StyleBoxFlat:
		var style := (source_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		var background := style.bg_color
		background.a = debug_panel_opacity
		style.bg_color = background
		panel.add_theme_stylebox_override("panel", style)


func _fit_debug_panel_to_viewport() -> void:
	var panel := panels.get("debug") as Control
	if panel == null or root == null:
		return
	var viewport_size := root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	var scale_factor := clampf(debug_panel_scale, 0.5, 1.5)
	var available := Vector2(maxf(1.0, viewport_size.x - 20.0), maxf(1.0, viewport_size.y - 20.0))
	var panel_width := minf(maxf(300.0, debug_panel_size.x), available.x)
	var panel_height := minf(maxf(220.0, debug_panel_size.y), available.y)
	var target_size := Vector2(panel_width, panel_height)
	var target_position := debug_panel_position
	if target_position.x < 0.0 or target_position.y < 0.0:
		target_position = (viewport_size - target_size) * 0.5
	target_position.x = clampf(target_position.x, 0.0, maxf(0.0, viewport_size.x - target_size.x))
	target_position.y = clampf(target_position.y, 0.0, maxf(0.0, viewport_size.y - target_size.y))
	debug_panel_position = target_position

	panel.pivot_offset = Vector2.ZERO
	panel.scale = Vector2.ONE * scale_factor
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = target_position.x
	panel.offset_top = target_position.y
	panel.offset_right = target_position.x + panel_width / scale_factor
	panel.offset_bottom = target_position.y + panel_height / scale_factor
	panel.custom_minimum_size = Vector2.ZERO
	panel.clip_contents = true
	if debug_object_list != null:
		debug_object_list.custom_minimum_size = Vector2(
			minf(250.0, maxf(190.0, panel_width * 0.27)),
			minf(260.0, maxf(180.0, panel_height * 0.34))
		)


func _toggle_debug_window_settings() -> void:
	if debug_window_settings != null:
		debug_window_settings.visible = not debug_window_settings.visible


func _on_debug_panel_dimension_changed(_value: float) -> void:
	if debug_panel_width_slider != null:
		debug_panel_size.x = debug_panel_width_slider.value
	if debug_panel_height_slider != null:
		debug_panel_size.y = debug_panel_height_slider.value
	_fit_debug_panel_to_viewport()
	_save_debug_panel_settings()


func _on_debug_panel_opacity_changed(value: float) -> void:
	debug_panel_opacity = clampf(value, 0.25, 1.0)
	_apply_debug_panel_appearance()
	_save_debug_panel_settings()


func _on_debug_panel_scale_changed(value: float) -> void:
	debug_panel_scale = clampf(value / 100.0, 0.5, 1.5)
	if debug_panel_scale_label != null:
		debug_panel_scale_label.text = "%d%%" % roundi(debug_panel_scale * 100.0)
	_fit_debug_panel_to_viewport()
	_save_debug_panel_settings()


func _reset_debug_panel_position() -> void:
	debug_panel_position = Vector2(-1.0, -1.0)
	_fit_debug_panel_to_viewport()
	_save_debug_panel_settings()


func _on_debug_title_gui_input(event: InputEvent) -> void:
	var panel := panels.get("debug") as Control
	if panel == null:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			debug_panel_dragging = true
			debug_panel_drag_offset = mouse_button.global_position - panel.global_position
		elif debug_panel_dragging:
			debug_panel_dragging = false
			_save_debug_panel_settings()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and debug_panel_dragging:
		var mouse_motion := event as InputEventMouseMotion
		debug_panel_position = mouse_motion.global_position - root.global_position - debug_panel_drag_offset
		_fit_debug_panel_to_viewport()
		get_viewport().set_input_as_handled()


func _toggle_debug_spawn_menu() -> void:
	if debug_spawn_menu == null:
		return
	debug_spawn_menu.visible = not debug_spawn_menu.visible
	if debug_spawn_toggle != null:
		debug_spawn_toggle.text = "− Предмет" if debug_spawn_menu.visible else "+ Предмет"


func _on_debug_spawn_confirmed() -> void:
	if debug_spawn_option == null or debug_spawn_option.selected < 0:
		return
	var item_id := str(debug_spawn_option.get_item_metadata(debug_spawn_option.selected))
	var amount := maxi(1, roundi(debug_spawn_amount.value if debug_spawn_amount != null else 1.0))
	debug_spawn_item_requested.emit(item_id, amount)


func set_debug_item_catalog(definitions: Dictionary, categories: Dictionary) -> void:
	debug_spawn_catalog = definitions.duplicate(true)
	debug_spawn_categories = categories.duplicate(true)
	if debug_spawn_category != null:
		debug_spawn_category.clear()
		debug_spawn_category.add_item("Все типы")
		debug_spawn_category.set_item_metadata(0, "all")
		var category_ids: Array = []
		for category_value in debug_spawn_categories.values():
			var category_name := str(category_value)
			if not category_ids.has(category_name):
				category_ids.append(category_name)
		category_ids.sort()
		for category_name in category_ids:
			debug_spawn_category.add_item(_debug_category_label(category_name))
			debug_spawn_category.set_item_metadata(debug_spawn_category.item_count - 1, category_name)
		debug_spawn_category.select(0)
	_refresh_debug_spawn_options()


func _debug_category_label(category: String) -> String:
	match category:
		"tools":
			return "Инструменты"
		"weapons":
			return "Оружие"
		"food":
			return "Еда"
		"materials":
			return "Материалы"
		"ammunition":
			return "Боеприпасы"
	return category


func _on_debug_spawn_category_changed(_index: int) -> void:
	_refresh_debug_spawn_options()


func _refresh_debug_spawn_options() -> void:
	if debug_spawn_option == null:
		return
	var previous_id := ""
	if debug_spawn_option.selected >= 0:
		previous_id = str(debug_spawn_option.get_item_metadata(debug_spawn_option.selected))
	debug_spawn_option.clear()
	var selected_category := "all"
	if debug_spawn_category != null and debug_spawn_category.selected >= 0:
		selected_category = str(debug_spawn_category.get_item_metadata(debug_spawn_category.selected))
	var item_ids: Array = debug_spawn_catalog.keys()
	item_ids.sort()
	for item_id_value in item_ids:
		var item_id := str(item_id_value)
		var category := str(debug_spawn_categories.get(item_id, "materials"))
		if selected_category != "all" and category != selected_category:
			continue
		var definition: Dictionary = debug_spawn_catalog[item_id]
		debug_spawn_option.add_item(str(definition.get("label", item_id)))
		debug_spawn_option.set_item_metadata(debug_spawn_option.item_count - 1, item_id)
		if item_id == previous_id:
			debug_spawn_option.select(debug_spawn_option.item_count - 1)
	if debug_spawn_option.item_count > 0 and debug_spawn_option.selected < 0:
		debug_spawn_option.select(0)


func _on_save_debug_default_pressed(property_path: String, editor: Control) -> void:
	var value: Variant = 0.0
	if editor is OptionButton:
		var option := editor as OptionButton
		if option.selected >= 0:
			value = option.get_item_text(option.selected)
	elif editor is SpinBox:
		value = (editor as SpinBox).value
	debug_default_requested.emit(property_path, value)


func _on_debug_item_save_pressed() -> void:
	debug_item_save_requested.emit()


func set_debug_inventory_items(items: Array[Dictionary], open_slots: int, selected_slot: int, item_data: Dictionary) -> void:
	if debug_inventory_option == null:
		return
	var last_slot := mini(items.size(), 9 + maxi(0, open_slots))
	var signature := "%d|%d" % [open_slots, selected_slot]
	for slot_index in range(last_slot):
		var stack: Dictionary = items[slot_index]
		var item_id := str(stack.get("id", ""))
		var amount := int(stack.get("amount", 0))
		if not item_id.is_empty() and amount > 0:
			signature += "|%d:%s:%d" % [slot_index, item_id, amount]
	if signature == debug_inventory_items_signature:
		return
	debug_inventory_items_signature = signature
	debug_inventory_option.clear()
	debug_inventory_option.add_item("— Предмет из инвентаря / хотбара —")
	debug_inventory_option.set_item_metadata(0, -1)
	var selected_index := 0
	for slot_index in range(last_slot):
		var stack: Dictionary = items[slot_index]
		var item_id := str(stack.get("id", ""))
		var amount := int(stack.get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			continue
		var definition: Dictionary = item_data.get(item_id, {})
		var item_label := str(definition.get("label", item_id.capitalize()))
		var location := "Быстрый %d" % (slot_index + 1) if slot_index < 9 else "Рюкзак %d" % (slot_index - 8)
		debug_inventory_option.add_item("%s  ·  %s ×%d" % [location, item_label, amount])
		var option_index := debug_inventory_option.item_count - 1
		debug_inventory_option.set_item_metadata(option_index, slot_index)
		if slot_index == selected_slot:
			selected_index = option_index
	debug_inventory_option.select(selected_index)

func set_debug_item_save_enabled(enabled: bool) -> void:
	if debug_item_save_button != null:
		debug_item_save_button.visible = enabled
		debug_item_save_button.disabled = not enabled

func set_debug_world_actions_enabled(enabled: bool) -> void:
	for node_name in ["DebugClone", "DebugReset", "DebugDelete"]:
		var action_button := _find_node(node_name) as Button
		if action_button != null:
			action_button.disabled = not enabled
func _on_debug_filter_changed(_index: int) -> void:
	_render_debug_object_list()

func _on_debug_object_selected(index: int) -> void:
	if debug_object_list == null or index < 0 or index >= debug_object_list.item_count:
		return
	var object_id := str(debug_object_list.get_item_metadata(index))
	if object_id.is_empty():
		return
	debug_object_selected.emit(object_id)

func _on_debug_inventory_option_selected(index: int) -> void:
	if debug_inventory_option == null or index < 0 or index >= debug_inventory_option.item_count:
		return
	debug_inventory_item_selected.emit(int(debug_inventory_option.get_item_metadata(index)))

func _on_debug_nearby_toggled(_enabled: bool) -> void:
	_render_debug_object_list()
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
	var entries_to_show: Array[Dictionary] = debug_objects.duplicate(true)
	entries_to_show.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
	)
	for entry in entries_to_show:
		var kind := str(entry.get("kind", "other"))
		var object_id := str(entry.get("id", ""))
		var selected_id := str(entry.get("selected_id", ""))
		var distance := float(entry.get("distance", 0.0))
		if debug_nearby_toggle != null and debug_nearby_toggle.button_pressed and distance > 600.0 and object_id != selected_id:
			continue
		if filter_value != "all":
			if filter_value == "tree" and kind != "tree" and kind != "stump":
				continue
			elif filter_value == "rock" and kind != "rock":
				continue
			elif filter_value == "drop" and kind not in ["drop", "tools", "weapons", "food", "materials", "ammunition"]:
				continue
			elif filter_value in ["tools", "weapons", "food", "materials", "ammunition"] and kind != filter_value:
				continue
			elif filter_value == "player" and kind != "player":
				continue
		var display_label := str(entry.get("label", "Объект"))
		if kind != "player":
			display_label += "  ·  %d px" % roundi(distance)
		debug_object_list.add_item(display_label)
		var item_index := debug_object_list.item_count - 1
		debug_object_list.set_item_metadata(item_index, object_id)
		if object_id == selected_id:
			debug_object_list.select(item_index)
	if debug_object_list.item_count == 0:
		debug_object_list.add_item("Нет объектов поблизости")
		debug_object_list.set_item_disabled(0, true)
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
	var has_code_editable_properties := false
	for property_data in properties:
		if bool(property_data.get("save_default", false)):
			has_code_editable_properties = true
			break
	if has_code_editable_properties:
		var hint := _make_label("Измени характеристику и нажми «В код» рядом с ней — значение запишется в .tres-файл предмета.", 11, Color("#b8d49f"))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		debug_properties.add_child(hint)
	for property_data in properties:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := _make_label(str(property_data.get("label", property_data.get("path", "Параметр"))), 11)
		title.custom_minimum_size.x = 164
		row.add_child(title)
		var property_path := str(property_data.get("path", ""))
		if bool(property_data.get("readonly", false)):
			var value_label := _make_label(str(property_data.get("value", "")), 11, Color("#c3cfb8"))
			value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(value_label)
			debug_properties.add_child(row)
			continue
		var editor: Control
		if property_data.has("options"):
			var option_editor := OptionButton.new()
			var options: Array = property_data["options"]
			for option in options:
				option_editor.add_item(str(option))
			option_editor.select(clampi(roundi(float(property_data.get("value", 0.0))), 0, maxi(0, options.size() - 1)))
			option_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			option_editor.item_selected.connect(_on_inspector_option_changed.bind(property_path))
			row.add_child(option_editor)
			editor = option_editor
		else:
			var spin_editor := SpinBox.new()
			spin_editor.min_value = float(property_data.get("min", -100000.0))
			spin_editor.max_value = float(property_data.get("max", 100000.0))
			spin_editor.step = float(property_data.get("step", 0.1))
			spin_editor.value = float(property_data.get("value", 0.0))
			spin_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin_editor.value_changed.connect(_on_inspector_value_changed.bind(property_path))
			row.add_child(spin_editor)
			editor = spin_editor
		debug_properties.add_child(row)
		if bool(property_data.get("save_default", false)):
			var save_button := Button.new()
			save_button.text = "В базу"
			save_button.custom_minimum_size = Vector2(68, 26)
			save_button.tooltip_text = "Сохранить это значение в файл каталога предмета (.tres)."
			save_button.add_theme_color_override("font_color", Color("#c6e8b5"))
			save_button.pressed.connect(_on_save_debug_default_pressed.bind(property_path, editor))
			row.add_child(save_button)

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

func _set_slot_icon(button: Button, item_id: String, count: int, tooltip: String = "") -> void:
	if button == null:
		return
	var icon_rect := button.get_node_or_null("Icon") as TextureRect
	var count_label := button.get_node_or_null("StackCount") as Label
	if icon_rect != null:
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item_definition: Dictionary = item_definitions_cache.get(item_id, {})
		var definition_icon := item_definition.get("icon") as Texture2D
		if definition_icon != null:
			icon_rect.texture = definition_icon
		elif ITEM_TEXTURE_PATHS.has(item_id):
			icon_rect.texture = load(ITEM_TEXTURE_PATHS[item_id]) as Texture2D
		else:
			icon_rect.texture = null
		icon_rect.visible = icon_rect.texture != null
		button.text = ""
	button.set_meta("item_id", item_id)
	if count_label != null:
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.text = str(count) if count > 1 else ""
	if tooltip != "":
		button.tooltip_text = tooltip
	else:
		button.tooltip_text = str(ITEM_LABELS.get(item_id, "Пустая ячейка"))

func set_inventory_data(items: Array[Dictionary], open_slots: int, maximum_slots: int, definitions: Dictionary) -> void:
	item_definitions_cache = definitions
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
	if definition.has("description"):
		lines.append(str(definition["description"]))
	if definition.has("category"):
		lines.append("Категория: %s" % _debug_category_label(str(definition["category"])))
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
		if panel_name == "debug":
			_fit_debug_panel_to_viewport()
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
		if not unlocked:
			slot.tooltip_text = "Ячейка закрыта"
		elif str(slot.get_meta("item_id", "")).is_empty():
			slot.tooltip_text = "Пустая ячейка"
		var icon_rect := slot.get_node_or_null("Icon") as TextureRect
		if icon_rect != null:
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count_label := slot.get_node_or_null("StackCount") as Label
		if count_label != null:
			count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lock_mark := slot.get_node_or_null("LockMark") as Label
		if lock_mark != null:
			lock_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
