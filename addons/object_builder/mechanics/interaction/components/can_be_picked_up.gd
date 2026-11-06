@tool
extends "res://addons/object_builder/mechanics/interaction/component.gd"

signal pickup_requested(interactor: Node, item: Node2D)

var _pickup_pending := false
var _picked_up := false


func _on_configured() -> void:
    _load_options({"enabled": true, "one_time_pickup": true})


func pickup(interactor: Node) -> bool:
    if not _require_target():
        return false
    if not _is_enabled():
        return _fail("Подбор отключён.")
    if interactor == null or not is_instance_valid(interactor):
        return _fail("Не передан инициатор подбора.")
    if _pickup_pending:
        return _fail("Запрос подбора уже ожидает подтверждения.")
    if _picked_up and bool(get_option("one_time_pickup", true)):
        return _fail("Предмет уже был подобран.")
    _pickup_pending = true
    pickup_requested.emit(interactor, _target)
    action_completed.emit("pickup_requested")
    return true


func confirm_pickup(accepted: bool) -> bool:
    if not _pickup_pending:
        return _fail("Нет ожидающего запроса подбора.")
    _pickup_pending = false
    if accepted:
        _picked_up = true
        state_changed.emit("picked_up", true)
        action_completed.emit("picked_up")
    else:
        action_completed.emit("pickup_rejected")
    return true


func is_pickup_pending() -> bool:
    return _pickup_pending


func is_picked_up() -> bool:
    return _picked_up
