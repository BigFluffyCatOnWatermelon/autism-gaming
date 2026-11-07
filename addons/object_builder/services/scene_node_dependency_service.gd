@tool
extends RefCounted
## Finds scene and ObjectDefinition references that may be affected by deleting a node subtree.

const GENERATED_NODE_ID_META := "object_builder_node_id"


static func inspect(scene_root: Node, removed_node: Node, definition: ObjectDefinition = null) -> Array[Dictionary]:
	var references: Array[Dictionary] = []
	if scene_root == null or removed_node == null:
		return references
	if not is_instance_valid(scene_root) or not is_instance_valid(removed_node):
		return references
	if removed_node != scene_root and not scene_root.is_ancestor_of(removed_node):
		return references

	var subtree_nodes := _collect_nodes(removed_node)
	var subtree_ids := _collect_generated_ids(subtree_nodes)
	var seen: Dictionary = {}
	var all_nodes := _collect_nodes(scene_root)
	_collect_node_path_references(all_nodes, removed_node, references, seen)
	_collect_signal_references(all_nodes, removed_node, references, seen)
	_collect_animation_references(all_nodes, removed_node, references, seen)
	_collect_definition_references(scene_root, removed_node, subtree_ids, definition, references, seen)
	references.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("source_path", "")) < str(b.get("source_path", ""))
	)
	return references


static func _collect_nodes(root_node: Node) -> Array[Node]:
	var result: Array[Node] = [root_node]
	for child in root_node.get_children():
		result.append_array(_collect_nodes(child))
	return result


static func _collect_generated_ids(nodes: Array[Node]) -> Dictionary:
	var result: Dictionary = {}
	for node in nodes:
		if node.has_meta(GENERATED_NODE_ID_META):
			var node_id := str(node.get_meta(GENERATED_NODE_ID_META)).strip_edges()
			if not node_id.is_empty():
				result[node_id] = true
	return result


static func _is_within(candidate: Node, subtree_root: Node) -> bool:
	if candidate == null or subtree_root == null:
		return false
	return candidate == subtree_root or subtree_root.is_ancestor_of(candidate)


static func _add_reference(
	references: Array[Dictionary],
	seen: Dictionary,
	kind: String,
	source_path: String,
	details: String
) -> void:
	var key := "%s|%s|%s" % [kind, source_path, details]
	if seen.has(key):
		return
	seen[key] = true
	references.append({
		"kind": kind,
		"source_path": source_path,
		"details": details
	})


static func _collect_node_path_references(
	all_nodes: Array[Node],
	removed_node: Node,
	references: Array[Dictionary],
	seen: Dictionary
) -> void:
	for source_node in all_nodes:
		var source_is_removed := _is_within(source_node, removed_node)
		for property_info in source_node.get_property_list():
			if int(property_info.get("type", TYPE_NIL)) != TYPE_NODE_PATH:
				continue
			if (int(property_info.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
				continue
			var property_name := str(property_info.get("name", ""))
			if property_name.is_empty():
				continue
			var value: Variant = source_node.get(property_name)
			if not value is NodePath or value.is_empty():
				continue
			var target_node := source_node.get_node_or_null(value) as Node
			var target_is_removed := _is_within(target_node, removed_node)
			if not source_is_removed and not target_is_removed:
				continue
			if source_is_removed and target_is_removed:
				continue
			var kind := "NodePath из удаляемой части" if source_is_removed else "NodePath на удаляемую часть"
			var detail := "%s → %s" % [property_name, str(value)]
			_add_reference(references, seen, kind, str(source_node.get_path()), detail)


static func _collect_signal_references(
	all_nodes: Array[Node],
	removed_node: Node,
	references: Array[Dictionary],
	seen: Dictionary
) -> void:
	for source_node in all_nodes:
		var source_is_removed := _is_within(source_node, removed_node)
		for signal_info in source_node.get_signal_list():
			var signal_name := str(signal_info.get("name", ""))
			if signal_name.is_empty():
				continue
			for connection in source_node.get_signal_connection_list(signal_name):
				var callable: Callable = connection.get("callable", Callable())
				var target_node := callable.get_object() as Node
				var target_is_removed := _is_within(target_node, removed_node)
				if not source_is_removed and not target_is_removed:
					continue
				if source_is_removed and target_is_removed:
					continue
				var method_name := str(callable.get_method())
				var endpoint := str(target_node.get_path()) if target_node != null else method_name
				var kind := "Сигнал удаляемой части" if source_is_removed else "Внешний сигнал на удаляемую часть"
				_add_reference(
					references, seen, kind, str(source_node.get_path()),
					"%s → %s.%s" % [signal_name, endpoint, method_name]
				)


static func _collect_animation_references(
	all_nodes: Array[Node],
	removed_node: Node,
	references: Array[Dictionary],
	seen: Dictionary
) -> void:
	for source_node in all_nodes:
		if not source_node is AnimationPlayer:
			continue
		var player := source_node as AnimationPlayer
		var player_is_removed := _is_within(player, removed_node)
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			if library == null:
				continue
			for animation_name in library.get_animation_list():
				var animation := library.get_animation(animation_name)
				if animation == null:
					continue
				var animation_root := player.get_node_or_null(player.root_node) as Node
				if animation_root == null:
					animation_root = player
				for track_index in range(animation.get_track_count()):
					var track_path := animation.track_get_path(track_index)
					var target_node := animation_root.get_node_or_null(track_path) as Node
					var target_is_removed := _is_within(target_node, removed_node)
					if not player_is_removed and not target_is_removed:
						continue
					if player_is_removed and target_is_removed:
						continue
					var kind := "Анимация удаляемого узла" if player_is_removed else "AnimationPlayer с треком на удаляемую часть"
					var detail := "%s / %s → %s" % [str(library_name), str(animation_name), str(track_path)]
					_add_reference(references, seen, kind, str(player.get_path()), detail)


static func _collect_definition_references(
	scene_root: Node,
	removed_node: Node,
	subtree_ids: Dictionary,
	definition: ObjectDefinition,
	references: Array[Dictionary],
	seen: Dictionary
) -> void:
	if definition == null:
		return
	for node_definition in definition.node_definitions:
		if node_definition == null:
			continue
		var parent_is_removed := false
		if not node_definition.parent_node_path.is_empty():
			var parent_node := scene_root.get_node_or_null(node_definition.parent_node_path) as Node
			parent_is_removed = _is_within(parent_node, removed_node)
		elif subtree_ids.has(node_definition.parent_node_id):
			parent_is_removed = true
		if parent_is_removed:
			_add_reference(
				references, seen, "Декларативная структура",
				"ObjectDefinition",
				"Узел %s зависит от удаляемого родителя %s." % [node_definition.node_id, node_definition.parent_node_id if node_definition.parent_node_path.is_empty() else str(node_definition.parent_node_path)]
			)
	for connection in definition.signal_connections:
		if connection == null:
			continue
		var source_removed := subtree_ids.has(connection.source_node_id)
		var target_removed := subtree_ids.has(connection.target_node_id)
		if source_removed or target_removed:
			_add_reference(
				references, seen, "Декларативный сигнал",
				"ObjectDefinition",
				"%s: %s → %s.%s" % [connection.connection_id, connection.source_node_id, connection.target_node_id, connection.method_name]
			)
