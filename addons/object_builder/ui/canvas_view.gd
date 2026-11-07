@tool
extends VBoxContainer
## Interactive 2D canvas for the current Object Builder scene.

const CanvasGridScript = preload("res://addons/object_builder/ui/canvas_grid.gd")
const CanvasOverlayScript = preload("res://addons/object_builder/ui/canvas_overlay.gd")
const CanvasGeometry = preload("res://addons/object_builder/ui/canvas_geometry.gd")
const CanvasInteractionControllerScript = preload("res://addons/object_builder/ui/canvas_interaction_controller.gd")
## The canvas edits an isolated preview copy; committed values are applied to the real scene by the plugin.

signal part_selected(path: NodePath)
signal transform_committed(path: NodePath, property_name: String, new_value: Variant, old_value: Variant)
signal open_scene_requested

const MIN_ZOOM := 0.08
const MAX_ZOOM := 8.0
const ZOOM_FACTOR := 1.2
const GRID_STEP := 32.0
const SNAP_STEP := 8.0



var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _surface: Control
var _stage: Node2D
var _grid: Node2D
var _camera: Camera2D
var _preview_instance: Node
var _interaction_controller: RefCounted
var _zoom := 1.0
var _grid_enabled := true
var _editing_enabled := false
var _snap_enabled := true
var _status_label: Label
var _zoom_label: Label
var _grid_button: Button
var _snap_button: CheckBox
var _open_scene_button: Button



func build() -> void:
	if _viewport != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 300)
	add_theme_constant_override("separation", 5)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	add_child(toolbar)
	var heading := Label.new()
	heading.text = "ХОЛСТ ОБЪЕКТА"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(heading)

	_add_toolbar_button(toolbar, "−", "Уменьшить масштаб", _on_zoom_out_pressed)
	_zoom_label = Label.new()
	_zoom_label.custom_minimum_size = Vector2(48, 0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(_zoom_label)
	_add_toolbar_button(toolbar, "+", "Увеличить масштаб", _on_zoom_in_pressed)
	_add_toolbar_button(toolbar, "Вписать", "Показать объект целиком", _fit_canvas)
	_add_toolbar_button(toolbar, "Центр", "Вернуть камеру к началу координат", _center_canvas)

	_grid_button = Button.new()
	_grid_button.text = "Сетка"
	_grid_button.toggle_mode = true
	_grid_button.button_pressed = true
	_grid_button.toggled.connect(_on_grid_toggled)
	toolbar.add_child(_grid_button)

	_snap_button = CheckBox.new()
	_snap_button.text = "Привязка"
	_snap_button.button_pressed = true
	_snap_button.tooltip_text = "Перемещать части шагом 8 пикселей"
	_snap_button.toggled.connect(_on_snap_toggled)
	toolbar.add_child(_snap_button)

	_open_scene_button = Button.new()
	_open_scene_button.text = "Открыть сцену"
	_open_scene_button.tooltip_text = "Открыть сцену в редакторе Godot, чтобы включить редактирование на холсте"
	_open_scene_button.pressed.connect(_on_open_scene_pressed)
	toolbar.add_child(_open_scene_button)

	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.custom_minimum_size = Vector2(0, 220)
	add_child(canvas_panel)

	var surface_host := Control.new()
	surface_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_child(surface_host)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.stretch = false
	surface_host.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)

	_stage = Node2D.new()
	_viewport.add_child(_stage)
	_grid = CanvasGridScript.new()
	_grid.z_index = -4096
	_grid.z_as_relative = false
	_stage.add_child(_grid)

	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	_stage.add_child(_camera)
	_camera.call_deferred("make_current")

	_surface = CanvasOverlayScript.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	_surface.focus_mode = Control.FOCUS_ALL
	_surface.resized.connect(_on_surface_resized)
	surface_host.add_child(_surface)

	_interaction_controller = CanvasInteractionControllerScript.new()
	_interaction_controller.call("configure", _viewport, _surface, _camera)
	_interaction_controller.connect("part_selected", Callable(self, "_on_interaction_part_selected"))
	_interaction_controller.connect("transform_committed", Callable(self, "_on_interaction_transform_committed"))
	_interaction_controller.connect("zoom_requested", Callable(self, "_on_interaction_zoom_requested"))
	_surface.set("canvas_owner", _interaction_controller)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Выбери объект в библиотеке, чтобы показать его части."
	add_child(_status_label)
	_set_zoom(1.0)
	call_deferred("_on_surface_resized")


