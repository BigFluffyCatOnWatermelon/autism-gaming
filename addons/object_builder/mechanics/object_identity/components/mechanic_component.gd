@tool
extends ObjectComponent

signal state_changed(key: String, new_value: Variant)
signal action_completed(result: Variant)
signal action_failed(reason: String)

var _runtime_options: Dictionary = {}


func _load_options(defaults: Dictionary) -> void:
    _runtime_options.clear()
    for key in defaults:
        _runtime_options[key] = get_setting(str(key), defaults[key])


func configure_mechanic(values: Dictionary) -> bool:
    for key in values:
        var name := str(key)
        if not _runtime_options.has(name):
            action_failed.emit("Неизвестная настройка: %s" % name)
            return false
        if typeof(values[key]) != typeof(_runtime_options[name]):
            action_failed.emit("Неверный тип настройки: %s" % name)
            return false

    for key in values:
        _runtime_options[str(key)] = values[key]
        state_changed.emit(str(key), values[key])
    action_completed.emit(export_runtime_state())
    return true


func get_option(key: String, fallback: Variant = null) -> Variant:
    return _runtime_options.get(key, fallback)


func set_option(key: String, value: Variant) -> bool:
    if not _runtime_options.has(key):
        action_failed.emit("Неизвестная настройка: %s" % key)
        return false
    if typeof(value) != typeof(_runtime_options[key]):
        action_failed.emit("Неверный тип настройки: %s" % key)
        return false
    _runtime_options[key] = value
    state_changed.emit(key, value)
    return true


func export_runtime_state() -> Dictionary:
    return _runtime_options.duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
    return configure_mechanic(state)


func get_shared_enabled_state(fallback: bool) -> bool:
    var root := get_object_root()
    return bool(root.get_meta("object_builder_enabled_state", fallback)) if root != null else fallback


func set_shared_enabled_state(value: bool) -> void:
    var root := get_object_root()
    if root != null:
        root.set_meta("object_builder_enabled_state", value)


func fail(reason: String) -> bool:
    action_failed.emit(reason)
    return false
