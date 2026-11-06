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
	await _test_simple_capability_resolution()
	_test_capability_selection_plans()
	_test_capability_schema_and_application_plan()
	_test_capability_library_size_and_status()
	await _test_component_node_bindings()
	_test_declarative_scene_structure()
	_test_creation_profile_registry()
	await _test_extension_registries()

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





func _test_declarative_scene_structure() -> void:
	var definition := ObjectDefinition.new()
	definition.object_id = "declarative_structure_smoke"
	definition.display_name = "Declarative Structure"
	definition.category = "Other"
	definition.root_type = "Node2D"

	var visual := ObjectNodeDefinition.new()
	visual.node_id = "visual"
	visual.parent_node_id = "root"
	visual.node_type = "Node2D"
	visual.node_name = "Visual"
	visual.properties = {"position": Vector2(8.0, 12.0)}

	var interaction := ObjectNodeDefinition.new()
	interaction.node_id = "interaction"
	interaction.parent_node_id = "visual"
	interaction.node_type = "Area2D"
	interaction.node_name = "Interaction"
	interaction.groups = PackedStringArray(["interactable"])
	interaction.metadata = {"interaction_kind": "test"}

	var timer := ObjectNodeDefinition.new()
	timer.node_id = "timer"
	timer.parent_node_id = "interaction"
	timer.node_type = "Timer"
	timer.node_name = "Timeout"
	timer.properties = {"wait_time": 0.75, "one_shot": true}

	var connection := ObjectSignalConnectionDefinition.new()
	connection.connection_id = "timer_hides_root"
	connection.source_node_id = "timer"
	connection.signal_name = "timeout"
	connection.target_node_id = "root"
	connection.method_name = "hide"
	connection.flags = Object.CONNECT_PERSIST

	definition.node_definitions = [visual, interaction, timer]
	definition.signal_connections = [connection]

	var plan_root := Node2D.new()
	var plan := ObjectSceneStructureService.build_plan(definition, plan_root)
	var ordered: Array = plan.get("ordered_nodes", [])
	_expect(
		bool(plan.get("ok", false)) and ordered.size() == 3,
		"scene structure preflight resolves parent nodes before their children"
	)
	plan_root.free()

	var instance := ObjectFactory.instantiate(definition)
	_expect(instance != null, "factory builds an object from declarative node definitions")
	if instance == null:
		return
	var visual_node := instance.get_node_or_null("Visual") as Node2D
	var interaction_node := instance.get_node_or_null("Visual/Interaction") as Area2D
	var timer_node := instance.get_node_or_null("Visual/Interaction/Timeout") as Timer
	_expect(visual_node != null, "factory creates the declared visual node")
	_expect(interaction_node != null, "factory creates nested nodes in parent order")
	_expect(timer_node != null, "factory creates the declared Timer node")
	if visual_node != null:
		_expect(visual_node.position == Vector2(8.0, 12.0), "declared node properties are applied")
	if interaction_node != null:
		_expect(interaction_node.is_in_group("interactable"), "declared node groups are applied")
		_expect(interaction_node.get_meta("interaction_kind", "") == "test", "declared node metadata is applied")
	if timer_node != null:
		_expect(is_equal_approx(timer_node.wait_time, 0.75), "Timer properties are configured")
		_expect(timer_node.one_shot, "boolean node properties are configured")
		_expect(
			timer_node.is_connected("timeout", Callable(instance, "hide")),
			"declared signal connection is applied"
		)

	var definition_path := "user://object_builder_structure_smoke.tres"
	var definition_save_error := ResourceSaver.save(definition, definition_path)
	_expect(definition_save_error == OK, "node and signal definitions serialize as ObjectDefinition resources")
	if definition_save_error == OK:
		var loaded_definition := ResourceLoader.load(definition_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ObjectDefinition
		_expect(
			loaded_definition != null
			and loaded_definition.node_definitions.size() == 3
			and loaded_definition.signal_connections.size() == 1,
			"serialized ObjectDefinition restores all declared nodes and signal connections"
		)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(definition_path))

	var packed := PackedScene.new()
	var pack_error := packed.pack(instance)
	_expect(pack_error == OK, "declarative scene structure can be packed as a real PackedScene")
	instance.free()
	if pack_error == OK:
		var restored := packed.instantiate()
		_expect(
			restored.get_node_or_null("Visual/Interaction/Timeout") is Timer,
			"nested generated nodes survive PackedScene round-trip"
		)
		var restored_timer := restored.get_node("Visual/Interaction/Timeout") as Timer
		_expect(
			restored_timer.is_connected("timeout", Callable(restored, "hide")),
			"persistent signal connections survive PackedScene round-trip"
		)
		restored.free()

	var invalid_definition := ObjectDefinition.new()
	invalid_definition.object_id = "invalid_structure_smoke"
	invalid_definition.display_name = "Invalid Structure"
	invalid_definition.category = "Other"
	var valid_first := ObjectNodeDefinition.new()
	valid_first.node_id = "would_be_created"
	valid_first.node_type = "Node2D"
	valid_first.node_name = "WouldBeCreated"
	var invalid_second := ObjectNodeDefinition.new()
	invalid_second.node_id = "invalid_property"
	invalid_second.node_type = "Node2D"
	invalid_second.node_name = "InvalidProperty"
	invalid_second.properties = {"property_that_does_not_exist": 1}
	invalid_definition.node_definitions = [valid_first, invalid_second]
	var untouched_root := Node2D.new()
	var invalid_plan := ObjectSceneStructureService.apply_structure(invalid_definition, untouched_root)
	_expect(
		not bool(invalid_plan.get("ok", false))
		and untouched_root.get_node_or_null("WouldBeCreated") == null,
		"invalid structure is rejected before any node is added"
	)
	untouched_root.free()

	var orphan_definition := ObjectDefinition.new()
	orphan_definition.object_id = "orphan_structure_smoke"
	orphan_definition.display_name = "Orphan Structure"
	orphan_definition.category = "Other"
	var orphan := ObjectNodeDefinition.new()
	orphan.node_id = "orphan"
	orphan.parent_node_id = "missing_parent"
	orphan.node_name = "Orphan"
	orphan_definition.node_definitions = [orphan]
	var orphan_root := Node2D.new()
	var orphan_errors := ObjectSceneStructureService.build_plan(orphan_definition, orphan_root).get("errors", PackedStringArray())
	_expect(not orphan_errors.is_empty(), "structure preflight rejects missing parent IDs")
	orphan_root.free()

	var invalid_signal_definition := ObjectDefinition.new()
	invalid_signal_definition.object_id = "invalid_signal_structure_smoke"
	invalid_signal_definition.display_name = "Invalid Signal Structure"
	invalid_signal_definition.category = "Other"
	var invalid_signal := ObjectSignalConnectionDefinition.new()
	invalid_signal.connection_id = "missing_method"
	invalid_signal.source_node_id = "root"
	invalid_signal.signal_name = "ready"
	invalid_signal.target_node_id = "root"
	invalid_signal.method_name = "method_that_does_not_exist"
	invalid_signal_definition.signal_connections = [invalid_signal]
	var signal_root := Node2D.new()
	var invalid_signal_plan := ObjectSceneStructureService.build_plan(invalid_signal_definition, signal_root)
	_expect(
		not bool(invalid_signal_plan.get("ok", false)),
		"structure preflight rejects connections to missing methods"
	)
	signal_root.free()


