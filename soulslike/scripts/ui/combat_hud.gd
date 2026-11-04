extends CanvasLayer

@onready var health_bar: ProgressBar = $Root/Margins/Content/TopLeft/Health
@onready var stamina_bar: ProgressBar = $Root/Margins/Content/TopLeft/Stamina
@onready var health_text: Label = $Root/Margins/Content/TopLeft/HealthText
@onready var stamina_text: Label = $Root/Margins/Content/TopLeft/StaminaText
@onready var souls_label: Label = $Root/Margins/Content/BottomRight/Souls
@onready var flask_label: Label = $Root/Margins/Content/BottomRight/Flasks
@onready var state_label: Label = $Root/Margins/Content/BottomLeft/State
@onready var prompt_label: Label = $Root/Margins/Content/CenterBottom/Prompt
@onready var message_label: Label = $Root/Margins/Content/CenterBottom/Message
@onready var boss_panel: Control = $Root/Margins/Content/BossPanel
@onready var boss_title: Label = $Root/Margins/Content/BossPanel/BossTitle
@onready var boss_bar: ProgressBar = $Root/Margins/Content/BossPanel/BossHealth
@onready var pause_panel: Control = $Root/PausePanel

var player: PlayerController
var message_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0] as PlayerController
		player.souls_changed.connect(_on_souls_changed)
		player.stats_changed.connect(_refresh)
		player.player_died.connect(_on_player_died)
		player.interaction_prompt_changed.connect(_on_prompt_changed)
		player.status_message.connect(show_message)
		_on_souls_changed(player.souls)
		_refresh()
	var bosses := get_tree().get_nodes_in_group("bosses")
	for entry in bosses:
		var boss := entry as BossController
		if is_instance_valid(boss) and boss.state != EnemyBase.AIState.DEAD:
			boss.boss_health_changed.connect(_on_boss_health_changed)
			boss.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
	if is_instance_valid(player):
		_refresh()
	if message_time > 0.0:
		message_time -= delta
	elif message_label.visible:
		message_label.visible = false

func _refresh() -> void:
	if not is_instance_valid(player):
		return
	health_bar.max_value = player.health.maximum_health
	health_bar.value = player.health.current_health
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	health_text.text = "VITALITY  %d / %d" % [roundi(player.health.current_health), roundi(player.health.maximum_health)]
	stamina_text.text = "STAMINA  %d / %d" % [roundi(player.stamina), roundi(player.max_stamina)]
	flask_label.text = "✦  ESTUS  %d / %d   [Q]" % [player.get_flask_charges(), player.max_flasks]
	state_label.text = "ASHEN OATH   •   " + _state_name(player.state)
	if player.blocking:
		state_label.text = "GUARD UP   •   ASHEN OATH"

func _state_name(value: int) -> String:
	match value:
		PlayerController.ActionState.WINDUP: return "WINDUP"
		PlayerController.ActionState.ACTIVE: return "STRIKE"
		PlayerController.ActionState.RECOVERY: return "RECOVERY"
		PlayerController.ActionState.DODGING: return "DODGE"
		PlayerController.ActionState.STAGGERED: return "GUARD BROKEN"
		PlayerController.ActionState.DEAD: return "YOU HAVE FALLEN"
		_: return "READY"

func _on_souls_changed(total: int) -> void:
	souls_label.text = "◈   %s" % String.num_int64(total)

func _on_prompt_changed(prompt: String) -> void:
	prompt_label.text = prompt
	prompt_label.visible = not prompt.is_empty()

func show_message(message: String) -> void:
	message_label.text = message
	message_label.visible = true
	message_time = 2.4

func _on_player_died() -> void:
	show_message("YOU DIED   •   RETURNING TO THE LAST BONFIRE")

func _on_boss_health_changed(title: String, current: float, maximum: float, phase: int) -> void:
	boss_panel.visible = true
	boss_title.text = "%s   •   PHASE %d" % [title.to_upper(), phase]
	boss_bar.max_value = maximum
	boss_bar.value = current

func _on_boss_defeated() -> void:
	boss_panel.visible = false
	show_message("THE BELL FALLS SILENT")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()

func _set_paused(value: bool) -> void:
	get_tree().paused = value
	pause_panel.visible = value

func _on_resume_pressed() -> void:
	_set_paused(false)

func _on_restart_pressed() -> void:
	_set_paused(false)
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	_set_paused(false)
	get_tree().quit()
