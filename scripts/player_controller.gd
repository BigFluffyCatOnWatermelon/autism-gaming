extends CharacterBody2D

var game_config: Dictionary = {}
var current_health: float = 100.0
var current_stamina: float = 100.0
var moving := false
var running := false
var crouching := false
var rolling := false
var roll_direction := Vector2.DOWN
var last_move_direction := Vector2.DOWN
var facing_row := 0
var roll_timer := 0.0
var roll_cooldown_timer := 0.0
var invulnerability_timer := 0.0
var walk_animation_time := 0.0

var sprite: Sprite2D
var shadow: Sprite2D
var camera: Camera2D

func configure(settings: Dictionary) -> void:
	game_config = settings
	current_health = float(game_config.player.max_health)
	current_stamina = float(game_config.player.max_stamina)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2

	var body_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = float(game_config.player.collision_radius)
	capsule.height = 28.0
	body_shape.shape = capsule
	body_shape.position = Vector2(0, 4)
	add_child(body_shape)

	shadow = Sprite2D.new()
	shadow.texture = load("res://public/assets/shadow.png")
	shadow.position = Vector2(0, 15)
	shadow.scale = Vector2(1.15, 1.0)
	shadow.z_index = -1
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.texture = load("res://public/assets/player.png")
	sprite.hframes = 4
	sprite.vframes = 5
	sprite.scale = Vector2.ONE * float(game_config.player.sprite_scale)
	sprite.position = Vector2(0, -3)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = float(game_config.camera.follow_speed)
	camera.zoom = Vector2.ONE * float(game_config.camera.base_zoom)
	add_child(camera)
	camera.make_current()

func _physics_process(delta: float) -> void:
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
		running = Input.is_action_pressed("run") and moving and not crouching and current_stamina > 0.0
		var speed := float(game_config.player.walk_speed)
		if crouching:
			speed *= float(game_config.player.crouch_multiplier)
		elif running:
			speed *= float(game_config.player.run_multiplier)
		velocity = input_vector * speed

		if running:
			current_stamina = maxf(0.0, current_stamina - float(game_config.player.stamina_run_drain) * delta)
		else:
			current_stamina = minf(float(game_config.player.max_stamina), current_stamina + float(game_config.player.stamina_regen) * delta)

	move_and_slide()
	_update_facing(input_vector)
	_update_visuals(delta)

func _try_dodge(input_vector: Vector2) -> void:
	if rolling or roll_cooldown_timer > 0.0:
		return
	if current_stamina < float(game_config.player.roll_stamina_cost):
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
	walk_animation_time += delta
	var frame := 0
	if moving and not rolling:
		var interval := 0.085 if running else 0.145
		frame = int(walk_animation_time / interval) % 4
	if crouching:
		sprite.frame_coords = Vector2i(0, 4)
	else:
		sprite.frame_coords = Vector2i(frame, facing_row)
	if rolling:
		sprite.modulate = Color(0.7, 0.85, 1.0, 0.72)
		sprite.rotation = roll_direction.angle() + PI * 0.5
	else:
		sprite.modulate = Color.WHITE
		sprite.rotation = 0.0
	shadow.scale = Vector2(0.9, 0.82) if crouching else Vector2(1.15, 1.0)
	z_index = int(global_position.y / 16.0)
