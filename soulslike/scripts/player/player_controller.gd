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
@export_group("Camera")
@export var camera_target_height := 1.35
@export var camera_distance := 6.4
@export var camera_min_distance := 3.5
@export var camera_max_distance := 9.0
@export_range(12.0, 48.0, 0.5) var camera_pitch_degrees := 19.0
@export var camera_sensitivity := 0.0025
@export var camera_follow_speed := 12.0
@export var camera_collision_margin := 0.22
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
@export_group("Weapons")
@export var weapon_loadout: Array[Resource] = []
@export_group("Defense")
@export var damage_resistances: Dictionary = {"physical": 0.0, "fire": 0.0, "magic": 0.0}

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
var attack_poise_damage := 26.0
var attack_damage_type: StringName = &"physical"
var current_attack_kind: StringName = &"light"
var current_weapon: WeaponDefinition
var current_weapon_index := -1
var camera_yaw := 0.0
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
var _direct_pressed: Dictionary = {}
var _direct_just_pressed: Dictionary = {}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_apply_mouse_look((event as InputEventMouseMotion).relative)
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if DisplayServer.get_name() != "headless" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and mouse_event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(-0.65)
				return
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(0.65)
				return
			var mouse_action := _mouse_to_action(mouse_event.button_index)
			if mouse_action != &"":
				_set_direct_action(mouse_action, mouse_event.pressed, false)
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		var action := _key_to_action(code)
		if action != &"":
			_set_direct_action(action, key_event.pressed, key_event.echo)

func _apply_mouse_look(relative: Vector2) -> void:
	if locked_target != null and is_instance_valid(locked_target):
		return
	camera_yaw = wrapf(camera_yaw - relative.x * camera_sensitivity, -PI, PI)
	camera_pitch_degrees = clampf(camera_pitch_degrees - relative.y * camera_sensitivity * 180.0 / PI, 12.0, 48.0)
	camera_rig.global_rotation = Vector3(0.0, camera_yaw, 0.0)
	_update_camera_transform()

func _zoom_camera(amount: float) -> void:
	camera_distance = clampf(camera_distance + amount, camera_min_distance, camera_max_distance)
	_update_camera_transform()

func _update_camera_transform() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(camera_rig):
		return
	var pitch := deg_to_rad(camera_pitch_degrees)
	var desired_local := Vector3(0.0, sin(pitch) * camera_distance, cos(pitch) * camera_distance)
	camera.position = desired_local
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	if not is_inside_tree() or get_world_3d() == null:
		return
	var query := PhysicsRayQueryParameters3D.create(camera_rig.global_position, camera_rig.to_global(desired_local))
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		camera.position = camera_rig.to_local(hit.position + hit.normal * camera_collision_margin)

func get_weapon_name() -> String:
	return current_weapon.display_name if current_weapon != null else "UNARMED"

func _switch_weapon() -> void:
	if weapon_loadout.size() < 2:
		status_message.emit("NO SECONDARY WEAPON")
		return
	var next_index := (current_weapon_index + 1) % weapon_loadout.size()
	var next_weapon := weapon_loadout[next_index] as WeaponDefinition
	if next_weapon == null:
		status_message.emit("INVALID WEAPON SLOT")
		return
	current_weapon_index = next_index
	current_weapon = next_weapon
	apply_progression_stats(true)
	status_message.emit("EQUIPPED  •  " + current_weapon.display_name.to_upper())
	stats_changed.emit()

func _key_to_action(code: int) -> StringName:
	match code:
		KEY_W: return &"move_forward"
		KEY_S: return &"move_back"
		KEY_A: return &"move_left"
		KEY_D: return &"move_right"
		KEY_SHIFT: return &"sprint"
		KEY_SPACE: return &"dodge"
		KEY_E: return &"interact"
		KEY_F: return &"parry"
		KEY_Q: return &"heal"
		KEY_TAB: return &"lock_target"
		KEY_ESCAPE: return &"pause"
		KEY_J: return &"light_attack"
		KEY_K: return &"heavy_attack"
		KEY_L: return &"block"
		KEY_V: return &"switch_weapon"
	return &""

func _mouse_to_action(button: int) -> StringName:
	match button:
		MOUSE_BUTTON_LEFT: return &"light_attack"
		MOUSE_BUTTON_MIDDLE: return &"heavy_attack"
		MOUSE_BUTTON_RIGHT: return &"block"
	return &""

func _set_direct_action(action: StringName, pressed: bool, echo: bool) -> void:
	_direct_pressed[action] = pressed
	if pressed and not echo:
		_direct_just_pressed[action] = true

func _action_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action) or bool(_direct_pressed.get(action, false))

func _action_just_pressed(action: StringName) -> bool:
	var direct := bool(_direct_just_pressed.get(action, false))
	_direct_just_pressed.erase(action)
	return Input.is_action_just_pressed(action) or direct

func _get_move_input() -> Vector2:
	var mapped := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direct := Vector2(
		float(bool(_direct_pressed.get(&"move_right", false))) - float(bool(_direct_pressed.get(&"move_left", false))),
		float(bool(_direct_pressed.get(&"move_back", false))) - float(bool(_direct_pressed.get(&"move_forward", false)))
	)
	if direct.length_squared() > 0.0:
		return direct.normalized()
	return mapped

func _ready() -> void:
	set_process_input(true)
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
	if not weapon_loadout.is_empty():
		current_weapon_index = 0
		current_weapon = weapon_loadout[0] as WeaponDefinition
	# The camera orbits the player from an over-the-shoulder third-person position.
	camera_rig.top_level = true
	camera_rig.global_position = global_position + Vector3.UP * camera_target_height
	camera_yaw = 0.0
	camera_rig.global_rotation = Vector3(0.0, camera_yaw, 0.0)
	_update_camera_transform()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if RunState.has_checkpoint:
		global_position = RunState.checkpoint_position
	RunState.souls_changed.connect(_on_run_souls_changed)
	_on_run_souls_changed(RunState.souls)
	stats_changed.emit()

