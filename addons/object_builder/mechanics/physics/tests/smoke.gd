extends SceneTree

const COLLISION = preload("res://addons/object_builder/mechanics/physics/components/has_collision.gd")
const BLOCKING = preload("res://addons/object_builder/mechanics/physics/components/blocks_movement.gd")
const PUSH = preload("res://addons/object_builder/mechanics/physics/components/can_be_pushed.gd")
const PULL = preload("res://addons/object_builder/mechanics/physics/components/can_be_pulled.gd")
const MASS = preload("res://addons/object_builder/mechanics/physics/components/has_mass.gd")
const GRAVITY = preload("res://addons/object_builder/mechanics/physics/components/affected_by_gravity.gd")
const BOUNCE = preload("res://addons/object_builder/mechanics/physics/components/can_bounce.gd")
const ROLL = preload("res://addons/object_builder/mechanics/physics/components/can_roll.gd")
const SLIDE = preload("res://addons/object_builder/mechanics/physics/components/can_slide.gd")
const MATERIAL = preload("res://addons/object_builder/mechanics/physics/components/has_physics_material.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var errors: Array[String] = []
    var host := Node2D.new()
    root.add_child(host)

    var static_body := StaticBody2D.new()
    host.add_child(static_body)
    var shape := CollisionShape2D.new()
    shape.shape = CircleShape2D.new()
    static_body.add_child(shape)

    var collision = COLLISION.new()
    host.add_child(collision)
    collision._on_configured()
    if not collision.bind_target(static_body):
        errors.append("has_collision: не удалось привязать StaticBody2D.")
    elif not collision.set_collision_enabled(false):
        errors.append("has_collision: не удалось отключить коллизию.")
    else:
        await process_frame
        if not shape.disabled:
            errors.append("has_collision: форма не отключена.")
        collision.set_collision_enabled(true)
        await process_frame
        if shape.disabled:
            errors.append("has_collision: форма не включена обратно.")

    var blocking = BLOCKING.new()
    host.add_child(blocking)
    blocking._on_configured()
    if not blocking.bind_target(static_body):
        errors.append("blocks_movement: не удалось привязать CollisionObject2D.")
    elif not blocking.set_blocking(false) or static_body.get_collision_layer_value(1):
        errors.append("blocks_movement: бит слоя не был отключён.")
    elif not blocking.set_blocking(true) or not static_body.get_collision_layer_value(1):
        errors.append("blocks_movement: бит слоя не был включён обратно.")
    if blocking.configure_mechanic({"collision_layer_bit": 33}):
        errors.append("blocks_movement: недопустимый номер слоя принят.")

    var character := CharacterBody2D.new()
    host.add_child(character)
    var push = PUSH.new()
    host.add_child(push)
    push._on_configured()
    push.bind_target(character)
    if not push.push(Vector2.RIGHT):
        errors.append("can_be_pushed: толчок не выполнен.")
    elif character.velocity.x <= 0.0:
        errors.append("can_be_pushed: скорость не увеличилась.")
    if push.push(Vector2(INF, 0.0)):
        errors.append("can_be_pushed: бесконечное направление принято.")

    var pull = PULL.new()
    host.add_child(pull)
    pull._on_configured()
    pull.bind_target(character)
    var source := Node2D.new()
    host.add_child(source)
    source.global_position = Vector2.LEFT * 100.0
    var before_pull := character.velocity.x
    if not pull.pull_towards(source):
        errors.append("can_be_pulled: притяжение не выполнено.")
    elif character.velocity.x >= before_pull:
        errors.append("can_be_pulled: скорость не направлена к источнику.")
    pull.configure_mechanic({"maximum_distance": 10.0})
    if pull.pull_towards(source):
        errors.append("can_be_pulled: превышение дальности не отклонено.")

    var rigid := RigidBody2D.new()
    host.add_child(rigid)
    var mass = MASS.new()
    host.add_child(mass)
    mass._on_configured()
    if not mass.bind_target(rigid) or not mass.set_mass(7.5) or not is_equal_approx(rigid.mass, 7.5):
        errors.append("has_mass: масса не установлена.")
    if mass.set_mass(0.0):
        errors.append("has_mass: нулевая масса принята.")

    var gravity = GRAVITY.new()
    host.add_child(gravity)
    gravity._on_configured()
    if not gravity.bind_target(rigid) or not gravity.set_gravity_scale(0.0) or not is_zero_approx(rigid.gravity_scale):
        errors.append("affected_by_gravity: масштаб гравитации не применён.")
    if gravity.set_gravity_scale(101.0):
        errors.append("affected_by_gravity: значение за диапазоном принято.")

    var bounce = BOUNCE.new()
    host.add_child(bounce)
    bounce._on_configured()
    if not bounce.bind_target(rigid) or rigid.physics_material_override == null:
        errors.append("can_bounce: PhysicsMaterial не назначен.")
    elif not bounce.set_bounce(0.9) or not is_equal_approx(rigid.physics_material_override.bounce, 0.9):
        errors.append("can_bounce: коэффициент отскока не установлен.")
    if bounce.set_bounce(2.0):
        errors.append("can_bounce: коэффициент выше 1 принят.")

    var roll = ROLL.new()
    host.add_child(roll)
    roll._on_configured()
    roll.bind_target(rigid)
    if not roll.roll(1.0) or rigid.angular_velocity <= 0.0:
        errors.append("can_roll: угловая скорость не установлена.")
    if roll.roll(0.0):
        errors.append("can_roll: нулевое направление принято.")

    var slide = SLIDE.new()
    host.add_child(slide)
    slide._on_configured()
    if not slide.bind_target(rigid) or not slide.set_sliding(true):
        errors.append("can_slide: режим скольжения не включился.")
    elif rigid.physics_material_override.friction >= 0.1:
        errors.append("can_slide: коэффициент трения не уменьшен.")
    if not slide.set_sliding(false):
        errors.append("can_slide: обычный режим не восстановлен.")

    var material = MATERIAL.new()
    host.add_child(material)
    material._on_configured()
    if not material.bind_target(rigid):
        errors.append("has_physics_material: не удалось привязать физическое тело.")
    elif not material.configure_mechanic({"friction":0.3,"bounce":0.4,"rough":true,"absorbent":false}):
        errors.append("has_physics_material: настройки материала не приняты.")
    elif not material.apply_material():
        errors.append("has_physics_material: применение материала не удалось.")
    else:
        if not is_equal_approx(rigid.physics_material_override.friction, 0.3):
            errors.append("has_physics_material: неверное трение.")
        if not is_equal_approx(rigid.physics_material_override.bounce, 0.4):
            errors.append("has_physics_material: неверный отскок.")
        if not rigid.physics_material_override.rough:
            errors.append("has_physics_material: rough не включён.")

    host.queue_free()
    if errors.is_empty():
        print("MODULE_TESTS: PASS")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        print("MODULE_TESTS: FAIL")
        quit(1)
