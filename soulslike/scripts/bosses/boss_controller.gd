extends EnemyBase
class_name BossController
signal boss_health_changed(title: String, current: float, maximum: float, phase: int)
signal boss_defeated
@export var boss_key := "warden_of_the_bell"
@export var phase_two_threshold := 0.55
@export var phase_two_speed := 3.25
@export var phase_two_damage := 34.0
var phase := 1
var attack_pattern_index := 0

func _ready() -> void:
	super._ready()
	if RunState.is_defeated(boss_key):
		state = AIState.DEAD
		visible = false
		collision_shape.set_deferred("disabled", true)
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
		return
	add_to_group("bosses")

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
				boss_health_changed.emit(enemy_title, current_health, maximum_health, phase)
		AIState.CHASE:
			if distance > detection_range * 1.8:
				state = AIState.IDLE
			elif distance <= attack_range + 0.75:
				state = AIState.WINDUP
				state_time = 0.98 if phase == 1 else 0.68
				_set_telegraph(true)
			else:
				_move_toward_player(delta)
		AIState.WINDUP:
			_stop_horizontal(delta)
			_face_player()
			if distance > attack_range * 1.9:
				state = AIState.CHASE
				_set_telegraph(false)
			elif state_time <= 0.0:
				state = AIState.ATTACK
				_set_telegraph(false)
				_perform_boss_attack()
				state = AIState.RECOVER
				state_time = 1.28 if phase == 1 else 0.78
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

func _perform_boss_attack() -> void:
	if body_visual.has_method("play_attack"):
		body_visual.call("play_attack", true)
	if not is_instance_valid(player):
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var facing_dot := forward.dot(offset.normalized()) if distance > 0.001 else 1.0
	var pattern := attack_pattern_index % (3 if phase == 2 else 2)
	attack_pattern_index += 1
	var hit := false
	if pattern == 0:
		hit = distance <= 4.0 and facing_dot >= 0.0
	elif pattern == 1:
		hit = distance <= (4.8 if phase == 2 else 4.1)
	else:
		hit = distance <= 3.0 and facing_dot >= -0.1
	if hit:
		player.receive_damage(DamageInfo.new(attack_damage, &"physical", 30.0, self))

func receive_damage(info: DamageInfo) -> void:
	if state == AIState.DEAD:
		return
	super.receive_damage(info)
	if state != AIState.DEAD:
		if phase == 1 and current_health <= maximum_health * phase_two_threshold:
			_enter_phase_two()
		boss_health_changed.emit(enemy_title, current_health, maximum_health, phase)

func _enter_phase_two() -> void:
	phase = 2
	if body_visual.has_method("enrage"):
		body_visual.call("enrage")
	var effects := get_tree().get_first_node_in_group("combat_vfx")
	if effects != null and effects.has_method("spawn_death"):
		effects.call("spawn_death", global_position + Vector3.UP * 1.4)
	move_speed = phase_two_speed
	attack_damage = phase_two_damage
	attack_recovery = 0.78
	if base_material != null:
		var enraged := base_material.duplicate() as StandardMaterial3D
		enraged.emission_enabled = true
		enraged.emission = Color(0.34, 0.035, 0.018, 1.0)
		enraged.emission_energy_multiplier = 1.25
		var mesh := body_visual.get_node_or_null("Torso") as MeshInstance3D
		if mesh != null:
			mesh.material_override = enraged
	if is_instance_valid(player):
		player.status_message.emit("THE WARDEN AWAKENS  •  PHASE II")
	boss_health_changed.emit(enemy_title, current_health, maximum_health, phase)

func _die() -> void:
	if state == AIState.DEAD:
		return
	RunState.set_defeated(boss_key)
	boss_defeated.emit()
	if is_instance_valid(player):
		player.status_message.emit("WARDEN OF THE BELL — SLAIN")
	super._die()
