@tool
extends "res://addons/object_builder/mechanics/physics/component.gd"


func _on_configured() -> void:
    _load_options({"gravity_scale": 1.0})


func _validate_option(key: String, value: Variant) -> bool:
    return key != "gravity_scale" or (float(value) >= -100.0 and float(value) <= 100.0)


func bind_target(target: Node) -> bool:
    if not super.bind_target(target):
        return false
    if not target is RigidBody2D:
        return _fail("Масштаб гравитации поддерживается для RigidBody2D.")
    return set_gravity_scale(float(get_option("gravity_scale", 1.0)))


func set_gravity_scale(value: float) -> bool:
    if not _require_target():
        return false
    if not _target is RigidBody2D:
        return _fail("Целевой узел должен быть RigidBody2D.")
    if not is_finite(value) or value < -100.0 or value > 100.0:
        return _fail("Масштаб гравитации должен быть в диапазоне -100–100.")
    (_target as RigidBody2D).gravity_scale = value
    _runtime_options["gravity_scale"] = value
    state_changed.emit("gravity_scale", value)
    action_completed.emit(value)
    return true
