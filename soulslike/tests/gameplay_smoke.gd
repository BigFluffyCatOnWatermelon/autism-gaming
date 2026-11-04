extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/locations/ashen_outskirts.tscn")

func _send_key_to_player(player: PlayerController, key_code: int, pressed: bool) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = key_code
	key_event.physical_keycode = key_code
	key_event.pressed = pressed
	player._input(key_event)

func _send_mouse_to_player(player: PlayerController, button: MouseButton, pressed: bool) -> void:
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = button
	mouse_event.pressed = pressed
	player._input(mouse_event)

func _send_key(key_code: int, pressed: bool) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = key_code
	key_event.physical_keycode = key_code
	key_event.pressed = pressed
	Input.parse_input_event(key_event)

func _ready() -> void:
	await get_tree().process_frame
	if not InputMap.has_action("move_forward"):
		_fail("InputSetup did not register the movement actions.")
		return

	var world := MAIN_SCENE.instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	for _frame in range(3):
		await get_tree().physics_frame

	var player := world.get_node("Player") as PlayerController
	var enemy := world.get_node("Hollow_01") as EnemyBase
	var guard := world.get_node("ShieldGuard") as EnemyBase
	var bonfire := world.get_node("Bonfire") as Bonfire
	if player == null or enemy == null or guard == null or bonfire == null:
		_fail("Main scene did not expose the player, enemy and bonfire.")
		return

	var start_z := player.global_position.z
	_send_key(KEY_W, true)
	for _frame in range(30):
		await get_tree().physics_frame
	_send_key(KEY_W, false)
	if player.global_position.z >= start_z - 0.35:
		_fail("W / move_forward did not move the character toward world -Z.")
		return

	var after_forward_z := player.global_position.z
	_send_key(KEY_S, true)
	for _frame in range(30):
		await get_tree().physics_frame
	_send_key(KEY_S, false)
	if player.global_position.z <= after_forward_z + 0.35:
		_fail("S / move_back did not move the character toward world +Z.")
		return

	enemy.global_position = Vector3(0.0, 0.0, -3.0)
	player.global_position = Vector3(0.0, 0.0, -1.0)
	player.rotation.y = 0.0
	player.state = PlayerController.ActionState.FREE
	player.velocity = Vector3.ZERO
	enemy.state = EnemyBase.AIState.IDLE
	var health_before := enemy.current_health
	var light_key_bound := false
	for mapped_event in InputMap.action_get_events("light_attack"):
		if mapped_event is InputEventKey and (mapped_event as InputEventKey).physical_keycode == KEY_J:
			light_key_bound = true
	if not light_key_bound:
		_fail("J key is missing from the light_attack InputMap.")
		return
	_send_key_to_player(player, KEY_J, true)
	await get_tree().physics_frame
	if player.state != PlayerController.ActionState.WINDUP:
		_fail("Physical J key event did not start the light attack. State: %s" % player.state)
		return
	_send_key_to_player(player, KEY_J, false)
	print("LIGHT INPUT STARTED; state=", player.state, " stamina=", player.stamina)
	enemy.global_position = player.to_global(Vector3(0.0, 0.0, -1.0))
	for _frame in range(42):
		await get_tree().physics_frame
	if enemy.current_health >= health_before:
		_fail("The attack started, but the melee hitbox did not damage an enemy in range.")
		return

	# Verify the actual mouse-button route used by the default left-click attack.
	player.state = PlayerController.ActionState.FREE
	player.stamina = player.max_stamina
	var health_after_keyboard_attack := enemy.current_health
	_send_mouse_to_player(player, MOUSE_BUTTON_LEFT, true)
	await get_tree().physics_frame
	if player.state != PlayerController.ActionState.WINDUP:
		_fail("Left mouse button did not start the light attack.")
		return
	_send_mouse_to_player(player, MOUSE_BUTTON_LEFT, false)
	for _frame in range(42):
		await get_tree().physics_frame
	if enemy.current_health >= health_after_keyboard_attack:
		_fail("Left mouse attack did not damage the enemy.")
		return

	# Third-person orbit, zoom and shoulder-height tracking.
	var yaw_before := player.camera_yaw
	player._apply_mouse_look(Vector2(80.0, 0.0))
	if is_equal_approx(player.camera_yaw, yaw_before):
		_fail("Mouse-look did not rotate the third-person camera.")
		return
	var distance_before := player.camera_distance
	player._zoom_camera(-0.65)
	if player.camera_distance >= distance_before:
		_fail("Mouse-wheel zoom did not move the camera closer.")
		return
	if player.camera_rig.global_position.distance_to(player.global_position) < 0.5:
		_fail("Camera focus did not follow the player at shoulder height.")
		return

	# V cycles actual data-driven movesets.
	var first_weapon_name := player.get_weapon_name()
	player._switch_weapon()
	if player.get_weapon_name() == first_weapon_name or player.get_weapon_name() != "Grave Cleaver":
		_fail("Weapon switching did not equip the second weapon definition.")
		return
	player._switch_weapon()

	# A close attack from directly behind applies the weapon critical multiplier.
	player.global_position = Vector3(0.0, 0.0, 1.0)
	enemy.global_position = Vector3.ZERO
	enemy.rotation = Vector3.ZERO
	enemy.state = EnemyBase.AIState.CHASE
	player.state = PlayerController.ActionState.ACTIVE
	player.attack_damage = 10.0
	player.attack_poise_damage = 26.0
	player.attack_damage_type = &"physical"
	player.hit_targets.clear()
	var health_before_critical := enemy.current_health
	player._on_attack_body_entered(enemy)
	var critical_multiplier := player.current_weapon.critical_multiplier
	if not is_equal_approx(health_before_critical - enemy.current_health, 10.0 * critical_multiplier):
		_fail("Backstab did not apply the weapon's critical multiplier.")
		return

	# A frontal shield reduces light damage and breaks to a heavy hit.
	player.global_position = Vector3(-6.0, 0.0, -8.0)
	guard.global_position = Vector3(-6.0, 0.0, -7.0)
	guard.rotation = Vector3.ZERO
	guard.current_health = guard.maximum_health
	guard.shield_broken_time = 0.0
	guard.current_poise = guard.maximum_poise
	var guard_health_before := guard.current_health
	guard.receive_damage(DamageInfo.new(40.0, &"physical", 20.0, player))
	var guarded_damage := guard_health_before - guard.current_health
	if guarded_damage > 15.0:
		_fail("Shield guard did not meaningfully reduce frontal light damage.")
		return
	guard_health_before = guard.current_health
	guard.receive_damage(DamageInfo.new(50.0, &"physical", 82.0, player))
	if guard.shield_broken_time <= 0.0 or guard.current_health >= guard_health_before:
		_fail("Heavy poise damage did not break the shield guard.")
		return

	player.global_position = bonfire.global_position + Vector3(1.0, 0.0, 0.0)
	player.health.apply_damage(35.0)
	player.stamina = 5.0
	player.flask_charges = 0
	bonfire.interact(player)
	if not RunState.has_checkpoint:
		_fail("Bonfire interaction did not persist a checkpoint.")
		return
	if player.health.current_health < player.health.maximum_health - 0.1:
		_fail("Bonfire did not restore player health.")
		return
	if player.stamina < player.max_stamina - 0.1 or player.flask_charges != player.max_flasks:
		_fail("Bonfire did not restore stamina and flasks.")
		return

	var hud = world.get_node("CombatHUD")
	hud.call("_close_level_panel")
	RunState.add_souls(1000)
	var vitality_before := int(RunState.attributes["vitality"])
	var level_before := RunState.level
	if not RunState.level_up("vitality"):
		_fail("A valid vitality level-up was rejected.")
		return
	player.apply_progression_stats(true)
	if RunState.level != level_before + 1 or int(RunState.attributes["vitality"]) != vitality_before + 1:
		_fail("Level and Vitality did not increase.")
		return
	if player.max_health <= 120.0:
		_fail("Vitality did not increase maximum health.")
		return

	print("GAMEPLAY CHECKS PASSED: movement, camera orbit/zoom, weapon swap, melee/backstab, shield break, bonfire and progression.")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("GAMEPLAY CHECK FAILED: " + message)
	get_tree().quit(1)
