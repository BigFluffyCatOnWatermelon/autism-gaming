@tool
extends "res://addons/web_object_builder/mechanics/movement/component.gd"


func move_direction_with_speed(direction: Vector2, speed: float, delta: float) -> bool:
    return _apply_motion(direction, speed, delta)


func _run_directional_motion(direction: Vector2, speed_key: String, delta: float) -> bool:
    var speed := float(get_option(speed_key, 0.0))
    return _apply_motion(direction, speed, delta)
