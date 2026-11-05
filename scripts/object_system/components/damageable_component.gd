@tool
extends ObjectComponent
class_name DamageableComponent

signal damage_received(applied_damage: float, remaining_health: float, source: Node)
signal damage_blocked(incoming_damage: float, source: Node)

@export var can_receive_damage: bool = true
@export_range(0.0, 10.0, 0.01, "or_greater") var damage_multiplier: float = 1.0
@export_range(0.0, 1000000.0, 0.1, "or_greater") var flat_reduction: float = 0.0


func _on_configured() -> void:
	can_receive_damage = _read_bool("can_receive_damage", can_receive_damage)
	damage_multiplier = maxf(0.0, _read_number("damage_multiplier", damage_multiplier))
	flat_reduction = maxf(0.0, _read_number("flat_reduction", flat_reduction))


func receive_damage(incoming_damage: float, source: Node = null) -> float:
	if is_nan(incoming_damage) or is_inf(incoming_damage) or incoming_damage <= 0.0:
		return 0.0
	if not can_receive_damage:
		damage_blocked.emit(incoming_damage, source)
		return 0.0

	var adjusted_damage := maxf(0.0, incoming_damage * damage_multiplier - flat_reduction)
	if adjusted_damage <= 0.0:
		damage_blocked.emit(incoming_damage, source)
		return 0.0

	var health := _find_health_component()
	if health == null:
		damage_blocked.emit(incoming_damage, source)
		return 0.0

	var applied_damage := health.apply_damage(adjusted_damage)
	if applied_damage <= 0.0:
		damage_blocked.emit(incoming_damage, source)
		return 0.0

	damage_received.emit(applied_damage, health.current_health, source)
	return applied_damage


func set_damage_enabled(value: bool) -> void:
	can_receive_damage = value


func _find_health_component() -> HealthComponent:
	var parent_node := get_parent()
	if parent_node == null:
		return null
	for child in parent_node.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null


func _read_number(key: String, fallback: float) -> float:
	var value: Variant = settings.get(key, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var numeric_value := float(value)
		if not is_nan(numeric_value) and not is_inf(numeric_value):
			return numeric_value
	return fallback


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = settings.get(key, fallback)
	if typeof(value) == TYPE_BOOL:
		return value
	return fallback
