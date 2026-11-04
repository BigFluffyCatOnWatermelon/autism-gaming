extends CharacterBody3D
class_name PlayerController

signal stats_changed
signal souls_changed(total: int)
signal player_died

enum ActionState { FREE, WINDUP, ACTIVE, RECOVERY, DODGING, STAGGERED, DEAD }

@export_group("Movement")
@export var walk_speed: float = 4.2
@export var sprint_speed: float = 6.6
@export var acceleration: float = 24.0
@export var gravity: float = 24.0
@export_group("Combat")
@export var max_health: float = 120.0
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 22.0
@export var light_damage: float = 24.0
@export var heavy_damage: float = 43.0
@export var light_cost: float = 20.0
@export var heavy_cost: float = 34.0
@export var dodge_cost: float = 26.0
@export var dodge_speed: float = 10.5
@export var dodge_duration: float = 0.48
@export var invulnerability_duration: float = 0.34

@onready var health: HealthComponent = $Health
@onready var attack_area: Area3D = $AttackArea
@onready var camera: Camera3D = $CameraRig/Camera3D

var stamina: float
var souls: int = 0
var state: ActionState = ActionState.FREE
var action_time: float = 0.0
var queued_attack: StringName = &""
var attack_damage: float = 0.0
var hit_targets: Array[Node] = []
var facing: Vector3 = Vector3.FORWARD
var dodge_direction: Vector3 = Vector3.ZERO
var invulnerability_time: float = 0.0
var blocking: bool = false
var hurt_lock: float = 0.0

func _ready() -> void:
	add_to_group("player")
	stamina = max_stamina
	health.maximum_health = max_health
	health.current_health = max_health
	health.health_changed.emit(health.current_health, health.maximum_health)
	health.depleted.connect(_on_depleted)
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_body_entered)
	stats_changed.emit()
	souls_changed.emit(souls)

func _physics_process(delta: float) -> void:
	if state == ActionState.DEAD:
		return
	invulnerability_time = maxf(0.0, invulnerability_time - delta)
	hurt_lock = maxf(0.0, hurt_lock - delta)
	_update_action(delta)
	_update_movement(delta)
	if state == ActionState.FREE:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
		blocking = Input.is_action_pressed("block") and stamina > 0.0
		if Input.is_action_just_pressed("dodge"):
			_start_dodge()
		elif Input.is_action_just_pressed("heavy_attack"):
			_request_attack(&"heavy")
		elif Input.is_action_just_pressed("light_attack"):
			_request_attack(&"light")
	elif state == ActionState.WINDUP or state == ActionState.ACTIVE or state == ActionState.RECOVERY:
		if Input.is_action_just_pressed("light_attack") or Input.is_action_just_pressed("heavy_attack"):
			queued_attack = &"heavy" if Input.is_action_just_pressed("heavy_attack") else &"light"
	stats_changed.emit()

func _update_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_basis := camera.global_basis
	var forward := -camera_basis.z
	var right := camera_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var move_direction := (right * input_vector.x + forward * input_vector.y).normalized()
	if state == ActionState.DODGING:
		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed
	elif state == ActionState.STAGGERED:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	else:
		var sprinting := Input.is_action_pressed("sprint") and stamina > 1.0 and not blocking and state == ActionState.FREE
		var speed := sprint_speed if sprinting else walk_speed
		if sprinting and move_direction.length_squared() > 0.01:
			stamina = maxf(0.0, stamina - 17.0 * delta)
		if blocking:
			speed *= 0.48
		if state != ActionState.FREE:
			speed *= 0.25
		velocity.x = move_toward(velocity.x, move_direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * speed, acceleration * delta)
		if move_direction.length_squared() > 0.01 and state == ActionState.FREE:
			facing = move_direction
			rotation.y = atan2(-facing.x, -facing.z)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
	move_and_slide()

func _request_attack(kind: StringName) -> void:
	if state != ActionState.FREE:
		queued_attack = kind
		return
	var cost := heavy_cost if kind == &"heavy" else light_cost
	if stamina < cost:
		return
	stamina -= cost
	attack_damage = heavy_damage if kind == &"heavy" else light_damage
	state = ActionState.WINDUP
	action_time = 0.42 if kind == &"heavy" else 0.22
	attack_area.scale = Vector3.ONE * (1.25 if kind == &"heavy" else 1.0)
	hit_targets.clear()
	blocking = false

func _start_dodge() -> void:
	if state != ActionState.FREE or stamina < dodge_cost:
		return
	stamina -= dodge_cost
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_vector.x, 0.0, input_vector.y)
	if dir.length_squared() > 0.01:
		var basis := camera.global_basis
		dir = basis.x * dir.x - basis.z * dir.z
		dir.y = 0.0
		dodge_direction = dir.normalized()
	else:
		dodge_direction = facing
	state = ActionState.DODGING
	action_time = dodge_duration
	invulnerability_time = invulnerability_duration
	blocking = false

func _update_action(delta: float) -> void:
	if state == ActionState.FREE:
		return
	action_time -= delta
	if state == ActionState.WINDUP and action_time <= 0.0:
		state = ActionState.ACTIVE
		action_time = 0.16 if attack_damage == light_damage else 0.23
		attack_area.monitoring = true
		_check_attack_overlaps()
	elif state == ActionState.ACTIVE:
		_check_attack_overlaps()
		if action_time <= 0.0:
			attack_area.monitoring = false
			state = ActionState.RECOVERY
			action_time = 0.42 if attack_damage == light_damage else 0.68
	elif action_time <= 0.0:
		if state == ActionState.DODGING or state == ActionState.RECOVERY or state == ActionState.STAGGERED:
			state = ActionState.FREE
		if queued_attack != &"" and state == ActionState.FREE:
			var next_attack := queued_attack
			queued_attack = &""
			_request_attack(next_attack)

func _check_attack_overlaps() -> void:
	for body in attack_area.get_overlapping_bodies():
		_on_attack_body_entered(body)

func _on_attack_body_entered(body: Node3D) -> void:
	if state != ActionState.ACTIVE or hit_targets.has(body):
		return
	if body.has_method("receive_damage"):
		hit_targets.append(body)
		body.receive_damage(DamageInfo.new(attack_damage, &"physical", 22.0, self))

func receive_damage(info: DamageInfo) -> void:
	if state == ActionState.DEAD or invulnerability_time > 0.0 or hurt_lock > 0.0:
		return
	var damage := info.amount
	if blocking:
		damage *= 0.28
		stamina = maxf(0.0, stamina - info.amount * 0.85)
		if stamina <= 0.0:
			blocking = false
			state = ActionState.STAGGERED
			action_time = 0.8
	if state != ActionState.STAGGERED:
		health.apply_damage(damage)
	hurt_lock = 0.18
	stats_changed.emit()

func add_souls(amount: int) -> void:
	souls += maxi(0, amount)
	souls_changed.emit(souls)

func _on_depleted() -> void:
	state = ActionState.DEAD
	attack_area.monitoring = false
	player_died.emit()
