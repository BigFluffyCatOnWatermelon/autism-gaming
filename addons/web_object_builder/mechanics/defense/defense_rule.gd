@tool
extends "res://addons/web_object_builder/mechanics/object_identity/components/mechanic_component.gd"

signal shield_changed(current_value: float, maximum_value: float)

var _invulnerability_left := 0.0


func _on_configured() -> void:
	_load_options({
		"armor_flat_reduction": 5.0,
		"armor_percent_reduction": 0.2,
		"damage_resistances_json": "{}",
		"immune_effects_csv": "",
		"shield_current": 50.0,
		"shield_maximum": 50.0,
		"projectile_reduction": 0.5,
		"projectile_reflection_enabled": true,
		"invulnerability_duration": 0.5,
		"weak_points_json": "{}",
		"status_resistances_json": "{}",
		"health_regeneration_per_second": 1.0
	})
	var maximum := maxf(0.0, _number("shield_maximum", 50.0))
	set_option("shield_maximum", maximum)
	set_option("shield_current", clampf(_number("shield_current", maximum), 0.0, maximum))


func calculate_armored_damage(incoming_damage: float) -> float:
	var damage := _positive(incoming_damage)
	var percent := clampf(_number("armor_percent_reduction", 0.2), 0.0, 1.0)
	var flat := maxf(0.0, _number("armor_flat_reduction", 5.0))
	return float(_emit(maxf(0.0, damage * (1.0 - percent) - flat)))


func calculate_typed_damage(damage_type: String, incoming_damage: float) -> float:
	if not _feature_enabled():
		return _positive(incoming_damage)
	var key := damage_type.strip_edges().to_lower()
	var values := _json_dictionary("damage_resistances_json")
	var resistance := _numeric(values.get(key, values.get("*", 0.0)), 0.0)
	return float(_emit(_positive(incoming_damage) * (1.0 - clampf(resistance, 0.0, 1.0))))


func is_effect_immune(effect_id: String) -> bool:
	if not _feature_enabled():
		return false
	var requested := effect_id.strip_edges().to_lower()
	if requested.is_empty():
		return false
	for entry in str(get_option("immune_effects_csv", "")).split(",", false):
		var normalized := str(entry).strip_edges().to_lower()
		if normalized == "*" or normalized == requested:
			return true
	return false


func absorb_damage_with_shield(incoming_damage: float) -> Dictionary:
	var incoming := _positive(incoming_damage)
	var shield := maxf(0.0, _number("shield_current", 0.0))
	var absorbed := minf(shield, incoming)
	var remaining := maxf(0.0, incoming - absorbed)
	var next_shield := shield - absorbed
	set_option("shield_current", next_shield)
	shield_changed.emit(next_shield, maxf(0.0, _number("shield_maximum", 0.0)))
	return _emit({
		"absorbed": absorbed,
		"remaining_damage": remaining,
		"shield_current": next_shield
	})


func calculate_projectile_damage(incoming_damage: float) -> float:
	if not _feature_enabled():
		return _positive(incoming_damage)
	var reduction := clampf(_number("projectile_reduction", 0.5), 0.0, 1.0)
	return float(_emit(_positive(incoming_damage) * (1.0 - reduction)))


func reflect_projectile(incoming_direction: Vector2, surface_normal: Vector2) -> Dictionary:
	if not bool(get_option("projectile_reflection_enabled", true)):
		return {"reflected": false, "direction": incoming_direction}
	if incoming_direction.is_zero_approx() or surface_normal.is_zero_approx():
		return {"reflected": false, "direction": incoming_direction}
	var reflected := incoming_direction.normalized().bounce(surface_normal.normalized()).normalized()
	return _emit({"reflected": true, "direction": reflected})


func begin_invulnerability_window(duration: float = -1.0) -> float:
	var requested := _number("invulnerability_duration", 0.5) if duration < 0.0 else duration
	_invulnerability_left = maxf(0.0, requested)
	_emit(_invulnerability_left)
	return _invulnerability_left


func tick_invulnerability_window(delta: float) -> bool:
	if delta > 0.0 and not is_nan(delta) and not is_inf(delta):
		_invulnerability_left = maxf(0.0, _invulnerability_left - delta)
	return _invulnerability_left > 0.0


func is_invulnerable() -> bool:
	return _invulnerability_left > 0.0


func get_weak_point_multiplier(point_id: String) -> float:
	var values := _json_dictionary("weak_points_json")
	var value := _numeric(values.get(point_id.strip_edges().to_lower(), 1.0), 1.0)
	return maxf(0.0, value)


func get_status_effect_multiplier(effect_id: String) -> float:
	var values := _json_dictionary("status_resistances_json")
	var resistance := _numeric(values.get(effect_id.strip_edges().to_lower(), values.get("*", 0.0)), 0.0)
	return 1.0 - clampf(resistance, 0.0, 1.0)


func regenerate_health(delta: float, health_component: Node = null) -> float:
	if delta <= 0.0 or is_nan(delta) or is_inf(delta):
		return 0.0
	var target := health_component
	if target == null:
		target = ObjectFactory.get_component(get_object_root(), "health")
	if not is_instance_valid(target) or not target.has_method("heal"):
		return 0.0
	var amount := maxf(0.0, _number("health_regeneration_per_second", 1.0)) * delta
	return float(target.call("heal", amount))


func get_shield_ratio() -> float:
	var maximum := maxf(0.0, _number("shield_maximum", 0.0))
	return 0.0 if maximum <= 0.0 else clampf(_number("shield_current", 0.0) / maximum, 0.0, 1.0)


func restore_shield(amount: float) -> float:
	if amount <= 0.0 or is_nan(amount) or is_inf(amount):
		return 0.0
	var before := _number("shield_current", 0.0)
	var maximum := maxf(0.0, _number("shield_maximum", 0.0))
	var next_value := minf(maximum, before + amount)
	set_option("shield_current", next_value)
	shield_changed.emit(next_value, maximum)
	return next_value - before


func _feature_enabled() -> bool:
	return bool(get_option("enabled", true))


func _json_dictionary(key: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(str(get_option(key, "{}")))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _numeric(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var result := float(value)
		if not is_nan(result) and not is_inf(result):
			return result
	elif typeof(value) == TYPE_STRING and str(value).is_valid_float():
		return str(value).to_float()
	return fallback


func _number(key: String, fallback: float) -> float:
	return _numeric(get_option(key, fallback), fallback)


func _positive(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(0.0, value)


func _emit(value: Variant) -> Variant:
	action_completed.emit(value)
	return value
