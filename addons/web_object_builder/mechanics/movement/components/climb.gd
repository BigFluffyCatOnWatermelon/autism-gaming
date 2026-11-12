@tool
extends "res://addons/web_object_builder/mechanics/movement/components/motion_component.gd"


func _on_configured() -> void:
    _load_options({"climb_speed": 80.0})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "climb_speed":
        return float(value) >= 0.0 and float(value) <= 2000.0
    return true


func climb(vertical_input: float, delta: float) -> bool:
    if not is_finite(vertical_input):
        return _fail("Величина вертикального ввода некорректна.")
    var direction := Vector2(0.0, clampf(vertical_input, -1.0, 1.0))
    return _run_directional_motion(direction, "climb_speed", delta)
