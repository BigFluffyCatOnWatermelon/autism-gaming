@tool
extends RefCounted
class_name ObjectSceneStructureService

const ROOT_NODE_ID := "root"
const NODE_ID_META := "object_builder_node_id"
const ALLOWED_CONNECTION_FLAGS := (
	Object.CONNECT_DEFERRED
	| Object.CONNECT_PERSIST
	| Object.CONNECT_ONE_SHOT
	| Object.CONNECT_REFERENCE_COUNTED
)


## Validates the complete declarative structure without mutating the scene.
## Nodes are topologically ordered so every generated parent exists before its children.
static func build_plan(definition: ObjectDefinition, scene_root: Node) -> Dictionary:
	var errors := PackedStringArray()
	if definition == null:
		return _failed_plan(["Не передано определение объекта."])
	if scene_root == null:
		return _failed_plan(["Не создан корневой узел объекта."])

	var node_definitions: Dictionary = {}
	var pending: Array[ObjectNodeDefinition] = []
	for node_definition in definition.node_definitions:
		if node_definition == null:
			errors.append("В структуре объекта есть пустое описание узла.")
			continue
		if not node_definition.enabled:
			continue
		var node_id := node_definition.node_id.strip_edges()
		if node_id.is_empty() or node_id == ROOT_NODE_ID:
			errors.append("Каждому создаваемому узлу нужен уникальный ID, отличный от 'root'.")
			continue
		if node_definitions.has(node_id):
			errors.append("В структуре повторяется ID узла: " + node_id)
			continue
		if not ClassDB.class_exists(node_definition.node_type):
			errors.append("Неизвестный тип узла '%s' для '%s'." % [node_definition.node_type, node_id])
			continue
		if not ClassDB.is_parent_class(node_definition.node_type, "Node"):
			errors.append("Тип '%s' не является узлом Godot." % node_definition.node_type)
			continue
		if node_definition.node_name.strip_edges().is_empty():
			errors.append("У узла '%s' не задано имя." % node_id)
		if node_definition.parent_node_path.is_empty():
			var parent_id := node_definition.parent_node_id.strip_edges()
			if parent_id.is_empty():
				parent_id = ROOT_NODE_ID
			if parent_id != ROOT_NODE_ID and not node_definitions.has(parent_id):
				# Parent may appear later in the source array; resolve after collecting all IDs.
				pass
		else:
			if node_definition.parent_node_id.strip_edges() not in ["", ROOT_NODE_ID]:
				errors.append("У узла '%s' одновременно заданы ID-родитель и путь к родителю." % node_id)
			elif scene_root.get_node_or_null(node_definition.parent_node_path) == null:
				errors.append("Для узла '%s' не найден родитель '%s'." % [node_id, str(node_definition.parent_node_path)])
		node_definitions[node_id] = node_definition
		pending.append(node_definition)

	var ordered_nodes: Array[ObjectNodeDefinition] = []
	var unresolved: Array[ObjectNodeDefinition] = pending.duplicate()
	var resolved_ids: Dictionary = {ROOT_NODE_ID: true}
	for node_definition in pending:
		if not node_definition.parent_node_path.is_empty():
			continue
		var parent_id := node_definition.parent_node_id.strip_edges()
		if parent_id.is_empty():
			parent_id = ROOT_NODE_ID
		if not node_definitions.has(parent_id) and parent_id != ROOT_NODE_ID:
			errors.append("У узла '%s' отсутствует родитель '%s'." % [node_definition.node_id, parent_id])
	while not unresolved.is_empty():
		var progressed := false
		for index in range(unresolved.size() - 1, -1, -1):
			var node_definition := unresolved[index] as ObjectNodeDefinition
			var parent_id := node_definition.parent_node_id.strip_edges()
			if parent_id.is_empty():
				parent_id = ROOT_NODE_ID
			if not node_definition.parent_node_path.is_empty() or resolved_ids.has(parent_id):
				ordered_nodes.append(node_definition)
				resolved_ids[node_definition.node_id] = true
				unresolved.remove_at(index)
				progressed = true
		if not progressed:
			var unresolved_ids := PackedStringArray()
			for node_definition in unresolved:
				unresolved_ids.append(node_definition.node_id)
			errors.append("В структуре есть цикл родительских узлов или недостижимые узлы: " + ", ".join(unresolved_ids))
			break

	for node_definition in pending:
		errors.append_array(_validate_node_properties(node_definition))

	var connection_ids: Dictionary = {}
	var connections: Array[ObjectSignalConnectionDefinition] = []
	for connection in definition.signal_connections:
		if connection == null:
			errors.append("В списке сигналов есть пустое соединение.")
			continue
		if not connection.enabled:
			continue
		var connection_id := connection.connection_id.strip_edges()
		if connection_id.is_empty():
			errors.append("Каждому соединению сигнала нужен постоянный ID.")
		elif connection_ids.has(connection_id):
			errors.append("Повторяется ID соединения сигнала: " + connection_id)
		else:
			connection_ids[connection_id] = true
		if connection.signal_name.strip_edges().is_empty() or connection.method_name.strip_edges().is_empty():
			errors.append("У соединения '%s' не указаны сигнал или метод." % connection_id)
		if not resolved_ids.has(connection.source_node_id) or not resolved_ids.has(connection.target_node_id):
			errors.append("Соединение '%s' ссылается на неизвестный узел." % connection_id)
		if (connection.flags & ~ALLOWED_CONNECTION_FLAGS) != 0:
			errors.append("У соединения '%s' указаны неизвестные флаги." % connection_id)
		connections.append(connection)

	if errors.is_empty():
		for connection in connections:
			var source := _resolve_node(scene_root, connection.source_node_id, {})
			var target := _resolve_node(scene_root, connection.target_node_id, {})
			if source == null or target == null:
				# Generated nodes are not present yet; their signal/method contracts are checked on apply.
				continue
			if not _has_signal(source, connection.signal_name):
				errors.append("У узла '%s' нет сигнала '%s'." % [connection.source_node_id, connection.signal_name])
			if not target.has_method(connection.method_name):
				errors.append("У узла '%s' нет метода '%s'." % [connection.target_node_id, connection.method_name])

	if not errors.is_empty():
		return _failed_plan(errors)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"ordered_nodes": ordered_nodes,
		"connections": connections,
		"node_ids": resolved_ids
	}


