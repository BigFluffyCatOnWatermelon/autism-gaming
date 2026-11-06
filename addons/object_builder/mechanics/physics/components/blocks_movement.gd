@tool
extends "res://addons/object_builder/mechanics/physics/component.gd"

func _on_configured() -> void:
    _load_options({"blocking_enabled": true, "collision_layer_bit": 1})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "collision_layer_bit":
        return int(value) >= 1 and int(value) <= 32
    return true


func bind_target(target: Node) -> bool:
    if not super.bind_target(target):
        return false
    if not target is CollisionObject2D:
        return _fail("Для блокировки движения нужен CollisionObject2D.")
    return set_blocking(bool(get_option("blocking_enabled", true)))


func set_blocking(value: bool) -> bool:
    if not _require_target():
        return false
    if not _target is CollisionObject2D:
        return _fail("Целевой узел больше не является CollisionObject2D.")
    if typeof(value) != TYPE_BOOL:
        return _fail("Состояние блокировки должно быть Boolean.")
    var body := _target as CollisionObject2D
    body.set_collision_layer_value(int(get_option("collision_layer_bit", 1)), value)
    _runtime_options["blocking_enabled"] = value
    state_changed.emit("blocking_enabled", value)
    action_completed.emit(value)
    return true


func is_blocking() -> bool:
    return bool(get_option("blocking_enabled", true))
