extends Node2D
class_name ResourceDrop

const ITEM_TEXTURES := {
	"sword": preload("res://Assets/Weapons/sword.png"),
	"pickaxe": preload("res://Assets/Tools/pickaxe.png"),
	"axe": preload("res://Assets/Tools/axe.png"),
	"bow": preload("res://Assets/Weapons/bow.png"),
	"arrows": preload("res://Assets/Items/arrows.png"),
}

var item_id := "wood"
var amount := 1
var default_item_id := "wood"
var default_amount := 1
var default_velocity := Vector2.ZERO
var velocity := Vector2.ZERO
var vertical_offset := 0.0
var vertical_velocity := 0.0
var gravity := 520.0
var friction := 380.0
var bounce_factor := 0.36
var bounce_count := 2
var pickup_radius := 22.0
var magnet_speed := 570.0
var magnet_target: Node2D
var picked := false
var debug_selected := false
var player_drop_protected := false
var player_drop_origin := Vector2.ZERO
var player_drop_exclusion_radius := 0.0

func configure(kind: String, quantity: int, launch_velocity: Vector2, settings: Dictionary) -> void:
	item_id = kind
	amount = maxi(1, quantity)
	velocity = launch_velocity
	default_item_id = kind
	default_amount = amount
	default_velocity = launch_velocity
	gravity = float(settings.get("gravity", gravity))
	pickup_radius = float(settings.get("pickup_distance", pickup_radius))
	friction = float(settings.get("horizontal_friction", friction))
	bounce_factor = float(settings.get("bounce_factor", bounce_factor))
	magnet_speed = float(settings.get("magnet_speed", magnet_speed))
	vertical_velocity = randf_range(120.0, 220.0)
	queue_redraw()

func set_magnet_target(target: Node2D) -> void:
	magnet_target = target

func clear_magnet_target() -> void:
	magnet_target = null

func set_debug_selected(value: bool) -> void:
	debug_selected = value
	queue_redraw()

func protect_from_player(origin: Vector2, exclusion_radius: float) -> void:
	player_drop_origin = origin
	player_drop_exclusion_radius = maxf(0.0, exclusion_radius)
	player_drop_protected = global_position.distance_to(origin) <= player_drop_exclusion_radius

func is_protected_from_player() -> bool:
	if not player_drop_protected:
		return false
	if global_position.distance_to(player_drop_origin) > player_drop_exclusion_radius:
		player_drop_protected = false
	return player_drop_protected

func can_collect() -> bool:
	return not picked and vertical_offset <= 4.0

func collect() -> int:
	if picked:
		return 0
	picked = true
	return amount

func _physics_process(delta: float) -> void:
	if picked:
		return
	if is_instance_valid(magnet_target):
		var direction := (magnet_target.global_position - global_position)
		if direction.length_squared() > 0.01:
			velocity = velocity.move_toward(direction.normalized() * magnet_speed, 1500.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	global_position += velocity * delta

	if vertical_offset > 0.0 or vertical_velocity > 0.0:
		vertical_velocity -= gravity * delta
		vertical_offset += vertical_velocity * delta
		if vertical_offset <= 0.0:
			vertical_offset = 0.0
			if bounce_count > 0 and absf(vertical_velocity) > 34.0:
				vertical_velocity = absf(vertical_velocity) * bounce_factor
				velocity *= 0.72
				bounce_count -= 1
			else:
				vertical_velocity = 0.0
	z_index = int(global_position.y / 16.0) + 3
	queue_redraw()

func _draw() -> void:
	if debug_selected:
		draw_arc(Vector2(0, -4), 15.0, 0.0, TAU, 32, Color("#8ee6ff"), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.25, 0.55))
	draw_circle(Vector2.ZERO, 6.0, Color(0.02, 0.03, 0.02, 0.30))
	var lift := Vector2(0, -vertical_offset)
	if item_id == "wood":
		draw_set_transform(lift + Vector2(0, -2), deg_to_rad(18.0), Vector2.ONE)
		draw_rect(Rect2(-7, -4, 14, 8), Color("#8b5a32"))
		draw_rect(Rect2(-5, -3, 10, 2), Color("#c48a4c"))
		draw_line(Vector2(-4, 1), Vector2(4, 1), Color("#5f3d27"), 1.0)
	elif item_id == "stone":
		draw_set_transform(lift, deg_to_rad(-8.0), Vector2.ONE)
		var points := PackedVector2Array([Vector2(-7, 2), Vector2(-5, -5), Vector2(2, -7), Vector2(8, -1), Vector2(5, 5), Vector2(-3, 6)])
		draw_colored_polygon(points, Color("#818d8b"))
		draw_line(Vector2(-3, -3), Vector2(3, -5), Color("#c1c9bd"), 1.0)
	elif ITEM_TEXTURES.has(item_id):
		draw_set_transform(lift, 0.0, Vector2.ONE * 0.72)
		draw_texture_rect(ITEM_TEXTURES[item_id], Rect2(-16, -16, 32, 32))
	if amount > 1:
		draw_set_transform(lift, 0.0, Vector2.ONE)
		draw_string(ThemeDB.fallback_font, Vector2(8, -4), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
