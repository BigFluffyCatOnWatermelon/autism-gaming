extends RefCounted
class_name DamageInfo

var amount: float
var damage_type: StringName
var poise_damage: float
var source: Node3D

func _init(p_amount: float, p_type: StringName = &"physical", p_poise: float = 10.0, p_source: Node3D = null) -> void:
	amount = p_amount
	damage_type = p_type
	poise_damage = p_poise
	source = p_source
