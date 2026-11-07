extends SceneTree

const WorkspaceViewScript = preload("res://addons/object_builder/ui/workspace_view.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workspace = WorkspaceViewScript.new()
	workspace.call("build")
	root.add_child(workspace)

	_expect(workspace.call("get_toolbar_actions") is HBoxContainer, "workspace exposes a toolbar action host")
	_expect(workspace.call("get_library_host") is VBoxContainer, "workspace exposes a library host")
	_expect(workspace.call("get_editor_host") is VBoxContainer, "workspace exposes an editor host")
	_expect(workspace.call("get_inspector_host") is VBoxContainer, "workspace exposes a contextual inspector host")
	_expect(float(workspace.call("get_inspector_minimum_width")) >= 300.0, "inspector has enough minimum width for readable details")
	_expect(workspace.call("is_library_visible"), "library panel is visible by default")
	_expect(workspace.call("is_inspector_visible"), "inspector panel is visible by default")
	_expect(not workspace.call("is_diagnostics_visible"), "diagnostics panel starts collapsed")

	workspace.call("set_document_info", "Дуб", "Nature", false, true)
	_expect(workspace.call("get_document_name_text") == "Дуб", "workspace title follows the selected object")
	workspace.call("set_selection_info", "Sprite2D", "Object/Visuals/Sprite2D")
	_expect(workspace.call("get_selection_name_text").is_empty(), "selected scene part is not duplicated in Properties")
	_expect(workspace.call("get_inspector_host").get_child_count() == 0, "workspace does not add a duplicate metadata summary to Properties")

	var initial_state: Dictionary = workspace.call("get_layout_state")
	_expect(bool(initial_state.get("library_visible", false)), "workspace layout stores library visibility")
	_expect(bool(initial_state.get("inspector_visible", false)), "workspace layout stores inspector visibility")
	_expect(not bool(initial_state.get("diagnostics_visible", true)), "workspace layout stores collapsed diagnostics")

	workspace.call("set_library_visible", false)
	workspace.call("set_inspector_visible", false)
	workspace.call("set_diagnostics_visible", true)
	_expect(not workspace.call("is_library_visible"), "library visibility can be toggled")
	_expect(not workspace.call("is_inspector_visible"), "inspector visibility can be toggled")
	_expect(workspace.call("is_diagnostics_visible"), "diagnostics visibility can be toggled")

	var saved_state: Dictionary = workspace.call("get_layout_state")
	saved_state["library_split_offset"] = -90
	saved_state["inspector_split_offset"] = 80
	var restored = WorkspaceViewScript.new()
	restored.call("build")
	root.add_child(restored)
	restored.call("apply_layout_state", saved_state)
	var restored_state: Dictionary = restored.call("get_layout_state")
	_expect(not restored.call("is_library_visible"), "saved library visibility is restored")
	_expect(not restored.call("is_inspector_visible"), "saved inspector visibility is restored")
	_expect(restored.call("is_diagnostics_visible"), "saved diagnostics visibility is restored")
	_expect(int(restored_state.get("library_split_offset")) == -90, "library splitter position is restored")
	_expect(int(restored_state.get("inspector_split_offset")) == 80, "inspector splitter position is restored")

	workspace.call("set_status", "Тестовая ошибка", true)
	_expect(workspace.call("is_diagnostics_visible"), "errors automatically reveal the diagnostics panel")
	_expect(workspace.call("get_diagnostics_message") == "Тестовая ошибка", "diagnostics displays the current message")

	root.remove_child(workspace)
	workspace.free()
	root.remove_child(restored)
	restored.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder workspace view tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
