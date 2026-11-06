@tool
extends "res://addons/object_builder/mechanics/interaction/component.gd"

signal interaction_requested(interactor: Node)


func _on_configured() -> void:
    _load_options({"enabled": true})


func request_interaction(interactor: Node) -> bool:
    if not _require_target():
        return false
    if not _is_enabled():
        return _fail("Взаимодействие отключено.")
    if interactor == null or not is_instance_valid(interactor):
        return _fail("Не передан действующий инициатор взаимодействия.")
    interaction_requested.emit(interactor)
    action_completed.emit(interactor)
    return true