func _test_creation_profile_registry() -> void:
	var profile_ids := ObjectCreationProfileRegistry.get_profile_ids()
	_expect(profile_ids.size() == 12, "all twelve built-in creation profiles are registered")
	_expect(
		profile_ids.has("npc") and profile_ids.has("resource") and profile_ids.has("weapon")
		and profile_ids.has("other"),
		"built-in profiles cover common object categories and generic objects"
	)
	_expect(
		not ObjectCreationProfileRegistry.has_profile(""),
		"blank creation is an explicit no-profile choice, not a mandatory profile"
	)

	var generic := ObjectCreationProfileRegistry.get_definition("other")
	_expect(generic != null, "generic creation profile can be loaded")
	if generic != null:
		_expect(
			generic.suggested_root_type == "Node2D"
			and generic.suggested_category == "Other"
			and generic.suggested_properties.is_empty(),
			"generic profile creates a clean object without preset properties"
		)

	var weapon := ObjectCreationProfileRegistry.get_definition("weapon")
	_expect(weapon != null, "weapon profile can be loaded from the registry")
	if weapon != null:
		_expect(
			weapon.suggested_category == "Equipment"
			and weapon.suggested_root_type == "Area2D"
			and not weapon.suggested_properties.is_empty(),
			"weapon profile exposes category, suggested root and starter properties"
		)
		if not weapon.suggested_properties.is_empty():
			_expect(
				weapon.suggested_properties[0].property_id == "damage",
				"weapon starter property keeps its stable property ID"
			)

	var first_copy := ObjectCreationProfileRegistry.get_definition("weapon")
	var second_copy := ObjectCreationProfileRegistry.get_definition("weapon")
	if first_copy != null and second_copy != null and not first_copy.suggested_properties.is_empty():
		first_copy.suggested_properties[0].display_name = "Изменено только в копии"
		_expect(
			second_copy.suggested_properties[0].display_name != "Изменено только в копии",
			"editing a retrieved profile copy does not mutate the registry"
		)

	var custom_profile := ObjectCreationProfileDefinition.new()
	custom_profile.profile_id = "smoke_custom_profile"
	custom_profile.display_name = "Профиль smoke-теста"
	custom_profile.description = "Внешний профиль не ограничивает возможности."
	custom_profile.suggested_category = "Other"
	custom_profile.suggested_root_type = "Node2D"
	custom_profile.suggested_properties = [_make_property("custom_value", "Integer", 7)]
	var source_id := "object_builder_profile_smoke_test"
	_expect(
		ObjectCreationProfileRegistry.register_definition(custom_profile, source_id),
		"extension can register a custom creation profile"
	)
	_expect(
		ObjectCreationProfileRegistry.has_profile("smoke_custom_profile")
		and ObjectCreationProfileRegistry.get_source_id("smoke_custom_profile") == source_id,
		"custom creation profile is discoverable with its source"
	)

	var builtin_override := custom_profile.duplicate(true) as ObjectCreationProfileDefinition
	builtin_override.profile_id = "npc"
	_expect(
		not ObjectCreationProfileRegistry.register_definition(builtin_override, source_id),
		"extension cannot override a built-in creation profile"
	)
	_expect(
		ObjectCreationProfileRegistry.unregister_source(source_id).is_empty()
		and not ObjectCreationProfileRegistry.has_profile("smoke_custom_profile"),
		"unregistering an extension removes only its own creation profiles"
	)
	_expect(
		ObjectCreationProfileRegistry.validate_registry().is_empty(),
		"creation profile registry validates after extension registration and removal"
	)



