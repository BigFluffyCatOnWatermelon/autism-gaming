extends RefCounted
class_name GameConfig

const ItemCatalogServiceScript = preload("res://scripts/item_catalog_service.gd")

# Centralized gameplay balance. WorldController keeps an editable runtime copy.
static func make_default() -> Dictionary:
	var config: Dictionary = {
		"world": {
			"width": 3600,
			"height": 3600,
			"grass_tile_size": 32,
			"seed": 20261102,
			"start_day": 1,
			"start_hour": 8.0,
			"game_minutes_per_real_second": 1.0,
			"days_per_season": 30,
			"default_weather": "clear",
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
			"stamina_sprint_resume": 30.0,
			"roll_invulnerability_ms": 220.0,
			"strength": 10.0,
			"agility": 10.0,
			"defense": 0.0,
			"magnet": 1.0,
			"pickup_base_radius": 34.0,
			"pickup_magnet_per_level": 14.0,
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
		"weapons": {},
		"resources": {
			"tree_health": 90.0,
			"rock_health": 110.0,
			"tree_wood_drop": 5,
			"rock_stone_drop": 4,
			"tree_hit_radius": 29.0,
			"rock_hit_radius": 23.0,
			"swing_strength": 1.0,
			"destruction_duration": 0.48,
			"fall_angle_degrees": 78.0,
			"resistance_cutting": 1.0,
			"resistance_piercing": 1.0,
			"resistance_crushing": 1.0,
		},
		"drops": {
			"scatter_speed_min": 100.0,
			"scatter_speed_max": 230.0,
			"horizontal_friction": 380.0,
			"gravity": 520.0,
			"bounce_factor": 0.36,
			"magnet_speed": 570.0,
			"pickup_distance": 22.0,
		},
		"inventory": {
			"hotbar_slots": 9,
			"base_backpack_slots": 12,
			"max_backpack_slots": 27,
			"expansion_step": 3,
			"max_stack": 99,
			"starting_arrows": 30,
		},
		"items": {},
		"settings": {
			"screen_shake": true,
			"show_fps": false,
		},
	}
	var catalog_data: Dictionary = ItemCatalogServiceScript.load_all()
	config["items"] = catalog_data.get("items", config["items"])
	config["weapons"] = catalog_data.get("weapons", config["weapons"])
	config["item_definitions"] = catalog_data.get("definitions", {})
	config["item_categories"] = catalog_data.get("categories", {})
	config["item_catalog_by_id"] = catalog_data.get("catalog_by_id", {})
	config["item_catalogs"] = catalog_data.get("catalogs", {})
	return config
