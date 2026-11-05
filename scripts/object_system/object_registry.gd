extends Node
class_name ObjectRegistry

@export var reload_on_ready: bool = true

var _definitions: Dictionary = {}


func _ready() -> void:
	if reload_on_ready:
		reload()


func reload() -> void:
	_definitions.clear()
	for definition in ObjectLibraryService.load_definitions():
		if definition == null or definition.object_id.is_empty():
			continue
		if _definitions.has(definition.object_id):
			push_warning("ObjectRegistry: повторяющийся ID объекта: " + definition.object_id)
			continue
		_definitions[definition.object_id] = definition


func get_definition(object_id: String) -> ObjectDefinition:
	return _definitions.get(object_id) as ObjectDefinition


func get_all_definitions() -> Array[ObjectDefinition]:
	var result: Array[ObjectDefinition] = []
	for definition in _definitions.values():
		if definition is ObjectDefinition:
			result.append(definition)
	return result


func instantiate_by_id(
	object_id: String,
	parent: Node = null,
	property_overrides: Dictionary = {}
) -> Node:
	if not _definitions.has(object_id):
		reload()
	var definition := get_definition(object_id)
	if definition == null:
		push_warning("ObjectRegistry: объект не найден в библиотеке: " + object_id)
		return null
	var instance := ObjectFactory.instantiate(definition, property_overrides)
	if instance != null and parent != null:
		parent.add_child(instance)
	return instance
