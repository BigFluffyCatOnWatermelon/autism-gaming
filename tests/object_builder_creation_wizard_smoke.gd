extends SceneTree

const DialogViewScript = preload("res://addons/object_builder/ui/dialog_view.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dialog_view = DialogViewScript.new()
	root.add_child(dialog_view)
	dialog_view.call("build", [], [], [])

	var categories: Array[Dictionary] = [
		{"id": "Other", "label": "Другое"},
		{"id": "Nature", "label": "Природа"}
	]
	var templates: Array[Dictionary] = [
		{"id": "template_chest", "label": "Сундук"}
	]
	var objects: Array[Dictionary] = [
		{"id": "tree_oak", "label": "Дуб"}
	]
	dialog_view.call("set_creation_category_options", categories, "Nature")
	dialog_view.call("set_creation_sources", templates, objects)
	dialog_view.call("reset_creation_wizard", "template")

	var form: Dictionary = dialog_view.call("get_creation_form_values")
	_expect(form.get("mode") == "template", "wizard selects the template creation path")
	_expect(form.get("source_id") == "template_chest", "wizard resolves templates by stable object ID")
	_expect(form.get("category") == "Nature", "wizard stores the category ID rather than the translated label")

	(dialog_view.get("_creation_name_edit") as LineEdit).text = "Дубовый сундук"
	(dialog_view.get("_creation_tags_edit") as LineEdit).text = "wood, chest, wood"
	(dialog_view.get("_creation_description_edit") as TextEdit).text = "Хранит вещи"
	form = dialog_view.call("get_creation_form_values")
	_expect(form.get("display_name") == "Дубовый сундук", "wizard returns the display name")
	_expect(form.get("tags") == PackedStringArray(["wood", "chest"]), "wizard parses and deduplicates comma-separated tags")
	_expect(form.get("description") == "Хранит вещи", "wizard returns the object description")

	dialog_view.call("reset_creation_wizard", "duplicate")
	form = dialog_view.call("get_creation_form_values")
	_expect(form.get("mode") == "duplicate", "wizard switches to existing-object copy mode")
	_expect(form.get("source_id") == "tree_oak", "wizard resolves existing objects by stable ID")

	dialog_view.call("reset_creation_wizard", "import")
	dialog_view.call("_on_creation_import_file_selected", "res://scenes/import_me.tscn")
	form = dialog_view.call("get_creation_form_values")
	_expect(form.get("mode") == "import", "wizard switches to scene import mode")
	_expect(form.get("import_path") == "res://scenes/import_me.tscn", "wizard preserves the selected scene path")

	dialog_view.call("set_creation_sources", [], [])
	var mode_option := dialog_view.get("_creation_mode_option") as OptionButton
	_expect(mode_option.is_item_disabled(1), "template mode is disabled when no templates exist")
	_expect(mode_option.is_item_disabled(2), "copy mode is disabled when no saved objects exist")

	root.remove_child(dialog_view)
	dialog_view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder creation wizard tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
