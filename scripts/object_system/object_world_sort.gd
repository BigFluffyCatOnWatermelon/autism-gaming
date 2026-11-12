@tool
extends Node
## Applies the game's shared foot-point sorting convention to Object Builder scenes.

const WORLD_Z_SORT_OFFSET := 2048
const SORT_BIAS := 1


func _ready() -> void:
	set_process(true)
	update_sort_order()


func _process(_delta: float) -> void:
	update_sort_order()


func update_sort_order() -> void:
	var target := get_parent() as Node2D
	if target == null:
		return
	var footprint := Vector2(32.0, 32.0)
	var footprint_value: Variant = target.get_meta("object_builder_size", footprint)
	if footprint_value is Vector2:
		footprint = footprint_value
	var foot_y: float = target.global_position.y + maxf(1.0, footprint.y) * 0.5
	target.z_as_relative = false
	target.z_index = clampi(floori(foot_y) + WORLD_Z_SORT_OFFSET + SORT_BIAS, -4096, 4096)
