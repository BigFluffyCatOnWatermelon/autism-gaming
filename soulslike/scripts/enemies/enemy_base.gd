extends CharacterBody3D
class_name EnemyBase

enum AIState { IDLE, CHASE, WINDUP, ATTACK, RECOVER, STUNNED, DEAD }

@export var maximum_health: float = 75.0
@export var move_speed: float = 2.4
@export var detection_range: float = 10.0
@export var attack_range: float = 1.8
@export var attack_damage: float = 18.0
@export var souls_reward: int = 45
@export var attack_windup: float = 0.72
@export var attack_recovery: float = 1.05
@export var gravity: float = 22.0

var current_health: float
var state: AIState = AIState.IDLE
var state_time: float = 0.0
var player: PlayerController
var spawn_position: Vector3

func _ready() -> void:
	current_health = maximum_health
	spawn_position = global_position
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
			if distance <= detection_range:
				state = AIState.CHASE
		AIState.CHASE:
			if distance > detection_range * 1.6:
				state = AIState.IDLE
			elif distance <= attack_range:
				state = AIState.WINDUP
				state_time = attack_windup
			else:
				_move_toward_player(delta)
		AIState.WINDUP:
			_face_player()
			if distance > attack_range * 1.35:
				state = AIState.CHASE
			elif state_time <= 0.0:
				state = AIState.ATTACK
				_perform_attack()
				state = AIState.RECOVER
				state_time = attack_recovery
		AIState.RECOVER:
			if state_time <= 0.0:
				state = AIState.CHASE
		AIState.STUNNED:
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
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)
	_face_player()

func _face_player() -> void:
	var direction := player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _perform_attack() -> void:
	if not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= attack_range + 0.35:
		player.receive_damage(DamageInfo.new(attack_damage, &"physical", 16.0, self))

func receive_damage(info: DamageInfo) -> void:
	if state == AIState.DEAD:
		return
	current_health = maxf(0.0, current_health - info.amount)
	if current_health <= 0.0:
		_die()
	else:
		state = AIState.STUNNED
		state_time = 0.28
		var push := global_position - info.source.global_position if info.source != null else Vector3.ZERO
		push.y = 0.0
		if push.length_squared() > 0.001:
			velocity += push.normalized() * 2.8

func _die() -> void:
	state = AIState.DEAD
	if is_instance_valid(player):
		player.add_souls(souls_reward)
	queue_free()
