@tool
extends "res://addons/object_builder/mechanics/physics/component.gd"

var _material: PhysicsMaterial


func _on_configured() -> void:
    _load_options({"friction": 0.6, "bounce": 0.0, "rough": false, "absorbent": false})


func _validate_option(key: String, value: Variant) -> bool:
    if key in ["friction", "bounce"]:
        return float(value) >= 0.0 and float(value) <= 1.0
    return true


func bind_target(target: Node) -> bool:
    if not super.bind_target(target):
        return false
    if not (target is StaticBody2D or target is RigidBody2D):
        return _fail("Материал физики требует StaticBody2D или RigidBody2D.")
    var existing := _target.get("physics_material_override") as PhysicsMaterial
    _material = existing.duplicate(true) as PhysicsMaterial if existing != null else PhysicsMaterial.new()
    _target.set("physics_material_override", _material)
    return apply_material()


func apply_material() -> bool:
    if not _require_target():
        return false
    if not (_target is StaticBody2D or _target is RigidBody2D):
        return _fail("Целевой узел должен быть StaticBody2D или RigidBody2D.")
    if _material == null:
        _material = PhysicsMaterial.new()
        _target.set("physics_material_override", _material)
    _material.friction = float(get_option("friction", 0.6))
    _material.bounce = float(get_option("bounce", 0.0))
    _material.rough = bool(get_option("rough", false))
    _material.absorbent = bool(get_option("absorbent", false))
    action_completed.emit({"friction": _material.friction, "bounce": _material.bounce})
    return true