func _test_extension_registries() -> void:
	_expect(
		ObjectComponentCatalog.get_source_id("health") == "builtin",
		"built-in Health is registered in the shared component registry"
	)
	_expect(
		ObjectComponentCatalog.get_source_id("destructible") == "builtin",
		"built-in Destructible is registered in the shared component registry"
	)
	_expect(
		ObjectComponentCatalog.create_definition("health") != null
		and ObjectComponentCatalog.get_component_ids("Stats").has("health"),
		"built-in components are discovered through the same registry query API as extensions"
	)
	_expect(
		not ObjectComponentCatalog.unregister_source("builtin").is_empty(),
		"built-in component registry source is protected from extension removal"
	)

	var source_id := "object_builder_registry_smoke"

	var custom_component := ObjectComponentDefinition.new()
	custom_component.component_id = "registry_test_health"
	custom_component.display_name = "Registry Test Health"
	custom_component.description = "Временная проверка внешней регистрации компонента."
	custom_component.category = "Stats"
	custom_component.category_id = "Stats"
	custom_component.category_display_name = "Характеристики"
	custom_component.component_version = 1
	custom_component.component_script = load(
		"res://scripts/object_system/components/health_component.gd"
	) as Script
	custom_component.setting_definitions = ObjectComponentDefinition.get_builtin_setting_definitions("health")
	for descriptor in custom_component.setting_definitions:
		custom_component.settings[str(descriptor.get("key", ""))] = descriptor.get("default_value")

	_expect(
		ObjectComponentCatalog.register_definition(custom_component, source_id),
		"extension registry accepts a valid custom component definition"
	)
	_expect(
		ObjectComponentCatalog.has_component("registry_test_health"),
		"registered custom component becomes discoverable by ID"
	)
	_expect(
		ObjectComponentCatalog.get_source_id("registry_test_health") == source_id,
		"component registry remembers the owning extension source"
	)
	_expect(
		ObjectComponentCatalog.create_definition("registry_test_health") != null,
		"registered custom component can be instantiated as a definition"
	)
	_expect(
		ObjectComponentCatalog.get_component_ids("Stats").has("registry_test_health"),
		"custom component appears in its category list"
	)

	var dependency_component := custom_component.duplicate(true) as ObjectComponentDefinition
	dependency_component.component_id = "registry_test_requires_health"
	dependency_component.display_name = "Registry Test Dependent"
	dependency_component.description = "Проверяет автоматическое подключение обязательного компонента."
	dependency_component.supported_node_types = PackedStringArray(["StaticBody2D"])
	dependency_component.required_component_ids = PackedStringArray(["registry_test_health"])
	_expect(
		ObjectComponentCatalog.register_definition(dependency_component, source_id),
		"registry accepts a component with a supported node type and a required component"
	)

	var dependency_scene_root := Node2D.new()
	dependency_scene_root.name = "DependencyRoot"
	var dependency_physics := StaticBody2D.new()
	dependency_physics.name = "Physics"
	dependency_scene_root.add_child(dependency_physics)
	dependency_physics.owner = dependency_scene_root
	var dependency_packed_scene := PackedScene.new()
	_expect(
		dependency_packed_scene.pack(dependency_scene_root) == OK,
		"component dependency scene with a physics node can be packed"
	)
	dependency_scene_root.free()

	var dependency_binding := ObjectComponentBinding.new()
	dependency_binding.binding_id = "registry_component_needs_health"
	dependency_binding.component_definition = dependency_component.duplicate(true) as ObjectComponentDefinition
	dependency_binding.target_node_path = NodePath("Physics")
	var dependency_object := ObjectDefinition.new()
	dependency_object.object_id = "component_node_type_dependency_smoke"
	dependency_object.display_name = "Component Node Type Dependency Smoke"
	dependency_object.category = "Other"
	dependency_object.scene = dependency_packed_scene
	dependency_object.component_bindings = [dependency_binding]

	_expect(
		ObjectLibraryService.validate_definition(dependency_object).is_empty(),
		"component binding with supported StaticBody2D target and available dependency passes validation"
	)
	var dependency_instance := ObjectFactory.instantiate(dependency_object)
	_expect(
		dependency_instance != null,
		"factory instantiates a component binding with its required component"
	)
	if dependency_instance != null:
		var physics_node := dependency_instance.get_node("Physics")
		var dependent_component := ObjectFactory.get_component(dependency_instance, "registry_test_requires_health")
		var required_component := ObjectFactory.get_component(dependency_instance, "registry_test_health")
		_expect(
			dependent_component != null and dependent_component.get_parent() == physics_node,
			"custom component attaches to its requested supported physics node"
		)
		_expect(
			required_component != null and required_component.get_parent() == physics_node,
			"factory automatically attaches the missing required component to the same node"
		)
		dependency_instance.free()

	var unsupported_scene_root := Node2D.new()
	unsupported_scene_root.name = "UnsupportedRoot"
	var visual_node := Node2D.new()
	visual_node.name = "Visuals"
	unsupported_scene_root.add_child(visual_node)
	visual_node.owner = unsupported_scene_root
	var unsupported_packed_scene := PackedScene.new()
	_expect(
		unsupported_packed_scene.pack(unsupported_scene_root) == OK,
		"unsupported target scene can be packed"
	)
	unsupported_scene_root.free()

	var unsupported_binding := ObjectComponentBinding.new()
	unsupported_binding.binding_id = "registry_component_wrong_node"
	unsupported_binding.component_definition = dependency_component.duplicate(true) as ObjectComponentDefinition
	unsupported_binding.target_node_path = NodePath("Visuals")
	var unsupported_validation_root := unsupported_packed_scene.instantiate()
	var unsupported_plan := ObjectComponentCatalog.resolve_bindings([unsupported_binding], unsupported_validation_root)
	_expect(
		not bool(unsupported_plan.get("ok", false)),
		"component binding is rejected when its target node type is not supported"
	)
	unsupported_validation_root.free()
	var unsupported_definition := ObjectDefinition.new()
	unsupported_definition.object_id = "component_unsupported_node_type_smoke"
	unsupported_definition.display_name = "Unsupported Node Type Smoke"
	unsupported_definition.category = "Other"
	unsupported_definition.scene = unsupported_packed_scene
	unsupported_definition.component_bindings = [unsupported_binding]
	_expect(
		not ObjectLibraryService.validate_definition(unsupported_definition).is_empty(),
		"library validation reports a component binding placed on an unsupported node type"
	)

	var custom_capability := ObjectCapabilityDefinition.new()
	custom_capability.capability_id = "registry_test_durability"
	custom_capability.display_name = "Проверочная прочность"
	custom_capability.description = "Проверяет регистрацию пользовательской возможности."
	custom_capability.category_id = "stats"
	custom_capability.category_name = "Характеристики"
	custom_capability.icon = "shield"
	custom_capability.keywords = PackedStringArray(["прочность", "проверка"])
	custom_capability.component_ids = PackedStringArray(["registry_test_health"])
	custom_capability.available_in_simple_mode = true
	custom_capability.version = 1

	_expect(
		ObjectCapabilityCatalog.register_definition(custom_capability, source_id),
		"extension registry accepts a capability that references a registered component"
	)
	_expect(
		ObjectCapabilityCatalog.has_capability("registry_test_durability"),
		"registered custom capability becomes discoverable by ID"
	)
	_expect(
		ObjectCapabilityCatalog.get_source_id("registry_test_durability") == source_id,
		"capability registry remembers the owning extension source"
	)
	_expect(
		ObjectCapabilityCatalog.get_capability_ids("stats").has("registry_test_durability"),
		"custom capability appears in the simple-mode category list"
	)
	var category_found := false
	for category in ObjectCapabilityCatalog.get_categories():
		if str(category.get("id", "")) == "stats":
			category_found = str(category.get("display_name", "")) == "Характеристики"
	_expect(category_found, "capability registry exposes custom category metadata")

	var selection := ObjectCapabilityCatalog.create_selection("registry_test_durability")
	_expect(selection != null, "custom capability can create a saved user selection")
	if selection != null:
		selection.set_component_setting("registry_test_health", "max_health", 73.0)
		selection.set_component_setting("registry_test_health", "starting_health", 73.0)
		var definition := ObjectDefinition.new()
		definition.object_id = "custom_registry_runtime_smoke"
		definition.display_name = "Custom Registry Runtime Smoke"
		definition.category = "Other"
		definition.capabilities = [selection]

		_expect(
			ObjectLibraryService.validate_definition(definition).is_empty(),
			"object using a custom capability passes library validation"
		)
		var instance := ObjectFactory.instantiate(definition)
		_expect(instance != null, "ObjectFactory resolves a custom registered capability")
		if instance != null:
			var test_world := Node2D.new()
			root.add_child(test_world)
			test_world.add_child(instance)
			await process_frame
			var custom_health := ObjectFactory.get_component(instance, "registry_test_health") as HealthComponent
			_expect(custom_health != null, "custom component script is attached by its registered ID")
			if custom_health != null:
				_expect(
					is_equal_approx(custom_health.max_health, 73.0)
					and is_equal_approx(custom_health.current_health, 73.0),
					"custom capability settings reach the registered component instance"
				)
			test_world.free()

	var reserved_component := ObjectComponentDefinition.new()
	reserved_component.component_id = "health"
	reserved_component.display_name = "Attempted Override"
	reserved_component.component_script = custom_component.component_script
	_expect(
		not ObjectComponentCatalog.register_definition(reserved_component, "another_extension"),
		"extension cannot shadow a built-in component ID"
	)

	var unknown_dependency := ObjectCapabilityDefinition.new()
	unknown_dependency.capability_id = "registry_test_bad_dependency"
	unknown_dependency.display_name = "Bad Dependency"
	unknown_dependency.description = "Should not register."
	unknown_dependency.category_id = "general"
	unknown_dependency.category_name = "Основное"
	unknown_dependency.required_capability_ids = PackedStringArray(["does_not_exist"])
	_expect(
		not ObjectCapabilityCatalog.register_definition(unknown_dependency, "bad_extension"),
		"capability with an unknown dependency is rejected"
	)
	_expect(
		not ObjectCapabilityCatalog.has_capability("registry_test_bad_dependency"),
		"failed capability registration does not partially modify the registry"
	)

	var cycle_a := ObjectCapabilityDefinition.new()
	cycle_a.capability_id = "registry_cycle_a"
	cycle_a.display_name = "Cycle A"
	cycle_a.description = "Dependency cycle test."
	cycle_a.category_id = "general"
	cycle_a.category_name = "Основное"
	cycle_a.required_capability_ids = PackedStringArray(["registry_cycle_b"])
	var cycle_b := ObjectCapabilityDefinition.new()
	cycle_b.capability_id = "registry_cycle_b"
	cycle_b.display_name = "Cycle B"
	cycle_b.description = "Dependency cycle test."
	cycle_b.category_id = "general"
	cycle_b.category_name = "Основное"
	cycle_b.required_capability_ids = PackedStringArray(["registry_cycle_a"])
	_expect(
		not ObjectCapabilityCatalog.register_definitions([cycle_a, cycle_b], "cycle_extension").is_empty(),
		"capability registry rejects a dependency cycle in an atomic batch"
	)
	_expect(
		not ObjectCapabilityCatalog.has_capability("registry_cycle_a")
		and not ObjectCapabilityCatalog.has_capability("registry_cycle_b"),
		"failed dependency batch leaves no partially registered cards"
	)

	var conflict_a := ObjectCapabilityDefinition.new()
	conflict_a.capability_id = "registry_conflict_a"
	conflict_a.display_name = "Conflict A"
	conflict_a.description = "Conflict validation test."
	conflict_a.category_id = "general"
	conflict_a.category_name = "Основное"
	conflict_a.incompatible_capability_ids = PackedStringArray(["registry_conflict_b"])
	var conflict_b := ObjectCapabilityDefinition.new()
	conflict_b.capability_id = "registry_conflict_b"
	conflict_b.display_name = "Conflict B"
	conflict_b.description = "Conflict validation test."
	conflict_b.category_id = "general"
	conflict_b.category_name = "Основное"
	conflict_b.incompatible_capability_ids = PackedStringArray(["registry_conflict_a"])
	_expect(
		ObjectCapabilityCatalog.register_definitions([conflict_a, conflict_b], "conflict_extension").is_empty(),
		"registry accepts a mutually declared pair of incompatible capabilities"
	)
	var conflict_selection_a := ObjectCapabilityCatalog.create_selection("registry_conflict_a")
	var conflict_selection_b := ObjectCapabilityCatalog.create_selection("registry_conflict_b")
	_expect(
		not ObjectCapabilityService.validate_selections([conflict_selection_a, conflict_selection_b]).is_empty(),
		"selected incompatible capabilities are rejected before object creation"
	)
	_expect(
		ObjectCapabilityCatalog.unregister_source("conflict_extension").is_empty(),
		"extension can unregister a capability source after its objects are no longer registered"
	)

	_expect(
		ObjectCapabilityCatalog.unregister_source(source_id).is_empty(),
		"extension can unregister its capability definitions"
	)
	_expect(
		ObjectComponentCatalog.unregister_source(source_id).is_empty(),
		"extension can unregister components after dependent capability cards are removed"
	)
	_expect(
		not ObjectCapabilityCatalog.has_capability("registry_test_durability")
		and not ObjectComponentCatalog.has_component("registry_test_health"),
		"unregistering an extension removes all definitions owned by that source"
	)



