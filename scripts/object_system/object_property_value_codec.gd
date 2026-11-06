@tool
extends RefCounted
## Converts custom-property values between their stored Variant and editor text forms.
## Kept outside the UI plugin so forms and tests can reuse the same rules.


static func make_property_id(value: String) -> String:
	var result := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	result = result.validate_filename()
	if result.is_empty():
		result = "property"
	return result


static func format_default_value(value: Variant, type_name: String) -> String:
	if type_name == "Vector2" and value is Vector2:
		var vector_value: Vector2 = value
		return "%s, %s" % [str(vector_value.x), str(vector_value.y)]
	return str(value)


static func parse_default_value(value: String, type_name: String) -> Variant:
	match type_name:
		"Integer":
			return value.to_int()
		"Float":
			return value.to_float()
		"Boolean":
			return value.strip_edges().to_lower() in ["true", "1", "yes", "да"]
		"Vector2":
			var parts := value.split(",")
			if parts.size() == 2:
				return Vector2(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float())
			return Vector2.ZERO
		_:
			return value
