@tool
extends "res://addons/web_object_builder/mechanics/interaction/component.gd"

signal closed

const STATE_KEY: StringName = &"object_builder_open_state"


func _on_configured() -> void:
    _load_options({"enabled": true, "starts_open": false})


func close() -> bool:
    if not _require_target() or not _is_enabled():
        return _fail("Закрытие недоступно.")
    if not _read_shared_state(STATE_KEY, bool(get_option("starts_open", false))):
        return _fail("Объект уже закрыт.")
    _write_shared_state(STATE_KEY, false)
    closed.emit()
    state_changed.emit("open", false)
    action_completed.emit(false)
    return true


func is_open() -> bool:
    return _read_shared_state(STATE_KEY, bool(get_option("starts_open", false)))
