@tool
extends "res://addons/web_object_builder/mechanics/interaction/component.gd"

signal hold_progress_changed(progress: float)
signal hold_completed(interactor: Node)

var _holding := false
var _hold_elapsed := 0.0
var _holder: Node


func _on_configured() -> void:
    _load_options({"hold_duration": 1.0, "enabled": true})


func _validate_option(key: String, value: Variant) -> bool:
    return key != "hold_duration" or (float(value) >= 0.05 and float(value) <= 120.0)


func begin_hold(interactor: Node) -> bool:
    if not _require_target() or not _is_enabled():
        return _fail("Удержание взаимодействия недоступно.")
    if interactor == null or not is_instance_valid(interactor):
        return _fail("Не передан инициатор удержания.")
    if _holding:
        return _fail("Удержание уже выполняется.")
    _holding = true
    _hold_elapsed = 0.0
    _holder = interactor
    state_changed.emit("holding", true)
    hold_progress_changed.emit(0.0)
    action_completed.emit("started")
    return true


func advance_hold(delta: float) -> bool:
    if not _holding:
        return _fail("Удержание ещё не начато.")
    if not is_finite(delta) or delta <= 0.0 or delta > 10.0:
        return _fail("Шаг времени должен быть в диапазоне (0; 10].")
    if _holder == null or not is_instance_valid(_holder):
        cancel_hold()
        return _fail("Инициатор взаимодействия больше не существует.")
    _hold_elapsed = minf(_hold_elapsed + delta, float(get_option("hold_duration", 1.0)))
    var progress := _hold_elapsed / float(get_option("hold_duration", 1.0))
    hold_progress_changed.emit(progress)
    if progress >= 1.0:
        _holding = false
        hold_completed.emit(_holder)
        state_changed.emit("holding", false)
        action_completed.emit("completed")
        _holder = null
    return true


func cancel_hold() -> bool:
    if not _holding:
        return false
    _holding = false
    _hold_elapsed = 0.0
    _holder = null
    hold_progress_changed.emit(0.0)
    state_changed.emit("holding", false)
    return true


func get_hold_progress() -> float:
    if not _holding:
        return 0.0
    return clampf(_hold_elapsed / float(get_option("hold_duration", 1.0)), 0.0, 1.0)


func is_holding() -> bool:
    return _holding
