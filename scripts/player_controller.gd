extends CharacterBody2D

const GameConfigScript = preload("res://scripts/game_config.gd")
const PLAYER_SHEET_PATH := "res://Assets/CozyVillageFarm/08_Characters/Player/player_walk_idle_sheet.png"
const ATTACK_SHEET_PATHS := {
	"axe": "res://Assets/CozyVillageFarm/08_Characters/Player/player_action_axe.png",
	"pickaxe": "res://Assets/CozyVillageFarm/08_Characters/Player/player_action_pickaxe.png",
}
const ITEM_TEXTURE_PATHS := {
	"sword": "res://Assets/CozyVillageFarm/06_Farming/Tools/basic/sword_basic.png",
	"pickaxe": "res://Assets/CozyVillageFarm/06_Farming/Tools/basic/pickaxe_basic.png",
	"axe": "res://Assets/CozyVillageFarm/06_Farming/Tools/basic/axe_basic.png",
	"bow": "res://Assets/Weapons/bow.png",
	"arrows": "res://Assets/Items/arrows.png",
}

var game_config: Dictionary = {}
var current_health: float = 100.0
var current_stamina: float = 100.0
var moving := false
var running := false
var crouching := false
var rolling := false
var stamina_exhausted := false
var debug_infinite_stamina := false
var debug_invulnerable := false
var debug_selected := false
var roll_direction := Vector2.DOWN
var last_move_direction := Vector2.DOWN
var facing_row := 0
var roll_timer := 0.0
var roll_cooldown_timer := 0.0
var invulnerability_timer := 0.0
var walk_animation_time := 0.0
var idle_animation_time := 0.0
var attack_animation_time := 0.0
var attack_animation_duration := 0.0
var attack_animation_item := ""
var attack_animation_row := 0
var attack_animation_uses_sheet := false
var current_held_item := ""

var sprite: Sprite2D
var shadow: Sprite2D
var camera: Camera2D
var held_item_sprite: Sprite2D

func configure(settings: Dictionary) -> void:
	game_config = settings
	current_health = float(game_config.player.max_health)
	current_stamina = float(game_config.player.max_stamina)
	stamina_exhausted = false
	if camera != null:
		camera.position_smoothing_speed = float(game_config.camera.follow_speed)
		camera.zoom = Vector2.ONE * float(game_config.camera.base_zoom)

func _ready() -> void:
	if game_config.is_empty():
		game_config = GameConfigScript.make_default()
	collision_layer = 1
	collision_mask = 2
	queue_redraw()

	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape == null:
		body_shape = CollisionShape2D.new()
		body_shape.name = "CollisionShape2D"
		add_child(body_shape)
	var capsule := body_shape.shape as CapsuleShape2D
	if capsule == null:
		capsule = CapsuleShape2D.new()
		body_shape.shape = capsule
	capsule.radius = float(game_config.player.collision_radius)
	capsule.height = 28.0
	body_shape.position = Vector2(0, 4)

	shadow = get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		shadow.texture = load("res://Assets/Effects/shadow.png")
		add_child(shadow)
	shadow.position = Vector2(0, 15)
	shadow.scale = Vector2(1.15, 1.0)
	shadow.z_index = -1
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)
	sprite.texture = load(PLAYER_SHEET_PATH) as Texture2D
	sprite.hframes = 6
	sprite.vframes = 4
	sprite.scale = Vector2.ONE * float(game_config.player.sprite_scale)
	sprite.position = Vector2(0, -3)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	held_item_sprite = get_node_or_null("HeldItem") as Sprite2D
	if held_item_sprite == null:
		held_item_sprite = Sprite2D.new()
		held_item_sprite.name = "HeldItem"
		add_child(held_item_sprite)
	held_item_sprite.scale = Vector2(0.72, 0.72)
	held_item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	held_item_sprite.z_index = 2
	held_item_sprite.visible = false

	camera = get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
	camera.position_smoothing_enabled = false
	camera.position_smoothing_speed = float(game_config.camera.follow_speed)
	camera.zoom = Vector2.ONE * float(game_config.camera.base_zoom)
	if not Engine.is_editor_hint():
		camera.make_current()

