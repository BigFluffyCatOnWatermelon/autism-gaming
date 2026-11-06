@tool
extends "res://addons/object_builder/mechanics/movement/component.gd"

var _dash_tween: Tween
var _last_dash_msec: int = -1


func _on_configured() -> void:
    _load_options({"dash_distance": 96.0, "dash_duration": 0.18, "cooldown_seconds": 0.6})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "dash_distance":
        return float(value) >= 1.0 and float(value) <= 2000.0
    if key == "dash_duration":
        return float(value) >= 0.03 and float(value) <= 2.0
    if key == "cooldown_seconds":
        return float(value) >= 0.0 and float(value) <= 60.0
    return true


func dash(direction: Vector2) -> bool:
    if _target == null or not is_instance_valid(_target):
        return _fail("Сначала привяжите Node2D через bind_target().")
    if not _target.is_inside_tree():
        return _fail("Целевой объект должен находиться в SceneTree.")
    if not is_finite(direction.x) or not is_finite(direction.y) or direction == Vector2.ZERO:
        return _fail("Для рывка требуется ненулевое конечное направление.")
    if _dash_tween != null and _dash_tween.is_running():
        return _fail("Рывок уже выполняется.")
    var now := Time.get_ticks_msec()
    var cooldown_msec := int(float(get_option("cooldown_seconds", 0.6)) * 1000.0)
    if _last_dash_msec >= 0 and now - _last_dash_msec < cooldown_msec:
        return _fail("Рывок ещё перезаряжается.")
    var destination := _target.global_position + direction.normalized() * float(get_option("dash_distance", 96.0))
    _last_dash_msec = now
    _dash_tween = _target.create_tween()
    _dash_tween.tween_property(_target, "global_position", destination, float(get_option("dash_duration", 0.18))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    action_completed.emit(destination)
    return true