func _test_capability_selection_plans() -> void:
	var empty_selections: Array[ObjectCapabilitySelection] = []
	var add_damage_plan := ObjectCapabilityService.plan_selection_change(
		empty_selections,
		"can_receive_damage",
		true
	)
	_expect(
		bool(add_damage_plan.get("ok", false)),
		"adding a capability with one dependency produces a valid change plan"
	)
	if not bool(add_damage_plan.get("ok", false)):
		return

	var planned_values: Array[ObjectCapabilitySelection] = []
	var raw_values: Variant = add_damage_plan.get("selections", [])
	if raw_values is Array:
		for value in raw_values:
			if value is ObjectCapabilitySelection:
				planned_values.append(value as ObjectCapabilitySelection)

	_expect(planned_values.size() == 2, "adding Damageable automatically includes its Health dependency")
	var health_selection: ObjectCapabilitySelection
	var damage_selection: ObjectCapabilitySelection
	for selection in planned_values:
		if selection.capability_id == "has_health":
			health_selection = selection
		elif selection.capability_id == "can_receive_damage":
			damage_selection = selection
	_expect(
		health_selection != null and health_selection.enabled and health_selection.automatically_added,
		"automatically required Health selection is marked as dependency-managed"
	)
	_expect(
		damage_selection != null and damage_selection.enabled and not damage_selection.automatically_added,
		"user-selected capability is not marked as an automatic dependency"
	)

	var generated_bindings := ObjectCapabilityService.build_component_bindings(planned_values)
	_expect(
		generated_bindings.size() == 2,
		"dependency-complete selection plan produces both runtime component bindings"
	)
	var generated_ids := PackedStringArray()
	for binding in generated_bindings:
		generated_ids.append(binding.get_component_id())
	_expect(
		generated_ids.has("health") and generated_ids.has("damageable"),
		"selection plan resolves both Health and Damageable"
	)

	var forbidden_disable_plan := ObjectCapabilityService.plan_selection_change(
		planned_values,
		"has_health",
		false
	)
	_expect(
		not bool(forbidden_disable_plan.get("ok", false)),
		"required capability cannot be disabled while an active capability depends on it"
	)
	var forbidden_errors: PackedStringArray = forbidden_disable_plan.get("errors", PackedStringArray())
	_expect(
		not forbidden_errors.is_empty() and str(forbidden_errors[0]).contains("Сначала отключи"),
		"blocked dependency change explains which feature must be disabled first"
	)
	_expect(
		health_selection.enabled and damage_selection.enabled,
		"failed change plan leaves the original selection list untouched"
	)

	var remove_damage_plan := ObjectCapabilityService.plan_selection_change(
		planned_values,
		"can_receive_damage",
		false
	)
	_expect(
		bool(remove_damage_plan.get("ok", false)),
		"dependent capability can be disabled before its automatic dependency"
	)
	var after_remove: Array[ObjectCapabilitySelection] = []
	var remove_values: Variant = remove_damage_plan.get("selections", [])
	if remove_values is Array:
		for value in remove_values:
			if value is ObjectCapabilitySelection:
				after_remove.append(value as ObjectCapabilitySelection)
	var health_after_remove: ObjectCapabilitySelection
	var damage_after_remove: ObjectCapabilitySelection
	for selection in after_remove:
		if selection.capability_id == "has_health":
			health_after_remove = selection
		elif selection.capability_id == "can_receive_damage":
			damage_after_remove = selection
	_expect(
		damage_after_remove != null and not damage_after_remove.enabled,
		"disabling a capability retains it as a disabled choice"
	)
	_expect(
		health_after_remove != null and not health_after_remove.enabled,
		"orphaned automatic dependency is disabled with its last dependent"
	)

	var manual_health_plan := ObjectCapabilityService.plan_selection_change(
		empty_selections,
		"has_health",
		true
	)
	var manual_values: Array[ObjectCapabilitySelection] = []
	var manual_raw: Variant = manual_health_plan.get("selections", [])
	if manual_raw is Array:
		for value in manual_raw:
			if value is ObjectCapabilitySelection:
				manual_values.append(value as ObjectCapabilitySelection)
	var add_damage_to_manual_plan := ObjectCapabilityService.plan_selection_change(
		manual_values,
		"can_receive_damage",
		true
	)
	var manual_with_damage: Array[ObjectCapabilitySelection] = []
	var manual_with_damage_raw: Variant = add_damage_to_manual_plan.get("selections", [])
	if manual_with_damage_raw is Array:
		for value in manual_with_damage_raw:
			if value is ObjectCapabilitySelection:
				manual_with_damage.append(value as ObjectCapabilitySelection)
	var remove_manual_damage_plan := ObjectCapabilityService.plan_selection_change(
		manual_with_damage,
		"can_receive_damage",
		false
	)
	var manual_health_remains := false
	var manual_health_is_still_manual := false
	var remaining_raw: Variant = remove_manual_damage_plan.get("selections", [])
	if remaining_raw is Array:
		for value in remaining_raw:
			if value is ObjectCapabilitySelection and value.capability_id == "has_health":
				manual_health_remains = (value as ObjectCapabilitySelection).enabled
				manual_health_is_still_manual = not (value as ObjectCapabilitySelection).automatically_added
	_expect(
		bool(remove_manual_damage_plan.get("ok", false))
		and manual_health_remains
		and manual_health_is_still_manual,
		"manually selected Health remains enabled after the dependent capability is removed"
	)

	var invalid_selection := ObjectCapabilityCatalog.create_selection("unknown_capability")
	var invalid_plan := ObjectCapabilityService.plan_selection_change(
		empty_selections,
		"unknown_capability",
		true
	)
	_expect(
		not bool(invalid_plan.get("ok", false)),
		"unknown capability change is rejected before mutating selections"
	)
	var disabled_invalid := ObjectCapabilitySelection.new()
	disabled_invalid.capability_id = "unknown_capability"
	disabled_invalid.enabled = false
	_expect(
		ObjectCapabilityService.validate_selections([disabled_invalid]).is_empty(),
		"disabled legacy selections do not block object validation"
	)



