extends Resource
class_name WeaponDefinition

@export var display_name := "Unnamed Weapon"
@export var base_light_damage := 25.0
@export var base_heavy_damage := 48.0
@export var strength_light_scaling := 1.8
@export var dexterity_light_scaling := 0.8
@export var strength_heavy_scaling := 3.0
@export var dexterity_heavy_scaling := 0.0
@export var light_stamina_cost := 19.0
@export var heavy_stamina_cost := 36.0
@export var light_windup := 0.24
@export var heavy_windup := 0.46
@export var light_active := 0.19
@export var heavy_active := 0.25
@export var light_recovery := 0.42
@export var heavy_recovery := 0.58
@export var light_range_scale := 1.0
@export var heavy_range_scale := 1.35
@export var light_poise_damage := 26.0
@export var heavy_poise_damage := 50.0
@export var critical_multiplier := 2.6
@export var damage_type: StringName = &"physical"
