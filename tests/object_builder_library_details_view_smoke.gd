extends SceneTree

const DetailsViewScript = preload("res://addons/object_builder/ui/library_details_view.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var details_view = DetailsViewScript.new()
	root.add_child(details_view)
	details_view.call("build")
	_expect(details_view.visible, "unified Properties inspector shows an empty-state prompt before selection")
	_expect(details_view.custom_minimum_size == Vector2.ZERO, "details view does not impose a second panel minimum size")
	_expect(details_view.get_child_count() == 1, "details view does not add a duplicate inner header")

	details_view.call("set_details", {
		"display_name": "Дуб",
		"object_id": "tree_oak",
		"category": "Nature",
		"description": "Большое дерево для лесной зоны.",
		"is_template": false,
		"preview_texture": null,
		"tags_text": "tree wood forest",
		"capabilities_text": "Можно повредить",
		"dependencies_text": "Можно повредить → Есть здоровье"
	})
	_expect(details_view.visible, "details panel appears for a selected entry")
	_expect(str(details_view.call("get_display_name_text")) == "Дуб", "details panel displays the selected object's name")
	_expect(str(details_view.call("get_capabilities_text")).contains("Можно повредить"), "details panel displays enabled capabilities")
	_expect(str(details_view.call("get_dependencies_text")).contains("Есть здоровье"), "details panel displays capability dependencies")

	details_view.call("set_details", {})
	_expect(details_view.visible, "unified Properties inspector remains present when the selection is cleared")

	root.remove_child(details_view)
	details_view.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder library details view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
