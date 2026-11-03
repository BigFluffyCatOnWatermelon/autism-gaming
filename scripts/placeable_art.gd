@tool
extends StaticBody2D

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
	z_index = clampi(floori(global_position.y) + depth_adjustment, -4096, 4096)
