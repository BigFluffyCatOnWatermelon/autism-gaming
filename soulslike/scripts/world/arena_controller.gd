extends Node3D

@export var restart_delay: float = 2.2
var dead_player: PlayerController
var restart_timer: float = -1.0

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		player.player_died.connect(_on_player_died)

func _process(delta: float) -> void:
	if restart_timer >= 0.0:
		restart_timer -= delta
		if restart_timer <= 0.0:
			get_tree().reload_current_scene()
	if Input.is_key_pressed(KEY_R) and dead_player != null:
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	dead_player = get_tree().get_first_node_in_group("player") as PlayerController
	restart_timer = restart_delay
