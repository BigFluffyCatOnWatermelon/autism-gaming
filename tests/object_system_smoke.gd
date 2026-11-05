extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	_test_runtime_property_values()
	_test_definition_range_validation()

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
	_expect(
		ObjectFactory.get_custom_property_definition(instance, "health") == health,
		"property definition metadata is attached to instance"
	)

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


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
