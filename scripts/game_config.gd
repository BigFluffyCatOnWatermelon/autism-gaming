extends RefCounted
class_name GameConfig

# The only place for frequently tuned gameplay and balance values.
# WorldController makes a deep copy so the F3 inspector can change them live.
static func make_default() -> Dictionary:
	return {
		"world": {
			"width": 3600,
			"height": 3600,
			"grass_tile_size": 32,
			"tree_count": 100,
			"rock_count": 75,
			"keep_spawn_clear_radius": 230.0,
			"seed": 20261102,
		},
		"player": {
			"max_health": 100.0,
			"max_stamina": 100.0,
			"walk_speed": 155.0,
			"run_multiplier": 1.65,
			"crouch_multiplier": 0.52,
			"roll_speed_multiplier": 3.3,
			"roll_duration_ms": 260.0,
			"roll_cooldown_ms": 680.0,
			"roll_stamina_cost": 22.0,
			"stamina_run_drain": 19.0,
			"stamina_regen": 16.0,
			"roll_invulnerability_ms": 220.0,
			"strength": 10.0,
			"agility": 10.0,
			"defense": 0.0,
			"sprite_scale": 1.25,
			"collision_radius": 8.0,
		},
		"camera": {
			"base_zoom": 1.85,
			"run_zoom": 1.58,
			"crouch_zoom": 2.15,
			"follow_speed": 8.0,
			"zoom_lerp_speed": 5.0,
			"shake_duration_ms": 125.0,
			"shake_strength": 4.0,
		},
		"combat": {
			"damage_attribute_scale": 0.025,
			"slash_radius": 76.0,
			"slash_arc_degrees": 118.0,
			"effect_reach_scale": 0.72,
			"effect_width_skill_scale": 0.035,
			"arc_skill_bonus": 0.8,
			"thrust_range": 116.0,
			"thrust_width": 24.0,
			"arrow_speed": 620.0,
			"arrow_range": 620.0,
			"attack_stamina_cost": 7.0,
		},
		"weapons": {
			"sword": {
				"damage": 24.0,
				"damage_type": "cutting",
				"cooldown": 0.42,
				"slash": {"damage": 26.0, "damage_type": "cutting", "cooldown": 0.52, "stamina_cost": 9.0, "reach": 76.0, "arc_degrees": 118.0, "effect_width": 13.0},
				"thrust": {"damage": 19.0, "damage_type": "piercing", "cooldown": 0.31, "stamina_cost": 6.0, "reach": 116.0, "width": 24.0, "effect_width": 10.0},
			},
			"pickaxe": {
				"damage": 20.0, "damage_type": "piercing", "cooldown": 0.61, "reach": 66.0,
				"stone_multiplier": 2.4, "wood_multiplier": 0.0, "width": 18.0, "effect_width": 18.0,
			},
			"axe": {
				"damage": 25.0, "damage_type": "cutting", "cooldown": 0.56, "reach": 72.0,
				"wood_multiplier": 2.5, "nature_multiplier": 1.7, "stone_multiplier": 0.0,
				"arc_degrees": 148.0, "width": 36.0, "effect_width": 36.0,
			},
			"bow": {
				"damage": 18.0, "damage_type": "piercing", "cooldown": 0.52,
				"projectile_speed": 620.0, "projectile_range": 620.0, "stamina_cost": 3.0,
			},
		},
		"inventory": {
			"hotbar_slots": 9,
			"base_backpack_slots": 12,
			"max_backpack_slots": 24,
			"expansion_step": 3,
			"starting_arrows": 30,
		},
		"settings": {
			"screen_shake": true,
			"show_fps": false,
		},
	}
