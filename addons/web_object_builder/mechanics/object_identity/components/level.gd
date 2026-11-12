@tool
extends "res://addons/web_object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"initial_level": 1})
    set_option("initial_level", clampi(int(get_option("initial_level", 1)), 1, 999))


func get_level() -> int:
    return int(get_option("initial_level", 1))


func set_level(value: int) -> bool:
    if value < 1 or value > 999:
        return fail("Уровень должен находиться в диапазоне 1–999.")
    return set_option("initial_level", value)