func _test_capability_schema_and_application_plan() -> void:
	var health_schema := ObjectCapabilityCatalog.get_settings_schema("has_health")
	var has_max_health := false
	for descriptor in health_schema:
		if str(descriptor.get("setting_key", "")) == "max_health":
			has_max_health = (
				str(descriptor.get("component_id", "")) == "health"
				and str(descriptor.get("value_type", "")) == "Float"
				and str(descriptor.get("level", "")) in ["Basic", "Advanced", "Expert"]
			)
	_expect(
		not health_schema.is_empty() and has_max_health,
		"implemented capability exposes a typed settings schema sourced from its runtime component"
	)

	if not health_schema.is_empty():
		health_schema[0]["display_name"] = "Изменение только копии"
		var fresh_schema := ObjectCapabilityCatalog.get_settings_schema("has_health")
		_expect(
			str(fresh_schema[0].get("display_name", "")) != "Изменение только копии",
			"capability settings schema is returned as a defensive deep copy"
		)

	var invalid_schema := ObjectCapabilityDefinition.new()
	invalid_schema.capability_id = "registry_invalid_setting_schema"
	invalid_schema.display_name = "Invalid Setting Schema"
	invalid_schema.description = "Must fail validation."
	invalid_schema.category_id = "general"
	invalid_schema.category_name = "Основное"
	invalid_schema.component_ids = PackedStringArray(["health"])
	invalid_schema.settings_schema = [{
		"component_id": "health",
		"setting_key": "max_health",
		"value_type": "String",
		"level": "basic"
	}]
	var invalid_schema_errors := ObjectCapabilityCatalog.register_definitions(
		[invalid_schema],
		"invalid_schema_extension"
	)
	_expect(
		not invalid_schema_errors.is_empty()
		and not ObjectCapabilityCatalog.has_capability("registry_invalid_setting_schema"),
		"registry rejects a capability whose declared setting type conflicts with its component schema"
	)

	var invalid_level := ObjectCapabilityDefinition.new()
	invalid_level.capability_id = "registry_invalid_setting_level"
	invalid_level.display_name = "Invalid Setting Level"
	invalid_level.description = "Must fail validation."
	invalid_level.category_id = "general"
	invalid_level.category_name = "Основное"
	invalid_level.component_ids = PackedStringArray(["health"])
	invalid_level.settings_schema = [{
		"component_id": "health",
		"setting_key": "max_health",
		"value_type": "Float",
		"level": "impossible"
	}]
	var invalid_level_errors := ObjectCapabilityCatalog.register_definitions(
		[invalid_level],
		"invalid_level_extension"
	)
	_expect(
		not invalid_level_errors.is_empty()
		and not ObjectCapabilityCatalog.has_capability("registry_invalid_setting_level"),
		"registry rejects unknown Basic/Advanced/Expert setting levels"
	)

	var empty_selections: Array[ObjectCapabilitySelection] = []
	var planned: Dictionary = ObjectCapabilityService.plan_selection_change(
		empty_selections,
		"can_receive_damage",
		true
	)
	_expect(bool(planned.get("ok", false)), "valid capability setup produces the next selection state")
	if not bool(planned.get("ok", false)):
		return

	var planned_values: Array[ObjectCapabilitySelection] = []
	var raw_values: Variant = planned.get("selections", [])
	if raw_values is Array:
		for value in raw_values:
			if value is ObjectCapabilitySelection:
				planned_values.append(value as ObjectCapabilitySelection)

	var first_plan := ObjectCapabilityService.build_application_plan(empty_selections, planned_values)
	var first_added: Array = first_plan.get("added_components", [])
	_expect(
		bool(first_plan.get("ok", false))
		and bool(first_plan.get("changed", false))
		and first_added.size() == 2,
		"preflight reports both Health and Damageable before applying the selection"
	)

	var repeated_plan := ObjectCapabilityService.build_application_plan(planned_values, planned_values)
	var repeated_added: Array = repeated_plan.get("added_components", [])
	var repeated_removed: Array = repeated_plan.get("removed_components", [])
	var repeated_updated: Array = repeated_plan.get("updated_components", [])
	_expect(
		bool(repeated_plan.get("ok", false))
		and not bool(repeated_plan.get("changed", true))
		and repeated_added.is_empty()
		and repeated_removed.is_empty()
		and repeated_updated.is_empty(),
		"reapplying the same capability selection is idempotent and produces no duplicate component delta"
	)

	var changed_values: Array[ObjectCapabilitySelection] = []
	for selection in planned_values:
		var copied := selection.duplicate(true) as ObjectCapabilitySelection
		if copied.capability_id == "has_health":
			copied.set_component_setting("health", "max_health", 175.0)
		changed_values.append(copied)
	var settings_plan := ObjectCapabilityService.build_application_plan(planned_values, changed_values)
	var updated_components: Array = settings_plan.get("updated_components", [])
	_expect(
		bool(settings_plan.get("ok", false))
		and updated_components.size() == 1
		and str(updated_components[0].get("component_id", "")) == "health",
		"preflight detects component setting changes separately from added or removed modules"
	)


