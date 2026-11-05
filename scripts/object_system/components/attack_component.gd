@tool
extends ObjectComponent
class_name AttackComponent

signal attack_performed(target: Node, applied_damage: float)
signal attack_failed(target: Node, reason: String)

@export var can_attack: bool = true
@export_range(0.0, 1000000.0, 0.1, "or_greater") var attack_damage: float = 12.0
@export_range(0.0, 100000.0, 0.1, "or_greater") var attack_range: float = 220.0
@export_range(0.0, 60.0, 0.01, "or_greater") var cooldown: float = 0.4
@export var require_range: bool = true

var _cooldown_remaining := 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)


func _on_configured() -> void:
	can_attack = _read_bool("can_attack", can_attack)
	attack_damage = maxf(0.0, _read_number("attack_damage", attack_damage))
	attack_range = maxf(0.0, _read_number("attack_range", attack_range))
	cooldown = maxf(0.0, _read_number("cooldown", cooldown))
	require_range = _read_bool("require_range", require_range)


func perform_attack(target: Node, source: Node = null) -> float:
	if target == null:
		return _fail(target, "target_missing")
	if not can_attack:
		return _fail(target, "attack_disabled")
	if _cooldown_remaining > 0.0:
		return _fail(target, "cooldown")

	var attacker := get_parent()
	if attacker == null:
		return _fail(target, "attacker_missing")
	if require_range and not _is_target_in_range(attacker, target):
		return _fail(target, "out_of_range")

	var damageable := ObjectFactory.get_component(target, "damageable") as DamageableComponent
	if damageable == null:
		return _fail(target, "target_not_damageable")

	var damage_source := source if source != null else attacker
	var applied_damage := damageable.receive_damage(attack_damage, damage_source)
	_cooldown_remaining = cooldown
	if applied_damage <= 0.0:
		return _fail(target, "damage_blocked")

	attack_performed.emit(target, applied_damage)
	return applied_damage


func set_attack_enabled(enabled: bool) -> void:
	can_attack = enabled


func reset_cooldown() -> void:
	_cooldown_remaining = 0.0


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func _is_target_in_range(attacker: Node, target: Node) -> bool:
	if not attacker is Node2D or not target is Node2D:
		return false
	var attacker_2d := attacker as Node2D
	var target_2d := target as Node2D
	return attacker_2d.global_position.distance_to(target_2d.global_position) <= attack_range


func _fail(target: Node, reason: String) -> float:
	attack_failed.emit(target, reason)
	return 0.0


func _read_number(key: String, fallback: float) -> float:
	var value: Variant = settings.get(key, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if not is_nan(number) and not is_inf(number):
			return number
	return fallback


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = settings.get(key, fallback)
	if typeof(value) == TYPE_BOOL:
		return value
	return fallback
