extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed_scene := load("res://scenes/tests/component_test.tscn") as PackedScene
	_expect(packed_scene != null, "component test scene resource loads")
	if packed_scene == null:
		_finish()
		return

	var scene_instance := packed_scene.instantiate()
	_expect(scene_instance != null, "component test scene instantiates")
	if scene_instance == null:
		_finish()
		return

	root.add_child(scene_instance)
	await process_frame

	_expect(scene_instance.has_method("has_test_components"), "test scene exposes component verification")
	if scene_instance.has_method("has_test_components"):
		_expect(scene_instance.has_test_components(), "test dummy receives Health and Damageable")
		_expect(is_equal_approx(scene_instance.get_test_max_health(), 100.0), "test dummy has configured maximum health")
		_expect(is_equal_approx(scene_instance.get_test_health(), 100.0), "test dummy starts at configured health")

		var first_damage: float = scene_instance.apply_test_damage(10.0)
		_expect(is_equal_approx(first_damage, 10.5), "test scene applies Damageable multiplier and flat reduction")
		_expect(is_equal_approx(scene_instance.get_test_health(), 89.5), "test scene forwards adjusted damage into Health")

		var healed: float = scene_instance.heal_test_object(5.0)
		_expect(is_equal_approx(healed, 5.0), "test scene can heal a living object")
		_expect(is_equal_approx(scene_instance.get_test_health(), 94.5), "test scene reports healed health")

		scene_instance.set_damage_enabled(false)
		_expect(is_equal_approx(scene_instance.apply_test_damage(10.0), 0.0), "test scene can disable incoming damage")
		_expect(is_equal_approx(scene_instance.get_test_health(), 94.5), "blocked hit leaves health unchanged")

		scene_instance.set_damage_enabled(true)
		scene_instance.set_invulnerable(true)
		_expect(is_equal_approx(scene_instance.apply_test_damage(10.0), 0.0), "test scene can enable Health invulnerability")
		_expect(is_equal_approx(scene_instance.get_test_health(), 94.5), "invulnerability leaves health unchanged")

		scene_instance.set_invulnerable(false)
		_expect(
			is_equal_approx(scene_instance.apply_test_damage(200.0), 94.5),
			"test scene caps lethal damage to remaining health"
		)
		_expect(not scene_instance.is_test_alive(), "test scene receives the lethal state")
		scene_instance.reset_test_object()
		_expect(scene_instance.is_test_alive(), "test scene reset restores a living state")
		_expect(is_equal_approx(scene_instance.get_test_health(), 100.0), "test scene reset restores starting health")

	scene_instance.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("COMPONENT_TEST_SCENE: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("COMPONENT_TEST_SCENE: " + failure)
	quit(1)
