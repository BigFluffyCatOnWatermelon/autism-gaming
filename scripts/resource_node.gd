@tool
extends StaticBody2D

@export_enum("tree", "rock") var resource_type := "tree":
	set(value):
		resource_type = value
		if is_inside_tree():
			queue_redraw()

var health := 90.0
var max_health := 90.0
var hit_radius := 28.0
var flash_timer := 0.0

func configure(kind: String, starting_health: float) -> void:
	resource_type = kind
	health = starting_health
	max_health = starting_health
	hit_radius = 29.0 if kind == "tree" else 23.0
	queue_redraw()

func _ready() -> void:
	max_health = 90.0 if resource_type == "tree" else 110.0
	health = max_health
	hit_radius = 29.0 if resource_type == "tree" else 23.0
	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 12.0 if resource_type == "tree" else 16.0
		collision.shape = circle
		collision.position = Vector2(0, 8)
		add_child(collision)
	if not Engine.is_editor_hint():
		collision_layer = 2
		collision_mask = 0
	queue_redraw()

func apply_damage(amount: float) -> bool:
	if amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	flash_timer = 0.12
	queue_redraw()
	return health <= 0.0

func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		if flash_timer == 0.0:
			queue_redraw()
	z_index = int(global_position.y / 16.0)

func _draw() -> void:
	if resource_type == "tree":
		draw_rect(Rect2(-5, 5, 10, 28), Color("#76502e"))
		draw_rect(Rect2(-8, 17, 4, 12), Color("#51371f"))
		draw_rect(Rect2(-25, -28, 50, 34), Color("#245d32"))
		draw_rect(Rect2(-20, -40, 40, 20), Color("#347c3d"))
		draw_rect(Rect2(-15, -48, 27, 14), Color("#4b9144"))
		draw_rect(Rect2(-29, -15, 13, 16), Color("#1d4c2c"))
		draw_rect(Rect2(14, -20, 13, 18), Color("#1d4c2c"))
		draw_rect(Rect2(-13, -33, 8, 7), Color("#69a84d"))
		draw_rect(Rect2(6, -22, 8, 7), Color("#69a84d"))
	else:
		var points := PackedVector2Array([
			Vector2(-20, 5), Vector2(-15, -12), Vector2(-5, -22),
			Vector2(12, -18), Vector2(22, -3), Vector2(16, 12),
			Vector2(-10, 14)
		])
		draw_colored_polygon(points, Color("#727e7d"))
		draw_line(Vector2(-15, -8), Vector2(-4, -18), Color("#aab5a7"), 3.0)
		draw_line(Vector2(-4, -18), Vector2(9, -15), Color("#aab5a7"), 2.0)
		draw_rect(Rect2(-7, -6, 7, 5), Color("#596563"))

	if flash_timer > 0.0:
		draw_rect(Rect2(-8, -3, 16, 12), Color(1, 1, 1, 0.32))
	if health < max_health:
		var width := 42.0
		var top := -58.0 if resource_type == "tree" else -34.0
		draw_rect(Rect2(-width * 0.5, top, width, 5), Color("#252525"))
		draw_rect(Rect2(-width * 0.5, top, width * (health / max_health), 5), Color("#d85a4f"))
