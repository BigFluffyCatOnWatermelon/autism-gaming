extends CharacterBody2D

const GameConfigScript = preload("res://scripts/game_config.gd")
const WORLD_Z_SORT_OFFSET := 2048
@export_group("Анимации персонажа")
@export_subgroup("Idle")
@export var idle_sheet: Texture2D = preload("res://Assets/CozyVillageFarm/08_Characters/Player/player_walk_idle_sheet.png")
@export_range(1, 256, 1) var idle_columns: int = 6
@export_range(1, 256, 1) var idle_rows: int = 4
## Legacy fallback used by older scenes when Idle Frames Per Direction is 0.
@export_range(1, 256, 1) var idle_frame_count: int = 2
## 0 = use the legacy Idle Frame Count value above.
@export_range(0, 256, 1) var idle_frames_per_direction: int = 0
@export var idle_flip_h := false
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var idle_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Walk")
@export var movement_sheet: Texture2D = preload("res://Assets/CozyVillageFarm/08_Characters/Player/player_walk_idle_sheet.png")
@export_range(1, 256, 1) var movement_columns: int = 6
@export_range(1, 256, 1) var movement_rows: int = 4
@export var walk_flip_h := false
@export_range(1, 256, 1) var movement_frames_per_direction: int = 4
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var movement_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Run")
@export var run_sheet: Texture2D
@export_range(1, 256, 1) var run_columns: int = 6
@export_range(1, 256, 1) var run_rows: int = 4
@export var run_flip_h := false
@export_range(1, 256, 1) var run_frames_per_direction: int = 8
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var run_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Sitting")
@export var sitting_sheet: Texture2D
@export_range(1, 256, 1) var sitting_columns: int = 1
@export_range(1, 256, 1) var sitting_rows: int = 1
@export var sitting_flip_h := false
@export_range(1, 256, 1) var sitting_frames_per_direction: int = 1
## Same eight-direction order as other animations. Empty uses the legacy four-row layout.
@export var sitting_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Hurt")
@export var hurt_sheet: Texture2D
@export_range(1, 256, 1) var hurt_columns: int = 3
@export_range(1, 256, 1) var hurt_rows: int = 4
@export var hurt_flip_h := false
@export_range(1, 256, 1) var hurt_frames_per_direction: int = 3
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var hurt_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Death")
@export var death_sheet: Texture2D
@export_range(1, 256, 1) var death_columns: int = 4
@export_range(1, 256, 1) var death_rows: int = 4
@export var death_flip_h := false
@export_range(1, 256, 1) var death_frames_per_direction: int = 4
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var death_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Dodge")
@export var dodge_sheet: Texture2D
@export_range(1, 256, 1) var dodge_columns: int = 5
@export_range(1, 256, 1) var dodge_rows: int = 4
@export var dodge_flip_h := false
@export_range(1, 256, 1) var dodge_frames_per_direction: int = 5
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var dodge_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Interact")
@export var interact_sheet: Texture2D
@export_range(1, 256, 1) var interact_columns: int = 4
@export_range(1, 256, 1) var interact_rows: int = 4
@export var interact_flip_h := false
@export_range(1, 256, 1) var interact_frames_per_direction: int = 4
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var interact_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_group("Боевые анимации")
@export_subgroup("Axe")
@export var axe_attack_sheet: Texture2D = preload("res://Assets/CozyVillageFarm/08_Characters/Player/player_action_axe.png")
@export_range(1, 256, 1) var axe_attack_columns: int = 3
@export_range(1, 256, 1) var axe_attack_rows: int = 4
@export var axe_attack_flip_h := false
@export_range(1, 256, 1) var axe_attack_frames_per_direction: int = 3
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var axe_attack_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Pickaxe")
@export var pickaxe_attack_sheet: Texture2D = preload("res://Assets/CozyVillageFarm/08_Characters/Player/player_action_pickaxe.png")
@export_range(1, 256, 1) var pickaxe_attack_columns: int = 3
@export_range(1, 256, 1) var pickaxe_attack_rows: int = 4
@export var pickaxe_attack_flip_h := false
@export_range(1, 256, 1) var pickaxe_attack_frames_per_direction: int = 3
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var pickaxe_attack_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Sword Slash")
@export var sword_slash_sheet: Texture2D = preload("res://Assets/CozyVillageFarm/08_Characters/Player/player_action_axe.png")
@export_range(1, 256, 1) var sword_slash_columns: int = 3
@export_range(1, 256, 1) var sword_slash_rows: int = 4
@export var sword_slash_flip_h := false
@export_range(1, 256, 1) var sword_slash_frames_per_direction: int = 3
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var sword_slash_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Sword Thrust")
@export var sword_thrust_sheet: Texture2D = preload("res://Assets/CozyVillageFarm/08_Characters/Player/player_action_pickaxe.png")
@export_range(1, 256, 1) var sword_thrust_columns: int = 3
@export_range(1, 256, 1) var sword_thrust_rows: int = 4
@export var sword_thrust_flip_h := false
@export_range(1, 256, 1) var sword_thrust_frames_per_direction: int = 3
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var sword_thrust_direction_frame_starts: PackedInt32Array = PackedInt32Array()

