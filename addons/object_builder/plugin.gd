@tool
extends EditorPlugin

## Archived compatibility stub.
## The active editor, library dock, object services and mechanic packages
## are owned by addons/web_object_builder. This plugin intentionally registers
## no controls, menus, inspectors or editor callbacks.


func _enter_tree() -> void:
	push_warning(
		"Object Builder is archived. The active editor is Web Object Builder; "
		+ "disable this legacy plugin."
	)


func _exit_tree() -> void:
	pass
