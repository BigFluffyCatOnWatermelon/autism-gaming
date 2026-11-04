extends CharacterBody3D
class_name PlayerController

signal stats_changed
signal souls_changed(total: int)
signal player_died
signal interaction_prompt_changed(prompt: String)
signal status_message(message: String)

enum ActionState { FREE, WINDUP, ACTIVE, RECOVERY, DODGING, STAGGERED, DEAD }

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.2
@export var acceleration := 32.0
@export var gravity := 24.0
@export var camera_offset := Vector3(0.0, 13.0, 10.0)
@export_group("Combat")
@export var max_health := 120.0
@export var max_stamina := 100.0
@export var stamina_regen := 26.0
@export var stamina_regen_delay := 0.65
@export var light_damage := 25.0
@export var heavy_damage := 48.0
@export var light_cost := 19.0
@export var heavy_cost := 36.0
@export var dodge_cost := 25.0
@export var dodge_speed := 11.5
@export var dodge_duration := 0.48
@export var invulnerability_duration := 0.34
@export var parry_window_duration := 0.24
@export_group("Flasks")
@export var flask_heal_amount := 48.0
@export var max_flasks := 3

@onready var health: HealthComponent = $Health
@onready var attack_area: Area3D = $AttackArea
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D

var stamina := 100.0
var souls := 0
var flask_charges := 3
var state: ActionState = ActionState.FREE
var action_time := 0.0
var queued_attack: StringName = &""
var attack_damage := 0.0
var hit_targets: Array[Node] = []
var facing := Vector3.FORWARD
var dodge_direction := Vector3.ZERO
var invulnerability_time := 0.0
var parry_window := 0.0
var stamina_regen_wait := 0.0
var hurt_lock := 0.0
var blocking := false
var riposte_ready := false
var current_interactable: Node3D
var locked_target: Node3D

func _ready() -> void:
	add_to_group("player")
	apply_progression_stats(false)
	stamina = max_stamina
	flask_charges = max_flasks
	health.maximum_health = max_health
	health.current_health = max_health
	health.health_changed.emit(health.current_health, health.maximum_health)
	health.depleted.connect(_on_depleted)
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_body_entered)
	# The camera has its own world-space compass; character yaw cannot rotate WASD.
	camera_rig.top_level = true
	camera_rig.global_position = global_position
	camera_rig.global_rotation = Vector3.ZERO
	camera.position = camera_offset
	if RunState.has_checkpoint:
		global_position = RunState.checkpoint_position
	RunState.souls_changed.connect(_on_run_souls_changed)
	_on_run_souls_changed(RunState.souls)
	stats_changed.emit()

func _process(delta: float) -> void:
	camera_rig.global_position = camera_rig.global_position.lerp(global_position, minf(1.0, delta * 9.0))
	_update_interactable_prompt()

func _physics_process(delta: float) -> void:
	if state == ActionState.DEAD:
		return
	invulnerability_time = maxf(0.0, invulnerability_time - delta)
	parry_window = maxf(0.0, parry_window - delta)
	hurt_lock = maxf(0.0, hurt_lock - delta)
	stamina_regen_wait = maxf(0.0, stamina_regen_wait - delta)
	_update_action(delta)
	_update_movement(delta)

	if state == ActionState.FREE:
		if stamina_regen_wait <= 0.0 and not blocking:
			stamina = minf(max_stamina, stamina + stamina_regen * delta)
		blocking = Input.is_action_pressed("block") and stamina > 0.0
		if Input.is_action_just_pressed("interact"):
			_interact()
		if Input.is_action_just_pressed("parry"):
			_start_parry()
		elif Input.is_action_just_pressed("dodge"):
			_start_dodge()
		elif Input.is_action_just_pressed("heavy_attack"):
			_request_attack(&"heavy")
		elif Input.is_action_just_pressed("light_attack"):
			_request_attack(&"light")
		elif Input.is_action_just_pressed("heal"):
			_use_flask()
		if Input.is_action_just_pressed("lock_target"):
			_toggle_target_lock()
	elif state == ActionState.WINDUP or state == ActionState.ACTIVE or state == ActionState.RECOVERY:
		if Input.is_action_just_pressed("light_attack") or Input.is_action_just_pressed("heavy_attack"):
			queued_attack = &"heavy" if Input.is_action_just_pressed("heavy_attack") else &"light"
	stats_changed.emit()

func _update_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Both camera and character movement use a fixed world compass.
	var forward := -camera_rig.global_basis.z
	var right := camera_rig.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var move_direction := (right * input_vector.x - forward * input_vector.y).normalized()

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
			stamina = maxf(0.0, stamina - 19.0 * delta)
			stamina_regen_wait = stamina_regen_delay
		if blocking:
			speed *= 0.42
		if state != ActionState.FREE:
			speed *= 0.18
		velocity.x = move_toward(velocity.x, move_direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * speed, acceleration * delta)
		if locked_target != null and is_instance_valid(locked_target):
			_face_position(locked_target.global_position)
		elif move_direction.length_squared() > 0.01 and state == ActionState.FREE:
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
		status_message.emit("Not enough stamina")
		return
	stamina -= cost
	stamina_regen_wait = stamina_regen_delay
	attack_damage = heavy_damage if kind == &"heavy" else light_damage
	if riposte_ready:
		attack_damage *= 1.8
		riposte_ready = false
	state = ActionState.WINDUP
	action_time = 0.46 if kind == &"heavy" else 0.24
	attack_area.scale = Vector3.ONE * (1.35 if kind == &"heavy" else 1.0)
	hit_targets.clear()
	blocking = false
	if has_node("Weapon"):
		(get_node("Weapon") as Node3D).visible = true

