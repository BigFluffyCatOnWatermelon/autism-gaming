@tool
extends ConfirmationDialog
## Small editor for the name and description of a user-owned capability preset.

var _name_input: LineEdit
var _description_input: TextEdit


func build() -> void:
	if _name_input != null:
		return
	title = "Пользовательский набор"
	min_size = Vector2i(420, 260)
	ok_button_text = "Сохранить"
	add_cancel_button("Отмена")

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	add_child(content)

	var name_label := Label.new()
	name_label.text = "Название"
	content.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Например, Быстрый ресурс"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_name_input)

	var description_label := Label.new()
	description_label.text = "Описание (необязательно)"
	content.add_child(description_label)

	_description_input = TextEdit.new()
	_description_input.placeholder_text = "Кратко опиши, для каких объектов подходит этот набор."
	_description_input.custom_minimum_size = Vector2(0, 92)
	_description_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_description_input)


func configure(dialog_title: String, initial_name: String, initial_description: String, confirm_label: String = "Сохранить") -> void:
	build()
	title = dialog_title
	_name_input.text = initial_name
	_description_input.text = initial_description
	get_ok_button().text = confirm_label
	_name_input.grab_focus()


func get_display_name() -> String:
	return _name_input.text.strip_edges() if _name_input != null else ""


func get_description() -> String:
	return _description_input.text.strip_edges() if _description_input != null else ""
