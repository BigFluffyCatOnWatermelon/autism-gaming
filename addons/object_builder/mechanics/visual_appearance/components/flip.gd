@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"flip_horizontal": false, "flip_vertical": false})


func apply_to(sprite: Sprite2D, horizontal: bool = true, vertical: bool = false) -> bool:
    if not is_instance_valid(sprite):
        return fail("Не передан действительный Sprite2D.")
    sprite.flip_h = horizontal
    sprite.flip_v = vertical
    set_option("flip_horizontal", horizontal)
    set_option("flip_vertical", vertical)
    action_completed.emit({"horizontal": horizontal, "vertical": vertical})
    return true
