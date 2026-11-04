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

func _get_visual_bottom_y() -> float:
	var bottom_y := -INF
	var sprites: Array[Sprite2D] = []
	_collect_sprites(self, sprites)
	for sprite in sprites:
		if not is_instance_valid(sprite) or not sprite.visible or sprite.texture == null:
			continue
		var rect := sprite.get_rect()
		var corners := [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
		for corner in corners:
			bottom_y = maxf(bottom_y, sprite.to_global(corner).y)
	return global_position.y if is_inf(bottom_y) else bottom_y


func _collect_sprites(root: Node, result: Array[Sprite2D]) -> void:
	for child in root.get_children():
		if child is Sprite2D:
			result.append(child as Sprite2D)
		_collect_sprites(child, result)


func _update_depth() -> void:
	z_as_relative = false
	z_index = clampi(floori(_get_visual_bottom_y()) + WORLD_Z_SORT_OFFSET + depth_adjustment, -4096, 4096)