@export_subgroup("Bow")
@export var bow_attack_sheet: Texture2D
@export_range(1, 256, 1) var bow_attack_columns: int = 5
@export_range(1, 256, 1) var bow_attack_rows: int = 4
@export var bow_attack_flip_h := false
@export_range(1, 256, 1) var bow_attack_frames_per_direction: int = 5
## Порядок направлений: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Значение — линейный индекс первого кадра (row * columns + column). Пример: 8 направлений по 4 кадра в одной строке: Columns=32, Rows=1, Frames per direction=4, массив [0,4,8,12,16,20,24,28]. Пустой массив включает совместимый режим старых 4 строк.
@export var bow_attack_direction_frame_starts: PackedInt32Array = PackedInt32Array()

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
var facing_direction_index := 0
var roll_timer := 0.0
var roll_cooldown_timer := 0.0
var invulnerability_timer := 0.0
var walk_animation_time := 0.0
var idle_animation_time := 0.0
var sitting_animation_time := 0.0
var attack_animation_time := 0.0
var attack_animation_duration := 0.0
var attack_animation_item := ""
var attack_animation_frame_start := 0
var attack_animation_direction_index := 0
var attack_animation_uses_sheet := false
var active_attack_columns := 3
var active_attack_rows := 4
var active_attack_frames_per_direction := 3
var active_attack_direction_frame_starts: PackedInt32Array = PackedInt32Array()
var active_animation_flip_h := false
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
	shadow.position = Vector2(0, 0)
	shadow.scale = Vector2(1.15, 1.0)
	shadow.z_index = -1
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)
	sprite.texture = movement_sheet
	sprite.hframes = maxi(1, movement_columns)
	sprite.vframes = maxi(1, movement_rows)
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

# Shared world-space anchors. CharacterBody2D stays at the physics-body origin.
# The collision capsule is centered at y=4 with height 28, so its bottom is y=18.
const GROUND_ANCHOR := Vector2(0.0, 18.0)
const AIM_ANCHOR := Vector2(0.0, -3.0)
const HAND_DISTANCE := 13.0
const HAND_OFFSET := Vector2(0.0, 3.0)

func get_ground_position() -> Vector2:
	return to_global(GROUND_ANCHOR)

func get_foot_sort_y() -> float:
	return get_ground_position().y

func _get_direction_index(direction: Vector2) -> int:
	if direction.length_squared() < 0.001:
		return facing_direction_index
	# Clockwise order, starting at Down.
	var angle := atan2(direction.x, direction.y)
	return posmod(roundi(angle / (PI / 4.0)), 8)


func _get_legacy_direction_start_frame(direction_index: int, columns: int) -> int:
	# Compatibility with the original four-row sheets:
	# Down, Up, Right, Left. Diagonals use the vertical direction as before.
	var row := 0
	match direction_index:
		2:
			row = 2 # Right
		3, 4, 5:
			row = 1 # Up and upper diagonals
		6:
			row = 3 # Left
		_:
			row = 0 # Down and lower diagonals
	return row * maxi(1, columns)


func _get_direction_start_frame(
		direction_frame_starts: PackedInt32Array,
		direction_index: int,
		columns: int
	) -> int:
	if direction_index >= 0 and direction_index < direction_frame_starts.size():
		var configured_start := direction_frame_starts[direction_index]
		if configured_start >= 0:
			return configured_start
	return _get_legacy_direction_start_frame(direction_index, columns)


func _get_frame_coords(frame_index: int, columns: int) -> Vector2i:
	var safe_columns := maxi(1, columns)
	var safe_index := maxi(0, frame_index)
	return Vector2i(safe_index % safe_columns, floori(float(safe_index) / float(safe_columns)))


func _set_sprite_frame(frame_index: int) -> void:
	if sprite == null:
		return
	var frame_total := maxi(1, sprite.hframes * sprite.vframes)
	var safe_index := clampi(frame_index, 0, frame_total - 1)
	sprite.frame_coords = _get_frame_coords(safe_index, sprite.hframes)