func _process(delta: float) -> void:
	var focus := global_position + Vector3.UP * camera_target_height
	var follow_weight := 1.0 - exp(-camera_follow_speed * delta)
	camera_rig.global_position = camera_rig.global_position.lerp(focus, follow_weight)
	if locked_target != null:
		if not is_instance_valid(locked_target) or not locked_target.visible:
			locked_target = null
		else:
			var target_direction := locked_target.global_position - global_position
			target_direction.y = 0.0
			if target_direction.length_squared() > 0.001:
				var target_yaw := atan2(-target_direction.x, -target_direction.z)
				camera_yaw = lerp_angle(camera_yaw, target_yaw, 1.0 - exp(-delta * 9.0))
	camera_rig.global_rotation = Vector3(0.0, camera_yaw, 0.0)
	_update_camera_transform()
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
		blocking = _action_pressed(&"block") and stamina > 0.0
		if _action_just_pressed(&"interact"):
			_interact()
		if _action_just_pressed(&"parry"):
			_start_parry()
		elif _action_just_pressed(&"dodge"):
			_start_dodge()
		elif _action_just_pressed(&"heavy_attack"):
			_request_attack(&"heavy")
		elif _action_just_pressed(&"light_attack"):
			_request_attack(&"light")
		elif _action_just_pressed(&"heal"):
			_use_flask()
		elif _action_just_pressed(&"switch_weapon"):
			_switch_weapon()
		if _action_just_pressed(&"lock_target"):
			_toggle_target_lock()
	elif state == ActionState.WINDUP or state == ActionState.ACTIVE or state == ActionState.RECOVERY:
		var light_buffered := _action_just_pressed(&"light_attack")
		var heavy_buffered := _action_just_pressed(&"heavy_attack")
		if light_buffered or heavy_buffered:
			queued_attack = &"heavy" if heavy_buffered else &"light"
	stats_changed.emit()

func _update_movement(delta: float) -> void:
	var input_vector := _get_move_input()
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
		var sprinting := _action_pressed(&"sprint") and stamina > 1.0 and not blocking and state == ActionState.FREE
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
	var is_heavy := kind == &"heavy"
	var cost := (current_weapon.heavy_stamina_cost if is_heavy else current_weapon.light_stamina_cost) if current_weapon != null else (heavy_cost if is_heavy else light_cost)
	if stamina < cost:
		status_message.emit("Not enough stamina")
		return
	stamina -= cost
	stamina_regen_wait = stamina_regen_delay
	current_attack_kind = kind
	attack_damage = heavy_damage if is_heavy else light_damage
	attack_poise_damage = (current_weapon.heavy_poise_damage if is_heavy else current_weapon.light_poise_damage) if current_weapon != null else (50.0 if is_heavy else 26.0)
	attack_damage_type = current_weapon.damage_type if current_weapon != null else &"physical"
	if riposte_ready:
		attack_damage *= 1.8
		riposte_ready = false
	state = ActionState.WINDUP
	var windup := (current_weapon.heavy_windup if is_heavy else current_weapon.light_windup) if current_weapon != null else (0.46 if is_heavy else 0.24)
	action_time = windup
	var range_scale := (current_weapon.heavy_range_scale if is_heavy else current_weapon.light_range_scale) if current_weapon != null else (1.35 if is_heavy else 1.0)
	attack_area.scale = Vector3.ONE * range_scale
	hit_targets.clear()
	blocking = false

func _start_dodge() -> void:
	if state != ActionState.FREE or stamina < dodge_cost:
		return
	stamina -= dodge_cost
	stamina_regen_wait = stamina_regen_delay
	var input_vector := _get_move_input()
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
	var is_heavy := current_attack_kind == &"heavy"
	if state == ActionState.WINDUP and action_time <= 0.0:
		state = ActionState.ACTIVE
		action_time = (current_weapon.heavy_active if is_heavy else current_weapon.light_active) if current_weapon != null else (0.25 if is_heavy else 0.19)
		attack_area.monitoring = true
		_check_attack_overlaps()
	elif state == ActionState.ACTIVE:
		_check_attack_overlaps()
		if action_time <= 0.0:
			attack_area.monitoring = false
			state = ActionState.RECOVERY
			action_time = (current_weapon.heavy_recovery if is_heavy else current_weapon.light_recovery) if current_weapon != null else (0.58 if is_heavy else 0.42)
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
		var dealt_damage := attack_damage
		var poise := attack_poise_damage
		var is_critical := body.has_method("is_backstab_position") and bool(body.is_backstab_position(self))
		if is_critical:
			var multiplier := current_weapon.critical_multiplier if current_weapon != null else 2.5
			dealt_damage *= multiplier
			poise = maxf(poise, 100.0)
			status_message.emit("BACKSTAB  •  CRITICAL HIT")
		else:
			status_message.emit("HIT!")
		body.receive_damage(DamageInfo.new(dealt_damage, attack_damage_type, poise, self))

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
	var resistance := clampf(float(damage_resistances.get(String(info.damage_type), 0.0)), 0.0, 0.85)
	var damage := info.amount * (1.0 - resistance)
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
	if current_weapon != null:
		light_damage = current_weapon.base_light_damage + float(strength - 10) * current_weapon.strength_light_scaling + float(dexterity - 10) * current_weapon.dexterity_light_scaling
		heavy_damage = current_weapon.base_heavy_damage + float(strength - 10) * current_weapon.strength_heavy_scaling + float(dexterity - 10) * current_weapon.dexterity_heavy_scaling
	else:
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