func _test_capability_library_size_and_status() -> void:
	var all_ids := ObjectCapabilityCatalog.get_capability_ids("", false)
	var simple_ids := ObjectCapabilityCatalog.get_capability_ids("", true)
	_expect(
		all_ids.size() == 200,
		"built-in mechanics library exposes exactly 200 entries"
	)
	_expect(
		simple_ids.size() == 200,
		"all 200 mechanics are searchable in the simple-mode catalogue"
	)

	var seen_ids: Dictionary = {}
	var category_counts: Dictionary = {}
	var implemented_count := 0
	var planned_count := 0
	var planned_without_runtime: bool = true

	for capability_id in all_ids:
		_expect(
			not seen_ids.has(capability_id),
			"mechanics catalogue contains unique ID: " + capability_id
		)
		seen_ids[capability_id] = true
		var definition := ObjectCapabilityCatalog.get_definition(capability_id)
		if definition == null:
			planned_without_runtime = false
			continue
		category_counts[definition.category_id] = int(category_counts.get(definition.category_id, 0)) + 1
		if definition.runtime_status == "Implemented":
			implemented_count += 1
		elif definition.runtime_status == "Planned":
			planned_count += 1
			if not definition.component_ids.is_empty():
				planned_without_runtime = false
		else:
			planned_without_runtime = false

	_expect(
		implemented_count == 4 and planned_count == 196,
		"catalogue explicitly distinguishes four runtime mechanics and 196 planned mechanics"
	)
	_expect(
		planned_without_runtime,
		"planned entries do not advertise missing runtime components"
	)
	_expect(
		category_counts.size() == 20,
		"mechanics catalogue exposes twenty distinct categories"
	)
	for category_id in category_counts:
		_expect(
			int(category_counts[category_id]) == 10,
			"category '%s' contains exactly ten mechanics" % str(category_id)
		)

	var movement_capability := ObjectCapabilityCatalog.get_definition("can_move")
	_expect(
		movement_capability != null and movement_capability.runtime_status == "Planned",
		"new movement mechanic is discoverable and visibly marked as planned"
	)
	if movement_capability != null:
		var movement_selection := ObjectCapabilityCatalog.create_selection("can_move")
		_expect(
			not ObjectCapabilityService.validate_selections([movement_selection]).is_empty(),
			"planned mechanics cannot be enabled as if their runtime behavior already existed"
		)

	var health_capability := ObjectCapabilityCatalog.get_definition("has_health")
	_expect(
		health_capability != null and health_capability.runtime_status == "Implemented",
		"existing Health mechanic remains enabled and is not downgraded"
	)


