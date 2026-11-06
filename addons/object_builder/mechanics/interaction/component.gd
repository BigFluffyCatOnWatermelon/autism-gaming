@tool
extends ObjectComponent

signal state_changed(key: String, new_value: Variant)
signal action_completed(result: Variant)
signal action_failed(reason: String)

var _runtime_options: Dictionary = {}
var _target: Node2D


func _load_options(defaults: Dictionary) -> void:
    _runtime_options.clear()
    for key in defaults:
        _runtime_options[str(key)] = get_setting(str(key), defaults[key])


func configure_mechanic(values: Dictionary) -> bool:
    for raw_key in values:
        var key := str(raw_key)
        if not _runtime_options.has(key):
            return _fail("Неизвестная настройка: %s" % key)
        if typeof(values[raw_key]) != typeof(_runtime_options[key]):
            return _fail("Неверный тип настройки: %s" % key)
        if not _validate_option(key, values[raw_key]):
            return _fail("Недопустимое значение настройки: %s" % key)
    for raw_key in values:
        var key := str(raw_key)
        _runtime_options[key] = values[raw_key]
        state_changed.emit(key, values[raw_key])
    action_completed.emit(export_runtime_state())
    return true


func _validate_option(_key: String, _value: Variant) -> bool:
    return true


func get_option(key: String, fallback: Variant = null) -> Variant:
    return _runtime_options.get(key, fallback)


func export_runtime_state() -> Dictionary:
    return _runtime_options.duplicate(true)


func bind_target(target: Node2D) -> bool:
    if target == null or not is_instance_valid(target):
        return _fail("Не передан действующий Node2D.")
    _target = target
    return true


func _require_target() -> bool:
    if _target == null or not is_instance_valid(_target):
        return _fail("Сначала привяжите целевой Node2D через bind_target().")
    return true


func _is_enabled() -> bool:
    return bool(get_option("enabled", true))


func _read_shared_state(meta_key: StringName, fallback: bool) -> bool:
    if not _require_target():
        return fallback
    return bool(_target.get_meta(meta_key, fallback))


func _write_shared_state(meta_key: StringName, value: bool) -> void:
    if _target != null and is_instance_valid(_target):
        _target.set_meta(meta_key, value)


func _fail(reason: String) -> bool:
    action_failed.emit(reason)
    return false
