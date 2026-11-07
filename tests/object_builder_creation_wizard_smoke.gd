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
		{"id": "Nature", "label": "Природа"},
		{"id": "Items", "label": "Предметы"},
		{"id": "Furniture", "label": "Мебель"}
	]
	var templates: Array[Dictionary] = [
		{
			"id": "template_chest",
			"label": "Сундук",
			"category": "Items",
			"description": "Сохраняет вещи",
			"tags": PackedStringArray(["wood", "chest"])
		},
		{
			"id": "template_crate",
			"label": "Ящик",
			"category": "Furniture",
			"description": "Небольшой ящик",
			"tags": PackedStringArray(["box", "wood"])
		}
	]
	var objects: Array[Dictionary] = [
		{
			"id": "tree_oak",
			"label": "Дуб",
			"category": "Nature",
			"description": "Лесное дерево",
			"tags": PackedStringArray(["tree", "wood"])
		}
	]
	dialog_view.call("set_creation_category_options", categories, "Nature")
	dialog_view.call("set_creation_sources", templates, objects)
	dialog_view.call("reset_creation_wizard", "template")

	var form: Dictionary = dialog_view.call("get_creation_form_values")
	_expect(form.get("mode") == "template", "wizard selects the template creation path")
	_expect(form.get("source_id") == "template_chest", "wizard resolves templates by stable object ID")
	_expect(form.get("display_name") == "Сундук — копия", "wizard suggests a copy name for a selected template")
	_expect(form.get("category") == "Items", "wizard inherits a source category as a suggestion")
	_expect(form.get("tags") == PackedStringArray(["wood", "chest"]), "wizard inherits source tags")
	_expect(form.get("description") == "Сохраняет вещи", "wizard inherits the source description")

	(dialog_view.get("_creation_name_edit") as LineEdit).text = "Дубовый сундук"
	(dialog_view.get("_creation_tags_edit") as LineEdit).text = "wood, chest, wood"
	(dialog_view.get("_creation_description_edit") as TextEdit).text = "Хранит вещи"
	form = dialog_view.call("get_creation_form_values")
	_expect(form.get("display_name") == "Дубовый сундук", "wizard returns the display name")
	_expect(form.get("tags") == PackedStringArray(["wood", "chest"]), "wizard parses and deduplicates comma-separated tags")
	_expect(form.get("description") == "Хранит вещи", "wizard returns the object description")

	(dialog_view.get("_creation_name_edit") as LineEdit).text = "Мой сундук"
	(dialog_view.get("_creation_tags_edit") as LineEdit).text = "my, tags"
	(dialog_view.get("_creation_description_edit") as TextEdit).text = "Моё описание"
	dialog_view.call("set_creation_category", "Nature")
	var source_option := dialog_view.get("_creation_source_option") as OptionButton
	source_option.select(1)
	source_option.item_selected.emit(1)
	form = dialog_view.call("get_creation_form_values")
	_expect(form.get("display_name") == "Мой сундук", "changing source does not overwrite a manually edited name")
	_expect(form.get("category") == "Nature", "changing source does not overwrite a manually selected category")
	_expect(form.get("tags") == PackedStringArray(["my", "tags"]), "changing source does not overwrite manually edited tags")
	_expect(form.get("description") == "Моё описание", "changing source does not overwrite a manually edited description")

	dialog_view.call("reset_creation_wizard", "duplicate")
	form = dialog_view.call("get_creation_form_values")
	_expect(form.get("mode") == "duplicate", "wizard switches to existing-object copy mode")
	_expect(form.get("source_id") == "tree_oak", "wizard resolves existing objects by stable ID")
	_expect(form.get("display_name") == "Дуб — копия", "wizard suggests a copy name for an existing object")
	_expect(form.get("category") == "Nature", "wizard inherits existing object category")
	_expect(form.get("tags") == PackedStringArray(["tree", "wood"]), "wizard inherits existing object tags")
	_expect(form.get("description") == "Лесное дерево", "wizard inherits existing object description")

	dialog_view.call("reset_creation_wizard", "import")
	dialog_view.call("_on_creation_import_file_selected", "res://scenes/import_me.tscn")
	form = dialog_view.call("get_creation_form_values")
	_expect(form.get("mode") == "import", "wizard switches to scene import mode")
	_expect(form.get("import_path") == "res://scenes/import_me.tscn", "wizard preserves the selected scene path")
	_expect(form.get("display_name") == "import_me", "wizard suggests an object name from the imported scene file")

	dialog_view.call("set_creation_category", "Other")
	dialog_view.call("suggest_creation_category", "Nature")
	_expect(dialog_view.call("get_creation_form_values").get("category") == "Nature", "profile category fills an untouched category field")
	dialog_view.call("set_creation_category", "Items")
	dialog_view.call("suggest_creation_category", "Furniture")
	_expect(dialog_view.call("get_creation_form_values").get("category") == "Items", "profile suggestion does not overwrite a manual category choice")
	dialog_view.call("clear_creation_category_suggestion")
	_expect(dialog_view.call("get_creation_form_values").get("category") == "Items", "clearing profile suggestion preserves a manual category choice")
	dialog_view.call("set_creation_category", "Other")
	dialog_view.call("suggest_creation_category", "Nature")
	dialog_view.call("clear_creation_category_suggestion")
	_expect(dialog_view.call("get_creation_form_values").get("category") == "Other", "clearing an untouched profile suggestion restores the default category")

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
