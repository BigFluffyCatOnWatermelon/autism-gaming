extends Node2D
class_name ResourceDrop

const WORLD_Z_SORT_OFFSET := 2048

const ITEM_TEXTURES := {
	"sword": preload("res://Assets/CozyVillageFarm/06_Farming/Tools/basic/sword_basic.png"),
	"pickaxe": preload("res://Assets/CozyVillageFarm/06_Farming/Tools/basic/pickaxe_basic.png"),
	"axe": preload("res://Assets/CozyVillageFarm/06_Farming/Tools/basic/axe_basic.png"),
	"bow": preload("res://Assets/Weapons/bow.png"),
	"arrows": preload("res://Assets/Items/arrows.png"),
	"wood": preload("res://Assets/CozyVillageFarm/10_Items/Resources/wood.png"),
	"stone": preload("res://Assets/CozyVillageFarm/10_Items/Resources/stone.png"),
}

var item_id := "wood"
var category := "materials"
var stack_limit := 99
var item_definition: Resource
var default_definition: Resource
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
var player_drop_lock_remaining := 0.0
var magnet_radius_multiplier := 1.0
var player_nearby := false

var visual: Sprite2D
var shadow: Sprite2D
var pickup_area: Area2D

func _ready() -> void:
	z_as_relative = false
	shadow = get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		shadow.texture = load("res://Assets/Effects/shadow.png") as Texture2D
		shadow.position = Vector2(0, 6)
		shadow.scale = Vector2(0.5, 0.28)
		shadow.z_index = -1
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(shadow)

	visual = get_node_or_null("Visual") as Sprite2D
	if visual == null:
		visual = Sprite2D.new()
		visual.name = "Visual"
		visual.centered = true
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(visual)

	pickup_area = get_node_or_null("PickupArea") as Area2D
	if pickup_area == null:
		pickup_area = Area2D.new()
		pickup_area.name = "PickupArea"
		pickup_area.collision_layer = 0
		pickup_area.collision_mask = 1
		pickup_area.monitoring = true
		pickup_area.monitorable = false
		add_child(pickup_area)
		var shape_node := CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = maxf(pickup_radius, 24.0)
		shape_node.shape = circle
		pickup_area.add_child(shape_node)
		pickup_area.body_entered.connect(_on_pickup_body_entered)
		pickup_area.body_exited.connect(_on_pickup_body_exited)
	_refresh_visual()

func configure(kind: String, quantity: int, launch_velocity: Vector2, settings: Dictionary, definition: Resource = null) -> void:
	set_item_definition(kind, definition, quantity)
	velocity = launch_velocity
	default_item_id = kind
	default_amount = amount
	default_velocity = launch_velocity
	default_definition = definition.duplicate(true) if definition != null else null
	gravity = float(settings.get("gravity", gravity))
	pickup_radius = float(settings.get("pickup_distance", pickup_radius))
	friction = float(settings.get("horizontal_friction", friction))
	bounce_factor = float(settings.get("bounce_factor", bounce_factor))
	magnet_speed = float(settings.get("magnet_speed", magnet_speed))
	vertical_velocity = randf_range(120.0, 220.0)
	if is_inside_tree():
		_refresh_visual()
	queue_redraw()


func set_item_definition(kind: String, definition: Resource, quantity: int = -1) -> void:
	item_id = kind
	item_definition = definition
	category = str(definition.get("category")) if definition != null else "materials"
	stack_limit = 1 if category in ["tools", "weapons"] else (maxi(1, int(definition.get("stack_limit"))) if definition != null else 99)
	var desired_amount := amount if quantity < 0 else quantity
	amount = clampi(desired_amount, 1, stack_limit)
	_refresh_visual()
	queue_redraw()


func _refresh_visual() -> void:
	if visual == null:
		return
	var definition_icon: Texture2D
	if item_definition != null:
		definition_icon = item_definition.get("icon") as Texture2D
	visual.texture = definition_icon if definition_icon != null else ITEM_TEXTURES.get(item_id) as Texture2D
	visual.visible = visual.texture != null
	visual.scale = Vector2.ONE if category == "materials" or category == "ammunition" else Vector2.ONE * 0.9
	visual.position = Vector2(0, -vertical_offset)

func _on_pickup_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true

func _on_pickup_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false

func set_magnet_target(target: Node2D) -> void:
	magnet_target = target

func clear_magnet_target() -> void:
	magnet_target = null

func set_debug_selected(value: bool) -> void:
	debug_selected = value
	queue_redraw()

func protect_from_player(origin: Vector2, exclusion_radius: float, lock_seconds: float = 0.9, magnet_multiplier: float = 0.35) -> void:
	player_drop_origin = origin
	player_drop_exclusion_radius = maxf(0.0, exclusion_radius)
	player_drop_lock_remaining = maxf(0.0, lock_seconds)
	magnet_radius_multiplier = clampf(magnet_multiplier, 0.1, 1.0)
	player_drop_protected = true


func is_protected_from_player() -> bool:
	if not player_drop_protected:
		return false
	if player_drop_lock_remaining > 0.0:
		return true
	if global_position.distance_to(player_drop_origin) > player_drop_exclusion_radius:
		player_drop_protected = false
	return player_drop_protected


func get_magnet_radius(base_radius: float) -> float:
	return maxf(0.0, base_radius) * magnet_radius_multiplier


func can_collect() -> bool:
	return not picked and vertical_offset <= 4.0 and player_nearby

func collect() -> int:
	if picked:
		return 0
	picked = true
	return amount

func _physics_process(delta: float) -> void:
	if picked:
		return
	if player_drop_lock_remaining > 0.0:
		player_drop_lock_remaining = maxf(0.0, player_drop_lock_remaining - delta)
	if is_instance_valid(magnet_target):
		var target_position: Vector2 = magnet_target.global_position
		if magnet_target.has_method("get_ground_position"):
			target_position = magnet_target.get_ground_position()
		var direction := target_position - global_position
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
	if visual != null:
		visual.position.y = -vertical_offset
	z_as_relative = false
	z_index = clampi(floori(global_position.y) + WORLD_Z_SORT_OFFSET + 3, -4096, 4096)
	queue_redraw()

func _draw() -> void:
	if debug_selected:
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color("#8ee6ff"), 2.0, true)
	if amount > 1:
		draw_string(ThemeDB.fallback_font, Vector2(8, -vertical_offset - 5), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)
