@tool
extends "res://addons/web_object_builder/mechanics/physics/component.gd"

var _material: PhysicsMaterial
var _original_friction := 1.0


func _on_configured() -> void:
    _load_options({"sliding_friction": 0.05, "normal_friction": 1.0})


func _validate_option(key: String, value: Variant) -> bool:
    if key in ["sliding_friction", "normal_friction"]:
        return float(value) >= 0.0 and float(value) <= 1.0
    return true


func bind_target(target: Node) -> bool:
    if not super.bind_target(target):
        return false
    if not (target is StaticBody2D or target is RigidBody2D):
        return _fail("Скольжение через PhysicsMaterial требует StaticBody2D или RigidBody2D.")
    var existing := _target.get("physics_material_override") as PhysicsMaterial
    _material = existing.duplicate(true) as PhysicsMaterial if existing != null else PhysicsMaterial.new()
    _original_friction = _material.friction
    _target.set("physics_material_override", _material)
    return set_sliding(false)


func set_sliding(value: bool) -> bool:
    if not _require_target():
        return false
    if not (_target is StaticBody2D or _target is RigidBody2D):
        return _fail("Целевой узел должен быть StaticBody2D или RigidBody2D.")
    if typeof(value) != TYPE_BOOL:
        return _fail("Состояние скольжения должно быть Boolean.")
    if _material == null:
        _material = PhysicsMaterial.new()
        _target.set("physics_material_override", _material)
    _material.friction = float(get_option("sliding_friction", 0.05)) if value else float(get_option("normal_friction", _original_friction))
    _runtime_options["sliding_enabled"] = value
    state_changed.emit("sliding_enabled", value)
    action_completed.emit(value)
    return true