## Applies a previously validated structure. Every created node is tracked and removed on failure.
static func apply_structure(definition: ObjectDefinition, scene_root: Node) -> Dictionary:
	var plan := build_plan(definition, scene_root)
	if not bool(plan.get("ok", false)):
		return plan

	var nodes_by_id: Dictionary = {ROOT_NODE_ID: scene_root}
	var created_nodes: Array[Node] = []
	for node_definition in plan.get("ordered_nodes", []):
		var node := _instantiate_node(node_definition)
		if node == null:
			_rollback_created_nodes(created_nodes)
			return _failed_plan(["Не удалось создать узел '%s' типа '%s'." % [node_definition.node_id, node_definition.node_type]])
		var parent: Node
		if not node_definition.parent_node_path.is_empty():
			parent = scene_root.get_node_or_null(node_definition.parent_node_path)
		else:
			var parent_id := node_definition.parent_node_id.strip_edges()
			if parent_id.is_empty():
				parent_id = ROOT_NODE_ID
			parent = nodes_by_id.get(parent_id) as Node
		if parent == null:
			node.free()
			_rollback_created_nodes(created_nodes)
			return _failed_plan(["Родитель узла '%s' недоступен." % node_definition.node_id])
		var requested_name := node_definition.node_name.strip_edges().validate_node_name()
		node.name = _make_unique_child_name(parent, requested_name)
		parent.add_child(node)
		node.owner = scene_root
		node.set_meta(NODE_ID_META, node_definition.node_id)
		for group_name in node_definition.groups:
			if not group_name.strip_edges().is_empty():
				node.add_to_group(group_name.strip_edges(), true)
		for metadata_key in node_definition.metadata:
			node.set_meta(str(metadata_key), node_definition.metadata[metadata_key])
		if not _apply_node_properties(node, node_definition.properties):
			node.queue_free()
			_rollback_created_nodes(created_nodes)
			return _failed_plan(["Не удалось применить свойства узла '%s'." % node_definition.node_id])
		nodes_by_id[node_definition.node_id] = node
		created_nodes.append(node)

	var connected: Array[Dictionary] = []
	for connection in plan.get("connections", []):
		var source := _resolve_node(scene_root, connection.source_node_id, nodes_by_id)
		var target := _resolve_node(scene_root, connection.target_node_id, nodes_by_id)
		if source == null or target == null or not _has_signal(source, connection.signal_name) or not target.has_method(connection.method_name):
			_rollback_connections(connected)
			_rollback_created_nodes(created_nodes)
			return _failed_plan(["Не удалось разрешить сигнал или метод в соединении '%s'." % connection.connection_id])
		var callable := Callable(target, connection.method_name)
		if source.is_connected(connection.signal_name, callable):
			continue
		var connect_error := source.connect(connection.signal_name, callable, connection.flags)
		if connect_error != OK:
			_rollback_connections(connected)
			_rollback_created_nodes(created_nodes)
			return _failed_plan(["Не удалось подключить сигнал '%s': код %d." % [connection.signal_name, connect_error]])
		connected.append({"source": source, "signal": connection.signal_name, "callable": callable})

	return {
		"ok": true,
		"errors": PackedStringArray(),
		"created_nodes": created_nodes,
		"connected_signals": connected,
		"nodes_by_id": nodes_by_id
	}


