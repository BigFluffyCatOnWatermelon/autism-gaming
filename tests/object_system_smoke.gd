extends SceneTree

var failures := PackedStringArray()
var health_died_signal_received := false
var destructible_destroyed_received := false


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_runtime_property_values()
	_test_definition_range_validation()
	_test_object_type_default()
	_test_serialized_property_data()
	_test_component_catalog_and_health()
	_test_damageable_component()
	_test_attack_component()
	await _test_destructible_component()
	_test_component_definition_inspector_settings()
	_test_component_definition_validation()
	await _test_component_node_bindings()

	if failures.is_empty():
		print("OBJECT_SYSTEM_TESTS: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("OBJECT_SYSTEM_TESTS: " + failure)
		quit(1)


func _test_runtime_property_values() -> void:
	var definition := ObjectDefinition.new()
	definition.object_id = "object_builder_smoke_test"
	definition.display_name = "Smoke Test Object"
	definition.category = "Other"
	definition.root_type = "Node2D"

	var health := _make_property("health", "Integer", 100)
	health.has_range = true
	health.minimum = 1
	health.maximum = 200

	var speed := _make_property("speed", "Float", 4.0)
	speed.has_range = true
	speed.minimum = 0.5
	speed.maximum = 8.0

	var title := _make_property("title", "String", "Tree")
	var enabled := _make_property("enabled", "Boolean", false)
	var offset := _make_property("offset", "Vector2", Vector2.ZERO)

	definition.custom_properties = [health, speed, title, enabled, offset]

	var instance := ObjectFactory.instantiate(definition, {
		"health": 999,
		"speed": 0.1,
		"title": "Oak",
		"enabled": true,
		"offset": Vector2(12.0, -4.0)
	})
	_expect(instance != null, "factory creates object")
	if instance == null:
		return

	_expect(ObjectFactory.get_custom_property(instance, "health") == 200, "integer override is clamped to max")
	_expect(
		is_equal_approx(float(ObjectFactory.get_custom_property(instance, "speed")), 0.5),
		"float override is clamped to min"
	)
	_expect(ObjectFactory.get_custom_property(instance, "title") == "Oak", "string override is applied")
	_expect(ObjectFactory.get_custom_property(instance, "enabled") == true, "boolean override is applied")
	_expect(
		ObjectFactory.get_custom_property(instance, "offset") == Vector2(12.0, -4.0),
		"Vector2 override is applied"
	)

	_expect(ObjectFactory.set_custom_property(instance, "health", 32.0), "integer accepts integral float")
	_expect(ObjectFactory.get_custom_property(instance, "health") == 32, "integer update is stored")
	_expect(not ObjectFactory.set_custom_property(instance, "health", 32.5), "integer rejects fractional value")
	_expect(ObjectFactory.get_custom_property(instance, "health") == 32, "rejected update leaves previous value unchanged")
	_expect(not ObjectFactory.set_custom_property(instance, "health", "broken"), "integer rejects string")
	_expect(not ObjectFactory.set_custom_property(instance, "missing", 1), "unknown property is rejected")
	_expect(
		ObjectFactory.set_custom_property(instance, "speed", 99.0),
		"valid float update succeeds"
	)
	_expect(
		is_equal_approx(float(ObjectFactory.get_custom_property(instance, "speed")), 8.0),
		"float update is clamped to max"
	)
	var attached_health_definition := ObjectFactory.get_custom_property_definition(instance, "health")
	_expect(attached_health_definition != null, "property definition is attached to instance")
	if attached_health_definition != null:
		_expect(attached_health_definition.default_value == 100, "attached property definition keeps its default value")

	var property_data := instance.get_node_or_null("ObjectProperties") as ObjectPropertyData
	_expect(property_data != null, "factory attaches a serialized property data node")
	if property_data != null:
		var inspector_has_health := false
		for property_info in property_data.get_property_list():
			if str(property_info.get("name", "")).ends_with("_health"):
				inspector_has_health = true
				_expect(int(property_info.get("type", TYPE_NIL)) == TYPE_INT, "health is exposed as an integer Inspector property")
		_expect(inspector_has_health, "custom property is exposed in the native Inspector property list")

	instance.free()

	var invalid_override_instance := ObjectFactory.instantiate(definition, {"health": "invalid"})
	_expect(invalid_override_instance != null, "factory survives invalid override")
	if invalid_override_instance != null:
		_expect(
			ObjectFactory.get_custom_property(invalid_override_instance, "health") == 100,
			"invalid override falls back to property default"
		)
		invalid_override_instance.free()


func _test_definition_range_validation() -> void:
	var definition := ObjectDefinition.new()
	definition.object_id = "object_builder_validation_test"
	definition.display_name = "Validation Test Object"
	definition.category = "Other"

	var integer_property := _make_property("count", "Integer", 5)
	integer_property.has_range = true
	integer_property.minimum = 0
	integer_property.maximum = 10
	definition.custom_properties = [integer_property]
	_expect(
		ObjectLibraryService.validate_definition(definition).is_empty(),
		"valid integer range passes definition validation"
	)

	integer_property.minimum = 0.5
	var errors := ObjectLibraryService.validate_definition(definition)
	_expect(not errors.is_empty(), "fractional integer boundary fails definition validation")


func _test_object_type_default() -> void:
	var definition := ObjectDefinition.new()
	_expect(definition.object_type == "other", "new object definitions default to generic type")
	definition.object_id = "object_type_smoke_test"
	definition.display_name = "Typed Object"
	definition.object_type = "resource"
	_expect(ObjectLibraryService.validate_definition(definition).is_empty(), "typed definition passes definition validation")


func _test_serialized_property_data() -> void:
	var health := _make_property("health_points", "Integer", 100)
	health.display_name = "Hit Points"
	health.group_name = "Combat"
	health.has_range = true
	health.minimum = 1
	health.maximum = 200

	var root := Node2D.new()
	root.name = "PropertyDataSmokeTest"
	var property_data := ObjectPropertyData.new()
	property_data.name = "ObjectProperties"
	root.add_child(property_data)
	property_data.owner = root
	property_data.configure([health], {"health_points": 145}, false)

	_expect(property_data.get("combat_hit_points") == 145, "dynamic Inspector getter returns stored custom value")
	property_data.set("combat_hit_points", 250)
	_expect(property_data.get("combat_hit_points") == 200, "dynamic Inspector setter clamps the configured range")
	_expect(ObjectFactory.get_custom_property(root, "health_points") == 200, "runtime API reads edits made through Inspector")
	_expect(root.get_meta("object_custom_properties", {}).get("health_points") == 200, "legacy metadata mirror follows Inspector edits")
	_expect(property_data._property_get_revert("combat_hit_points") == 100, "dynamic Inspector revert value uses definition default")
	_expect(ObjectFactory.set_custom_property(root, "health_points", 175), "runtime API writes the shared Inspector value")
	_expect(property_data.get("combat_hit_points") == 175, "Inspector field reflects values written through runtime API")

	var packed := PackedScene.new()
	_expect(packed.pack(root) == OK, "property data node can be packed into a scene")
	var restored_root := packed.instantiate()
	_expect(restored_root != null, "packed object scene can be instantiated")
	if restored_root != null:
		var restored_data := restored_root.get_node_or_null("ObjectProperties") as ObjectPropertyData
		_expect(restored_data != null, "packed scene keeps the property data node")
		if restored_data != null:
			_expect(restored_data.get_custom_property("health_points") == 175, "custom values survive scene pack and instantiate")
			_expect(restored_data.get_custom_property_definition("health_points") != null, "custom definitions survive scene pack and instantiate")
		restored_root.free()
	root.free()


func _test_component_catalog_and_health() -> void:
	var categories := ObjectComponentCatalog.get_categories()
	_expect(categories.size() == 8, "component catalog exposes the planned category groups")
	_expect(ObjectComponentCatalog.get_component_ids("Stats").has("health"), "Health is listed in the Stats category")
	_expect(ObjectComponentCatalog.get_component_ids("Combat").has("damageable"), "Damageable is listed in the Combat category")
	_expect(ObjectComponentCatalog.get_component_ids("Combat").has("attack"), "Attack is listed in the Combat category")
	_expect(ObjectComponentCatalog.has_component("HEALTH"), "catalog component IDs are case-insensitive")
	_expect(ObjectComponentCatalog.has_component("Damageable"), "Damageable is available by its stable ID")
	_expect(ObjectComponentCatalog.has_component("ATTACK"), "Attack is available by its stable ID")

	var component_definition := ObjectComponentCatalog.create_definition("health")
	_expect(component_definition != null, "catalog creates the Health component definition")
	if component_definition == null:
		return
	_expect(component_definition.component_script != null, "catalog definition supplies the Health script")
	_expect(component_definition.category == "Stats", "Health is grouped under Stats")

	component_definition.component_script = null
	var max_health_field := component_definition.get_inspector_property_name_for_setting("max_health")
	var starting_health_field := component_definition.get_inspector_property_name_for_setting("starting_health")
	component_definition._set(StringName(max_health_field), 120.0)
	component_definition._set(StringName(starting_health_field), 90.0)
	_expect(
		is_equal_approx(float(component_definition.settings.get("max_health", 0.0)), 120.0),
		"dynamic Inspector edits are stored in the serializable settings dictionary"
	)

	var definition := ObjectDefinition.new()
	definition.object_id = "health_component_smoke_test"
	definition.display_name = "Health Component Test"
	definition.category = "Other"
	definition.components = [component_definition]

	var instance := ObjectFactory.instantiate(definition)
	_expect(instance != null, "factory creates object with a catalog component")
	if instance == null:
		return

	var component := ObjectFactory.get_component(instance, "health") as HealthComponent
	_expect(component != null, "factory resolves component by its stable ID")
	if component == null:
		instance.free()
		return

	_expect(component.component_id == "health", "factory assigns the stable component ID")
	_expect(is_equal_approx(component.max_health, 120.0), "Health settings override the catalog default")
	_expect(is_equal_approx(component.current_health, 90.0), "Health starts at configured starting health")
	_expect(ObjectFactory.has_component(instance, "health"), "factory can check for a component by ID")

	health_died_signal_received = false
	component.died.connect(_on_health_component_died)
	_expect(is_equal_approx(component.apply_damage(25.0), 25.0), "Health applies non-lethal damage")
	_expect(is_equal_approx(component.current_health, 65.0), "damage reduces current health")
	_expect(is_equal_approx(component.heal(10.0), 10.0), "Health restores missing health")
	_expect(is_equal_approx(component.current_health, 75.0), "healing increases current health")
	component.set_max_health(60.0)
	_expect(is_equal_approx(component.current_health, 60.0), "reducing max health clamps current health")
	_expect(is_equal_approx(component.apply_damage(60.0), 60.0), "Health returns the exact lethal damage applied")
	_expect(not component.is_alive(), "Health reports a dead component at zero health")
	_expect(health_died_signal_received, "Health emits died exactly when health reaches zero")
	_expect(is_equal_approx(component.heal(10.0), 0.0), "dead components cannot be healed by default")
	component.reset_health()
	_expect(component.is_alive(), "reset_health restores the configured starting health")
	_expect(is_equal_approx(component.current_health, 60.0), "reset_health respects the current maximum")
	component.invulnerable = true
	_expect(is_equal_approx(component.apply_damage(10.0), 0.0), "invulnerable Health ignores damage")

	instance.free()


func _test_damageable_component() -> void:
	var damageable_definition := ObjectComponentCatalog.create_definition("damageable")
	var health_definition := ObjectComponentCatalog.create_definition("health")
	_expect(damageable_definition != null, "catalog creates the Damageable component definition")
	_expect(health_definition != null, "catalog creates Health dependency for Damageable")
	if damageable_definition == null or health_definition == null:
		return

	var multiplier_field := damageable_definition.get_inspector_property_name_for_setting("damage_multiplier")
	var has_multiplier_field := false
	for property_info in damageable_definition.get_property_list():
		if str(property_info.get("name", "")) == multiplier_field:
			has_multiplier_field = int(property_info.get("type", TYPE_NIL)) == TYPE_FLOAT
	_expect(has_multiplier_field, "Damageable multiplier is exposed as a typed Inspector field")
	_expect(
		damageable_definition._set(StringName(multiplier_field), 2.0),
		"Damageable multiplier can be configured through its Inspector field"
	)
	_expect(
		damageable_definition.set_setting("flat_reduction", 5.0),
		"Damageable flat reduction uses its validated settings API"
	)
	var definition := ObjectDefinition.new()
	definition.object_id = "damageable_component_smoke_test"
	definition.display_name = "Damageable Component Test"
	definition.category = "Other"
	definition.components = [damageable_definition, health_definition]

	var instance := ObjectFactory.instantiate(definition)
	_expect(instance != null, "factory creates object with Damageable and Health")
	if instance == null:
		return

	var damageable := ObjectFactory.get_component(instance, "damageable") as DamageableComponent
	var health := ObjectFactory.get_component(instance, "health") as HealthComponent
	_expect(damageable != null, "factory resolves Damageable by stable ID")
	_expect(health != null, "factory resolves Health alongside Damageable")
	if damageable == null or health == null:
		instance.free()
		return

	_expect(
		is_equal_approx(damageable.receive_damage(20.0), 35.0),
		"Damageable applies multiplier and flat damage reduction"
	)
	_expect(
		is_equal_approx(health.current_health, 65.0),
		"Damageable forwards adjusted damage to Health"
	)
	damageable.can_receive_damage = false
	_expect(
		is_equal_approx(damageable.receive_damage(10.0), 0.0),
		"Damageable can block incoming damage"
	)
	_expect(
		is_equal_approx(health.current_health, 65.0),
		"blocked damage does not reduce Health"
	)
	damageable.can_receive_damage = true
	health.invulnerable = true
	_expect(
		is_equal_approx(damageable.receive_damage(10.0), 0.0),
		"Damageable respects Health invulnerability"
	)
	_expect(
		is_equal_approx(health.current_health, 65.0),
		"Health invulnerability is preserved through Damageable"
	)

	instance.free()


func _test_attack_component() -> void:
	var attack_definition := ObjectComponentCatalog.create_definition("attack")
	_expect(attack_definition != null, "catalog creates the Attack component definition")
	if attack_definition == null:
		return

	var damage_field := attack_definition.get_inspector_property_name_for_setting("attack_damage")
	var has_damage_field := false
	for property_info in attack_definition.get_property_list():
		if str(property_info.get("name", "")) == damage_field:
			has_damage_field = int(property_info.get("type", TYPE_NIL)) == TYPE_FLOAT
	_expect(has_damage_field, "Attack damage is exposed as a float Inspector property")
	_expect(attack_definition.set_setting("attack_damage", 12.0), "Attack damage setting accepts a valid value")

	var target_definition := ObjectDefinition.new()
	target_definition.object_id = "attack_smoke_target"
	target_definition.display_name = "Attack Smoke Target"
	target_definition.category = "Other"
	target_definition.root_type = "Node2D"
	target_definition.components = [
		ObjectComponentCatalog.create_definition("health"),
		ObjectComponentCatalog.create_definition("damageable")
	]
	var test_world := Node2D.new()
	root.add_child(test_world)
	var target := ObjectFactory.instantiate(target_definition)
	_expect(target != null, "Attack smoke target can be created")
	if target == null:
		test_world.free()
		return
	test_world.add_child(target)
	target.position = Vector2(180.0, 0.0)

	var attacker_definition := ObjectDefinition.new()
	attacker_definition.object_id = "attack_smoke_attacker"
	attacker_definition.display_name = "Attack Smoke Attacker"
	attacker_definition.category = "Other"
	attacker_definition.root_type = "Node2D"
	attacker_definition.components = [attack_definition]
	var attacker := ObjectFactory.instantiate(attacker_definition)
	_expect(attacker != null, "Attack smoke attacker can be created")
	if attacker == null:
		test_world.free()
		return
	test_world.add_child(attacker)
	attacker.position = Vector2.ZERO

	var attack := ObjectFactory.get_component(attacker, "attack") as AttackComponent
	var health := ObjectFactory.get_component(target, "health") as HealthComponent
	_expect(attack != null, "factory resolves Attack by stable ID")
	_expect(health != null, "Attack smoke target has Health")
	if attack != null and health != null:
		_expect(
			is_equal_approx(attack.perform_attack(target, attacker), 12.0),
			"Attack applies configured damage through default Damageable settings"
		)
		_expect(is_equal_approx(health.current_health, 88.0), "Attack reduces target Health through Damageable")
		_expect(
			is_equal_approx(attack.perform_attack(target, attacker), 0.0),
			"Attack cooldown blocks an immediate second attack"
		)
		attacker.position = Vector2(-300.0, 0.0)
		attack.reset_cooldown()
		_expect(
			is_equal_approx(attack.perform_attack(target, attacker), 0.0),
			"Attack refuses a target outside configured range"
		)
		attack.set_attack_enabled(false)
		attacker.position = Vector2.ZERO
		attack.reset_cooldown()
		_expect(
			is_equal_approx(attack.perform_attack(target, attacker), 0.0),
			"Attack can be disabled"
		)
		_expect(is_equal_approx(health.current_health, 88.0), "failed Attack attempts do not alter Health")

	test_world.free()


func _test_destructible_component() -> void:
	var component_definition := ObjectComponentCatalog.create_definition("destructible")
	_expect(component_definition != null, "catalog creates the Destructible component definition")
	if component_definition == null:
		return

	_expect(
		ObjectComponentCatalog.get_component_ids("Destruction").has("destructible"),
		"Destructible appears in the Destruction category"
	)
	_expect(component_definition.set_setting("hide_on_destroy", true), "Destructible accepts a typed Inspector setting")
	_expect(not component_definition.set_setting("hide_on_destroy", 1), "Destructible rejects a setting with the wrong type")

	var health_definition := ObjectComponentCatalog.create_definition("health")
	var damageable_definition := ObjectComponentCatalog.create_definition("damageable")
	health_definition.settings["max_health"] = 40.0
	health_definition.settings["starting_health"] = 40.0

	var object_definition := ObjectDefinition.new()
	object_definition.object_id = "destructible_smoke_object"
	object_definition.display_name = "Destructible Smoke Object"
	object_definition.category = "Nature"
	object_definition.root_type = "StaticBody2D"
	object_definition.components = [health_definition, damageable_definition, component_definition]

	var body := ObjectFactory.instantiate(object_definition) as StaticBody2D
	_expect(body != null, "ObjectFactory creates a destructible physics object")
	if body == null:
		return

	body.collision_layer = 5
	body.collision_mask = 3
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	body.add_child(collision_shape)

	var test_world := Node2D.new()
	root.add_child(test_world)
	test_world.add_child(body)
	await process_frame

	var health := ObjectFactory.get_component(body, "health") as HealthComponent
	var damageable := ObjectFactory.get_component(body, "damageable") as DamageableComponent
	var destructible := ObjectFactory.get_component(body, "destructible") as DestructibleComponent
	_expect(health != null, "destructible object has Health")
	_expect(damageable != null, "destructible object has Damageable")
	_expect(destructible != null, "factory resolves Destructible by stable ID")
	if health == null or damageable == null or destructible == null:
		test_world.free()
		return

	destructible_destroyed_received = false
	destructible.destroyed.connect(_on_destructible_destroyed)
	_expect(is_equal_approx(health.apply_damage(100.0), 40.0), "lethal damage removes remaining Health")
	_expect(destructible.is_destroyed(), "Destructible reacts to Health.died")
	_expect(destructible_destroyed_received, "Destructible emits its destroyed signal")
	_expect(body.collision_layer == 0 and body.collision_mask == 0, "destruction disables physics layers and masks")
	_expect(collision_shape.disabled, "destruction disables child CollisionShape2D")
	_expect(not body.visible, "optional visibility setting hides the destroyed object")
	_expect(not damageable.can_receive_damage, "destruction disables further incoming damage")
	_expect(is_instance_valid(body), "destroyed object remains available for custom fall/stump behavior")

	_expect(destructible.repair(), "Destructible can restore a destroyed object")
	_expect(not destructible.is_destroyed(), "repair clears the destroyed state")
	_expect(body.collision_layer == 5 and body.collision_mask == 3, "repair restores original collision layers and masks")
	_expect(not collision_shape.disabled, "repair restores the original CollisionShape2D state")
	_expect(body.visible, "repair restores the original visibility")
	_expect(damageable.can_receive_damage, "repair restores the original damage setting")
	_expect(is_equal_approx(health.current_health, 40.0), "repair restores configured starting Health")
	_expect(not bool(body.get_meta("object_destroyed", true)), "repair clears the object's destroyed metadata")

	_expect(destructible.destroy(body), "Destructible also supports manual destruction")
	_expect(not destructible.destroy(body), "repeated destruction is ignored")
	test_world.free()


func _test_component_definition_inspector_settings() -> void:
	var component_definition := ObjectComponentCatalog.create_definition("health")
	_expect(component_definition != null, "Health definition exists for Inspector settings test")
	if component_definition == null:
		return

	var has_max_health := false
	var has_invulnerable := false
	var settings_are_storage_only := false
	var max_health_field := ""
	for property_info in component_definition.get_property_list():
		var property_name := str(property_info.get("name", ""))
		if property_name == "settings":
			var usage := int(property_info.get("usage", 0))
			settings_are_storage_only = (
				(usage & PROPERTY_USAGE_STORAGE) != 0
				and (usage & PROPERTY_USAGE_EDITOR) == 0
			)
		if property_name.ends_with("_max_health"):
			has_max_health = true
			max_health_field = property_name
			_expect(int(property_info.get("type", TYPE_NIL)) == TYPE_FLOAT, "Health max is exposed as a float Inspector property")
		if property_name.ends_with("_invulnerable"):
			has_invulnerable = true
			_expect(int(property_info.get("type", TYPE_NIL)) == TYPE_BOOL, "Health invulnerability is exposed as a boolean Inspector property")
	_expect(has_max_health, "Health max setting is listed in the native Inspector")
	_expect(has_invulnerable, "Health invulnerability setting is listed in the native Inspector")
	_expect(settings_are_storage_only, "raw settings dictionary is saved but hidden from the Inspector")
	_expect(is_equal_approx(float(component_definition._get(StringName(max_health_field))), 100.0), "component Inspector getter reads the catalog default")
	_expect(component_definition._set(StringName(max_health_field), 250.0), "component Inspector setter accepts a valid setting")
	_expect(is_equal_approx(float(component_definition.get_setting("max_health")), 250.0), "component settings API reads Inspector edits")
	_expect(component_definition._property_get_revert(StringName(max_health_field)) == 100.0, "component Inspector revert uses the catalog default")
	_expect(not component_definition._set(StringName(max_health_field), "invalid"), "component setting rejects a value with the wrong type")
	_expect(is_equal_approx(float(component_definition.get_setting("max_health")), 250.0), "rejected component setting leaves the previous value unchanged")

	var object_definition := ObjectDefinition.new()
	object_definition.object_id = "component_settings_serialization_test"
	object_definition.display_name = "Component Settings Serialization Test"
	object_definition.category = "Other"
	object_definition.components = [component_definition]
	var save_path := "user://component_settings_serialization_test.tres"
	var save_error := ResourceSaver.save(object_definition, save_path)
	_expect(save_error == OK, "ObjectDefinition with component settings can be saved")
	if save_error == OK:
		var loaded_definition := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_REPLACE) as ObjectDefinition
		_expect(loaded_definition != null, "saved ObjectDefinition with components can be loaded")
		if loaded_definition != null and not loaded_definition.components.is_empty():
			var loaded_component := loaded_definition.components[0]
			_expect(
				is_equal_approx(float(loaded_component.get_setting("max_health")), 250.0),
				"component Inspector values survive ObjectDefinition serialization"
			)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _test_component_definition_validation() -> void:
	var definition := ObjectDefinition.new()
	definition.object_id = "component_validation_test"
	definition.display_name = "Component Validation Test"
	definition.category = "Other"
	var health := ObjectComponentCatalog.create_definition("health")
	definition.components = [health]
	_expect(
		ObjectLibraryService.validate_definition(definition).is_empty(),
		"catalog component without an explicit script passes validation"
	)

	var duplicate := ObjectComponentCatalog.create_definition("health")
	definition.components.append(duplicate)
	_expect(
		not ObjectLibraryService.validate_definition(definition).is_empty(),
		"duplicate component IDs are rejected"
	)

	definition.components = []
	var unknown := ObjectComponentDefinition.new()
	unknown.component_id = "missing_component"
	definition.components = [unknown]
	_expect(
		not ObjectLibraryService.validate_definition(definition).is_empty(),
		"component without a script or catalog entry is rejected"
	)


