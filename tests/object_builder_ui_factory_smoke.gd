extends SceneTree

const UIFactory = preload("res://addons/object_builder/ui/ui_factory.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := VBoxContainer.new()
	root.add_child(host)

	var title := UIFactory.create_section_title(host, "Основное", 18)
	_expect(title.text == "Основное", "section title is created with its label")

	var name_edit := UIFactory.add_labeled_line_edit(host, "Название", "Имя объекта")
	_expect(name_edit.placeholder_text == "Имя объекта", "labeled line edit preserves its placeholder")
	_expect(host.get_child_count() == 3, "labeled line edit adds both label and input")

	var compact_row := HBoxContainer.new()
	host.add_child(compact_row)
	var compact_control := SpinBox.new()
	UIFactory.add_labeled_control(compact_row, "Масштаб", compact_control, 72.0)
	_expect(is_equal_approx(compact_control.custom_minimum_size.x, 72.0), "compact fields share one width rule")

	var spin_box := UIFactory.make_spin_box(-10.0, 10.0, 0.5)
	_expect(
		is_equal_approx(spin_box.min_value, -10.0)
		and is_equal_approx(spin_box.max_value, 10.0)
		and is_equal_approx(spin_box.step, 0.5),
		"numeric fields use the shared SpinBox configuration"
	)

	var empty_host := VBoxContainer.new()
	host.add_child(empty_host)
	var empty_label := UIFactory.add_empty_state(empty_host, "Нет объектов")
	_expect(empty_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "empty state wraps long messages")

	var dialog := AcceptDialog.new()
	root.add_child(dialog)
	var form := UIFactory.create_scrollable_dialog_body(dialog, Vector2i(320, 180))
	_expect(form.get_parent() is ScrollContainer, "dialog forms use the shared scroll container")
	_expect(form.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "dialog form expands horizontally")

	UIFactory.clear_children(empty_host)
	_expect(empty_host.get_child_count() == 0, "dynamic lists can be cleared through one helper")

	host.queue_free()
	dialog.queue_free()
	if failures.is_empty():
		print("Object Builder UI factory smoke tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
