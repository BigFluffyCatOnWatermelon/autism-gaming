@tool
extends "res://addons/web_object_builder/mechanics/interaction/component.gd"

signal toggled(new_state: bool)

const STATE_KEY: StringName = &"object_builder_toggle_state"


func _on_configured() -> void:
    _load_options({"enabled": true, "initial_state": false})


func toggle() -> bool:
    if not _require_target() or not _is_enabled():
        return _fail("Переключение состояния недоступно.")
    var next_state := not _read_shared_state(STATE_KEY, bool(get_option("initial_state", false)))
    _write_shared_state(STATE_KEY, next_state)
    toggled.emit(next_state)
    state_changed.emit("toggled", next_state)
    action_completed.emit(next_state)
    return true


func set_toggled(value: bool) -> bool:
    if not _require_target() or not _is_enabled():
        return _fail("Переключение состояния недоступно.")
    if typeof(value) != TYPE_BOOL:
        return _fail("Состояние должно быть Boolean.")
    _write_shared_state(STATE_KEY, value)
    toggled.emit(value)
    state_changed.emit("toggled", value)
    action_completed.emit(value)
    return true


func is_toggled() -> bool:
    return _read_shared_state(STATE_KEY, bool(get_option("initial_state", false)))
