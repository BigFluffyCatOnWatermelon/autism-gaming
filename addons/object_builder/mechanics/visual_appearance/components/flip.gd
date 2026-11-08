@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"flip_horizontal": false, "flip_vertical": false})


func apply_to(sprite: Sprite2D, horizontal: Variant = null, vertical: Variant = null) -> bool:
    if not is_instance_valid(sprite):
        return fail("Не передан действительный Sprite2D.")
    if (horizontal != null and typeof(horizontal) != TYPE_BOOL) or (vertical != null and typeof(vertical) != TYPE_BOOL):
        return fail("Параметры отражения должны быть Boolean.")
    var resolved_horizontal := bool(get_option("flip_horizontal", false)) if horizontal == null else bool(horizontal)
    var resolved_vertical := bool(get_option("flip_vertical", false)) if vertical == null else bool(vertical)
    sprite.flip_h = resolved_horizontal
    sprite.flip_v = resolved_vertical
    set_option("flip_horizontal", resolved_horizontal)
    set_option("flip_vertical", resolved_vertical)
    action_completed.emit({"horizontal": resolved_horizontal, "vertical": resolved_vertical})
    return true
