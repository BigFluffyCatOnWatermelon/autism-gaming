@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"tint_color": "#ffffff"})


func _apply_bound_target() -> bool:
    var target := find_canvas_item()
    if target == null:
        return fail("Для оттенка нужен CanvasItem в целевой ветке.")
    return apply_to(target)


func apply_to(target: CanvasItem, color_override: String = "") -> bool:
    if not is_instance_valid(target):
        return fail("Не передан действительный CanvasItem.")
    var raw := color_override.strip_edges()
    if raw.is_empty():
        raw = str(get_option("tint_color", "#ffffff"))
    var color := Color.from_string(raw, Color.WHITE)
    if not raw.is_valid_html_color():
        return fail("Неверный цвет оттенка: %s" % raw)
    target.modulate = Color(color.r, color.g, color.b, target.modulate.a)
    action_completed.emit(color)
    return true
