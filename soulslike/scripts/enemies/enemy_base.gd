extends CharacterBody3D
class_name EnemyBase

enum AIState { IDLE, CHASE, WINDUP, ATTACK, RECOVER, STUNNED, DEAD }

@export var enemy_title := "Ashen Hollow"
@export var maximum_health := 75.0
@export var move_speed := 2.55
@export var detection_range := 10.0
@export var attack_range := 2.0
@export var attack_damage := 18.0
@export var souls_reward := 45
@export var attack_windup := 0.82
@export var attack_recovery := 1.12
@export var gravity := 22.0
@export var attack_arc_degrees := 105.0

@onready var body_visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var telegraph: MeshInstance3D = $Telegraph

var current_health: float
var state: AIState = AIState.IDLE
var state_time := 0.0
var player: PlayerController
var spawn_position: Vector3
var spawn_rotation: Vector3
var reward_given := false
var base_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("enemies")
	current_health = maximum_health
	spawn_position = global_position
	spawn_rotation = global_rotation
	telegraph.visible = false
	var torso := body_visual.get_node_or_null("Torso") as MeshInstance3D
	if torso != null:
		base_material = torso.material_override as StandardMaterial3D
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0] as PlayerController

func _physics_process(delta: float) -> void:
	if state == AIState.DEAD:
		return
	if player == null or not is_instance_valid(player):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0] as PlayerController
		return

	state_time = maxf(0.0, state_time - delta)
	var distance := global_position.distance_to(player.global_position)
	match state:
		AIState.IDLE:
			_stop_horizontal(delta)
			if distance <= detection_range:
				state = AIState.CHASE
		AIState.CHASE:
			if distance > detection_range * 1.75:
				state = AIState.IDLE
			elif distance <= attack_range:
				state = AIState.WINDUP
				state_time = attack_windup
				_set_telegraph(true)
			else:
				_move_toward_player(delta)
		AIState.WINDUP:
			_stop_horizontal(delta)
			_face_player()
			if distance > attack_range * 1.55:
				state = AIState.CHASE
				_set_telegraph(false)
			elif state_time <= 0.0:
				state = AIState.ATTACK
				_set_telegraph(false)
				_perform_attack()
				state = AIState.RECOVER
				state_time = attack_recovery
		AIState.RECOVER:
			_stop_horizontal(delta)
			if state_time <= 0.0:
				state = AIState.CHASE
		AIState.STUNNED:
			_stop_horizontal(delta)
			if state_time <= 0.0:
				state = AIState.CHASE
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
	move_and_slide()

func _move_toward_player(delta: float) -> void:
	var direction := player.global_position - global_position
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 14.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 14.0 * delta)
	_face_player()

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)

func _face_player() -> void:
	if not is_instance_valid(player):
		return
	var direction := player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _perform_attack() -> void:
	if not is_instance_valid(player):
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	if offset.length() > attack_range + 0.35:
		return
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.dot(offset.normalized()) < cos(deg_to_rad(attack_arc_degrees * 0.5)):
		return
	player.receive_damage(DamageInfo.new(attack_damage, &"physical", 18.0, self))

func _set_telegraph(enabled: bool) -> void:
	telegraph.visible = enabled
	if enabled:
		telegraph.scale = Vector3(0.7, 1.0, 0.7)
		var tween := create_tween()
		tween.tween_property(telegraph, "scale", Vector3.ONE, attack_windup)

func receive_damage(info: DamageInfo) -> void:
	if state == AIState.DEAD:
		return
	current_health = maxf(0.0, current_health - info.amount)
	_flash_hit()
	if current_health <= 0.0:
		_die()
	else:
		state = AIState.STUNNED
		state_time = 0.38 if info.poise_damage >= 20.0 else 0.24
		var push := global_position - info.source.global_position if info.source != null else Vector3.ZERO
		push.y = 0.0
		if push.length_squared() > 0.001:
			velocity += push.normalized() * 3.2

func on_parried(_source: Node3D) -> void:
	if state == AIState.DEAD:
		return
	state = AIState.STUNNED
	state_time = 2.0
	_set_telegraph(false)
	_flash_hit()

func _flash_hit() -> void:
	var mesh := body_visual.get_node_or_null("Torso") as MeshInstance3D
	if mesh == null:
		return
	var flash := StandardMaterial3D.new()
	flash.albedo_color = Color(1.0, 0.55, 0.42, 1.0)
	flash.emission_enabled = true
	flash.emission = Color(1.0, 0.18, 0.08, 1.0)
	flash.emission_energy_multiplier = 1.5
	mesh.material_override = flash
	var tween := create_tween()
	tween.tween_interval(0.11)
	tween.tween_callback(func() -> void:
		if is_instance_valid(mesh):
			mesh.material_override = base_material
	)

func _die() -> void:
	state = AIState.DEAD
	_set_telegraph(false)
	if not reward_given and is_instance_valid(player):
		reward_given = true
		player.add_souls(souls_reward)
	body_visual.visible = false
	collision_shape.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

func reset_enemy() -> void:
	state = AIState.IDLE
	state_time = 0.0
	current_health = maximum_health
	reward_given = false
	global_position = spawn_position
	global_rotation = spawn_rotation
	velocity = Vector3.ZERO
	body_visual.visible = true
	collision_shape.set_deferred("disabled", false)
	collision_layer = 2
	collision_mask = 3
	telegraph.visible = false
	set_physics_process(true)
