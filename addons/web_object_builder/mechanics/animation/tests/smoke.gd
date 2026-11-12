extends SceneTree

const IDLE_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/idle_animation.gd")
const WALK_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/walk_animation.gd")
const RUN_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/run_animation.gd")
const ATTACK_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/attack_animation.gd")
const HIT_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/hit_animation.gd")
const DEATH_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/death_animation.gd")
const BLEND_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/animation_blending.gd")
const EVENT_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/animation_events.gd")
const VARIANT_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/animation_variants.gd")
const FRAME_SCRIPT = preload("res://addons/web_object_builder/mechanics/animation/components/frame_events.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var errors: Array[String] = []
    var host := Node.new()
    root.add_child(host)
    var player := AnimationPlayer.new()
    host.add_child(player)
    var library := AnimationLibrary.new()
    for name in ["idle", "idle_winter", "walk", "run", "attack", "hit", "death"]:
        var animation := Animation.new()
        animation.length = 1.0
        library.add_animation(StringName(name), animation)
    if player.add_animation_library(&"", library) != OK:
        errors.append("Не удалось подключить тестовую AnimationLibrary.")

    var idle = IDLE_SCRIPT.new()
    host.add_child(idle)
    idle._on_configured()
    if not idle.bind_animation_player(player):
        errors.append("idle: bind_animation_player отказал.")
    elif not idle.play_idle() or String(player.current_animation) != "idle":
        errors.append("idle: анимация ожидания не запустилась.")
    if idle.play_idle() and not player.is_playing():
        errors.append("idle: AnimationPlayer не перешёл в состояние воспроизведения.")


    var named_checks := [
        {"script": WALK_SCRIPT, "method": "play_walk", "expected": "walk", "label": "walk"},
        {"script": RUN_SCRIPT, "method": "play_run", "expected": "run", "label": "run"},
        {"script": ATTACK_SCRIPT, "method": "play_attack", "expected": "attack", "label": "attack"},
        {"script": HIT_SCRIPT, "method": "play_hit", "expected": "hit", "label": "hit"},
        {"script": DEATH_SCRIPT, "method": "play_death", "expected": "death", "label": "death"}
    ]
    for check in named_checks:
        var component = check["script"].new()
        host.add_child(component)
        component._on_configured()
        component.bind_animation_player(player)
        if not bool(component.call(check["method"])) or String(player.current_animation) != str(check["expected"]):
            errors.append("%s: анимация не запустилась." % str(check["label"]))

    var blend = BLEND_SCRIPT.new()
    host.add_child(blend)
    blend._on_configured()
    blend.bind_animation_player(player)
    if not blend.configure_mechanic({"blend_seconds": 0.25}) or not blend.play_blended("walk"):
        errors.append("blend: настройка или запуск смешанной анимации не удались.")
    if blend.configure_mechanic({"blend_seconds": 11.0}):
        errors.append("blend: значение выше предела было принято.")

    var events = EVENT_SCRIPT.new()
    host.add_child(events)
    events._on_configured()
    events.bind_animation_player(player)
    if not events.emit_marker("footstep"):
        errors.append("events: пользовательский marker не отправлен.")
    if events.emit_marker("   "):
        errors.append("events: пустой marker был принят.")

    var variants = VARIANT_SCRIPT.new()
    host.add_child(variants)
    variants._on_configured()
    variants.bind_animation_player(player)
    if not variants.configure_mechanic({"variant_map_json": "{\"idle\":{\"winter\":\"idle_winter\"}}"}):
        errors.append("variants: корректная JSON-таблица отклонена.")
    elif not variants.play_variant("idle", "winter") or String(player.current_animation) != "idle_winter":
        errors.append("variants: выбран не тот вариант анимации.")
    if variants.configure_mechanic({"variant_map_json": "[]"}):
        errors.append("variants: JSON-массив принят вместо объекта.")

    var sprite := AnimatedSprite2D.new()
    host.add_child(sprite)
    var frames = FRAME_SCRIPT.new()
    host.add_child(frames)
    frames._on_configured()
    if not frames.bind_animated_sprite(sprite):
        errors.append("frame events: не удалось привязать AnimatedSprite2D.")
    if not frames.configure_mechanic({"frames_csv": "0,2"}):
        errors.append("frame events: корректный фильтр кадров отклонён.")
    if frames.configure_mechanic({"frames_csv": "0,not-a-number"}):
        errors.append("frame events: некорректный фильтр кадров принят.")

    host.queue_free()
    if errors.is_empty():
        print("MODULE_TESTS: PASS")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        print("MODULE_TESTS: FAIL")
        quit(1)
