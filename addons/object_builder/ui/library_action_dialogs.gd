@tool
extends Node
## Small dialog host for object-library actions.

signal rename_confirmed(new_name: String)
signal delete_confirmed
signal export_path_selected(path: String)

const DialogService = preload("res://addons/object_builder/services/dialog_service.gd")

var _rename_dialog: ConfirmationDialog
var _rename_input: LineEdit
var _delete_dialog: ConfirmationDialog
var _export_dialog: FileDialog


func build() -> void:
	if _rename_dialog != null:
		return
	_build_rename_dialog()
	_build_delete_dialog()
	_build_export_dialog()


func popup_rename(current_name: String) -> void:
	if _rename_dialog == null:
		return
	_rename_input.text = current_name
	_rename_input.select_all()
	DialogService.popup_window_safely(_rename_dialog, Vector2i(440, 170), 0.62)
	_rename_input.grab_focus()


func popup_delete(display_name: String) -> void:
	if _delete_dialog == null:
		return
	_delete_dialog.dialog_text = (
		"Удалить «%s» из библиотеки?\n\n"
		+ "Определение и принадлежащая ему сцена будут перемещены в резервную копию "
		+ "в user://object_builder_trash."
	) % display_name
	DialogService.popup_window_safely(_delete_dialog, Vector2i(480, 210), 0.68)


func popup_export(suggested_file_name: String) -> void:
	if _export_dialog == null:
		return
	_export_dialog.current_file = suggested_file_name.validate_filename() + ".tres"
	DialogService.popup_window_safely(_export_dialog, Vector2i(760, 520), 0.78)


func _build_rename_dialog() -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Переименовать запись"
	_rename_dialog.ok_button_text = "Переименовать"
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(360, 44)
	_rename_dialog.add_child(content)
	var hint := Label.new()
	hint.text = "Новое название"
	content.add_child(hint)
	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "Название объекта"
	_rename_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_input.text_submitted.connect(_on_rename_submitted)
	content.add_child(_rename_input)


func _build_delete_dialog() -> void:
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Удалить запись?"
	_delete_dialog.ok_button_text = "Удалить"
	_delete_dialog.confirmed.connect(func() -> void:
		delete_confirmed.emit()
	)
	add_child(_delete_dialog)


func _build_export_dialog() -> void:
	_export_dialog = FileDialog.new()
	_export_dialog.title = "Экспорт определения Object Builder"
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.filters = PackedStringArray(["*.tres ; Object Builder Definition"])
	_export_dialog.file_selected.connect(_on_export_path_selected)
	add_child(_export_dialog)


func _on_rename_confirmed() -> void:
	rename_confirmed.emit(_rename_input.text.strip_edges())


func _on_rename_submitted(_value: String) -> void:
	_rename_dialog.hide()
	_on_rename_confirmed()


func _on_export_path_selected(path: String) -> void:
	export_path_selected.emit(path)
