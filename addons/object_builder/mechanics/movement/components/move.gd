@tool
extends "res://addons/object_builder/mechanics/movement/components/motion_component.gd"

func _on_configured() -> void:
    _load_options({"move_speed": 120.0})

func _validate_option(name: String, value: Variant) -> bool:
    if name == "move_speed":
        return float(value) >= 0.0 and float(value) <= 2000.0
    return true

func move_direction(direction: Vector2, delta: float) -> bool:
    return _run_directional_motion(direction, "move_speed", delta)
