@tool
extends ConfirmationDialog
## Transactional SpriteFrames editor. Changes are applied only after confirmation.

signal frames_accepted(frames: SpriteFrames)

const DialogService = preload("res://addons/object_builder/services/dialog_service.gd")

var _working_frames: SpriteFrames
var _animation_option: OptionButton
var _animation_name: LineEdit
var _frame_list: ItemList
var _fps: SpinBox
var _loop_mode: OptionButton
var _duration: SpinBox
var _status: Label
var _file_dialog: FileDialog
var _file_mode := "add"


func _ready() -> void:
	if _animation_option != null:
		return
	build()


func build() -> void:
	if _animation_option != null:
		return
	title = "Редактор SpriteFrames"
	min_size = Vector2i(620, 520)
	get_ok_button().text = "Применить"
	get_cancel_button().text = "Отмена"
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(580, 420)
	body.add_theme_constant_override("separation", 7)
	add_child(body)

	var animation_row := HBoxContainer.new()
	body.add_child(animation_row)
	_animation_option = OptionButton.new()
	_animation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_option.item_selected.connect(_on_animation_selected)
	animation_row.add_child(_animation_option)
	var add_animation_button := Button.new()
	add_animation_button.text = "+ Анимация"
	add_animation_button.pressed.connect(_add_animation)
	animation_row.add_child(add_animation_button)

	var rename_row := HBoxContainer.new()
	body.add_child(rename_row)
	_animation_name = LineEdit.new()
	_animation_name.placeholder_text = "Имя выбранной анимации"
	_animation_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_row.add_child(_animation_name)
	var rename_button := Button.new()
	rename_button.text = "Переименовать"
	rename_button.pressed.connect(_rename_current_animation)
	rename_row.add_child(rename_button)
	var remove_animation_button := Button.new()
	remove_animation_button.text = "Удалить"
	remove_animation_button.pressed.connect(_remove_current_animation)
	rename_row.add_child(remove_animation_button)

	var settings_row := HBoxContainer.new()
	body.add_child(settings_row)
	_fps = SpinBox.new()
	_fps.min_value = 0.1
	_fps.max_value = 120.0
	_fps.step = 0.1
	_fps.suffix = " FPS"
	_fps.value_changed.connect(_on_fps_changed)
	settings_row.add_child(_fps)
	_loop_mode = OptionButton.new()
	_loop_mode.add_item("Без цикла")
	_loop_mode.set_item_metadata(0, 0)
	_loop_mode.add_item("Цикл")
	_loop_mode.set_item_metadata(1, 1)
	_loop_mode.add_item("Пинг-понг")
	_loop_mode.set_item_metadata(2, 2)
	_loop_mode.item_selected.connect(_on_loop_mode_selected)
	settings_row.add_child(_loop_mode)

	_frame_list = ItemList.new()
	_frame_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame_list.icon_mode = ItemList.ICON_MODE_TOP
	_frame_list.fixed_icon_size = Vector2i(64, 64)
	_frame_list.max_columns = 0
	_frame_list.item_selected.connect(_on_frame_selected)
	body.add_child(_frame_list)

	var frame_toolbar := HBoxContainer.new()
	body.add_child(frame_toolbar)
	_add_button(frame_toolbar, "+ Добавить кадр", _on_add_frame_pressed)
	_add_button(frame_toolbar, "Заменить текстуру", _on_replace_frame_pressed)
	_add_button(frame_toolbar, "↑", _on_move_frame_up_pressed)
	_add_button(frame_toolbar, "↓", _on_move_frame_down_pressed)
	_add_button(frame_toolbar, "Удалить кадр", _on_remove_frame_pressed)
	_duration = SpinBox.new()
	_duration.min_value = 0.01
	_duration.max_value = 60.0
	_duration.step = 0.01
	_duration.suffix = "×"
	_duration.tooltip_text = "Относительная длительность кадра: множитель к базовой длительности кадра анимации."
	_duration.value_changed.connect(_on_duration_changed)
	body.add_child(_duration)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)

	_file_dialog = FileDialog.new()
	_file_dialog.title = "Выбрать изображение кадра"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg, *.svg, *.bmp, *.tga ; Изображения"])
	_file_dialog.file_selected.connect(_on_frame_file_selected)
	add_child(_file_dialog)
	confirmed.connect(_on_confirmed)


