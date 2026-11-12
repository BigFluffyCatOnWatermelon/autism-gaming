@tool
extends "res://addons/web_object_builder/mechanics/physics/component.gd"


func _on_configured() -> void:
    _load_options({"pull_impulse": 120.0, "maximum_distance": 1200.0})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "pull_impulse":
        return float(value) >= 0.0 and float(value) <= 100000.0
    if key == "maximum_distance":
        return float(value) >= 0.0 and float(value) <= 100000.0
    return true


func pull_towards(source: Node2D, strength_scale: float = 1.0) -> bool:
    if not _require_target():
        return false
    if source == null or not is_instance_valid(source):
        return _fail("Не передан действующий источник притяжения.")
    if not _target is Node2D:
        return _fail("Целевой узел должен быть Node2D.")
    if not is_finite(strength_scale) or strength_scale < 0.0 or strength_scale > 100.0:
        return _fail("Множитель силы должен находиться в диапазоне 0–100.")
    var target_2d := _target as Node2D
    var offset := source.global_position - target_2d.global_position
    if offset.is_zero_approx():
        action_completed.emit(Vector2.ZERO)
        return true
    var limit := float(get_option("maximum_distance", 1200.0))
    if limit > 0.0 and offset.length() > limit:
        return _fail("Источник находится за пределами дальности притяжения.")
    var impulse := offset.normalized() * float(get_option("pull_impulse", 120.0)) * strength_scale
    if _target is RigidBody2D:
        var body := _target as RigidBody2D
        if body.freeze:
            return _fail("Нельзя притянуть замороженное физическое тело.")
        body.apply_central_impulse(impulse)
    elif _target is CharacterBody2D:
        var body := _target as CharacterBody2D
        body.velocity += impulse
    else:
        return _fail("Притяжение поддерживается для RigidBody2D или CharacterBody2D.")
    action_completed.emit(impulse)
    return true
