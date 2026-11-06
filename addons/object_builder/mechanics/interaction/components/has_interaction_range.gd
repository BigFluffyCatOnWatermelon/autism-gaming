@tool
extends "res://addons/object_builder/mechanics/interaction/component.gd"


func _on_configured() -> void:
    _load_options({"interaction_range": 96.0})


func _validate_option(key: String, value: Variant) -> bool:
    return key != "interaction_range" or (float(value) >= 0.0 and float(value) <= 100000.0)


func is_within_range(interactor: Node2D) -> bool:
    if not _require_target():
        return false
    if interactor == null or not is_instance_valid(interactor):
        _fail("Не передан действующий инициатор взаимодействия.")
        return false
    return _target.global_position.distance_to(interactor.global_position) <= float(get_option("interaction_range", 96.0))


func require_in_range(interactor: Node2D) -> bool:
    if not is_within_range(interactor):
        return _fail("Объект находится за пределами радиуса взаимодействия.")
    action_completed.emit(true)
    return true
