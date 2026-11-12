@tool
extends "res://addons/web_object_builder/mechanics/movement/components/motion_component.gd"

var _is_swimming := false


func _on_configured() -> void:
    _load_options({"swim_speed": 70.0, "requires_swimming_state": true})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "swim_speed":
        return float(value) >= 0.0 and float(value) <= 2000.0
    return true


func set_swimming(active: bool) -> void:
    _is_swimming = active
    state_changed.emit("is_swimming", _is_swimming)


func is_swimming() -> bool:
    return _is_swimming


func swim(direction: Vector2, delta: float) -> bool:
    if bool(get_option("requires_swimming_state", true)) and not _is_swimming:
        return _fail("Объект не находится в состоянии плавания.")
    return _run_directional_motion(direction, "swim_speed", delta)


func export_runtime_state() -> Dictionary:
    var state := super.export_runtime_state()
    state["is_swimming"] = _is_swimming
    return state


func import_runtime_state(state: Dictionary) -> bool:
    var copy := state.duplicate(true)
    var swimming := bool(copy.get("is_swimming", false))
    copy.erase("is_swimming")
    if not super.import_runtime_state(copy):
        return false
    set_swimming(swimming)
    return true
