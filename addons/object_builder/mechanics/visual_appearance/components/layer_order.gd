@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"z_index": 0, "z_as_relative": true})
    set_option("z_index", clampi(int(get_option("z_index", 0)), -4096, 4096))


func _apply_bound_target() -> bool:
    var target := find_canvas_item()
    if target == null:
        return fail("Для порядка отрисовки нужен CanvasItem в целевой ветке.")
    return apply_to(target)


func apply_to(target: CanvasItem, z_value: int = 2147483647) -> bool:
    if not is_instance_valid(target):
        return fail("Не передан действительный CanvasItem.")
    var order := int(get_option("z_index", 0)) if z_value == 2147483647 else z_value
    if order < -4096 or order > 4096:
        return fail("Порядок отрисовки должен находиться в диапазоне -4096…4096.")
    target.z_index = order
    target.z_as_relative = bool(get_option("z_as_relative", true))
    set_option("z_index", order)
    action_completed.emit(order)
    return true