func _add_button(parent: HBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func open_for_sprite_frames(source: SpriteFrames) -> void:
	build()
	if source == null:
		_working_frames = SpriteFrames.new()
	else:
		_working_frames = source.duplicate(true) as SpriteFrames
	if _working_frames.get_animation_names().is_empty():
		_working_frames.add_animation(&"default")
	_refresh_animation_list()


func get_working_frames() -> SpriteFrames:
	return _working_frames


func get_animation_count() -> int:
	return _working_frames.get_animation_names().size() if _working_frames != null else 0


func get_frame_count() -> int:
	var animation := _get_selected_animation()
	return _working_frames.get_frame_count(animation) if _working_frames != null and not animation.is_empty() else 0


func _get_selected_animation() -> StringName:
	if _animation_option == null or _animation_option.selected < 0:
		return StringName()
	return StringName(str(_animation_option.get_item_metadata(_animation_option.selected)))


func _get_selected_frame() -> int:
	var selected := _frame_list.get_selected_items()
	return int(selected[0]) if not selected.is_empty() else -1


func _refresh_animation_list(preferred_name: StringName = StringName()) -> void:
	if _working_frames == null or _animation_option == null:
		return
	_animation_option.clear()
	var names := _working_frames.get_animation_names()
	var selected_index := 0
	for index in range(names.size()):
		var animation_name := StringName(str(names[index]))
		_animation_option.add_item(str(animation_name))
		_animation_option.set_item_metadata(index, str(animation_name))
		if animation_name == preferred_name:
			selected_index = index
	if not names.is_empty():
		_animation_option.select(selected_index)
		_animation_name.text = str(names[selected_index])
	_refresh_animation_controls()


func _refresh_animation_controls() -> void:
	var animation := _get_selected_animation()
	if animation.is_empty() or _working_frames == null:
		return
	_fps.set_value_no_signal(_working_frames.get_animation_speed(animation))
	var loop_mode := int(_working_frames.get_animation_loop_mode(animation))
	for index in range(_loop_mode.item_count):
		if int(_loop_mode.get_item_metadata(index)) == loop_mode:
			_loop_mode.select(index)
			break
	_refresh_frame_list()


func _refresh_frame_list(preferred_index: int = -1) -> void:
	_frame_list.clear()
	var animation := _get_selected_animation()
	if animation.is_empty() or _working_frames == null:
		return
	var count := _working_frames.get_frame_count(animation)
	for index in range(count):
		var texture := _working_frames.get_frame_texture(animation, index)
		_frame_list.add_item("Кадр %02d" % (index + 1), texture)
		_frame_list.set_item_tooltip(index, "Длительность кадра: %.2f×" % _working_frames.get_frame_duration(animation, index))
	if count > 0:
		var selected_index := clampi(preferred_index, 0, count - 1) if preferred_index >= 0 else 0
		_frame_list.select(selected_index)
		_duration.set_value_no_signal(_working_frames.get_frame_duration(animation, selected_index))
	else:
		_duration.set_value_no_signal(1.0)
	_update_status()


func _update_status() -> void:
	var animation := _get_selected_animation()
	var count := _working_frames.get_frame_count(animation) if _working_frames != null and not animation.is_empty() else 0
	_status.text = "Анимаций: %d · Кадров в выбранной: %d. Изменения пока не затрагивают сцену — нажми «Применить»." % [get_animation_count(), count]


func _add_animation() -> void:
	if _working_frames == null:
		return
	var base := "animation"
	var suffix := 1
	var candidate := "%s_%02d" % [base, suffix]
	while _working_frames.has_animation(StringName(candidate)):
		suffix += 1
		candidate = "%s_%02d" % [base, suffix]
	_working_frames.add_animation(StringName(candidate))
	_refresh_animation_list(StringName(candidate))


func _rename_current_animation() -> void:
	var old_name := _get_selected_animation()
	var new_name := StringName(_animation_name.text.strip_edges())
	if old_name.is_empty() or new_name.is_empty() or old_name == new_name:
		return
	if _working_frames.has_animation(new_name):
		_status.text = "Анимация с таким именем уже существует."
		return
	_working_frames.rename_animation(old_name, new_name)
	_refresh_animation_list(new_name)


func _remove_current_animation() -> void:
	var animation := _get_selected_animation()
	if animation.is_empty():
		return
	if get_animation_count() <= 1:
		_working_frames.clear_all()
		_refresh_animation_list(&"default")
		return
	_working_frames.remove_animation(animation)
	_refresh_animation_list()


func _on_animation_selected(_index: int) -> void:
	_refresh_animation_controls()


func _on_fps_changed(value: float) -> void:
	var animation := _get_selected_animation()
	if not animation.is_empty():
		_working_frames.set_animation_speed(animation, clampf(value, 0.1, 120.0))


func _on_loop_mode_selected(index: int) -> void:
	var animation := _get_selected_animation()
	if animation.is_empty() or index < 0 or index >= _loop_mode.item_count:
		return
	var loop_mode := int(_loop_mode.get_item_metadata(index))
	_working_frames.set_animation_loop_mode(animation, loop_mode)


func _on_frame_selected(index: int) -> void:
	var animation := _get_selected_animation()
	if animation.is_empty() or index < 0 or index >= _working_frames.get_frame_count(animation):
		return
	_duration.set_value_no_signal(_working_frames.get_frame_duration(animation, index))


func _on_duration_changed(value: float) -> void:
	var animation := _get_selected_animation()
	var index := _get_selected_frame()
	if animation.is_empty() or index < 0:
		return
	var texture := _working_frames.get_frame_texture(animation, index)
	_working_frames.set_frame(animation, index, texture, clampf(value, 0.01, 60.0))
	_frame_list.set_item_tooltip(index, "Длительность кадра: %.2f×" % value)


func add_frame(texture: Texture2D, duration: float = 1.0) -> bool:
	var animation := _get_selected_animation()
	if texture == null or animation.is_empty():
		return false
	_working_frames.add_frame(animation, texture, clampf(duration, 0.01, 60.0))
	_refresh_frame_list(_working_frames.get_frame_count(animation) - 1)
	return true


func replace_selected_frame(texture: Texture2D) -> bool:
	var animation := _get_selected_animation()
	var index := _get_selected_frame()
	if texture == null or animation.is_empty() or index < 0:
		return false
	var duration := _working_frames.get_frame_duration(animation, index)
	_working_frames.set_frame(animation, index, texture, duration)
	_refresh_frame_list(index)
	return true


func remove_selected_frame() -> bool:
	var animation := _get_selected_animation()
	var index := _get_selected_frame()
	if animation.is_empty() or index < 0:
		return false
	_working_frames.remove_frame(animation, index)
	_refresh_frame_list(mini(index, _working_frames.get_frame_count(animation) - 1))
	return true


func move_selected_frame(delta: int) -> bool:
	var animation := _get_selected_animation()
	var index := _get_selected_frame()
	var next_index := index + delta
	if animation.is_empty() or index < 0 or next_index < 0 or next_index >= _working_frames.get_frame_count(animation):
		return false
	var texture := _working_frames.get_frame_texture(animation, index)
	var duration := _working_frames.get_frame_duration(animation, index)
	_working_frames.remove_frame(animation, index)
	_working_frames.add_frame(animation, texture, duration, next_index)
	_refresh_frame_list(next_index)
	return true


func _on_add_frame_pressed() -> void:
	_file_mode = "add"
	DialogService.popup_window_safely(_file_dialog, Vector2i(760, 560), 0.88)


func _on_replace_frame_pressed() -> void:
	if _get_selected_frame() < 0:
		return
	_file_mode = "replace"
	DialogService.popup_window_safely(_file_dialog, Vector2i(760, 560), 0.88)


func _on_frame_file_selected(path: String) -> void:
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		_status.text = "Не удалось загрузить Texture2D: " + path
		return
	if _file_mode == "replace":
		replace_selected_frame(texture)
	else:
		add_frame(texture)


func _on_move_frame_up_pressed() -> void:
	move_selected_frame(-1)


func _on_move_frame_down_pressed() -> void:
	move_selected_frame(1)


func _on_remove_frame_pressed() -> void:
	remove_selected_frame()


func _on_confirmed() -> void:
	if _working_frames != null:
		frames_accepted.emit(_working_frames.duplicate(true) as SpriteFrames)