static func _instantiate_node(definition: ObjectNodeDefinition) -> Node:
	var instance: Object = ClassDB.instantiate(definition.node_type)
	return instance as Node if instance is Node else null


static func _validate_node_properties(definition: ObjectNodeDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	var instance := _instantiate_node(definition)
	if instance == null:
		errors.append("Тип узла '%s' нельзя создать." % definition.node_type)
		return errors
	var property_info_by_name: Dictionary = {}
	for property_info in instance.get_property_list():
		property_info_by_name[str(property_info.get("name", ""))] = property_info
	for property_name in definition.properties:
		var name := str(property_name)
		if name in ["name", "owner", "script"]:
			errors.append("Свойство '%s' нельзя задавать через простой контракт узла." % name)
			continue
		if not property_info_by_name.has(name):
			errors.append("У узла '%s' нет свойства '%s'." % [definition.node_id, name])
			continue
		var property_info: Dictionary = property_info_by_name[name]
		if (int(property_info.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			errors.append("Свойство '%s' не предназначено для сохранения." % name)
			continue
		var value: Variant = definition.properties[property_name]
		var expected_type := int(property_info.get("type", TYPE_NIL))
		if expected_type != TYPE_NIL and typeof(value) != expected_type:
			errors.append("Тип значения свойства '%s' не совпадает с типом узла '%s'." % [name, definition.node_id])
	instance.free()
	return errors


static func _apply_node_properties(node: Node, properties: Dictionary) -> bool:
	var property_names: Dictionary = {}
	for property_info in node.get_property_list():
		property_names[str(property_info.get("name", ""))] = true
	for property_name in properties:
		var name := str(property_name)
		if not property_names.has(name) or name in ["name", "owner", "script"]:
			return false
		node.set(name, properties[property_name])
	return true


static func _resolve_node(scene_root: Node, node_id: String, nodes_by_id: Dictionary) -> Node:
	if node_id == ROOT_NODE_ID:
		return scene_root
	if nodes_by_id.has(node_id):
		return nodes_by_id[node_id] as Node
	for node in scene_root.find_children("*", "", true, false):
		if node.has_meta(NODE_ID_META) and str(node.get_meta(NODE_ID_META)) == node_id:
			return node
	return null


static func _has_signal(node: Node, signal_name: String) -> bool:
	for signal_info in node.get_signal_list():
		if str(signal_info.get("name", "")) == signal_name:
			return true
	return false


static func _make_unique_child_name(parent: Node, requested_name: String) -> String:
	var base_name := requested_name if not requested_name.is_empty() else "Node"
	var candidate := base_name
	var suffix := 2
	while parent.has_node(NodePath(candidate)):
		candidate = "%s_%d" % [base_name, suffix]
		suffix += 1
	return candidate


static func _rollback_connections(connections: Array[Dictionary]) -> void:
	for connection in connections:
		var source := connection.get("source") as Node
		var signal_name := str(connection.get("signal", ""))
		var callable: Callable = connection.get("callable", Callable())
		if is_instance_valid(source) and source.is_connected(signal_name, callable):
			source.disconnect(signal_name, callable)


static func _rollback_created_nodes(nodes: Array[Node]) -> void:
	for index in range(nodes.size() - 1, -1, -1):
		var node := nodes[index]
		if is_instance_valid(node):
			node.free()


static func _failed_plan(errors: PackedStringArray) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"ordered_nodes": [],
		"connections": [],
		"node_ids": {}
	}
