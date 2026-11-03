@tool
extends Sprite2D

@export var depth_adjustment := 1
@export var anchor_at_bottom := true

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	if anchor_at_bottom and texture != null:
		offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
	z_as_relative = false
	set_process(true)
	_update_depth()

func _process(_delta: float) -> void:
	_update_depth()

func _update_depth() -> void:
	z_as_relative = false
	z_index = clampi(floori(global_position.y / 16.0) + depth_adjustment, -4096, 4096)
