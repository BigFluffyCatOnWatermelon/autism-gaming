@tool
extends Window
## Displays an isolated copy of the active Object Builder draft.


signal refresh_requested

const MIN_ZOOM := 0.08
const MAX_ZOOM := 8.0
const ZOOM_FACTOR := 1.25


class PreviewGrid:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(-800.0, -600.0, 1600.0, 1200.0), Color(0.12, 0.14, 0.17))
		for x in range(-800, 801, 32):
			draw_line(Vector2(x, -600), Vector2(x, 600), Color(0.19, 0.21, 0.24), 1.0)
		for y in range(-600, 601, 32):
			draw_line(Vector2(-800, y), Vector2(800, y), Color(0.19, 0.21, 0.24), 1.0)
		draw_line(Vector2(-800, 0), Vector2(800, 0), Color(0.38, 0.42, 0.47), 2.0)
		draw_line(Vector2(0, -600), Vector2(0, 600), Color(0.38, 0.42, 0.47), 2.0)


var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _stage: Node2D
var _camera: Camera2D
var _preview_instance: Node
var _message: Label
var _zoom_label: Label
var _zoom := 1.0


func build() -> void:
	if _viewport != null:
		return
	title = "Предпросмотр объекта"
	size = Vector2i(820, 620)
	min_size = Vector2i(520, 400)
	close_requested.connect(_on_close_requested)

	var margin := MarginContainer.new()
	for margin_name in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + margin_name, 10)
	add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	content.add_child(toolbar)

	var heading := Label.new()
	heading.text = "ТЕКУЩИЙ ЧЕРНОВИК"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(heading)

	_add_toolbar_button(toolbar, "−", "Уменьшить масштаб", _on_zoom_out_pressed)
	_zoom_label = Label.new()
	_zoom_label.custom_minimum_size = Vector2(48, 0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(_zoom_label)
	_add_toolbar_button(toolbar, "+", "Увеличить масштаб", _on_zoom_in_pressed)
	_add_toolbar_button(toolbar, "Вписать", "Подобрать масштаб, чтобы объект целиком помещался в окне", _fit_preview)
	_add_toolbar_button(toolbar, "Центр", "Вернуть камеру к началу координат объекта", _center_preview)
	_add_toolbar_button(toolbar, "Сбросить", "Пересоздать чистый Preview из текущего черновика", _on_refresh_pressed)

	var viewport_panel := PanelContainer.new()
	viewport_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(viewport_panel)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.custom_minimum_size = Vector2(0, 360)
	_viewport_container.stretch = true
	_viewport_container.resized.connect(_on_viewport_container_resized)
	viewport_panel.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 520)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)

	_stage = Node2D.new()
	_viewport.add_child(_stage)

	var grid := PreviewGrid.new()
	grid.z_index = -100
	_stage.add_child(grid)

	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	_stage.add_child(_camera)
	_camera.call_deferred("make_current")
	_set_zoom(1.0)

	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.text = "Предпросмотр изолирован от исходной сцены."
	content.add_child(_message)
	call_deferred("_on_viewport_container_resized")


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


func show_preview(instance: Node, display_name: String) -> bool:
	if _stage == null or instance == null or not is_instance_valid(instance):
		return false
	_clear_preview()
	_preview_instance = instance
	_stage.add_child(_preview_instance)
	title = "Предпросмотр — " + (display_name if not display_name.is_empty() else "Без названия")
	if _has_visible_content(_preview_instance):
		_message.text = "Показан текущий черновик. Изменения не сохраняются автоматически."
	else:
		_message.text = "В сцене пока нет видимых частей. Добавь изображение или Sprite2D и обнови предпросмотр."
	call_deferred("_fit_preview")
	return true


func _has_visible_content(node: Node) -> bool:
	if node is Sprite2D and (node as Sprite2D).texture != null:
		return true
	if node is AnimatedSprite2D:
		var animated := node as AnimatedSprite2D
		if animated.sprite_frames != null and animated.sprite_frames.get_frame_count(animated.animation) > 0:
			return true
	if node is Polygon2D and (node as Polygon2D).polygon.size() >= 3:
		return true
	if node is Line2D and (node as Line2D).points.size() >= 2:
		return true
	if node is TextureRect and (node as TextureRect).texture != null:
		return true
	for child in node.get_children():
		if _has_visible_content(child):
			return true
	return false