func _start_dodge() -> void:
	if state != ActionState.FREE or stamina < dodge_cost:
		return
	stamina -= dodge_cost
	stamina_regen_wait = stamina_regen_delay
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3.ZERO
	if input_vector.length_squared() > 0.01:
		direction = camera_rig.global_basis.x * input_vector.x + camera_rig.global_basis.z * input_vector.y
		direction.y = 0.0
	dodge_direction = direction.normalized() if direction.length_squared() > 0.01 else facing
	state = ActionState.DODGING
	action_time = dodge_duration
	invulnerability_time = invulnerability_duration
	blocking = false

func _start_parry() -> void:
	if state != ActionState.FREE or stamina < 12.0:
		return
	stamina -= 12.0
	stamina_regen_wait = stamina_regen_delay
	parry_window = parry_window_duration
	state = ActionState.RECOVERY
	action_time = 0.34
	blocking = false
	status_message.emit("Parry!")

func _use_flask() -> void:
	if state != ActionState.FREE or flask_charges <= 0 or health.current_health >= health.maximum_health:
		return
	flask_charges -= 1
	health.restore(flask_heal_amount)
	state = ActionState.RECOVERY
	action_time = 0.42
	blocking = false
	status_message.emit("Estus restored health")
	stats_changed.emit()

func _update_action(delta: float) -> void:
	if state == ActionState.FREE:
		return
	action_time -= delta
	if state == ActionState.WINDUP and action_time <= 0.0:
		state = ActionState.ACTIVE
		action_time = 0.19 if attack_damage <= heavy_damage else 0.25
		attack_area.monitoring = true
		_check_attack_overlaps()
	elif state == ActionState.ACTIVE:
		_check_attack_overlaps()
		if action_time <= 0.0:
			attack_area.monitoring = false
			state = ActionState.RECOVERY
			action_time = 0.42 if attack_damage <= heavy_damage else 0.58
			if has_node("Weapon"):
				(get_node("Weapon") as Node3D).visible = false
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
		body.receive_damage(DamageInfo.new(attack_damage, &"physical", 26.0, self))
		status_message.emit("Hit!")

func receive_damage(info: DamageInfo) -> void:
	if state == ActionState.DEAD or invulnerability_time > 0.0 or hurt_lock > 0.0:
		return
	if parry_window > 0.0:
		if info.source != null and info.source.has_method("on_parried"):
			info.source.on_parried(self)
		riposte_ready = true
		stamina = minf(max_stamina, stamina + 16.0)
		parry_window = 0.0
		status_message.emit("PARRY — RIPOSTE READY")
		stats_changed.emit()
		return
	var damage := info.amount
	if blocking:
		damage *= 0.24
		stamina = maxf(0.0, stamina - info.amount * 0.9)
		stamina_regen_wait = stamina_regen_delay
		if stamina <= 0.0:
			blocking = false
			state = ActionState.STAGGERED
			action_time = 0.9
			status_message.emit("GUARD BROKEN")
	health.apply_damage(damage)
	hurt_lock = 0.22
	stats_changed.emit()

func _interact() -> void:
	if current_interactable != null and is_instance_valid(current_interactable) and current_interactable.has_method("interact"):
		current_interactable.interact(self)

func _update_interactable_prompt() -> void:
	var best: Node3D
	var best_distance := 3.2
	for candidate in get_tree().get_nodes_in_group("interactables"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate as Node3D
	if best != current_interactable:
		current_interactable = best
		var prompt := ""
		if best != null and best.has_method("get_interaction_text"):
			prompt = best.get_interaction_text(self)
		interaction_prompt_changed.emit(prompt)

func _toggle_target_lock() -> void:
	if locked_target != null and is_instance_valid(locked_target):
		locked_target = null
		status_message.emit("Target unlocked")
		return
	var nearest: Node3D
	var nearest_distance := 18.0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance < nearest_distance and (candidate as Node3D).visible:
			nearest = candidate as Node3D
			nearest_distance = distance
	locked_target = nearest
	status_message.emit("Target locked" if nearest != null else "No target nearby")

func _face_position(target_position: Vector3) -> void:
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		facing = direction.normalized()
		rotation.y = atan2(-facing.x, -facing.z)

func add_souls(amount: int) -> void:
	RunState.add_souls(amount)

func _on_run_souls_changed(total: int) -> void:
	souls = total
	souls_changed.emit(total)

func rest_at_checkpoint() -> void:
	health.restore(health.maximum_health)
	stamina = max_stamina
	flask_charges = max_flasks
	blocking = false
	stats_changed.emit()
	status_message.emit("Rested at the bonfire")

func apply_progression_stats(keep_current: bool = true) -> void:
	var old_health_max := max_health
	var old_stamina_max := max_stamina
	var vitality := int(RunState.attributes.get("vitality", 10))
	var endurance := int(RunState.attributes.get("endurance", 10))
	var strength := int(RunState.attributes.get("strength", 10))
	var dexterity := int(RunState.attributes.get("dexterity", 10))
	max_health = 120.0 + float(vitality - 10) * 8.0
	max_stamina = 100.0 + float(endurance - 10) * 6.0
	light_damage = 25.0 + float(strength - 10) * 1.8 + float(dexterity - 10) * 0.8
	heavy_damage = 48.0 + float(strength - 10) * 3.0
	if is_instance_valid(health):
		health.maximum_health = max_health
		if keep_current:
			health.current_health = clampf(health.current_health + max_health - old_health_max, 0.0, max_health)
	if keep_current:
		stamina = clampf(stamina + max_stamina - old_stamina_max, 0.0, max_stamina)
	stats_changed.emit()

func get_flask_charges() -> int:
	return flask_charges

func _on_depleted() -> void:
	state = ActionState.DEAD
	attack_area.monitoring = false
	RunState.record_death(global_position)
	player_died.emit()
