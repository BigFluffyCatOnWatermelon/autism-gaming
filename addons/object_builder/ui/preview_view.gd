@tool
extends Window
## Displays an isolated copy of the active Object Builder draft.


signal refresh_requested

const DialogService = preload("res://addons/object_builder/services/dialog_service.gd")


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
var _stage: Node2D
var _preview_instance: Node
var _message: Label


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
	content.add_child(toolbar)

	var heading := Label.new()
	heading.text = "ТЕКУЩИЙ ЧЕРНОВИК"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(heading)

	var refresh_button := Button.new()
	refresh_button.text = "Обновить"
	refresh_button.tooltip_text = "Пересобрать предпросмотр из последних изменений"
	refresh_button.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_button)

	var viewport_panel := PanelContainer.new()
	viewport_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(viewport_panel)

	var viewport_container := SubViewportContainer.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.custom_minimum_size = Vector2(0, 360)
	viewport_container.stretch = true
	viewport_panel.add_child(viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 520)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(_viewport)

	_stage = Node2D.new()
	_viewport.add_child(_stage)

	var grid := PreviewGrid.new()
	grid.z_index = -100
	_stage.add_child(grid)

	var camera := Camera2D.new()
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	_stage.add_child(camera)
	camera.call_deferred("make_current")

	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.text = "Предпросмотр изолирован от исходной сцены."
	content.add_child(_message)


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


func _clear_preview() -> void:
	if _preview_instance != null and is_instance_valid(_preview_instance):
		if _preview_instance.get_parent() == _stage:
			_stage.remove_child(_preview_instance)
		_preview_instance.free()
	_preview_instance = null


func _on_refresh_pressed() -> void:
	refresh_requested.emit()


func _on_close_requested() -> void:
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_preview()
