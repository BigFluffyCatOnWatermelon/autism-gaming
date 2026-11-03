extends RefCounted

# Values saved from the in-game Debug Inspector. The button in each eligible
# property row updates this dictionary in the project source when it is writable.
const OVERRIDES: Dictionary = {
	# BEGIN GENERATED VALUES
	# END GENERATED VALUES
}


static func get_overrides() -> Dictionary:
	return OVERRIDES.duplicate(true)


static func apply(config: Dictionary) -> Dictionary:
	for key in OVERRIDES:
		_set_nested(config, str(key).split("."), OVERRIDES[key])
	return config


static func _set_nested(target: Dictionary, parts: PackedStringArray, value: Variant) -> void:
	if parts.size() < 2:
		return
	var current: Dictionary = target
	for index in range(parts.size() - 1):
		var next_value: Variant = current.get(parts[index])
		if not next_value is Dictionary:
			return
		current = next_value
	current[parts[parts.size() - 1]] = value
