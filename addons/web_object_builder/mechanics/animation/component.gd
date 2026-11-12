@tool
extends ObjectComponent

signal state_changed(key: String, new_value: Variant)
signal action_completed(result: Variant)
signal action_failed(reason: String)

var _runtime_options: Dictionary = {}


func _load_options(defaults: Dictionary) -> void:
    _runtime_options.clear()
    for key in defaults:
        _runtime_options[str(key)] = get_setting(str(key), defaults[key])


func configure_mechanic(values: Dictionary) -> bool:
    for key in values:
        var name := str(key)
        if not _runtime_options.has(name):
            return _fail("Неизвестная настройка: %s" % name)
        if typeof(values[key]) != typeof(_runtime_options[name]):
            return _fail("Неверный тип настройки: %s" % name)
        if not _validate_option(name, values[key]):
            return _fail("Недопустимое значение настройки: %s" % name)
    for key in values:
        var name := str(key)
        _runtime_options[name] = values[key]
        state_changed.emit(name, values[key])
    action_completed.emit(export_runtime_state())
    return true


func _validate_option(_key: String, _value: Variant) -> bool:
    return true


func get_option(key: String, fallback: Variant = null) -> Variant:
    return _runtime_options.get(key, fallback)


func set_option(key: String, value: Variant) -> bool:
    var update: Dictionary = {}
    update[key] = value
    return configure_mechanic(update)


func export_runtime_state() -> Dictionary:
    return _runtime_options.duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
    return configure_mechanic(state)


func _fail(reason: String) -> bool:
    action_failed.emit(reason)
    return false
