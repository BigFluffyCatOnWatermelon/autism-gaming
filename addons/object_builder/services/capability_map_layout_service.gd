extends RefCounted
class_name CapabilityMapLayoutService

static func domain_position(index: int) -> Vector2:
	const COLUMNS := 3
	const COLUMN_SPACING := 440.0
	const ROW_SPACING := 285.0
	return Vector2(float(index % COLUMNS) * COLUMN_SPACING, float(int(index / COLUMNS)) * ROW_SPACING)

static func mechanic_position(index: int, group_index: int) -> Vector2:
	const GROUP_SPACING := 560.0
	const NODE_SPACING := 168.0
	const COLUMNS := 3
	return Vector2(
		float(group_index) * GROUP_SPACING + float(index % COLUMNS) * 205.0,
		float(int(index / COLUMNS)) * NODE_SPACING
	)

static func local_position(index: int, count: int) -> Vector2:
	if index == 0:
		return Vector2(360, 250)
	var angle := TAU * float(index - 1) / float(maxi(1, count - 1)) - PI * 0.5
	var radius := 310.0 if count <= 8 else 390.0
	return Vector2(360, 250) + Vector2(cos(angle), sin(angle)) * radius