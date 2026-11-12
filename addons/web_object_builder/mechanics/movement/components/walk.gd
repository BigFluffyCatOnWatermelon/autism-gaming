@tool
extends "res://addons/web_object_builder/mechanics/movement/components/motion_component.gd"

func _on_configured() -> void:
    _load_options({"walk_speed": 80.0})

func _validate_option(name: String, value: Variant) -> bool:
    if name == "walk_speed":
        return float(value) >= 0.0 and float(value) <= 2000.0
    return true

func walk(direction: Vector2, delta: float) -> bool:
    return _run_directional_motion(direction, "walk_speed", delta)
