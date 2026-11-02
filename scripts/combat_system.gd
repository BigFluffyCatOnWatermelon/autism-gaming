extends RefCounted
class_name CombatSystem

const MATERIAL_MATCHUPS := {
	"wood": {"cutting": 1.15, "piercing": 0.65, "crushing": 0.9},
	"stone": {"cutting": 0.3, "piercing": 0.8, "crushing": 1.2},
	"flesh": {"cutting": 1.0, "piercing": 1.0, "crushing": 1.0},
	"nature": {"cutting": 1.35, "piercing": 0.75, "crushing": 0.9},
}

static func can_damage_resource(weapon_id: String, material: String) -> bool:
	match weapon_id:
		"sword":
			return false
		"pickaxe":
			return material == "stone"
		"axe":
			return material == "wood"
		_:
			return true

static func calculate_damage(attack: Dictionary, material: String, strength: float, config: Dictionary) -> float:
	var weapon_id := str(attack.get("weapon_id", ""))
	if weapon_id != "" and not can_damage_resource(weapon_id, material):
		return 0.0
	var damage_type: String = str(attack.get("damage_type", "crushing"))
	var material_data: Dictionary = MATERIAL_MATCHUPS.get(material, MATERIAL_MATCHUPS["flesh"])
	var material_multiplier: float = float(material_data.get(damage_type, 1.0))
	var strength_scale: float = float(config.combat.damage_attribute_scale)
	var attribute_multiplier: float = maxf(0.25, 1.0 + ((strength - 10.0) * strength_scale))
	# Configured melee damage is the per-hit value; compatibility handles resource efficiency.
	if weapon_id == "sword" or weapon_id == "pickaxe" or weapon_id == "axe":
		return maxf(0.0, roundf(float(attack.get("damage", 0.0)) * attribute_multiplier))
	var tool_multiplier := 1.0
	match material:
		"wood":
			tool_multiplier = float(attack.get("wood_multiplier", 1.0))
		"stone":
			tool_multiplier = float(attack.get("stone_multiplier", 1.0))
		"nature":
			tool_multiplier = float(attack.get("nature_multiplier", 1.0))
	var raw_damage: float = float(attack.get("damage", 0.0))
	return maxf(0.0, roundf(raw_damage * material_multiplier * tool_multiplier * attribute_multiplier))

static func angle_difference(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)

static func point_in_arc(origin: Vector2, target: Vector2, direction: float, radius: float, arc_degrees: float) -> bool:
	var offset := target - origin
	if offset.length() > radius or offset.length_squared() < 0.001:
		return false
	return absf(angle_difference(offset.angle(), direction)) <= deg_to_rad(arc_degrees * 0.5)

static func distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var line := finish - start
	var length_squared := line.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(line) / length_squared, 0.0, 1.0)
	return point.distance_to(start + line * t)
