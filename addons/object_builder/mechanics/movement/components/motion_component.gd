@tool
extends "res://addons/object_builder/mechanics/movement/component.gd"


func _run_directional_motion(direction: Vector2, speed_key: String, delta: float) -> bool:
    var speed := float(get_option(speed_key, 0.0))
    return _apply_motion(direction, speed, delta)
