@tool
extends "res://addons/object_builder/mechanics/object_identity/components/mechanic_component.gd"
signal rule_triggered(result: Variant)
var _combo_step := 0
var _combo_time_left := 0.0
var _target: WeakRef

func _on_configured() -> void:
    _load_options({"rule_type":"block","enabled":true,"damage_reduction":0.75,"parry_window":0.25,"counter_multiplier":1.5,"dodge_duration":0.35,"invulnerability":true,"aim_cone_degrees":8.0,"charge_time":1.0,"maximum_multiplier":2.5,"critical_chance":0.1,"critical_multiplier":2.0,"combo_window":0.8,"combo_multipliers":[1.0,1.15,1.4],"maximum_distance":600.0})

func _number(key: String, fallback: float) -> float:
    return float(get_option(key,fallback))
func _enabled() -> bool:
    return bool(get_option("enabled",true))
func _emit(value: Variant) -> Variant:
    action_completed.emit(value)
    rule_triggered.emit(value)
    return value

func block_damage(incoming_damage: float) -> float:
    if not _enabled(): return maxf(0.0,incoming_damage)
    return float(_emit(maxf(0.0,incoming_damage*(1.0-clampf(_number("damage_reduction",0.75),0.0,1.0))))

func resolve_parry(elapsed_since_input: float, incoming_damage: float) -> Dictionary:
    var success := _enabled() and elapsed_since_input >= 0.0 and elapsed_since_input <= _number("parry_window",0.25)
    var result: Dictionary = _emit({"success":success,"incoming_damage":0.0 if success else maxf(0.0,incoming_damage),"counter_multiplier":_number("counter_multiplier",1.5) if success else 1.0})
    return result

func begin_dodge() -> Dictionary:
    var result: Dictionary = _emit({"duration":maxf(0.0,_number("dodge_duration",0.35)),"invulnerable":bool(get_option("invulnerability",true))})
    return result

func set_aim_direction(direction: Vector2) -> Vector2:
    if not _enabled() or direction.is_zero_approx(): return Vector2.ZERO
    var result: Vector2 = _emit(direction.normalized())
    return result

func get_charge_multiplier(held_seconds: float) -> float:
    if not _enabled(): return 1.0
    var duration := maxf(0.01,_number("charge_time",1.0))
    return float(_emit(lerpf(1.0,maxf(1.0,_number("maximum_multiplier",2.5)),clampf(held_seconds/duration,0.0,1.0))))

func roll_critical_hit(rng: RandomNumberGenerator = null) -> float:
    if not _enabled(): return 1.0
    var roll := randf() if rng == null else rng.randf()
    return float(_emit(maxf(1.0,_number("critical_multiplier",2.0)) if roll < clampf(_number("critical_chance",0.1),0.0,1.0) else 1.0))

func advance_combo(delta: float) -> int:
    _combo_time_left=maxf(0.0,_combo_time_left-maxf(0.0,delta))
    if _combo_time_left<=0.0: _combo_step=0
    return _combo_step

func register_combo_hit() -> Dictionary:
    var values: Array=get_option("combo_multipliers",[1.0,1.15,1.4])
    if values.is_empty(): values=[1.0]
    _combo_step=mini(_combo_step+1,values.size())
    _combo_time_left=maxf(0.0,_number("combo_window",0.8))
    var result: Dictionary = _emit({"step":_combo_step,"multiplier":maxf(1.0,float(values[_combo_step-1]))})
    return result

func set_target(target: Node, origin: Node2D = null) -> bool:
    if not _enabled() or not is_instance_valid(target): return fail("Цель недействительна или выбор цели отключён.")
    if origin != null and target is Node2D and origin.global_position.distance_to((target as Node2D).global_position)>_number("maximum_distance",600.0):
        return fail("Цель находится слишком далеко.")
    _target=weakref(target)
    _emit(target)
    return true

func get_target() -> Node:
    if _target==null: return null
    var value: Variant=_target.get_ref()
    return value if is_instance_valid(value) else null

func clear_target() -> void:
    _target=null
    _emit(null)
