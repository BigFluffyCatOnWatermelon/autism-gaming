extends SceneTree

const SessionScript = preload("res://addons/object_builder/controllers/object_editor_session.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const PropertyScript = preload("res://scripts/object_system/object_property_definition.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session = SessionScript.new()
	var source = DefinitionScript.new()
	source.object_id = "object_chest"
	source.display_name = "Сундук"
	source.category = "Items"
	source.tags = PackedStringArray(["loot", "container"])
	var source_property = PropertyScript.new()
	source_property.property_id = "capacity"
	source_property.display_name = "Вместимость"
	source_property.value_type = "Integer"
	source_property.default_value = 12
	source.custom_properties.append(source_property)

	var draft: ObjectDefinition = session.call("begin_edit", source)
	_expect(draft != null and draft != source, "editing starts with an independent working copy")
	_expect(not bool(session.call("is_dirty")), "an existing object starts clean")
	_expect(session.call("get_original_definition").display_name == "Сундук", "the original snapshot is retained")
	_expect(draft.custom_properties[0] != source_property, "nested property resources are deeply duplicated")

	draft.display_name = "Изменённый сундук"
	(draft.custom_properties[0] as ObjectPropertyDefinition).default_value = 20
	_expect(source.display_name == "Сундук", "editing does not mutate the library source resource")
	_expect(source_property.default_value == 12, "editing nested resources does not mutate the original")
	_expect(not bool(session.call("is_dirty")), "session dirty state changes only when marked")
	session.call("mark_changed")
	_expect(bool(session.call("is_dirty")), "session records unsaved changes")

	var restored: ObjectDefinition = session.call("discard_changes")
	_expect(restored.display_name == "Сундук", "discard restores the accepted object snapshot")
	_expect((restored.custom_properties[0] as ObjectPropertyDefinition).default_value == 12, "discard restores nested values")
	_expect(not bool(session.call("is_dirty")), "discard clears the dirty flag")
	_expect(not bool(session.call("is_new")), "restored library objects are not new drafts")

	var new_definition = DefinitionScript.new()
	new_definition.object_id = "object_new"
	new_definition.display_name = "Новый объект"
	var new_draft: ObjectDefinition = session.call("begin_new", new_definition)
	_expect(bool(session.call("is_new")), "new objects are marked as new drafts")
	_expect(bool(session.call("is_dirty")), "new objects start with unsaved changes")
	_expect(session.call("get_original_definition") == null, "new drafts have no saved snapshot")

	new_draft.description = "Готов к сохранению"
	session.call("accept_saved_state", new_draft)
	_expect(not bool(session.call("is_new")), "saving converts a new draft into an existing object")
	_expect(not bool(session.call("is_dirty")), "accepting saved data clears the dirty flag")
	_expect(session.call("get_original_definition").description == "Готов к сохранению", "saved data becomes the new baseline")

	session.call("mark_changed")
	session.call("clear")
	_expect(session.call("get_working_definition") == null, "clearing the session releases the draft")
	_expect(not bool(session.call("is_dirty")), "clearing the session resets its state")

	source.free()
	new_definition.free()
	await process_frame
	if failures.is_empty():
		print("Object Builder editor session tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
