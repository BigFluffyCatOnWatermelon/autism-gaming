extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/locations/ashen_outskirts.tscn")

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
	var bonfire := world.get_node("Bonfire") as Bonfire
	if player == null or enemy == null or bonfire == null:
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
	_send_key(KEY_J, true)
	await get_tree().physics_frame
	if player.state != PlayerController.ActionState.WINDUP:
		_fail("Physical J key event did not start the light attack. State: %s" % player.state)
		return
	_send_key(KEY_J, false)
	enemy.global_position = player.to_global(Vector3(0.0, 0.0, -1.0))
	for _frame in range(42):
		await get_tree().physics_frame
	if enemy.current_health >= health_before:
		_fail("The attack started, but the melee hitbox did not damage an enemy in range.")
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

	print("GAMEPLAY CHECKS PASSED: forward/back movement, melee hit, bonfire rest/checkpoint and persistent level-up.")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("GAMEPLAY CHECK FAILED: " + message)
	get_tree().quit(1)
