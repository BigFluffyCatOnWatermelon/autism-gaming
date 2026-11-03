@tool
extends StaticBody2D

const WORLD_Z_SORT_OFFSET := 2048

@export var depth_adjustment := 1

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	set_process(true)
	_update_depth()

func _process(_delta: float) -> void:
	_update_depth()

func _update_depth() -> void:
	z_as_relative = false
	z_index = clampi(floori(global_position.y) + WORLD_Z_SORT_OFFSET + depth_adjustment, -4096, 4096)
