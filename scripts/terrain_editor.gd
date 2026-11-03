@tool
extends Node2D

const SEASON_TILESETS := [
	"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_ground_spring.tres",
	"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_ground_summer.tres",
	"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_ground_autumn.tres",
	"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_ground_winter.tres",
]

@export_enum("Весна", "Лето", "Осень", "Зима") var season: int = 0:
	set(value):
		season = clampi(value, 0, SEASON_TILESETS.size() - 1)
		if is_inside_tree():
			_apply_season()

@export var initialize_ground_if_empty := true
@export_range(32, 180, 1) var ground_width_cells := 114
@export_range(32, 180, 1) var ground_height_cells := 114

func _ready() -> void:
	_apply_season()
	_ensure_ground()

func _apply_season() -> void:
	var ground := get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		return
	var selected := load(SEASON_TILESETS[season]) as TileSet
	if selected == null:
		push_warning("Не удалось загрузить TileSet для выбранного сезона.")
		return
	ground.tile_set = selected

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
			var variant := posmod(x * 17 + y * 31 + posmod(x * y, 7), 4)
			ground.set_cell(Vector2i(x, y), variant, Vector2i.ZERO)
