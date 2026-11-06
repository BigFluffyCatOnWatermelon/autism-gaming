@tool
extends "res://addons/object_builder/mechanics/physics/component.gd"

var _shape_states: Dictionary = {}


func _on_configured() -> void:
    _load_options({"collision_enabled": true})


func bind_target(target: Node) -> bool:
    if not super.bind_target(target):
        return false
    _shape_states.clear()
    _collect_shapes(target)
    if _shape_states.is_empty():
        return _fail("В целевом узле не найдены CollisionShape2D или CollisionPolygon2D.")
    return set_collision_enabled(bool(get_option("collision_enabled", true)))


func _collect_shapes(node: Node) -> void:
    for child in node.get_children():
        if child is CollisionShape2D or child is CollisionPolygon2D:
            _shape_states[child] = bool(child.disabled)
        _collect_shapes(child)


func set_collision_enabled(value: bool) -> bool:
    if not _require_target():
        return false
    if typeof(value) != TYPE_BOOL:
        return _fail("Состояние коллизии должно быть Boolean.")
    if _shape_states.is_empty():
        return _fail("Не найдены формы коллизии.")
    for shape in _shape_states:
        if is_instance_valid(shape):
            shape.set_deferred("disabled", not value)
    _runtime_options["collision_enabled"] = value
    state_changed.emit("collision_enabled", value)
    action_completed.emit(value)
    return true


func is_collision_enabled() -> bool:
    return bool(get_option("collision_enabled", true))
