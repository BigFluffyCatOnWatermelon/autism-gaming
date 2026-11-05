extends Node2D
class_name ComponentTestScene

const TARGET_CENTER := Vector2(650.0, 270.0)

var _test_object: Node
var _health: HealthComponent
var _damageable: DamageableComponent
var _health_bar: ProgressBar
var _health_label: Label
var _status_label: Label
var _damage_toggle: CheckButton
var _invulnerable_toggle: CheckButton
var _last_action := "Тестовый объект готов."


func _ready() -> void:
	_create_test_object()
	_build_ui()
	_update_ui()


func _create_test_object() -> void:
	var definition := ObjectDefinition.new()
	definition.object_id = "component_test_dummy"
	definition.display_name = "Test Dummy"
	definition.object_type = "other"
	definition.category = "Other"
	definition.root_type = "Node2D"

	var health_definition := ObjectComponentCatalog.create_definition("health")
	var damageable_definition := ObjectComponentCatalog.create_definition("damageable")
	if health_definition == null or damageable_definition == null:
		push_error("ComponentTestScene: Health или Damageable отсутствует в каталоге.")
		return

	health_definition.settings["max_health"] = 100.0
	health_definition.settings["starting_health"] = 100.0
	health_definition.settings["invulnerable"] = false
	health_definition.settings["can_heal"] = true

	damageable_definition.settings["can_receive_damage"] = true
	damageable_definition.settings["damage_multiplier"] = 1.25
	damageable_definition.settings["flat_reduction"] = 2.0
	definition.components = [health_definition, damageable_definition]

	_test_object = ObjectFactory.instantiate(definition)
	if _test_object == null:
		push_error("ComponentTestScene: ObjectFactory не смог создать тестовый объект.")
		return

	_test_object.name = "TestDummy"
	_test_object.position = TARGET_CENTER
	add_child(_test_object)

	_health = ObjectFactory.get_component(_test_object, "health") as HealthComponent
	_damageable = ObjectFactory.get_component(_test_object, "damageable") as DamageableComponent
	if _health == null or _damageable == null:
		push_error("ComponentTestScene: созданный объект не получил Health и Damageable.")
		return

	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_health_died)
	_damageable.damage_received.connect(_on_damage_received)
	_damageable.damage_blocked.connect(_on_damage_blocked)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "TestUI"
	add_child(canvas)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	canvas.add_child(margin)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)

	var title := Label.new()
	title.text = "ТЕСТ КОМПОНЕНТОВ"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Изолированный объект: Health + Damageable"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.modulate = Color("#aebdca")
	content.add_child(subtitle)

	var divider := HSeparator.new()
	content.add_child(divider)

	_health_label = Label.new()
	_health_label.text = "Здоровье: —"
	content.add_child(_health_label)

	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(0.0, 18.0)
	content.add_child(_health_bar)

	var damage_title := Label.new()
	damage_title.text = "ПРОВЕРКА УРОНА"
	content.add_child(damage_title)

	var damage_row := HBoxContainer.new()
	content.add_child(damage_row)
	_add_action_button(damage_row, "Урон 10", _on_hit_ten_pressed)
	_add_action_button(damage_row, "Урон 25", _on_hit_twenty_five_pressed)

	var heal_row := HBoxContainer.new()
	content.add_child(heal_row)
	_add_action_button(heal_row, "Лечение 15", _on_heal_pressed)
	_add_action_button(heal_row, "Сброс", _on_reset_pressed)

	var toggles_title := Label.new()
	toggles_title.text = "ПРОВЕРКА ЗАЩИТЫ"
	content.add_child(toggles_title)

	_damage_toggle = CheckButton.new()
	_damage_toggle.text = "Принимать входящий урон"
	_damage_toggle.button_pressed = true
	_damage_toggle.toggled.connect(_on_damage_toggle_changed)
	content.add_child(_damage_toggle)

	_invulnerable_toggle = CheckButton.new()
	_invulnerable_toggle.text = "Неуязвимость Health"
	_invulnerable_toggle.button_pressed = false
	_invulnerable_toggle.toggled.connect(_on_invulnerable_toggle_changed)
	content.add_child(_invulnerable_toggle)

	var settings_label := Label.new()
	settings_label.text = "Настройки Damageable: множитель 1.25 · снижение 2"
	settings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_label.modulate = Color("#aebdca")
	content.add_child(settings_label)

	var status_title := Label.new()
	status_title.text = "СОБЫТИЯ"
	content.add_child(status_title)

	_status_label = Label.new()
	_status_label.custom_minimum_size = Vector2(0.0, 58.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = _last_action
	content.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var hint := Label.new()
	hint.text = "Формула: max(0, входящий урон × 1.25 − 2). После смерти нажми «Сброс»."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color("#aebdca")
	content.add_child(hint)


func _add_action_button(parent: HBoxContainer, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 36.0)
	button.pressed.connect(callback)
	parent.add_child(button)


func apply_test_damage(amount: float) -> float:
	if _damageable == null:
		return 0.0
	var applied := _damageable.receive_damage(amount, self)
	_last_action = "Фактически снято: %.1f HP." % applied
	_update_ui()
	return applied


func heal_test_object(amount: float) -> float:
	if _health == null:
		return 0.0
	var restored := _health.heal(amount)
	_last_action = "Восстановлено: %.1f HP." % restored
	_update_ui()
	return restored


func reset_test_object() -> void:
	if _health == null or _damageable == null:
		return
	_health.reset_health()
	_health.invulnerable = false
	_damageable.set_damage_enabled(true)
	if _damage_toggle != null:
		_damage_toggle.set_pressed_no_signal(true)
	if _invulnerable_toggle != null:
		_invulnerable_toggle.set_pressed_no_signal(false)
	_last_action = "Здоровье и защита сброшены."
	_update_ui()


func set_damage_enabled(enabled: bool) -> void:
	if _damageable == null:
		return
	_damageable.set_damage_enabled(enabled)
	if _damage_toggle != null:
		_damage_toggle.set_pressed_no_signal(enabled)
	_last_action = "Приём урона %s." % ("включён" if enabled else "отключён")
	_update_ui()


func set_invulnerable(enabled: bool) -> void:
	if _health == null:
		return
	_health.invulnerable = enabled
	if _invulnerable_toggle != null:
		_invulnerable_toggle.set_pressed_no_signal(enabled)
	_last_action = "Неуязвимость %s." % ("включена" if enabled else "отключена")
	_update_ui()


func get_test_health() -> float:
	return _health.current_health if _health != null else 0.0


func get_test_max_health() -> float:
	return _health.max_health if _health != null else 0.0


func is_test_alive() -> bool:
	return _health != null and _health.is_alive()


func has_test_components() -> bool:
	return _health != null and _damageable != null


func _on_hit_ten_pressed() -> void:
	apply_test_damage(10.0)


func _on_hit_twenty_five_pressed() -> void:
	apply_test_damage(25.0)


func _on_heal_pressed() -> void:
	heal_test_object(15.0)


func _on_reset_pressed() -> void:
	reset_test_object()


func _on_damage_toggle_changed(enabled: bool) -> void:
	set_damage_enabled(enabled)


func _on_invulnerable_toggle_changed(enabled: bool) -> void:
	set_invulnerable(enabled)


func _on_health_changed(_current: float, _maximum: float) -> void:
	_update_ui()


func _on_health_died() -> void:
	_last_action = "Объект уничтожен: Health отправил сигнал died."
	_update_ui()


func _on_damage_received(amount: float, remaining_health: float, _source: Node) -> void:
	_last_action = "Damageable: %.1f урона · осталось %.1f HP." % [amount, remaining_health]
	_update_ui()


func _on_damage_blocked(incoming_damage: float, _source: Node) -> void:
	_last_action = "Урон %.1f заблокирован." % incoming_damage
	_update_ui()


func _update_ui() -> void:
	var current := get_test_health()
	var maximum := get_test_max_health()
	if _health_label != null:
		_health_label.text = "Здоровье: %.1f / %.1f" % [current, maximum]
	if _health_bar != null:
		_health_bar.max_value = maxf(1.0, maximum)
		_health_bar.value = current
	if _status_label != null:
		_status_label.text = _last_action
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(390.0, 82.0), Vector2(540.0, 390.0)), Color("#202b35"), true)
	draw_rect(Rect2(Vector2(390.0, 82.0), Vector2(540.0, 390.0)), Color("#526474"), false, 2.0)

	var body_color := Color("#b98a62")
	if _health != null and not _health.is_alive():
		body_color = Color("#696b70")
	draw_rect(Rect2(TARGET_CENTER + Vector2(-56.0, -92.0), Vector2(112.0, 160.0)), Color("#101820"), true)
	draw_rect(Rect2(TARGET_CENTER + Vector2(-48.0, -84.0), Vector2(96.0, 144.0)), body_color, true)
	draw_rect(Rect2(TARGET_CENTER + Vector2(-32.0, -56.0), Vector2(14.0, 10.0)), Color("#202b35"), true)
	draw_rect(Rect2(TARGET_CENTER + Vector2(18.0, -56.0), Vector2(14.0, 10.0)), Color("#202b35"), true)
	draw_rect(Rect2(TARGET_CENTER + Vector2(-22.0, -12.0), Vector2(44.0, 8.0)), Color("#674a3b"), true)
	draw_rect(Rect2(TARGET_CENTER + Vector2(-48.0, 68.0), Vector2(40.0, 38.0)), Color("#384d63"), true)
	draw_rect(Rect2(TARGET_CENTER + Vector2(8.0, 68.0), Vector2(40.0, 38.0)), Color("#384d63"), true)

	var health_ratio := _health.get_health_ratio() if _health != null else 1.0
	draw_rect(Rect2(TARGET_CENTER + Vector2(-65.0, -116.0), Vector2(130.0, 12.0)), Color("#101820"), true)
	draw_rect(Rect2(TARGET_CENTER + Vector2(-63.0, -114.0), Vector2(126.0 * health_ratio, 8.0)), Color("#79c96b"), true)
