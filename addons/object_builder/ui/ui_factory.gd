@tool
extends RefCounted
## Shared UI primitives for Object Builder.
## Keep layout rules here so dialogs, panels and future screens behave consistently.


static func add_labeled_control(
	parent: Container,
	label_text: String,
	control: Control,
	compact_width: float = 0.0
) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)

	if compact_width > 0.0:
		control.custom_minimum_size = Vector2(compact_width, control.custom_minimum_size.y)
	else:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)


static func add_labeled_line_edit(
	parent: Container,
	label_text: String,
	placeholder: String
) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	add_labeled_control(parent, label_text, edit)
	return edit


static func create_section_title(
	parent: Container,
	title_text: String,
	font_size: int = 16
) -> Label:
	var title := Label.new()
	title.text = title_text
	if font_size > 0:
		title.add_theme_font_size_override("font_size", font_size)
	parent.add_child(title)
	return title


static func add_empty_state(parent: Container, message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


static func add_action_button(
	parent: Container,
	button_text: String,
	action: Callable = Callable(),
	tooltip: String = "",
	expand_horizontal: bool = false
) -> Button:
	var button := Button.new()
	button.text = button_text
	button.tooltip_text = tooltip
	if expand_horizontal:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if action.is_valid():
		button.pressed.connect(action)
	parent.add_child(button)
	return button


static func make_spin_box(minimum: float, maximum: float, step_value: float) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step_value
	control.allow_greater = false
	control.allow_lesser = false
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


static func create_scrollable_dialog_body(
	dialog: AcceptDialog,
	minimum_size: Vector2i,
	separation: int = 7
) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(minimum_size)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dialog.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", separation)
	scroll.add_child(content)
	return content


static func clear_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func popup_window_safely(
	window: Window,
	preferred_size: Vector2i,
	fallback_ratio: float = 0.82
) -> void:
	if window == null or not is_instance_valid(window):
		return

	var screen_index := DisplayServer.window_get_current_screen()
	var usable_size := DisplayServer.screen_get_usable_rect(screen_index).size
	if usable_size.x <= 0 or usable_size.y <= 0:
		window.popup_centered_clamped(preferred_size, fallback_ratio)
		return

	var maximum_size := Vector2i(
		mini(usable_size.x, maxi(240, int(floor(float(usable_size.x) * 0.90)))),
		mini(usable_size.y, maxi(180, int(floor(float(usable_size.y) * 0.84))))
	)
	window.max_size = maximum_size
	var requested_size := Vector2i(
		mini(preferred_size.x, maximum_size.x),
		mini(preferred_size.y, maximum_size.y)
	)
	window.size = requested_size
	window.popup_centered_clamped(requested_size, fallback_ratio)
