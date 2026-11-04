extends Node3D
class_name Bonfire
@export var checkpoint_id := "ashen_outskirts_rest"
@export var checkpoint_title := "The Ashen Outskirts"
@export var spawn_offset := Vector3(1.8, 0.0, 0.0)
@onready var flame: MeshInstance3D = $Flame
@onready var fire_light: OmniLight3D = $FireLight
var elapsed := 0.0

func _ready() -> void:
	add_to_group("interactables")
	_update_visual_state()

func _process(delta: float) -> void:
	elapsed += delta
	fire_light.light_energy = 2.1 + 0.22 * sin(elapsed * 9.0) + 0.1 * sin(elapsed * 17.0)
	flame.scale = Vector3(0.85, 1.0 + 0.12 * sin(elapsed * 11.0), 0.85)

func get_interaction_text(_player: Node3D) -> String:
	return "[E]  REST AT THE BONFIRE"

func interact(player: PlayerController) -> void:
	RunState.activate_checkpoint(checkpoint_id, checkpoint_title, global_position + spawn_offset)
	player.rest_at_checkpoint()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("reset_enemy"):
			enemy.reset_enemy()
	RunState.save_game()
	_update_visual_state()
	player.status_message.emit("CHECKPOINT KINDLED  •  WORLD RESTORED")

func _update_visual_state() -> void:
	if has_node("Ember"):
		(get_node("Ember") as MeshInstance3D).visible = RunState.checkpoint_id == checkpoint_id
