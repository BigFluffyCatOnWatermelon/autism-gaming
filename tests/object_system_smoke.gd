extends SceneTree

var failures := PackedStringArray()
var health_died_signal_received := false


func _initialize() -> void:
	_test_runtime_property_values()
	_test_definition_range_validation()
	_test_object_type_default()
	_test_serialized_property_data()
	_test_component_catalog_and_health()
	_test_component_definition_validation()

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
	_expect(ObjectComponentCatalog.get_component_ids("Combat").is_empty(), "empty component categories remain available")
	_expect(ObjectComponentCatalog.has_component("HEALTH"), "catalog component IDs are case-insensitive")

	var component_definition := ObjectComponentCatalog.create_definition("health")
	_expect(component_definition != null, "catalog creates the Health component definition")
	if component_definition == null:
		return
	_expect(component_definition.component_script != null, "catalog definition supplies the Health script")
	_expect(component_definition.category == "Stats", "Health is grouped under Stats")

	component_definition.component_script = null
	component_definition.settings["max_health"] = 120.0
	component_definition.settings["starting_health"] = 90.0

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


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