func set_held_item(item_id: String, aim_direction: Vector2) -> void:
	if held_item_sprite == null:
		return
	if not ITEM_TEXTURE_PATHS.has(item_id):
		current_held_item = ""
		held_item_sprite.visible = false
		return
	if current_held_item != item_id:
		held_item_sprite.texture = load(ITEM_TEXTURE_PATHS[item_id]) as Texture2D
		current_held_item = item_id
	var direction := aim_direction.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	var action_sheet_active := attack_animation_time > 0.0 and attack_animation_uses_sheet and attack_animation_item == item_id
	held_item_sprite.visible = not action_sheet_active
	if not held_item_sprite.visible:
		return
	var item_position := direction * 13.0 + Vector2(0, 3)
	var item_rotation := direction.angle()
	if attack_animation_time > 0.0 and attack_animation_item == item_id:
		var progress := 1.0 - attack_animation_time / maxf(attack_animation_duration, 0.001)
		var swing := sin(progress * PI)
		item_position += Vector2(-direction.y, direction.x) * swing * 7.0
		item_rotation += lerpf(-0.85, 0.55, progress)
	held_item_sprite.position = item_position
	held_item_sprite.rotation = item_rotation
	held_item_sprite.z_index = -2 if direction.y < -0.25 else 2

func play_attack_animation(item_id: String, aim_direction: Vector2, duration: float) -> void:
	if sprite == null:
		return
	var direction := aim_direction.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	attack_animation_item = item_id
	attack_animation_duration = maxf(0.16, duration)
	attack_animation_time = attack_animation_duration
	attack_animation_uses_sheet = ATTACK_SHEET_PATHS.has(item_id)
	if absf(direction.x) > absf(direction.y):
		attack_animation_row = 2 if direction.x > 0.0 else 3
	else:
		attack_animation_row = 1 if direction.y < 0.0 else 0
	if attack_animation_uses_sheet:
		sprite.texture = load(ATTACK_SHEET_PATHS[item_id]) as Texture2D
		sprite.hframes = 3
		sprite.vframes = 4
		sprite.frame_coords = Vector2i(0, attack_animation_row)

func _restore_player_sheet() -> void:
	if sprite == null:
		return
	sprite.texture = load(PLAYER_SHEET_PATH) as Texture2D
	sprite.hframes = 6
	sprite.vframes = 4

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = input_vector.length_squared() > 0.001
	if moving:
		last_move_direction = input_vector.normalized()

	if Input.is_action_just_pressed("dodge"):
		_try_dodge(input_vector)

	roll_cooldown_timer = maxf(0.0, roll_cooldown_timer - delta)
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)

	if rolling:
		roll_timer -= delta
		velocity = roll_direction * float(game_config.player.walk_speed) * float(game_config.player.roll_speed_multiplier)
		if roll_timer <= 0.0:
			rolling = false
	else:
		crouching = Input.is_action_pressed("crouch")
		var max_stamina := float(game_config.player.max_stamina)
		var recovery_threshold := max_stamina * float(game_config.player.stamina_sprint_resume) / 100.0
		if stamina_exhausted and current_stamina >= recovery_threshold:
			stamina_exhausted = false

		running = Input.is_action_pressed("run") and moving and not crouching and not stamina_exhausted and current_stamina > 0.0
		var speed := float(game_config.player.walk_speed)
		if crouching:
			speed *= float(game_config.player.crouch_multiplier)
		elif running:
			speed *= float(game_config.player.run_multiplier)
		velocity = input_vector * speed

		if debug_infinite_stamina:
			current_stamina = max_stamina
			stamina_exhausted = false
		elif running:
			current_stamina = maxf(0.0, current_stamina - float(game_config.player.stamina_run_drain) * delta)
			if current_stamina <= 0.0:
				stamina_exhausted = true
				running = false
		else:
			current_stamina = minf(max_stamina, current_stamina + float(game_config.player.stamina_regen) * delta)
			if stamina_exhausted and current_stamina >= recovery_threshold:
				stamina_exhausted = false

	move_and_slide()
	_update_facing(input_vector)
	_update_visuals(delta)
	queue_redraw()

