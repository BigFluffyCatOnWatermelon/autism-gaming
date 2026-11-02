extends Node2D
class_name ArrowProjectile

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Complete arrow silhouette: shaft, fletching and pointed metal head.
	draw_line(Vector2(-15, 0), Vector2(11, 0), Color("#6f4b2d"), 2.2, true)
	draw_line(Vector2(-13, -0.6), Vector2(8, -0.6), Color("#c8a46b"), 0.7, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -3.2), Vector2(16, 0), Vector2(8, 3.2), Vector2(10, 0)
	]), Color("#c7d1d3"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 0), Vector2(-19, -4.0), Vector2(-12, -2.0)
	]), Color("#a94e42"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 0), Vector2(-19, 4.0), Vector2(-12, 2.0)
	]), Color("#a94e42"))
