@tool
extends "res://addons/object_builder/mechanics/physics/component.gd"


func _on_configured() -> void:
    _load_options({"angular_speed": 5.0, "maximum_angular_speed": 20.0})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "angular_speed":
        return float(value) >= 0.0 and float(value) <= 100.0
    if key == "maximum_angular_speed":
        return float(value) >= 0.0 and float(value) <= 200.0
    return true


func roll(direction: float = 1.0) -> bool:
    if not _require_target():
        return false
    if not _target is RigidBody2D:
        return _fail("Качение поддерживается для RigidBody2D.")
    if not is_finite(direction) or is_zero_approx(direction):
        return _fail("Направление вращения должно быть конечным и ненулевым.")
    var body := _target as RigidBody2D
    if body.freeze:
        return _fail("Нельзя вращать замороженное физическое тело.")
    var speed := float(get_option("angular_speed", 5.0)) * signf(direction)
    var cap := float(get_option("maximum_angular_speed", 20.0))
    body.angular_velocity = clampf(speed, -cap, cap)
    action_completed.emit(body.angular_velocity)
    return true
