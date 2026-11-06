extends SceneTree

const MOVE_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/move.gd")
const WALK_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/walk.gd")
const RUN_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/run.gd")
const JUMP_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/jump.gd")
const DASH_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/dash.gd")
const FLY_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/fly.gd")
const SWIM_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/swim.gd")
const CLIMB_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/climb.gd")
const TELEPORT_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/teleport.gd")
const PATROL_SCRIPT = preload("res://addons/object_builder/mechanics/movement/components/patrol_route.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var errors: Array[String] = []
    var host := Node2D.new()
    root.add_child(host)
    var target := Node2D.new()
    host.add_child(target)

    var mover = MOVE_SCRIPT.new()
    host.add_child(mover)
    mover._on_configured()
    mover.bind_target(target)
    if not mover.move_direction(Vector2.RIGHT, 1.0) or not target.global_position.is_equal_approx(Vector2(120.0, 0.0)):
        errors.append("can_move: неверное перемещение по X.")
    if mover.move_direction(Vector2(INF, 0.0), 1.0):
        errors.append("can_move: бесконечное направление принято.")

    var walker = WALK_SCRIPT.new()
    host.add_child(walker)
    walker._on_configured()
    walker.bind_target(target)
    var before_walk := target.global_position
    if not walker.walk(Vector2.DOWN, 1.0) or not is_equal_approx(target.global_position.y - before_walk.y, 80.0):
        errors.append("can_walk: неверная скорость ходьбы.")

    var runner = RUN_SCRIPT.new()
    host.add_child(runner)
    runner._on_configured()
    runner.bind_target(target)
    var before_run := target.global_position
    if not runner.run(Vector2.RIGHT, 1.0) or not is_equal_approx(target.global_position.x - before_run.x, 180.0):
        errors.append("can_run: неверная скорость бега.")

    var flyer = FLY_SCRIPT.new()
    host.add_child(flyer)
    flyer._on_configured()
    flyer.bind_target(target)
    var before_fly := target.global_position
    if not flyer.fly(Vector2(1.0, 1.0), 1.0) or not is_equal_approx(target.global_position.distance_to(before_fly), 160.0):
        errors.append("can_fly: нормализация направления или скорость неверны.")

    var swimmer = SWIM_SCRIPT.new()
    host.add_child(swimmer)
    swimmer._on_configured()
    swimmer.bind_target(target)
    if swimmer.swim(Vector2.RIGHT, 1.0):
        errors.append("can_swim: плавание разрешено вне состояния воды.")
    swimmer.set_swimming(true)
    var before_swim := target.global_position
    if not swimmer.swim(Vector2.RIGHT, 1.0) or not is_equal_approx(target.global_position.x - before_swim.x, 70.0):
        errors.append("can_swim: неверное перемещение в воде.")

    var climber = CLIMB_SCRIPT.new()
    host.add_child(climber)
    climber._on_configured()
    climber.bind_target(target)
    var before_climb := target.global_position
    if not climber.climb(-1.0, 1.0) or not is_equal_approx(before_climb.y - target.global_position.y, 80.0):
        errors.append("can_climb: неверное вертикальное перемещение.")

    var teleporter = TELEPORT_SCRIPT.new()
    host.add_child(teleporter)
    teleporter._on_configured()
    teleporter.bind_target(target)
    if not teleporter.configure_mechanic({"max_range": 10.0}):
        errors.append("can_teleport: не удалось задать радиус.")
    if teleporter.teleport_to(Vector2(10000.0, 10000.0)):
        errors.append("can_teleport: выход за максимальную дальность принят.")
    if not teleporter.teleport_to(target.global_position + Vector2(5.0, 0.0)):
        errors.append("can_teleport: допустимая точка отклонена.")

    var jumper = JUMP_SCRIPT.new()
    host.add_child(jumper)
    jumper._on_configured()
    jumper.bind_target(target)
    if not jumper.jump():
        errors.append("can_jump: Tween-прыжок не запустился.")

    var dasher = DASH_SCRIPT.new()
    host.add_child(dasher)
    dasher._on_configured()
    dasher.bind_target(target)
    if dasher.dash(Vector2.ZERO):
        errors.append("can_dash: нулевое направление ошибочно принято.")
    if not dasher.dash(Vector2.RIGHT):
        errors.append("can_dash: корректный рывок не запустился.")
    if dasher.dash(Vector2.LEFT):
        errors.append("can_dash: одновременный второй рывок принят.")

    var patrol = PATROL_SCRIPT.new()
    host.add_child(patrol)
    patrol._on_configured()
    patrol.bind_target(target)
    if not patrol.configure_mechanic({"route_json": "[[10,0],[20,0]]", "patrol_speed": 10.0, "loop_route": false}):
        errors.append("has_patrol_route: корректный маршрут отклонён.")
    elif patrol.configure_mechanic({"route_json": "not-json"}):
        errors.append("has_patrol_route: некорректный JSON-маршрут принят.")
    elif not patrol.start_patrol():
        errors.append("has_patrol_route: запуск патруля не удался.")
    else:
        target.global_position = Vector2.ZERO
        patrol._physics_process(1.0)
        if not target.global_position.is_equal_approx(Vector2(10.0, 0.0)):
            errors.append("has_patrol_route: объект не дошёл до первой точки маршрута.")
        patrol._physics_process(1.0)
        if patrol.is_patrolling():
            errors.append("has_patrol_route: патруль не завершился на конце незамкнутого маршрута.")

    host.free()
    if errors.is_empty():
        print("MODULE_TESTS: PASS")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        print("MODULE_TESTS: FAIL")
        quit(1)
