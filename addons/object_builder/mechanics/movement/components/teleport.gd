@tool
extends "res://addons/object_builder/mechanics/movement/component.gd"


func _on_configured() -> void:
    _load_options({"max_range": 0.0})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "max_range":
        return float(value) >= 0.0 and float(value) <= 100000.0
    return true


func teleport_to(destination: Vector2) -> bool:
    if _target == null or not is_instance_valid(_target):
        return _fail("Сначала привяжите Node2D через bind_target().")
    if not is_finite(destination.x) or not is_finite(destination.y):
        return _fail("Координаты телепортации должны быть конечными числами.")
    var max_range := float(get_option("max_range", 0.0))
    if max_range > 0.0 and _target.global_position.distance_to(destination) > max_range:
        return _fail("Точка телепортации находится за пределами допустимого радиуса.")
    _target.global_position = destination
    action_completed.emit(destination)
    return true
