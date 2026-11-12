@tool
extends "res://addons/web_object_builder/mechanics/object_identity/components/mechanic_component.gd"
signal value_changed(current: float, maximum: float)

func _on_configured() -> void:
    _load_options({"current_value":100.0,"maximum_value":100.0,"minimum_value":0.0})
    var low := float(get_option("minimum_value",0.0))
    var high := maxf(low,float(get_option("maximum_value",100.0)))
    set_option("maximum_value",high)
    set_option("current_value",clampf(float(get_option("current_value",high)),low,high))

func get_value() -> float:
    return float(get_option("current_value",0.0))

func get_maximum() -> float:
    return float(get_option("maximum_value",100.0))

func set_value(value: float) -> float:
    var next := clampf(value,float(get_option("minimum_value",0.0)),get_maximum())
    if set_option("current_value",next):
        value_changed.emit(next,get_maximum())
    return next

func add_value(amount: float) -> float:
    if is_nan(amount) or is_inf(amount):
        fail("Значение должно быть конечным.")
        return 0.0
    var before := get_value()
    set_value(before+amount)
    return get_value()-before

func spend_value(amount: float) -> bool:
    if amount <= 0.0 or is_nan(amount) or is_inf(amount) or amount > get_value():
        return fail("Недостаточно ресурса или указано неверное количество.")
    set_value(get_value()-amount)
    return true

func get_ratio() -> float:
    var low := float(get_option("minimum_value",0.0))
    var span := get_maximum()-low
    return 0.0 if span <= 0.0 else clampf((get_value()-low)/span,0.0,1.0)

func tick(delta: float, rate_per_second: float) -> float:
    if delta <= 0.0 or is_nan(delta) or is_inf(delta):
        return 0.0
    return add_value(rate_per_second*delta)