func _test_component_node_bindings() -> void:
	var scene_root := Node2D.new()
	scene_root.name = "BindingRoot"

	var visuals := Node2D.new()
	visuals.name = "Visuals"
	scene_root.add_child(visuals)

	var physics := StaticBody2D.new()
	physics.name = "Physics"
	var hitbox := CollisionShape2D.new()
	hitbox.name = "Hitbox"
	hitbox.shape = CircleShape2D.new()
	physics.add_child(hitbox)
	scene_root.add_child(physics)

	var logic := Node.new()
	logic.name = "Logic"
	scene_root.add_child(logic)

	visuals.owner = scene_root
	physics.owner = scene_root
	hitbox.owner = scene_root
	logic.owner = scene_root

	var packed_scene := PackedScene.new()
	_expect(packed_scene.pack(scene_root) == OK, "multi-part object scene can be packed")
	scene_root.free()

	var health_binding := ObjectComponentCatalog.create_binding("health", NodePath("Visuals"))
	var damageable_binding := ObjectComponentCatalog.create_binding("damageable", NodePath("Physics"))
	var destructible_binding := ObjectComponentCatalog.create_binding("destructible", NodePath("Logic"))
	_expect(
		health_binding != null and damageable_binding != null and destructible_binding != null,
		"catalog can create component bindings for different object nodes"
	)
	if health_binding == null or damageable_binding == null or destructible_binding == null:
		return

	health_binding.binding_id = "health_on_visuals"
	health_binding.component_definition.settings["max_health"] = 40.0
	health_binding.component_definition.settings["starting_health"] = 40.0
	damageable_binding.binding_id = "damageable_on_physics"
	destructible_binding.binding_id = "destructible_on_logic"

	var definition := ObjectDefinition.new()
	definition.object_id = "multi_node_component_binding_smoke_test"
	definition.display_name = "Multi Node Component Binding Test"
	definition.category = "Other"
	definition.scene = packed_scene
	definition.component_bindings = [
		health_binding,
		damageable_binding,
		destructible_binding
	]

	_expect(
		ObjectLibraryService.validate_definition(definition).is_empty(),
		"valid component bindings to different scene nodes pass validation"
	)

	var instance := ObjectFactory.instantiate(definition)
	_expect(instance != null, "factory creates an object with multi-node component bindings")
	if instance == null:
		return

	var visual_node := instance.get_node("Visuals")
	var physics_node := instance.get_node("Physics")
	var health := ObjectFactory.get_component(instance, "health") as HealthComponent
	var damageable := ObjectFactory.get_component(instance, "damageable") as DamageableComponent
	var destructible := ObjectFactory.get_component(instance, "destructible") as DestructibleComponent

	_expect(health != null and health.get_parent() == visual_node, "Health is attached to the requested Visuals node")
	_expect(
		damageable != null and damageable.get_parent() == physics_node,
		"Damageable is attached to the requested Physics node"
	)
	_expect(
		destructible != null and destructible.get_parent() == instance.get_node("Logic"),
		"Destructible is attached to the requested Logic node"
	)
	_expect(
		health != null and health.get_object_root() == instance,
		"nested component can resolve its owning object root"
	)
	_expect(
		damageable != null and ObjectFactory.get_component_on(physics_node, "damageable") == damageable,
		"component can be resolved directly on its assigned node"
	)
	_expect(
		ObjectFactory.get_component_by_binding_id(instance, "health_on_visuals") == health,
		"component can be resolved by its stable binding ID"
	)
	_expect(
		ObjectFactory.get_components(instance).size() == 3,
		"factory can enumerate all components across the object hierarchy"
	)

	var test_world := Node2D.new()
	root.add_child(test_world)
	test_world.add_child(instance)
	await process_frame

	if health != null and damageable != null and destructible != null:
		_expect(
			is_equal_approx(damageable.receive_damage(10.0), 10.0),
			"Damageable on one node can find Health attached to another node"
		)
		_expect(
			is_equal_approx(health.current_health, 30.0),
			"cross-node damage reduces the shared object Health"
		)
		_expect(
			is_equal_approx(damageable.receive_damage(100.0), 30.0),
			"cross-node lethal damage reaches Health"
		)
		_expect(
			destructible.is_destroyed(),
			"Destructible on a third node reacts to the nested Health component"
		)
		_expect(
			int(physics.collision_layer) == 0 and int(physics.collision_mask) == 0,
			"nested Destructible disables collision on the owning object"
		)
		_expect(hitbox.disabled, "nested Destructible disables collision shapes on the owning object")
		_expect(destructible.repair(), "nested Destructible can repair the owning object")
		_expect(
			int(physics.collision_layer) == 1 and int(physics.collision_mask) == 1,
			"repair restores collision settings on a different node"
		)
		_expect(not hitbox.disabled, "repair restores the nested collision shape")
		_expect(
			is_equal_approx(health.current_health, 40.0),
			"repair restores Health attached to a different node"
		)

	var invalid_path := damageable_binding.target_node_path
	damageable_binding.target_node_path = NodePath("Missing/Node")
	_expect(
		not ObjectLibraryService.validate_definition(definition).is_empty(),
		"validation reports a component binding whose target node does not exist"
	)
	damageable_binding.target_node_path = invalid_path

	var duplicate_binding := ObjectComponentCatalog.create_binding("attack")
	duplicate_binding.binding_id = health_binding.binding_id
	definition.component_bindings.append(duplicate_binding)
	_expect(
		not ObjectLibraryService.validate_definition(definition).is_empty(),
		"validation rejects duplicate component binding IDs"
	)
	definition.component_bindings.erase(duplicate_binding)

	var save_path := "user://component_bindings_serialization_test.tres"
	var save_error := ResourceSaver.save(definition, save_path)
	_expect(save_error == OK, "component bindings and their scene can be serialized")
	if save_error == OK:
		var restored := ResourceLoader.load(
			save_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		) as ObjectDefinition
		_expect(restored != null, "serialized component bindings can be loaded")
		if restored != null:
			_expect(restored.component_bindings.size() == 3, "all component bindings survive serialization")
			if not restored.component_bindings.is_empty():
				_expect(
					restored.component_bindings[0].target_node_path == NodePath("Visuals"),
					"component target NodePath survives serialization"
				)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	test_world.free()

func _make_property(
	property_id: String,
	value_type: String,
	default_value: Variant
) -> ObjectPropertyDefinition:
	var definition := ObjectPropertyDefinition.new()
	definition.property_id = property_id
	definition.display_name = property_id.capitalize()
	definition.value_type = value_type
	definition.default_value = default_value
	return definition


func _on_health_component_died() -> void:
	health_died_signal_received = true


func _on_destructible_destroyed(_source: Node) -> void:
	destructible_destroyed_received = true


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
