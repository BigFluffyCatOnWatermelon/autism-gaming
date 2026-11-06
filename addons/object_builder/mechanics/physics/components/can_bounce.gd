@tool
extends "res://addons/object_builder/mechanics/physics/component.gd"

var _material: PhysicsMaterial


func _on_configured() -> void:
    _load_options({"bounce": 0.65, "friction": 0.2})


func _validate_option(key: String, value: Variant) -> bool:
    if key in ["bounce", "friction"]:
        return float(value) >= 0.0 and float(value) <= 1.0
    return true


func bind_target(target: Node) -> bool:
    if not super.bind_target(target):
        return false
    if not (target is StaticBody2D or target is RigidBody2D):
        return _fail("Отскок требует StaticBody2D или RigidBody2D.")
    _copy_or_create_material()
    return set_bounce(float(get_option("bounce", 0.65)))


func _copy_or_create_material() -> void:
    var existing := _target.get("physics_material_override") as PhysicsMaterial
    _material = existing.duplicate(true) as PhysicsMaterial if existing != null else PhysicsMaterial.new()
    _target.set("physics_material_override", _material)


func set_bounce(value: float) -> bool:
    if not _require_target():
        return false
    if not (_target is StaticBody2D or _target is RigidBody2D) or not is_finite(value) or value < 0.0 or value > 1.0:
        return _fail("Коэффициент отскока должен быть от 0 до 1, цель — StaticBody2D или RigidBody2D.")
    if _material == null:
        _copy_or_create_material()
    _material.bounce = value
    _material.friction = float(get_option("friction", 0.2))
    _runtime_options["bounce"] = value
    state_changed.emit("bounce", value)
    action_completed.emit(value)
    return true
