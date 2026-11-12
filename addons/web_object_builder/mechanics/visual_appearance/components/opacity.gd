@tool
extends "res://addons/web_object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"opacity": 1.0})
    set_option("opacity", clampf(float(get_option("opacity", 1.0)), 0.0, 1.0))


func apply_to(target: CanvasItem, value: float = -1.0) -> bool:
    if not is_instance_valid(target):
        return fail("Не передан действительный CanvasItem.")
    var alpha := value if value >= 0.0 else float(get_option("opacity", 1.0))
    if alpha < 0.0 or alpha > 1.0:
        return fail("Прозрачность должна находиться в диапазоне 0–1.")
    var current := target.modulate
    target.modulate = Color(current.r, current.g, current.b, alpha)
    set_option("opacity", alpha)
    action_completed.emit(alpha)
    return true
