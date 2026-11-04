extends Node3D
class_name SoulStain

func _ready() -> void:
	add_to_group("interactables")
	if RunState.lost_souls <= 0:
		queue_free()

func get_interaction_text(_player: Node3D) -> String:
	return "[E]  RECOVER %s SOULS" % String.num_int64(RunState.lost_souls)

func interact(player: PlayerController) -> void:
	var recovered := RunState.reclaim_lost_souls()
	if recovered > 0:
		player.status_message.emit("SOULS RECOVERED: +%s" % String.num_int64(recovered))
		queue_free()