func _test_simple_capability_resolution() -> void:
	var health_selection := ObjectCapabilityCatalog.create_selection("has_health")
	var damage_selection := ObjectCapabilityCatalog.create_selection("can_receive_damage")
	var destruction_selection := ObjectCapabilityCatalog.create_selection("breaks_when_health_empty")
	_expect(
		health_selection != null and damage_selection != null and destruction_selection != null,
		"simple capability catalogue creates friendly selections"
	)
	if health_selection == null or damage_selection == null or destruction_selection == null:
		return

	health_selection.set_component_setting("health", "max_health", 35.0)
	health_selection.set_component_setting("health", "starting_health", 35.0)

	var definition := ObjectDefinition.new()
	definition.object_id = "simple_capability_smoke_test"
	definition.display_name = "Simple Capability Test"
	definition.category = "Other"
	definition.capabilities = [damage_selection, destruction_selection, health_selection]

	var validation_errors := ObjectLibraryService.validate_definition(definition)
	_expect(validation_errors.is_empty(), "valid friendly capability selections pass object validation")

	var generated_bindings := ObjectCapabilityService.build_component_bindings(definition.capabilities)
	var generated_component_ids := PackedStringArray()
	for binding in generated_bindings:
		generated_component_ids.append(binding.get_component_id())
	_expect(
		generated_component_ids.size() == 3
		and generated_component_ids.has("health")
		and generated_component_ids.has("damageable")
		and generated_component_ids.has("destructible"),
		"capability dependency resolution adds Health automatically and creates the requested mechanics"
	)

	var instance := ObjectFactory.instantiate(definition)
	_expect(instance != null, "ObjectFactory instantiates an object from simple capability selections")
	if instance == null:
		return

	var test_world := Node2D.new()
	root.add_child(test_world)
	test_world.add_child(instance)
	await process_frame

	var health := ObjectFactory.get_component(instance, "health") as HealthComponent
	var damageable := ObjectFactory.get_component(instance, "damageable") as DamageableComponent
	var destructible := ObjectFactory.get_component(instance, "destructible") as DestructibleComponent
	_expect(health != null, "friendly capability selection resolves Health at runtime")
	_expect(damageable != null, "friendly capability selection resolves Damageable at runtime")
	_expect(destructible != null, "friendly capability selection resolves Destructible at runtime")
	if health != null and damageable != null and destructible != null:
		_expect(
			is_equal_approx(health.max_health, 35.0) and is_equal_approx(health.current_health, 35.0),
			"simple capability setting is applied to the hidden Health component"
		)
		_expect(
			is_equal_approx(damageable.receive_damage(35.0), 35.0),
			"object created from simple choices can receive damage"
		)
		_expect(
			destructible.is_destroyed(),
			"object created from simple choices becomes destroyed when health reaches zero"
		)
	test_world.free()

	var disabled_selection := ObjectCapabilityCatalog.create_selection("can_attack")
	disabled_selection.enabled = false
	var disabled_definition := ObjectDefinition.new()
	disabled_definition.object_id = "disabled_capability_smoke_test"
	disabled_definition.display_name = "Disabled Capability Test"
	disabled_definition.category = "Other"
	disabled_definition.capabilities = [disabled_selection]
	var disabled_instance := ObjectFactory.instantiate(disabled_definition)
	_expect(
		disabled_instance != null and not ObjectFactory.has_component(disabled_instance, "attack"),
		"disabled capability does not create hidden runtime components"
	)
	if disabled_instance != null:
		disabled_instance.free()

	var duplicate_selection := ObjectCapabilityCatalog.create_selection("has_health")
	definition.capabilities.append(duplicate_selection)
	_expect(
		not ObjectLibraryService.validate_definition(definition).is_empty(),
		"duplicate simple capability selections are rejected"
	)
	definition.capabilities.erase(duplicate_selection)

	var unknown_selection := ObjectCapabilitySelection.new()
	unknown_selection.capability_id = "unknown_capability"
	definition.capabilities.append(unknown_selection)
	_expect(
		not ObjectLibraryService.validate_definition(definition).is_empty(),
		"unknown capability IDs are rejected"
	)
	definition.capabilities.erase(unknown_selection)

	var save_path := "user://simple_capability_serialization_test.tres"
	var save_error := ResourceSaver.save(definition, save_path)
	_expect(save_error == OK, "simple capability selections can be serialized")
	if save_error == OK:
		var restored := ResourceLoader.load(
			save_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		) as ObjectDefinition
		_expect(restored != null, "serialized simple capability object can be loaded")
		if restored != null:
			_expect(
				restored.capabilities.size() == 3,
				"all friendly selections survive ObjectDefinition serialization"
			)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


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
	var physics_node := instance.get_node("Physics") as StaticBody2D
	var hitbox_instance := instance.get_node("Physics/Hitbox") as CollisionShape2D
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
			int(physics_node.collision_layer) == 0 and int(physics_node.collision_mask) == 0,
			"nested Destructible disables collision on the owning object"
		)
		_expect(hitbox_instance.disabled, "nested Destructible disables collision shapes on the owning object")
		_expect(destructible.repair(), "nested Destructible can repair the owning object")
		_expect(
			int(physics_node.collision_layer) == 1 and int(physics_node.collision_mask) == 1,
			"repair restores collision settings on a different node"
		)
		_expect(not hitbox_instance.disabled, "repair restores the nested collision shape")
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
