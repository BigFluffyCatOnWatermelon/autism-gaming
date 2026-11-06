@tool
extends "res://addons/object_builder/mechanics/interaction/component.gd"

signal used(user: Node)

var _use_count := 0


func _on_configured() -> void:
    _load_options({"enabled": true, "maximum_uses": 0})


func _validate_option(key: String, value: Variant) -> bool:
    return key != "maximum_uses" or (int(value) >= 0 and int(value) <= 1000000)


func use(user: Node) -> bool:
    if not _require_target():
        return false
    if not _is_enabled():
        return _fail("Использование отключено.")
    if user == null or not is_instance_valid(user):
        return _fail("Не передан пользователь.")
    var maximum := int(get_option("maximum_uses", 0))
    if maximum > 0 and _use_count >= maximum:
        return _fail("Исчерпано количество применений.")
    _use_count += 1
    used.emit(user)
    state_changed.emit("use_count", _use_count)
    action_completed.emit(_use_count)
    return true


func reset_uses() -> void:
    _use_count = 0
    state_changed.emit("use_count", _use_count)


func get_use_count() -> int:
    return _use_count
