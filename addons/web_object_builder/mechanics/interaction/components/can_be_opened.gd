@tool
extends "res://addons/web_object_builder/mechanics/interaction/component.gd"

signal opened

const STATE_KEY: StringName = &"object_builder_open_state"


func _on_configured() -> void:
    _load_options({"enabled": true, "starts_open": false})


func open() -> bool:
    if not _require_target() or not _is_enabled():
        return _fail("Открытие недоступно.")
    if _read_shared_state(STATE_KEY, bool(get_option("starts_open", false))):
        return _fail("Объект уже открыт.")
    _write_shared_state(STATE_KEY, true)
    opened.emit()
    state_changed.emit("open", true)
    action_completed.emit(true)
    return true


func is_open() -> bool:
    return _read_shared_state(STATE_KEY, bool(get_option("starts_open", false)))
