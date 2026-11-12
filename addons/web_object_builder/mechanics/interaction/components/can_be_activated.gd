@tool
extends "res://addons/web_object_builder/mechanics/interaction/component.gd"

signal activated
signal deactivated

const STATE_KEY: StringName = &"object_builder_active_state"


func _on_configured() -> void:
    _load_options({"enabled": true, "start_active": false})


func activate() -> bool:
    if not _require_target() or not _is_enabled():
        return _fail("Активация недоступна.")
    if _read_shared_state(STATE_KEY, bool(get_option("start_active", false))):
        return _fail("Объект уже активирован.")
    _write_shared_state(STATE_KEY, true)
    activated.emit()
    state_changed.emit("active", true)
    action_completed.emit(true)
    return true


func deactivate() -> bool:
    if not _require_target() or not _is_enabled():
        return _fail("Деактивация недоступна.")
    if not _read_shared_state(STATE_KEY, bool(get_option("start_active", false))):
        return _fail("Объект уже деактивирован.")
    _write_shared_state(STATE_KEY, false)
    deactivated.emit()
    state_changed.emit("active", false)
    action_completed.emit(false)
    return true


func is_active() -> bool:
    return _read_shared_state(STATE_KEY, bool(get_option("start_active", false)))
