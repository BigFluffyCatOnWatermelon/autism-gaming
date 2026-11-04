extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/locations/ashen_outskirts.tscn")

func _initialize() -> void:
	call_deferred("_run_gameplay_checks")

func _run_gameplay_checks() -> void:
	await process_frame
	if not InputMap.has_action("move_forward"):
		var setup_script = load("res://scripts/core/input_setup.gd")
		var setup = setup_script.new()
		root.add_child(setup)
		await process_frame

	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	for _frame in range(3):
		await physics_frame

	var player := world.get_node("Player") as PlayerController
	var enemy := world.get_node("Hollow_01") as EnemyBase
	var bonfire := world.get_node("Bonfire") as Bonfire
	if player == null or enemy == null or bonfire == null:
		_fail("Main scene did not expose the player, enemy and bonfire.")
		return

	var start_z := player.global_position.z
	Input.action_press("move_forward")
	for _frame in range(30):
		await physics_frame
	Input.action_release("move_forward")
	if player.global_position.z >= start_z - 0.35:
		_fail("W / move_forward did not move the character toward world -Z.")
		return

	var after_forward_z := player.global_position.z
	Input.action_press("move_back")
	for _frame in range(30):
		await physics_frame
	Input.action_release("move_back")
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
	Input.action_press("light_attack")
	for _frame in range(42):
		await physics_frame
	Input.action_release("light_attack")
	if enemy.current_health >= health_before:
		_fail("A light attack did not damage an enemy in front of the player.")
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
	quit(0)

func _fail(message: String) -> void:
	push_error("GAMEPLAY CHECK FAILED: " + message)
	quit(1)
