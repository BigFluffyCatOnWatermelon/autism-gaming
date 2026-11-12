@tool
extends ObjectComponent
class_name HealthComponent

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float, remaining_health: float)
signal healed(amount: float, current_health: float)
signal died

@export_range(1.0, 1000000.0, 0.1, "or_greater") var max_health: float = 100.0
@export_range(0.0, 1000000.0, 0.1, "or_greater") var current_health: float = 100.0
@export var invulnerable: bool = false
@export var can_heal: bool = true

var starting_health: float = 100.0
var _death_emitted: bool = false


func _on_configured() -> void:
	max_health = maxf(1.0, _read_number("max_health", max_health))
	starting_health = clampf(_read_number("starting_health", max_health), 0.0, max_health)
	current_health = starting_health
	invulnerable = _read_bool("invulnerable", invulnerable)
	can_heal = _read_bool("can_heal", can_heal)
	_death_emitted = current_health <= 0.0


func apply_damage(amount: float) -> float:
	if invulnerable or not is_alive() or amount <= 0.0 or is_nan(amount):
		return 0.0

	var applied_damage := minf(current_health, amount)
	if applied_damage <= 0.0:
		return 0.0

	_set_current_health(current_health - applied_damage)
	damaged.emit(applied_damage, current_health)
	return applied_damage


func heal(amount: float) -> float:
	if not can_heal or not is_alive() or amount <= 0.0 or is_nan(amount):
		return 0.0

	var restored := minf(amount, max_health - current_health)
	if restored <= 0.0:
		return 0.0

	_set_current_health(current_health + restored)
	healed.emit(restored, current_health)
	return restored


func set_current_health(value: float) -> void:
	_set_current_health(value)


func set_max_health(value: float, refill: bool = false) -> void:
	var previous_max := max_health
	max_health = maxf(1.0, value)
	var next_health := max_health if refill else minf(current_health, max_health)
	_set_current_health(next_health, not is_equal_approx(previous_max, max_health))


func reset_health() -> void:
	_set_current_health(minf(starting_health, max_health), true)


func tick_regeneration(delta: float) -> float:
	if delta <= 0.0 or not is_finite(delta):
		return 0.0
	if bool(get_setting("regeneration_enabled", false)):
		var rate := maxf(0.0, float(get_setting("health_regeneration_per_second", 1.0)))
		return heal(rate * delta)
	# Preserve explicitly bound legacy regeneration components while old scenes
	# and hand-authored advanced bindings are still in use.
	var legacy_regeneration := ObjectFactory.get_component(get_object_root(), "regenerates_health")
	if legacy_regeneration != null and legacy_regeneration.has_method("regenerate_health"):
		return float(legacy_regeneration.call("regenerate_health", delta, self))
	return 0.0


func is_alive() -> bool:
	return current_health > 0.0


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


func _set_current_health(value: float, force_signal: bool = false) -> void:
	var previous_health := current_health
	current_health = clampf(value, 0.0, max_health)
	if force_signal or not is_equal_approx(previous_health, current_health):
		health_changed.emit(current_health, max_health)

	if current_health <= 0.0 and previous_health > 0.0 and not _death_emitted:
		_death_emitted = true
		died.emit()
	elif current_health > 0.0:
		_death_emitted = false


func _read_number(key: String, fallback: float) -> float:
	var value: Variant = settings.get(key, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = settings.get(key, fallback)
	if typeof(value) == TYPE_BOOL:
		return value
	return fallback
