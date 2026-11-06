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


func bind_target(target: Node2D) -> bool:
    if target == null or not is_instance_valid(target):
        return _fail("Не передан действующий Node2D.")
    _target = target
    return true


func _apply_motion(direction: Vector2, speed: float, delta: float) -> bool:
    if _target == null or not is_instance_valid(_target):
        return _fail("Сначала привяжите Node2D через bind_target().")
    if not is_finite(direction.x) or not is_finite(direction.y):
        return _fail("Направление движения содержит некорректное число.")
    if not is_finite(delta) or delta <= 0.0:
        return _fail("Шаг времени должен быть положительным конечным числом.")
    if not is_finite(speed) or speed < 0.0:
        return _fail("Скорость должна быть неотрицательным конечным числом.")
    var normalized := direction.normalized()
    if normalized == Vector2.ZERO or speed == 0.0:
        action_completed.emit(Vector2.ZERO)
        return true
    var actual_displacement := normalized * speed * delta
    if _target is CharacterBody2D:
        if not Engine.is_in_physics_frame():
            return _fail("Для CharacterBody2D движение нужно вызывать из _physics_process().")
        var body := _target as CharacterBody2D
        var previous_position := body.global_position
        body.velocity = normalized * speed
        body.move_and_slide()
        actual_displacement = body.global_position - previous_position
    else:
        _target.global_position += actual_displacement
    action_completed.emit(actual_displacement)
    return true


func _fail(reason: String) -> bool:
    action_failed.emit(reason)
    return false