func _add_toolbar_button(
	toolbar: HBoxContainer,
	button_text: String,
	tooltip: String,
	action: Callable
) -> Button:
	var button := Button.new()
	button.text = button_text
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	toolbar.add_child(button)
	return button


func set_preview_instance(
	instance: Node,
	editing_enabled: bool,
	can_open_scene: bool,
	selected_path: NodePath = NodePath("")
) -> void:
	if _viewport == null:
		return
	_clear_preview()
	if instance == null or not is_instance_valid(instance):
		clear_canvas("Не удалось собрать предпросмотр сцены.")
		return
	_preview_instance = instance
	_disable_preview_processing(_preview_instance)
	_stage.add_child(_preview_instance)
	_editing_enabled = editing_enabled
	_interaction_controller.call("set_scene", _preview_instance, editing_enabled, selected_path)
	_open_scene_button.disabled = not can_open_scene
	_open_scene_button.visible = not editing_enabled
	if editing_enabled:
		_status_label.text = "Выбирай части щелчком и перемещай перетаскиванием. Средняя кнопка или пробел + ЛКМ — панорамирование."
	else:
		_status_label.text = "Предпросмотр. Чтобы редактировать части, открой сцену объекта кнопкой справа."
	call_deferred("_fit_canvas")
	_surface.queue_redraw()


func clear_canvas(message: String) -> void:
	_clear_preview()
	_editing_enabled = false
	_selected_path = NodePath("")
	_open_scene_button.disabled = true
	_open_scene_button.visible = false
	_status_label.text = message
	if _surface != null:
		_surface.queue_redraw()


func set_selected_path(path: NodePath) -> void:
	if _interaction_controller != null:
		_interaction_controller.call("set_selected_path", path)


func _disable_preview_processing(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_disable_preview_processing(child)


func _clear_preview() -> void:
	if _interaction_controller != null:
		_interaction_controller.call("set_scene", null, false, NodePath(""))
	if _preview_instance != null and is_instance_valid(_preview_instance):
		var parent := _preview_instance.get_parent()
		if parent != null:
			parent.remove_child(_preview_instance)
		_preview_instance.free()
	_preview_instance = null


func _on_surface_resized() -> void:
	if _viewport == null or _surface == null:
		return
	var target_size := Vector2i(
		maxi(1, roundi(_surface.size.x)),
		maxi(1, roundi(_surface.size.y))
	)
	if _viewport.size != target_size:
		_viewport.size = target_size


func _on_grid_toggled(enabled: bool) -> void:
	_grid_enabled = enabled
	if _grid != null:
		_grid.set("grid_enabled", enabled)
		_grid.queue_redraw()


func _on_snap_toggled(enabled: bool) -> void:
	_snap_enabled = enabled
	if _interaction_controller != null:
		_interaction_controller.call("set_snap_enabled", enabled)


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom * ZOOM_FACTOR)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom / ZOOM_FACTOR)


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	if _camera != null:
		_camera.zoom = Vector2.ONE * _zoom
	if _zoom_label != null:
		_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)
	if _interaction_controller != null:
		_interaction_controller.call("set_zoom", _zoom)


func _center_canvas() -> void:
	if _camera == null:
		return
	if _preview_instance is Node2D:
		_camera.position = (_preview_instance as Node2D).global_position
	else:
		_camera.position = Vector2.ZERO


func _fit_canvas() -> void:
	if _camera == null or _preview_instance == null or not is_instance_valid(_preview_instance):
		_center_canvas()
		_set_zoom(1.0)
		return
	var bounds: Dictionary = CanvasGeometry.collect_visual_bounds(_preview_instance)
	if not bounds.has("rect"):
		_center_canvas()
		_set_zoom(1.0)
		return
	var rect: Rect2 = bounds["rect"]
	var available := Vector2(_viewport.size) * 0.78
	var object_size := Vector2(maxf(rect.size.x, 32.0), maxf(rect.size.y, 32.0))
	var fit_zoom := minf(available.x / object_size.x, available.y / object_size.y)
	_camera.position = rect.get_center()
	_set_zoom(clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM))


func _on_interaction_part_selected(path: NodePath) -> void:
	part_selected.emit(path)


func _on_interaction_transform_committed(
	path: NodePath,
	property_name: String,
	new_value: Variant,
	old_value: Variant
) -> void:
	transform_committed.emit(path, property_name, new_value, old_value)


func _on_interaction_zoom_requested(factor: float) -> void:
	_set_zoom(_zoom * factor)




func _on_open_scene_pressed() -> void:
	open_scene_requested.emit()
