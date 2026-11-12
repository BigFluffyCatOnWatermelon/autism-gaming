@tool
extends "res://addons/web_object_builder/mechanics/physics/component.gd"


func _on_configured() -> void:
    _load_options({"push_impulse": 160.0, "mass_floor": 0.1})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "push_impulse":
        return float(value) >= 0.0 and float(value) <= 100000.0
    if key == "mass_floor":
        return float(value) >= 0.01 and float(value) <= 1000.0
    return true


func push(direction: Vector2, strength_scale: float = 1.0) -> bool:
    if not _require_target():
        return false
    if not is_finite(direction.x) or not is_finite(direction.y) or direction.is_zero_approx():
        return _fail("Для толчка требуется ненулевое конечное направление.")
    if not is_finite(strength_scale) or strength_scale < 0.0 or strength_scale > 100.0:
        return _fail("Множитель силы должен находиться в диапазоне 0–100.")
    var impulse := direction.normalized() * float(get_option("push_impulse", 160.0)) * strength_scale
    if _target is RigidBody2D:
        var body := _target as RigidBody2D
        if body.freeze:
            return _fail("Нельзя толкнуть замороженное физическое тело.")
        body.apply_central_impulse(impulse)
    elif _target is CharacterBody2D:
        var body := _target as CharacterBody2D
        body.velocity += impulse / maxf(float(get_option("mass_floor", 0.1)), 0.1)
    else:
        return _fail("Толчок поддерживается для RigidBody2D или CharacterBody2D.")
    action_completed.emit(impulse)
    return true
