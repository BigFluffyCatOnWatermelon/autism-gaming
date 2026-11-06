extends SceneTree

const INTERACT = preload("res://addons/object_builder/mechanics/interaction/components/can_interact.gd")
const PICKUP = preload("res://addons/object_builder/mechanics/interaction/components/can_be_picked_up.gd")
const ACTIVATE = preload("res://addons/object_builder/mechanics/interaction/components/can_be_activated.gd")
const OPEN = preload("res://addons/object_builder/mechanics/interaction/components/can_be_opened.gd")
const CLOSE = preload("res://addons/object_builder/mechanics/interaction/components/can_be_closed.gd")
const TOGGLE = preload("res://addons/object_builder/mechanics/interaction/components/can_be_toggled.gd")
const USE = preload("res://addons/object_builder/mechanics/interaction/components/can_be_used.gd")
const RANGE = preload("res://addons/object_builder/mechanics/interaction/components/has_interaction_range.gd")
const PROMPT = preload("res://addons/object_builder/mechanics/interaction/components/shows_interaction_prompt.gd")
const HOLD = preload("res://addons/object_builder/mechanics/interaction/components/supports_hold_interaction.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var errors: Array[String] = []
    var host := Node2D.new()
    root.add_child(host)
    var target := Node2D.new()
    host.add_child(target)
    var user := Node2D.new()
    host.add_child(user)

    var interaction = INTERACT.new()
    host.add_child(interaction)
    interaction._on_configured()
    interaction.bind_target(target)
    var interaction_count := [0]
    interaction.interaction_requested.connect(func(_user: Node) -> void: interaction_count[0] += 1)
    if not interaction.request_interaction(user) or interaction_count[0] != 1:
        errors.append("can_interact: запрос не передан подписчику.")
    interaction.configure_mechanic({"enabled":false})
    if interaction.request_interaction(user):
        errors.append("can_interact: отключённое взаимодействие принято.")

    var pickup = PICKUP.new()
    host.add_child(pickup)
    pickup._on_configured()
    pickup.bind_target(target)
    var pickup_count := [0]
    pickup.pickup_requested.connect(func(_user: Node, _item: Node2D) -> void: pickup_count[0] += 1)
    if not pickup.pickup(user) or not pickup.is_pickup_pending() or pickup_count[0] != 1:
        errors.append("can_be_picked_up: запрос подбора не сформирован.")
    if pickup.pickup(user):
        errors.append("can_be_picked_up: второй ожидающий запрос принят.")
    if not pickup.confirm_pickup(false) or pickup.is_picked_up():
        errors.append("can_be_picked_up: отклонение запроса обработано неверно.")
    if not pickup.pickup(user) or not pickup.confirm_pickup(true) or not pickup.is_picked_up():
        errors.append("can_be_picked_up: подтверждённый подбор не сохранён.")
    if pickup.pickup(user):
        errors.append("can_be_picked_up: повторный подбор принят при one_time_pickup.")

    var activation = ACTIVATE.new()
    host.add_child(activation)
    activation._on_configured()
    activation.bind_target(target)
    if not activation.activate() or not activation.is_active():
        errors.append("can_be_activated: активация не изменила состояние.")
    if not activation.deactivate() or activation.is_active():
        errors.append("can_be_activated: деактивация не изменила состояние.")

    var opener = OPEN.new()
    host.add_child(opener)
    opener._on_configured()
    opener.bind_target(target)
    var closer = CLOSE.new()
    host.add_child(closer)
    closer._on_configured()
    closer.bind_target(target)
    if not opener.open() or not closer.is_open():
        errors.append("can_be_opened: общее состояние не стало открытым.")
    if not closer.close() or opener.is_open():
        errors.append("can_be_closed: общий флаг не стал закрытым.")

    var toggle = TOGGLE.new()
    host.add_child(toggle)
    toggle._on_configured()
    toggle.bind_target(target)
    if not toggle.toggle() or not toggle.is_toggled():
        errors.append("can_be_toggled: переключение не включило состояние.")
    if not toggle.set_toggled(false) or toggle.is_toggled():
        errors.append("can_be_toggled: set_toggled(false) не выключил состояние.")

    var use_component = USE.new()
    host.add_child(use_component)
    use_component._on_configured()
    use_component.bind_target(target)
    use_component.configure_mechanic({"maximum_uses":2})
    if not use_component.use(user) or not use_component.use(user) or use_component.get_use_count() != 2:
        errors.append("can_be_used: счётчик применений работает неверно.")
    if use_component.use(user):
        errors.append("can_be_used: превышение лимита принято.")

    var range_component = RANGE.new()
    host.add_child(range_component)
    range_component._on_configured()
    range_component.bind_target(target)
    range_component.configure_mechanic({"interaction_range":50.0})
    user.global_position = Vector2(40.0,0.0)
    if not range_component.is_within_range(user):
        errors.append("has_interaction_range: объект внутри радиуса ошибочно отклонён.")
    user.global_position = Vector2(80.0,0.0)
    if range_component.is_within_range(user):
        errors.append("has_interaction_range: объект за радиусом ошибочно принят.")

    var prompt = PROMPT.new()
    host.add_child(prompt)
    prompt._on_configured()
    prompt.bind_target(target)
    prompt.configure_mechanic({"prompt_text":"Открыть сундук","prompt_range":50.0})
    user.global_position = Vector2(20.0,0.0)
    if prompt.get_prompt(user) != "Открыть сундук":
        errors.append("shows_interaction_prompt: текст подсказки не возвращён.")
    user.global_position = Vector2(100.0,0.0)
    if not prompt.get_prompt(user).is_empty():
        errors.append("shows_interaction_prompt: подсказка за радиусом не скрыта.")

    var hold = HOLD.new()
    host.add_child(hold)
    hold._on_configured()
    hold.bind_target(target)
    hold.configure_mechanic({"hold_duration":1.0})
    var completed_count := [0]
    hold.hold_completed.connect(func(_user: Node) -> void: completed_count[0] += 1)
    if not hold.begin_hold(user) or not hold.advance_hold(0.4):
        errors.append("supports_hold_interaction: запуск и первый шаг удержания не удались.")
    elif not is_equal_approx(hold.get_hold_progress(), 0.4):
        errors.append("supports_hold_interaction: неверный прогресс удержания.")
    hold.cancel_hold()
    if hold.get_hold_progress() != 0.0:
        errors.append("supports_hold_interaction: отмена не сбросила прогресс.")
    if not hold.begin_hold(user) or not hold.advance_hold(0.5) or not hold.advance_hold(0.5):
        errors.append("supports_hold_interaction: завершение удержания не удалось.")
    elif completed_count[0] != 1 or hold.is_holding():
        errors.append("supports_hold_interaction: событие завершения или состояние неверны.")

    host.queue_free()
    if errors.is_empty():
        print("MODULE_TESTS: PASS")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        print("MODULE_TESTS: FAIL")
        quit(1)
