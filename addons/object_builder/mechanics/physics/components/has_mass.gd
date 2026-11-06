@tool
extends "res://addons/object_builder/mechanics/physics/component.gd"


func _on_configured() -> void:
    _load_options({"mass": 1.0})


func _validate_option(key: String, value: Variant) -> bool:
    return key != "mass" or (float(value) >= 0.01 and float(value) <= 1000000.0)


func bind_target(target: Node) -> bool:
    if not super.bind_target(target):
        return false
    if not target is RigidBody2D:
        return _fail("Масса через это свойство поддерживается для RigidBody2D.")
    return set_mass(float(get_option("mass", 1.0)))


func set_mass(value: float) -> bool:
    if not _require_target():
        return false
    if not _target is RigidBody2D:
        return _fail("Целевой узел должен быть RigidBody2D.")
    if not is_finite(value) or value < 0.01 or value > 1000000.0:
        return _fail("Масса должна быть в диапазоне 0.01–1000000.")
    (_target as RigidBody2D).mass = value
    _runtime_options["mass"] = value
    state_changed.emit("mass", value)
    action_completed.emit(value)
    return true
