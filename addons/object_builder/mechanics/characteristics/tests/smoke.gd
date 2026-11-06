extends SceneTree
const STAT=preload("res://addons/object_builder/mechanics/characteristics/components/resource_stat.gd")
func _initialize() -> void:
 var errors: Array[String]=[]
 var stat=STAT.new()
 stat.configure({"current_value":50.0,"maximum_value":100.0,"minimum_value":0.0})
 if not is_equal_approx(stat.get_ratio(),0.5): errors.append("Ratio should reflect current/max.")
 if not is_equal_approx(stat.add_value(25.0),25.0): errors.append("Positive adjustment failed.")
 if not is_equal_approx(stat.add_value(-100.0),-75.0) or stat.get_value()!=0.0: errors.append("Lower bound clamp failed.")
 if stat.spend_value(1.0): errors.append("Spending below zero should fail.")
 if not stat.spend_value(0.0)==false: errors.append("Zero spend should fail.")
 var state: Dictionary=stat.export_runtime_state()
 var restored=STAT.new()
 restored.configure(state)
 if restored.get_value()!=stat.get_value(): errors.append("Runtime state restore failed.")
 if errors.is_empty(): print("Characteristics smoke: PASS")
 else:
  for error in errors: push_error(error)
  quit(1)
