@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"

var _original_states: Dictionary = {}


func _on_configured() -> void:
    _load_options({"part_paths": "", "parts_visible": true, "parts_offset": Vector2.ZERO})


func _apply_bound_target() -> bool:
    var root := get_bound_target()
    if root == null:
        return fail("Не привязан корневой узел составного объекта.")
    if str(get_option("part_paths", "")).strip_edges().is_empty():
        _restore_parts()
        return true
    return apply_to(root)


func apply_to(root: Node) -> bool:
    if not is_instance_valid(root):
        return fail("Не передан корневой узел составного объекта.")
    _restore_parts()
    var paths := str(get_option("part_paths", "")).split(";", false)
    var changed := 0
    for raw_path in paths:
        var path := raw_path.strip_edges()
        if path.is_empty():
            continue
        var node := root.get_node_or_null(NodePath(path))
        if node == null or not node is CanvasItem:
            continue
        var instance_id := node.get_instance_id()
        if not _original_states.has(instance_id):
            _original_states[instance_id] = {
                "node": node,
                "visible": node.visible,
                "position": node.position if node is Node2D or node is Control else Vector2.ZERO
            }
        node.visible = bool(get_option("parts_visible", true))
        if node is Node2D or node is Control:
            node.position = _original_states[instance_id]["position"] + get_option("parts_offset", Vector2.ZERO)
        changed += 1
    if changed == 0:
        return fail("Не найдено ни одной визуальной части по указанным NodePath.")
    action_completed.emit(changed)
    return true


func _restore_parts() -> void:
    for record in _original_states.values():
        var node: Node = record.get("node")
        if not is_instance_valid(node):
            continue
        node.visible = bool(record.get("visible", true))
        if node is Node2D or node is Control:
            node.position = record.get("position", Vector2.ZERO)
    _original_states.clear()


func _exit_tree() -> void:
    _restore_parts()
