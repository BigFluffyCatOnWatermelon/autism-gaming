@tool
extends Node2D
## Pixel grid drawn behind the editable scene.

const GRID_STEP := 32.0
var grid_enabled := true


func _draw() -> void:
	if not grid_enabled:
		return
	var extent := 4096.0
	var line_color := Color(0.28, 0.31, 0.35, 0.55)
	var axis_color := Color(0.42, 0.47, 0.53, 0.8)
	for coordinate in range(-128, 129):
		var offset := float(coordinate) * GRID_STEP
		var color := axis_color if coordinate == 0 else line_color
		var thickness := 1.5 if coordinate == 0 else 1.0
		draw_line(Vector2(offset, -extent), Vector2(offset, extent), color, thickness)
		draw_line(Vector2(-extent, offset), Vector2(extent, offset), color, thickness)
