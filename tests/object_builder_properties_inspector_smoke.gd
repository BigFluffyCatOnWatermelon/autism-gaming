extends SceneTree

const InspectorScript = preload("res://addons/object_builder/ui/properties_inspector_view.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var inspector = InspectorScript.new()
	inspector.call("build")
	root.add_child(inspector)
	var details := Control.new()
	var settings := Control.new()
	inspector.call("set_details_view", details)
	inspector.call("set_capability_settings_view", settings)

	_expect(inspector.get_child_count() == 2, "both contexts belong to one inspector root")
	_expect(details.visible and not settings.visible, "object details are the default context")
	_expect(inspector.call("get_active_context") == "details", "inspector reports object context")
	inspector.call("show_capability_settings")
	_expect(not details.visible and settings.visible, "capability settings replace details in the same surface")
	_expect(inspector.call("is_showing_capability_settings"), "inspector reports capability context")
	inspector.call("show_object_details")
	_expect(details.visible and not settings.visible, "returning to details hides capability settings")
	_expect(not inspector.call("is_showing_capability_settings"), "inspector returns to object context")

	root.remove_child(inspector)
	inspector.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder properties inspector tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