func get_aim_position() -> Vector2:
	return to_global(AIM_ANCHOR)

func get_hand_local_position(aim_direction: Vector2) -> Vector2:
	var direction := aim_direction.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	return direction * HAND_DISTANCE + HAND_OFFSET

func get_hand_position(aim_direction: Vector2) -> Vector2:
	return to_global(get_hand_local_position(aim_direction))

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

func play_attack_animation(item_id: String, aim_direction: Vector2, duration: float, animation_id: String = "") -> void:
	if sprite == null:
		return
	var direction := aim_direction.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT

	# item_id identifies the equipped item (used to hide its hand sprite).
	# animation_id selects the actual action sheet. For example, sword slashes
	# use the axe swing sheet and sword thrusts use the pickaxe strike sheet.
	var sheet_id := animation_id if not animation_id.is_empty() else item_id
	var action_texture: Texture2D
	var action_direction_frame_starts := PackedInt32Array()
	var action_frames_per_direction := 3
	match sheet_id:
		"axe":
			action_texture = axe_attack_sheet
			active_attack_columns = axe_attack_columns
			active_attack_rows = axe_attack_rows
			action_direction_frame_starts = axe_attack_direction_frame_starts
			action_frames_per_direction = axe_attack_frames_per_direction
		"pickaxe":
			action_texture = pickaxe_attack_sheet
			active_attack_columns = pickaxe_attack_columns
			active_attack_rows = pickaxe_attack_rows
			action_direction_frame_starts = pickaxe_attack_direction_frame_starts
			action_frames_per_direction = pickaxe_attack_frames_per_direction
		"sword_slash":
			action_texture = sword_slash_sheet
			active_attack_columns = sword_slash_columns
			active_attack_rows = sword_slash_rows
			action_direction_frame_starts = sword_slash_direction_frame_starts
			action_frames_per_direction = sword_slash_frames_per_direction
		"sword_thrust":
			action_texture = sword_thrust_sheet
			active_attack_columns = sword_thrust_columns
			active_attack_rows = sword_thrust_rows
			action_direction_frame_starts = sword_thrust_direction_frame_starts
			action_frames_per_direction = sword_thrust_frames_per_direction
		"bow":
			action_texture = bow_attack_sheet
			active_attack_columns = bow_attack_columns
			active_attack_rows = bow_attack_rows
			action_direction_frame_starts = bow_attack_direction_frame_starts
			action_frames_per_direction = bow_attack_frames_per_direction
		_:
			action_texture = null

	match sheet_id:
		"axe": active_animation_flip_h = axe_attack_flip_h
		"pickaxe": active_animation_flip_h = pickaxe_attack_flip_h
		"sword_slash": active_animation_flip_h = sword_slash_flip_h
		"sword_thrust": active_animation_flip_h = sword_thrust_flip_h
		"bow": active_animation_flip_h = bow_attack_flip_h

	if action_texture == null:
		attack_animation_time = 0.0
		attack_animation_uses_sheet = false
		attack_animation_item = item_id
		return

	attack_animation_item = item_id
	attack_animation_duration = maxf(0.24, duration)
	attack_animation_time = attack_animation_duration
	attack_animation_uses_sheet = true

	active_attack_direction_frame_starts = action_direction_frame_starts
	active_attack_frames_per_direction = maxi(1, active_attack_columns if action_direction_frame_starts.is_empty() else action_frames_per_direction)
	attack_animation_direction_index = _get_direction_index(direction)

	# Configure the full sprite-sheet grid and direction frame starts in the Inspector.
	sprite.texture = action_texture
	sprite.hframes = maxi(1, active_attack_columns)
	sprite.vframes = maxi(1, active_attack_rows)
	attack_animation_frame_start = _get_direction_start_frame(
		active_attack_direction_frame_starts,
		attack_animation_direction_index,
		sprite.hframes
	)
	_set_sprite_frame(attack_animation_frame_start)
	sprite.flip_h = active_animation_flip_h

func _restore_player_sheet() -> void:
	if sprite == null:
		return
	sprite.texture = movement_sheet
	sprite.hframes = maxi(1, movement_columns)
	sprite.vframes = maxi(1, movement_rows)
	sprite.flip_h = false

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
	facing_direction_index = _get_direction_index(direction)

