@tool
extends StaticBody2D
class_name ResourceNode

signal resource_broken(kind: String, drop_position: Vector2, amount: int)

@export_enum("tree", "rock", "stump") var resource_type := "tree":
	set(value):
		resource_type = value
		if is_inside_tree():
			queue_redraw()

@export var max_health := 90.0
@export var health := 90.0
@export var wood_drop_amount := 5
@export var stone_drop_amount := 4
@export var hit_radius := 29.0
@export var swing_strength := 1.0
@export var destruction_duration := 0.48
@export var fall_angle_degrees := 78.0
@export var damage_resistances: Dictionary = {
	"cutting": 1.0,
	"piercing": 1.0,
	"crushing": 1.0,
}

var flash_timer := 0.0
var sway_velocity := 0.0
var destroying := false
var debug_selected := false

func configure(kind: String, starting_health: float) -> void:
	resource_type = kind
	max_health = starting_health
	health = starting_health
	hit_radius = 29.0 if kind == "tree" else 23.0
	wood_drop_amount = 5
	stone_drop_amount = 4
	queue_redraw()

func _ready() -> void:
	if resource_type == "rock" and max_health == 90.0:
		max_health = 110.0
		health = max_health
	if resource_type == "tree":
		hit_radius = maxf(hit_radius, 29.0)
	else:
		hit_radius = maxf(hit_radius, 23.0)
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

func apply_damage(amount: float, damage_type: String = "crushing") -> bool:
	if amount <= 0.0 or destroying or resource_type == "stump":
		return false
	var resistance := float(damage_resistances.get(damage_type, 1.0))
	var final_damage := maxf(0.0, amount * resistance)
	health = maxf(0.0, health - final_damage)
	flash_timer = 0.13
	var direction := -1.0 if randf() < 0.5 else 1.0
	rotation += direction * deg_to_rad(4.0) * swing_strength
	sway_velocity += direction * deg_to_rad(38.0) * swing_strength
	queue_redraw()
	return health <= 0.0

func set_debug_selected(value: bool) -> void:
	debug_selected = value
	queue_redraw()

func begin_destroy() -> void:
	if destroying or resource_type == "stump":
		return
	destroying = true
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", true)
	if resource_type == "tree":
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(self, "rotation", deg_to_rad(fall_angle_degrees), destruction_duration)
		tween.tween_callback(_finish_tree_fall)
	else:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(0.18, 0.18), destruction_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "modulate:a", 0.0, destruction_duration)
		tween.chain().tween_callback(_finish_rock_break)

func _finish_tree_fall() -> void:
	resource_broken.emit("wood", global_position + Vector2(0, -12), maxi(1, wood_drop_amount))
	resource_type = "stump"
	health = 0.0
	rotation = 0.0
	modulate = Color.WHITE
	destroying = false
	queue_redraw()

func _finish_rock_break() -> void:
	resource_broken.emit("stone", global_position, maxi(1, stone_drop_amount))
	queue_free()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		if flash_timer == 0.0:
			queue_redraw()
	if not destroying and resource_type == "tree":
		# Damped spring: impact adds angular velocity, while the trunk eases back to rest.
		sway_velocity -= rotation * 26.0 * delta
		sway_velocity *= exp(-7.5 * delta)
		rotation += sway_velocity * delta
	z_index = int(global_position.y / 16.0)

func _draw() -> void:
	if debug_selected:
		draw_arc(Vector2(0, -12), 34.0 if resource_type == "tree" else 27.0, 0.0, TAU, 40, Color("#8ee6ff"), 2.0, true)

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
	elif resource_type == "stump":
		draw_rect(Rect2(-7, -2, 14, 18), Color("#76502e"))
		draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 9.0, Color("#ad8750"))
		draw_circle(Vector2.ZERO, 5.0, Color("#775536"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_line(Vector2(-4, -5), Vector2(3, -2), Color("#d4b47a"), 1.0)
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
		var damage_ratio := 1.0 - clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
		if damage_ratio > 0.18:
			draw_line(Vector2(-8, -14), Vector2(-2, -5), Color("#343d3a"), 1.5)
		if damage_ratio > 0.42:
			draw_line(Vector2(-2, -5), Vector2(-10, 4), Color("#343d3a"), 1.5)
		if damage_ratio > 0.66:
			draw_line(Vector2(7, -15), Vector2(3, -7), Color("#343d3a"), 1.5)
			draw_line(Vector2(3, -7), Vector2(14, 0), Color("#343d3a"), 1.5)

	if flash_timer > 0.0:
		draw_rect(Rect2(-8, -3, 16, 12), Color(1, 1, 1, 0.32))
	if resource_type != "stump" and health < max_health:
		var width := 42.0
		var top := -58.0 if resource_type == "tree" else -34.0
		draw_rect(Rect2(-width * 0.5, top, width, 5), Color("#252525"))
		draw_rect(Rect2(-width * 0.5, top, width * (health / max_health), 5), Color("#d85a4f"))
