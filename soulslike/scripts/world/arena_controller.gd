extends Node3D
const SOUL_STAIN_SCENE: PackedScene = preload("res://scenes/world/soul_stain.tscn")
@export var restart_delay := 3.0
var dead_player: PlayerController
var restart_timer := -1.0

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		player.player_died.connect(_on_player_died)
	if RunState.has_lost_souls:
		var stain := SOUL_STAIN_SCENE.instantiate()
		add_child(stain)
		stain.global_position = RunState.lost_position + Vector3(0.0, 0.12, 0.0)

func _process(delta: float) -> void:
	if restart_timer >= 0.0:
		restart_timer -= delta
		if restart_timer <= 0.0:
			get_tree().reload_current_scene()
	if dead_player != null and Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	dead_player = get_tree().get_first_node_in_group("player") as PlayerController
	restart_timer = restart_delay
