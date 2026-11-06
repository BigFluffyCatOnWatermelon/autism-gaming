@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"part_paths": "", "parts_visible": true, "parts_offset": Vector2.ZERO})


func apply_to(root: Node) -> bool:
    if not is_instance_valid(root):
        return fail("Не передан корневой узел составного объекта.")
    var paths := str(get_option("part_paths", "")).split(";", false)
    var changed := 0
    for raw_path in paths:
        var path := raw_path.strip_edges()
        if path.is_empty():
            continue
        var node := root.get_node_or_null(NodePath(path))
        if node == null:
            continue
        if node is CanvasItem:
            node.visible = bool(get_option("parts_visible", true))
            if node is Node2D:
                node.position += get_option("parts_offset", Vector2.ZERO)
            elif node is Control:
                node.position += get_option("parts_offset", Vector2.ZERO)
            changed += 1
    if changed == 0:
        return fail("Не найдено ни одной визуальной части по указанным NodePath.")
    action_completed.emit(changed)
    return true
