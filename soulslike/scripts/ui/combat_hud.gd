extends CanvasLayer

@onready var health_bar: ProgressBar = $Root/Margins/Content/TopLeft/Health
@onready var stamina_bar: ProgressBar = $Root/Margins/Content/TopLeft/Stamina
@onready var souls_label: Label = $Root/Margins/Content/BottomRight/Souls
@onready var state_label: Label = $Root/Margins/Content/BottomLeft/State
var player: PlayerController

func _ready() -> void:
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0] as PlayerController
		player.souls_changed.connect(_on_souls_changed)
		player.stats_changed.connect(_refresh)
		player.player_died.connect(_on_player_died)
		_on_souls_changed(player.souls)
		_refresh()

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		_refresh()

func _refresh() -> void:
	if not is_instance_valid(player):
		return
	health_bar.max_value = player.health.maximum_health
	health_bar.value = player.health.current_health
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	state_label.text = "BLOCK" if player.blocking else "ASHEN OATH  •  " + _state_name(player.state)

func _state_name(value: int) -> String:
	match value:
		PlayerController.ActionState.WINDUP: return "WINDUP"
		PlayerController.ActionState.ACTIVE: return "STRIKE"
		PlayerController.ActionState.RECOVERY: return "RECOVERY"
		PlayerController.ActionState.DODGING: return "DODGE"
		PlayerController.ActionState.STAGGERED: return "STAGGERED"
		PlayerController.ActionState.DEAD: return "FALLEN"
		_: return "READY"

func _on_souls_changed(total: int) -> void:
	souls_label.text = "◈  %d" % total

func _on_player_died() -> void:
	state_label.text = "YOU HAVE FALLEN  •  PRESS R TO RESTART"
