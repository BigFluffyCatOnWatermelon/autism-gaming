@tool
extends "res://addons/object_builder/mechanics/movement/component.gd"

var _jump_tween: Tween


func _on_configured() -> void:
    _load_options({"jump_height": 48.0, "jump_duration": 0.45})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "jump_height":
        return float(value) >= 1.0 and float(value) <= 1000.0
    if key == "jump_duration":
        return float(value) >= 0.05 and float(value) <= 5.0
    return true


func jump() -> bool:
    if _target == null or not is_instance_valid(_target):
        return _fail("Сначала привяжите Node2D через bind_target().")
    if not _target.is_inside_tree():
        return _fail("Целевой объект должен находиться в SceneTree.")
    if _jump_tween != null and _jump_tween.is_running():
        return _fail("Прыжок уже выполняется.")
    var start_y := _target.position.y
    var height := float(get_option("jump_height", 48.0))
    var duration := float(get_option("jump_duration", 0.45))
    _jump_tween = _target.create_tween()
    _jump_tween.tween_property(_target, "position:y", start_y - height, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _jump_tween.tween_property(_target, "position:y", start_y, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    action_completed.emit({"height": height, "duration": duration})
    return true
