@tool
extends StaticBody2D
class_name ResourceNode

signal resource_broken(kind: String, drop_position: Vector2, amount: int)

@export_enum("tree", "rock", "stump") var resource_type := "tree":
	set(value):
		resource_type = value
		if is_inside_tree():
			_update_visual()
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

var visual: Sprite2D
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
	_update_visual()
	queue_redraw()

func _ready() -> void:
	if resource_type == "rock" and max_health == 90.0:
		max_health = 110.0
		health = max_health
	if resource_type == "tree":
		hit_radius = maxf(hit_radius, 29.0)
	else:
		hit_radius = maxf(hit_radius, 23.0)

	visual = get_node_or_null("Visual") as Sprite2D
	if visual == null:
		visual = Sprite2D.new()
		visual.name = "Visual"
		add_child(visual)
	_update_visual()

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

func _update_visual() -> void:
	if visual == null:
		return
	var texture_path := "res://Assets/Resources/Trees/tree.svg"
	match resource_type:
		"rock":
			texture_path = "res://Assets/Resources/Rocks/rock.svg"
			visual.position = Vector2(0, -28)
		"stump":
			texture_path = "res://Assets/Resources/Stumps/stump.svg"
			visual.position = Vector2(0, -20)
		_:
			texture_path = "res://Assets/Resources/Trees/tree.svg"
			visual.position = Vector2(0, -48)
	visual.texture = load(texture_path) as Texture2D
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.z_index = -1

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
	if visual != null:
		visual.modulate = Color(1.55, 1.55, 1.55, 1.0)
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
	if visual != null:
		visual.modulate = Color.WHITE
	destroying = false
	_update_visual()
	queue_redraw()

func _finish_rock_break() -> void:
	resource_broken.emit("stone", global_position, maxi(1, stone_drop_amount))
	queue_free()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		if flash_timer == 0.0 and visual != null:
			visual.modulate = Color.WHITE
	if not destroying and resource_type == "tree":
		sway_velocity -= rotation * 26.0 * delta
		sway_velocity *= exp(-7.5 * delta)
		rotation += sway_velocity * delta
	z_index = int(global_position.y / 16.0)

func _draw() -> void:
	if debug_selected:
		draw_arc(Vector2(0, -30), 48.0 if resource_type == "tree" else 34.0, 0.0, TAU, 40, Color("#8ee6ff"), 2.0, true)
	if resource_type != "stump" and health < max_health:
		var width := 46.0
		var top := -100.0 if resource_type == "tree" else -58.0
		draw_rect(Rect2(-width * 0.5, top, width, 5), Color("#252525"))
		draw_rect(Rect2(-width * 0.5, top, width * clampf(health / maxf(max_health, 1.0), 0.0, 1.0), 5), Color("#d85a4f"))
