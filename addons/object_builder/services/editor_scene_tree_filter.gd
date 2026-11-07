@tool
extends RefCounted
## Filters editor tree notifications to the currently edited scene.


static func belongs_to_scene(scene_root: Node, changed_node: Node) -> bool:
	if scene_root == null or changed_node == null:
		return false
	if not is_instance_valid(scene_root) or not is_instance_valid(changed_node):
		return false
	if changed_node == scene_root:
		return true
	return scene_root.is_ancestor_of(changed_node)