func _update_visuals(delta: float) -> void:
	sprite.position = Vector2(0, -3)

	attack_animation_time = maxf(0.0, attack_animation_time - delta)
	if attack_animation_time <= 0.0 and attack_animation_uses_sheet:
		attack_animation_uses_sheet = false
		_restore_player_sheet()

	if attack_animation_time > 0.0 and attack_animation_uses_sheet:
		var progress := 1.0 - attack_animation_time / maxf(attack_animation_duration, 0.001)
		var action_frame := mini(
			active_attack_frames_per_direction - 1,
			int(floor(progress * float(active_attack_frames_per_direction)))
		)
		_set_sprite_frame(attack_animation_frame_start + action_frame)
	elif crouching and not moving and not rolling and sitting_sheet != null:
		walk_animation_time = 0.0
		idle_animation_time = 0.0
		sitting_animation_time += delta
		sprite.texture = sitting_sheet
		sprite.hframes = maxi(1, sitting_columns)
		sprite.vframes = maxi(1, sitting_rows)
		var sitting_start := _get_direction_start_frame(
			sitting_direction_frame_starts,
			facing_direction_index,
			sprite.hframes
		)
		var sitting_count := maxi(1, sitting_frames_per_direction)
		var sitting_frame := int(floor(sitting_animation_time / 0.35)) % sitting_count
		_set_sprite_frame(sitting_start + sitting_frame)
		sprite.flip_h = sitting_flip_h
	elif moving and not rolling:
		walk_animation_time += delta
		idle_animation_time = 0.0
		sitting_animation_time = 0.0
		if running and run_sheet != null:
			sprite.texture = run_sheet
			sprite.hframes = maxi(1, run_columns)
			sprite.vframes = maxi(1, run_rows)
			var run_start := _get_direction_start_frame(run_direction_frame_starts, facing_direction_index, sprite.hframes)
			var run_count := maxi(1, run_frames_per_direction)
			if run_direction_frame_starts.is_empty():
				run_count = sprite.hframes
			var run_frame := int(floor(walk_animation_time / 0.085)) % run_count
			_set_sprite_frame(run_start + run_frame)
			sprite.flip_h = run_flip_h
		else:
			sprite.texture = movement_sheet
			sprite.hframes = maxi(1, movement_columns)
			sprite.vframes = maxi(1, movement_rows)
			var walk_start := _get_direction_start_frame(movement_direction_frame_starts, facing_direction_index, sprite.hframes)
			var walk_count := maxi(1, movement_frames_per_direction)
			if movement_direction_frame_starts.is_empty():
				walk_count = maxi(1, mini(4, sprite.hframes))
			var frame := int(floor(walk_animation_time / (0.145 if not running else 0.085))) % walk_count
			_set_sprite_frame(walk_start + frame)
			sprite.flip_h = walk_flip_h
	else:
		walk_animation_time = 0.0
		sitting_animation_time = 0.0
		idle_animation_time += delta
		var has_separate_idle_sheet := idle_sheet != null
		var selected_idle_sheet: Texture2D = idle_sheet if has_separate_idle_sheet else movement_sheet
		var selected_idle_columns := maxi(1, idle_columns if has_separate_idle_sheet else movement_columns)
		var selected_idle_rows := maxi(1, idle_rows if has_separate_idle_sheet else movement_rows)
		var selected_idle_direction_starts := idle_direction_frame_starts if has_separate_idle_sheet else movement_direction_frame_starts
		sprite.texture = selected_idle_sheet
		sprite.hframes = selected_idle_columns
		sprite.vframes = selected_idle_rows
		var idle_max_frames := sprite.hframes * sprite.vframes if not selected_idle_direction_starts.is_empty() else sprite.hframes
		var configured_idle_frames := idle_frames_per_direction if idle_frames_per_direction > 0 else idle_frame_count
		var idle_count := clampi(configured_idle_frames, 1, idle_max_frames)
		var idle_start := _get_direction_start_frame(selected_idle_direction_starts, facing_direction_index, sprite.hframes)
		# Legacy sheets place idle frames at the end of each direction row.
		if selected_idle_direction_starts.is_empty():
			idle_start += maxi(0, selected_idle_columns - idle_count)
		var idle_frame := int(floor(idle_animation_time / 0.35)) % idle_count
		_set_sprite_frame(idle_start + idle_frame)
		sprite.flip_h = idle_flip_h

	if rolling:
		sprite.modulate = Color(0.7, 0.85, 1.0, 0.72)
		sprite.rotation = roll_direction.angle() + PI * 0.5
	else:
		sprite.modulate = Color.WHITE
		sprite.rotation = 0.0
	shadow.scale = Vector2(0.9, 0.82) if crouching else Vector2(1.15, 1.0)
	z_as_relative = false
	z_index = clampi(floori(get_foot_sort_y()) + WORLD_Z_SORT_OFFSET + 1, -4096, 4096)

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
