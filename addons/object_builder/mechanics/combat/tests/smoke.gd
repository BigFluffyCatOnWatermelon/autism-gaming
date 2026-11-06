extends SceneTree
const RULE=preload("res://addons/object_builder/mechanics/combat/components/combat_rule.gd")
func _initialize() -> void:
 var errors: Array[String]=[]
 var rule=RULE.new()
 rule.configure({"rule_type":"block","enabled":true,"damage_reduction":0.5})
 if not is_equal_approx(rule.block_damage(20.0),10.0): errors.append("Block reduction failed.")
 rule.configure({"rule_type":"parry","enabled":true,"parry_window":0.2,"counter_multiplier":2.0})
 var parry: Dictionary=rule.resolve_parry(0.1,15.0)
 if not parry.success or parry.incoming_damage!=0.0: errors.append("Parry window failed.")
 if rule.resolve_parry(0.5,15.0).success: errors.append("Parry accepted an out-of-window input.")
 rule.configure({"rule_type":"critical","enabled":true,"critical_chance":1.0,"critical_multiplier":3.0})
 if not is_equal_approx(rule.roll_critical_hit(),3.0): errors.append("Critical multiplier failed.")
 rule.configure({"rule_type":"combo","enabled":true,"combo_window":1.0,"combo_multipliers":[1.0,1.5]})
 if rule.register_combo_hit().step!=1 or not is_equal_approx(rule.register_combo_hit().multiplier,1.5): errors.append("Combo progression failed.")
 if errors.is_empty(): print("Combat smoke: PASS")
 else:
  for error in errors: push_error(error)
  quit(1)