func _try_dodge(input_vector: Vector2) -> void:
	if rolling or roll_cooldown_timer > 0.0:
		return
	if current_stamina < float(game_config.player.roll_stamina_cost) and not debug_infinite_stamina:
		return
	var direction := input_vector.normalized()
	if direction == Vector2.ZERO:
		direction = (get_global_mouse_position() - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = last_move_direction
	roll_direction = direction
	last_move_direction = direction
	rolling = true
	crouching = false
	running = false
	roll_timer = float(game_config.player.roll_duration_ms) / 1000.0
	roll_cooldown_timer = float(game_config.player.roll_cooldown_ms) / 1000.0
	invulnerability_timer = float(game_config.player.roll_invulnerability_ms) / 1000.0
	if not debug_infinite_stamina:
		current_stamina = maxf(0.0, current_stamina - float(game_config.player.roll_stamina_cost))

func _update_facing(input_vector: Vector2) -> void:
	var direction := input_vector
	if rolling:
		direction = roll_direction
	elif direction == Vector2.ZERO:
		direction = get_global_mouse_position() - global_position
	if direction.length_squared() < 0.001:
		return
	if absf(direction.x) > absf(direction.y):
		facing_row = 2 if direction.x < 0.0 else 3
	else:
		facing_row = 1 if direction.y < 0.0 else 0

func _update_visuals(delta: float) -> void:
	sprite.position = Vector2(0, -3)

	attack_animation_time = maxf(0.0, attack_animation_time - delta)
	if attack_animation_time <= 0.0 and attack_animation_uses_sheet:
		attack_animation_uses_sheet = false
		_restore_player_sheet()

	var sheet_row := facing_row
	if facing_row == 2:
		sheet_row = 3
	elif facing_row == 3:
		sheet_row = 2

	if attack_animation_time > 0.0 and attack_animation_uses_sheet:
		var progress := 1.0 - attack_animation_time / maxf(attack_animation_duration, 0.001)
		var action_frame := mini(2, int(floor(progress * 3.0)))
		sprite.frame_coords = Vector2i(action_frame, attack_animation_row)
	elif moving and not rolling:
		walk_animation_time += delta
		idle_animation_time = 0.0
		var interval := 0.085 if running else 0.145
		var frame := int(floor(walk_animation_time / interval)) % 4
		sprite.frame_coords = Vector2i(frame, sheet_row)
	else:
		walk_animation_time = 0.0
		idle_animation_time += delta
		var idle_frame := 4 + (int(floor(idle_animation_time / 0.35)) % 2)
		sprite.frame_coords = Vector2i(idle_frame, sheet_row)

	if rolling:
		sprite.modulate = Color(0.7, 0.85, 1.0, 0.72)
		sprite.rotation = roll_direction.angle() + PI * 0.5
	else:
		sprite.modulate = Color.WHITE
		sprite.rotation = 0.0
	shadow.scale = Vector2(0.9, 0.82) if crouching else Vector2(1.15, 1.0)
	z_index = int(global_position.y / 16.0)

func apply_damage(amount: float) -> bool:
	if amount <= 0.0 or debug_invulnerable or invulnerability_timer > 0.0:
		return false
	current_health = maxf(0.0, current_health - amount)
	return true

func heal(amount: float) -> void:
	current_health = minf(float(game_config.player.max_health), current_health + maxf(0.0, amount))

func set_debug_selected(value: bool) -> void:
	debug_selected = value
	queue_redraw()

func _draw() -> void:
	if debug_selected:
		draw_arc(Vector2(0, -3), 24.0, 0.0, TAU, 40, Color("#8ee6ff"), 2.0, true)