func _fit_preview() -> void:
	if _camera == null or _preview_instance == null or not is_instance_valid(_preview_instance):
		return
	var accumulated: Dictionary = {}
	_collect_visual_bounds(_preview_instance, accumulated)
	if not accumulated.has("rect"):
		_center_preview()
		_set_zoom(1.0)
		return

	var bounds: Rect2 = accumulated["rect"]
	var available_size := Vector2(_viewport.size) * 0.82
	var object_size := Vector2(maxf(bounds.size.x, 32.0), maxf(bounds.size.y, 32.0))
	var fit_zoom := minf(available_size.x / object_size.x, available_size.y / object_size.y)
	_camera.position = bounds.get_center()
	_set_zoom(clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM))


func _collect_visual_bounds(node: Node, accumulated: Dictionary) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			_include_rect(sprite.global_transform, sprite.get_rect(), accumulated)
	elif node is AnimatedSprite2D:
		var animated := node as AnimatedSprite2D
		if animated.sprite_frames != null and animated.sprite_frames.get_frame_count(animated.animation) > 0:
			_include_rect(animated.global_transform, animated.get_rect(), accumulated)
	elif node is Polygon2D:
		var polygon := node as Polygon2D
		for point in polygon.polygon:
			_include_point(polygon.global_transform * point, accumulated)
	elif node is Line2D:
		var line := node as Line2D
		for point in line.points:
			_include_point(line.global_transform * point, accumulated)
	elif node is TextureRect:
		var texture_rect := node as TextureRect
		if texture_rect.texture != null:
			_include_rect(texture_rect.get_global_transform(), texture_rect.get_rect(), accumulated)

	for child in node.get_children():
		_collect_visual_bounds(child, accumulated)


func _include_rect(transform: Transform2D, local_rect: Rect2, accumulated: Dictionary) -> void:
	if local_rect.size == Vector2.ZERO:
		return
	_include_point(transform * local_rect.position, accumulated)
	_include_point(transform * Vector2(local_rect.end.x, local_rect.position.y), accumulated)
	_include_point(transform * local_rect.end, accumulated)
	_include_point(transform * Vector2(local_rect.position.x, local_rect.end.y), accumulated)


func _include_point(point: Vector2, accumulated: Dictionary) -> void:
	if not accumulated.has("rect"):
		accumulated["rect"] = Rect2(point, Vector2.ZERO)
		return
	var bounds: Rect2 = accumulated["rect"]
	accumulated["rect"] = bounds.expand(point)


func _center_preview() -> void:
	if _camera == null:
		return
	if _preview_instance is Node2D:
		_camera.position = (_preview_instance as Node2D).global_position
	else:
		_camera.position = Vector2.ZERO


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	if _camera != null:
		_camera.zoom = Vector2.ONE * _zoom
	if _zoom_label != null:
		_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom * ZOOM_FACTOR)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom / ZOOM_FACTOR)


func _on_viewport_container_resized() -> void:
	if _viewport == null or _viewport_container == null:
		return
	var target_size := Vector2i(
		maxi(1, roundi(_viewport_container.size.x)),
		maxi(1, roundi(_viewport_container.size.y))
	)
	if _viewport.size != target_size:
		_viewport.size = target_size


func _clear_preview() -> void:
	if _preview_instance != null and is_instance_valid(_preview_instance):
		var parent := _preview_instance.get_parent()
		if parent != null:
			parent.remove_child(_preview_instance)
		_preview_instance.free()
	_preview_instance = null


func _on_refresh_pressed() -> void:
	refresh_requested.emit()


func _on_close_requested() -> void:
	_clear_preview()
	hide()
	if _message != null:
		_message.text = "Предпросмотр остановлен. Открой его снова, чтобы начать новый тест."


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_preview()
