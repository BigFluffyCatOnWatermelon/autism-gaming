@tool
extends Node2D

# The grass base is created once when the scene is first opened.
# The resulting cells are editable and are stored in terrain.tscn after Ctrl+S.
@export var initialize_ground_if_empty := true
@export_range(32, 180, 1) var ground_width_cells := 114
@export_range(32, 180, 1) var ground_height_cells := 114

func _ready() -> void:
	_ensure_ground()

func _ensure_ground() -> void:
	if not initialize_ground_if_empty:
		return

	var ground := get_node_or_null("Ground") as TileMapLayer
	if ground == null or ground.tile_set == null:
		return
	if not ground.get_used_cells().is_empty():
		return

	var start_x := -int(ground_width_cells / 2)
	var start_y := -int(ground_height_cells / 2)
	for x in range(start_x, start_x + ground_width_cells):
		for y in range(start_y, start_y + ground_height_cells):
			# Deterministic variation avoids visible repeating rows and remains stable after reload.
			var variant := posmod(x * 17 + y * 31 + posmod(x * y, 7), 4)
			ground.set_cell(Vector2i(x, y), 0, Vector2i(variant, 0))
