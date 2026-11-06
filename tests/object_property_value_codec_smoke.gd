extends SceneTree

const Codec = preload("res://scripts/object_system/object_property_value_codec.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(Codec.make_property_id(" Oak Tree-1 ") == "oak_tree_1", "property IDs are normalized consistently")
	_expect(Codec.format_default_value("hello", "String") == "hello", "string defaults are formatted as text")
	_expect(Codec.format_default_value(Vector2(2.5, -4.0), "Vector2") == "2.5, -4.0", "Vector2 defaults are formatted as comma-separated coordinates")

	var integer_value: Variant = Codec.parse_default_value("42", "Integer")
	_expect(typeof(integer_value) == TYPE_INT and integer_value == 42, "integer text is parsed as an integer")
	var float_value: Variant = Codec.parse_default_value("1.25", "Float")
	_expect(typeof(float_value) == TYPE_FLOAT and is_equal_approx(float_value, 1.25), "float text is parsed as a float")
	_expect(bool(Codec.parse_default_value("ДА", "Boolean")), "localized affirmative boolean values are supported")
	_expect(not bool(Codec.parse_default_value("false", "Boolean")), "false boolean text stays false")
	_expect(Codec.parse_default_value("8, -3.25", "Vector2") == Vector2(8.0, -3.25), "Vector2 coordinates are parsed")
	_expect(Codec.parse_default_value("invalid", "Vector2") == Vector2.ZERO, "invalid Vector2 text keeps the previous zero fallback")
	_expect(Codec.parse_default_value("hello", "String") == "hello", "string text is preserved")

	if failures.is_empty():
		print("Object Property Value Codec smoke tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
