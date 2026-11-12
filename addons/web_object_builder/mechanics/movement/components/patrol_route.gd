@tool
extends "res://addons/web_object_builder/mechanics/movement/component.gd"

signal patrol_point_reached(index: int, position: Vector2)
signal patrol_finished

var _route: Array[Vector2] = []
var _route_index := 0
var _patrolling := false


func _on_configured() -> void:
    _load_options({"route_json": "[[0,0],[128,0],[128,128]]", "patrol_speed": 60.0, "loop_route": true})
    _parse_route()


func _validate_option(key: String, value: Variant) -> bool:
    if key == "patrol_speed":
        return float(value) >= 0.0 and float(value) <= 2000.0
    return true


func configure_mechanic(values: Dictionary) -> bool:
    if values.has("route_json") and not _is_valid_route(str(values["route_json"])):
        return _fail("Неверный JSON-маршрут: ожидается непустой массив пар конечных координат.")
    if not super.configure_mechanic(values):
        return false
    if values.has("route_json"):
        return _parse_route()
    return true


func _is_valid_route(raw: String) -> bool:
    var parser := JSON.new()
    if parser.parse(raw) != OK:
        return false
    var parsed: Variant = parser.data
    if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
        return false
    for point in parsed:
        if typeof(point) != TYPE_ARRAY or point.size() != 2:
            return false
        if (typeof(point[0]) != TYPE_INT and typeof(point[0]) != TYPE_FLOAT) or (typeof(point[1]) != TYPE_INT and typeof(point[1]) != TYPE_FLOAT):
            return false
        if not is_finite(float(point[0])) or not is_finite(float(point[1])):
            return false
    return true


func _parse_route() -> bool:
    var parser := JSON.new()
    var parse_error := parser.parse(str(get_option("route_json", "[]")))
    if parse_error != OK:
        return _fail("Не удалось разобрать JSON-маршрут: " + parser.get_error_message())
    var parsed: Variant = parser.data
    if typeof(parsed) != TYPE_ARRAY:
        return _fail("Маршрут должен быть JSON-массивом координат.")
    var clean: Array[Vector2] = []
    for point in parsed:
        if typeof(point) != TYPE_ARRAY or point.size() != 2:
            return _fail("Каждая точка маршрута должна содержать ровно две координаты.")
        if (typeof(point[0]) != TYPE_INT and typeof(point[0]) != TYPE_FLOAT) or (typeof(point[1]) != TYPE_INT and typeof(point[1]) != TYPE_FLOAT):
            return _fail("Координаты маршрута должны быть числами.")
        var x := float(point[0])
        var y := float(point[1])
        if not is_finite(x) or not is_finite(y):
            return _fail("Координаты маршрута должны быть конечными числами.")
        clean.append(Vector2(x, y))
    if clean.is_empty():
        return _fail("Маршрут должен содержать хотя бы одну точку.")
    _route = clean
    _route_index = clampi(_route_index, 0, _route.size() - 1)
    return true


func start_patrol() -> bool:
    if not bool(get_setting("enabled", true)):
        return _fail("Патрулирование отключено в настройках.")
    if _target == null or not is_instance_valid(_target):
        return _fail("Сначала привяжите Node2D через bind_target().")
    if _route.is_empty() and not _parse_route():
        return false
    if _route.size() < 2:
        return _fail("Для патруля нужны как минимум две точки.")
    _patrolling = true
    set_physics_process(true)
    return true


func stop_patrol() -> void:
    _patrolling = false
    set_physics_process(false)


func is_patrolling() -> bool:
    return _patrolling


func _physics_process(delta: float) -> void:
    if not _patrolling:
        return
    if not bool(get_setting("enabled", true)):
        stop_patrol()
        return
    if _target == null or not is_instance_valid(_target):
        stop_patrol()
        action_failed.emit("Целевой объект больше не существует.")
        return
    if delta <= 0.0 or not is_finite(delta):
        return
    var destination := _route[_route_index]
    var step := float(get_option("patrol_speed", 60.0)) * delta
    _target.global_position = _target.global_position.move_toward(destination, step)
    if _target.global_position.distance_to(destination) <= 0.001:
        patrol_point_reached.emit(_route_index, destination)
        if _route_index + 1 < _route.size():
            _route_index += 1
        elif bool(get_option("loop_route", true)):
            _route_index = 0
        else:
            stop_patrol()
            patrol_finished.emit()
