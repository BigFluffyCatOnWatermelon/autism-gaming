@tool
extends EditorPlugin

const MENU_ITEM := "Cozy Village & Farm: обновить каталоги и сцены"
const PLACEABLE_SCRIPT: Script = preload("res://scripts/placeable_art.gd")

const TILESET_CATALOGS := [
	{"name":"World Assets","path":"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_world_assets_library.tres","roots":["res://Assets/CozyVillageFarm/02_Nature","res://Assets/CozyVillageFarm/03_Buildings","res://Assets/CozyVillageFarm/04_Props","res://Assets/CozyVillageFarm/05_Interiors"],"kind":"world"},
	{"name":"Creatures","path":"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_creatures_library.tres","roots":["res://Assets/CozyVillageFarm/07_Animals","res://Assets/CozyVillageFarm/08_Characters"],"kind":"creatures"},
	{"name":"Farming and Items","path":"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_farming_items_library.tres","roots":["res://Assets/CozyVillageFarm/06_Farming","res://Assets/CozyVillageFarm/10_Items"],"kind":"items"},
	{"name":"Beach and Fishing","path":"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_beach_library.tres","roots":["res://Assets/CozyVillageFarm/09_Beach_Fishing"],"kind":"beach"},
	{"name":"UI","path":"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_ui_library.tres","roots":["res://Assets/CozyVillageFarm/11_UI"],"kind":"ui"},
	{"name":"Effects","path":"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_effects_library.tres","roots":["res://Assets/CozyVillageFarm/12_Effects"],"kind":"effects"},
	{"name":"Terrain Extras","path":"res://Assets/CozyVillageFarm/Godot/TileSets/cozy_terrain_extras_library.tres","roots":["res://Assets/CozyVillageFarm/01_Terrain/Cliffs","res://Assets/CozyVillageFarm/01_Terrain/Bridges"],"kind":"terrain"}
]

const PLACEABLE_ROOTS := [
	{"source":"res://Assets/CozyVillageFarm/02_Nature","destination":"res://scenes/environment_assets/Nature"},
	{"source":"res://Assets/CozyVillageFarm/03_Buildings","destination":"res://scenes/environment_assets/Buildings"},
	{"source":"res://Assets/CozyVillageFarm/04_Props","destination":"res://scenes/environment_assets/Props"},
	{"source":"res://Assets/CozyVillageFarm/05_Interiors/Furniture","destination":"res://scenes/environment_assets/Interiors/Furniture"},
	{"source":"res://Assets/CozyVillageFarm/07_Animals","destination":"res://scenes/environment_assets/Animals"},
	{"source":"res://Assets/CozyVillageFarm/08_Characters","destination":"res://scenes/environment_assets/Characters"},
	{"source":"res://Assets/CozyVillageFarm/09_Beach_Fishing","destination":"res://scenes/environment_assets/Beach_Fishing"},
	{"source":"res://Assets/CozyVillageFarm/12_Effects","destination":"res://scenes/environment_assets/Effects"}
]

var _generation_done := false
var _generated_scenes := 0
var _generated_tiles := 0
var _force_refresh := false

func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, _refresh_assets)
	var filesystem := EditorInterface.get_resource_filesystem()
	if not filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		filesystem.filesystem_changed.connect(_on_filesystem_changed)
	call_deferred("_generate_all")

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		filesystem.filesystem_changed.disconnect(_on_filesystem_changed)

func _on_filesystem_changed() -> void:
	if not _generation_done:
		call_deferred("_generate_all")

func _refresh_assets() -> void:
	_force_refresh = true
	_generation_done = false
	_generate_all()

func _generate_all() -> void:
	if _generation_done:
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning():
		return

	_generation_done = true
	_generated_scenes = 0
	_generated_tiles = 0
	for catalog in TILESET_CATALOGS:
		_generate_catalog(catalog)
	for mapping in PLACEABLE_ROOTS:
		_scan_placeables(str(mapping.source), str(mapping.destination))
	_configure_ground_collision()
	print("Cozy Village & Farm: создано атласов TileSet: ", _generated_tiles, "; сцен объектов: ", _generated_scenes)
	_force_refresh = false
	if _generated_scenes > 0 or _generated_tiles > 0:
		filesystem.scan()

func _generate_catalog(catalog: Dictionary) -> void:
	var output_path := str(catalog.path)
	var tile_set := ResourceLoader.load(output_path) as TileSet
	if tile_set != null and tile_set.get_source_count() > 0 and not _force_refresh:
		return
	if tile_set == null:
		tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_set.resource_name = str(catalog.name)
	for source_id in tile_set.get_source_ids():
		tile_set.remove_source(source_id)
	while tile_set.get_physics_layers_count() > 0:
		tile_set.remove_physics_layer(tile_set.get_physics_layers_count() - 1)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 2)
	tile_set.set_physics_layer_collision_mask(0, 1)
	for root_path in catalog.roots:
		_add_directory_to_catalog(tile_set, str(root_path), str(catalog.kind))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var error := ResourceSaver.save(tile_set, output_path)
	if error != OK:
		push_warning("Не удалось сохранить каталог TileSet: " + output_path)

func _add_directory_to_catalog(tile_set: TileSet, directory_path: String, kind: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_add_directory_to_catalog(tile_set, path, kind)
		elif entry.get_extension().to_lower() == "png" and _is_catalog_texture(path):
			_add_texture_to_catalog(tile_set, path, kind)
	directory.list_dir_end()

func _is_catalog_texture(path: String) -> bool:
	var lower := path.to_lower()
	var file := lower.get_file()
	if file.begins_with("_") or "guide" in file or "preview" in lower:
		return false
	if "autotile" in file or "_anim_" in file or file.ends_with("_2f.png"):
		return false
	if "_sheet" in file or "_stages_" in file or "_all_" in file:
		return false
	if lower.contains("/example_scenes/") or lower.contains("/previews/") or lower.contains("/palette/"):
		return false
	return true

func _add_texture_to_catalog(tile_set: TileSet, path: String, kind: String) -> void:
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		return
	var width := texture.get_width()
	var height := texture.get_height()
	if width <= 0 or height <= 0:
		return
	var source := TileSetAtlasSource.new()
	source.resource_name = path.get_file().get_basename()
	var grid_aligned := width % 16 == 0 and height % 16 == 0
	if grid_aligned:
		source.texture = texture
		source.texture_region_size = Vector2i(16, 16)
		if path.to_lower().contains("/walls/") and width == 16 and height >= 32:
			for y in range(height / 16):
				source.create_tile(Vector2i(0, y))
				_apply_tile_collision(source.get_tile_data(Vector2i(0, y), 0), kind, path, 16, 16)
		else:
			source.create_tile(Vector2i.ZERO, Vector2i(width / 16, height / 16))
			_apply_tile_collision(source.get_tile_data(Vector2i.ZERO, 0), kind, path, width, height)
	else:
		# Keep irregular-sized UI, icon and prop textures as one complete atlas tile
		# instead of dropping them from the editor library.
		var region := Vector2i(maxi(16, width), maxi(16, height))
		if width < 16 or height < 16:
			var source_image := texture.get_image()
			if source_image == null:
				return
			var padded := Image.create(region.x, region.y, false, source_image.get_format())
			padded.fill(Color(0, 0, 0, 0))
			padded.blit_rect(source_image, Rect2i(Vector2i.ZERO, Vector2i(width, height)), Vector2i.ZERO)
			source.texture = ImageTexture.create_from_image(padded)
		else:
			source.texture = texture
		source.texture_region_size = region
		source.create_tile(Vector2i.ZERO)
		_apply_tile_collision(source.get_tile_data(Vector2i.ZERO, 0), kind, path, width, height)
	if tile_set.add_source(source) >= 0:
		_generated_tiles += 1

func _apply_tile_collision(data: TileData, kind: String, path: String, width: int, height: int) -> void:
	if data == null:
		return
	var lower := path.to_lower()
	var solid := false
	match kind:
		"world":
			solid = lower.contains("/trees/") or lower.contains("/rocks/") or lower.contains("/buildings/") or lower.contains("/03_buildings/") or lower.contains("/props/") or lower.contains("/04_props/") or lower.contains("/furniture/")
			if lower.contains("/flowers/") or lower.contains("/grass/") or lower.contains("/decor/") or lower.contains("banner") or lower.contains("rug"):
				solid = false
		"creatures":
			solid = true
		"beach":
			solid = not (lower.contains("buoy") or lower.contains("bobber") or lower.contains("shell"))
		"terrain":
			solid = lower.contains("/cliffs/")
	if not solid:
		return
	var collider_width := float(width) * 0.72
	var collider_height := maxf(5.0, float(height) * 0.24)
	var center_y := -collider_height * 0.5
	if lower.contains("/trees/"):
		collider_width = clampf(float(width) * 0.24, 5.0, 12.0)
		collider_height = clampf(float(height) * 0.22, 7.0, 13.0)
		center_y = -collider_height * 0.5
	elif lower.contains("/rocks/") or "rock" in lower:
		collider_width = float(width) * 0.82
		collider_height = maxf(6.0, float(height) * 0.48)
		center_y = -float(height) * 0.24
	elif lower.contains("/buildings/") or lower.contains("/03_buildings/") or lower.contains("/cliffs/"):
		collider_width = float(width) * 0.88
		collider_height = maxf(8.0, float(height) * 0.28)
		center_y = -collider_height * 0.5
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, _rectangle_polygon(collider_width, collider_height, center_y))

func _rectangle_polygon(width: float, height: float, center_y: float) -> PackedVector2Array:
	var hw := width * 0.5
	var hh := height * 0.5
	return PackedVector2Array([Vector2(-hw, center_y - hh), Vector2(hw, center_y - hh), Vector2(hw, center_y + hh), Vector2(-hw, center_y + hh)])

func _configure_ground_collision() -> void:
	for season in ["spring", "summer", "autumn", "winter"]:
		var path := "res://Assets/CozyVillageFarm/Godot/TileSets/cozy_ground_%s.tres" % season
		var tile_set := ResourceLoader.load(path) as TileSet
		if tile_set == null:
			continue
		if tile_set.get_physics_layers_count() == 0:
			tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, 2)
		tile_set.set_physics_layer_collision_mask(0, 1)
		for source_id in tile_set.get_source_ids():
			var source := tile_set.get_source(source_id) as TileSetAtlasSource
			if source == null:
				continue
			if source_id == 11 or source_id == 12 or source_id == 21:
				for coords in _get_tile_coords(source):
					var data := source.get_tile_data(coords, 0)
					if data != null:
						data.set_collision_polygons_count(0, 1)
						data.set_collision_polygon_points(0, 0, _rectangle_polygon(16.0, 16.0, 0.0))
			elif source_id == 17 or source_id == 20:
				_apply_water_corner_collision(source)
			elif source_id == 21:
				_configure_animated_atlas(source, 4, 5.0)
		_add_water_animation_source(tile_set, "res://Assets/CozyVillageFarm/01_Terrain/Base_Tiles/common/water_anim_4f.png", 5, 0, 5.0)
		_add_water_animation_source(tile_set, "res://Assets/CozyVillageFarm/01_Terrain/Base_Tiles/common/deep_water_anim_4f.png", 6, 0, 5.0)
		_add_water_animation_source(tile_set, "res://Assets/CozyVillageFarm/01_Terrain/Autotiles/%s/grass_over_water_anim_4f.png" % season, 0, 5, 5.0)
		_add_water_animation_source(tile_set, "res://Assets/CozyVillageFarm/01_Terrain/Autotiles/common/sand_over_water_anim_4f.png", 2, 5, 5.0)
		ResourceSaver.save(tile_set, path)

func _apply_water_corner_collision(source: TileSetAtlasSource) -> void:
	for coords in _get_tile_coords(source):
		var data := source.get_tile_data(coords, 0)
		if data == null:
			continue
		var polygons: Array[PackedVector2Array] = []
		var corners := [
			[TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, Vector2(-8, -8)],
			[TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, Vector2(0, -8)],
			[TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, Vector2(-8, 0)],
			[TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, Vector2(0, 0)]
		]
		for corner in corners:
			if data.get_terrain_peering_bit(int(corner[0])) == 5:
				var origin: Vector2 = corner[1]
				polygons.append(PackedVector2Array([origin, origin + Vector2(8, 0), origin + Vector2(8, 8), origin + Vector2(0, 8)]))
		data.set_collision_polygons_count(0, polygons.size())
		for index in range(polygons.size()):
			data.set_collision_polygon_points(0, index, polygons[index])

func _configure_animated_atlas(source: TileSetAtlasSource, speed: float, frame_separation: Vector2i) -> void:
	for coords in _get_tile_coords(source):
		# Each 64x64 autotile frame is four tiles wide. Frames are separated
		# by three atlas cells so the same corner tile animates across frames.
		source.set_tile_animation_columns(coords, 0)
		source.set_tile_animation_separation(coords, frame_separation)
		source.set_tile_animation_frames_count(coords, 4)
		source.set_tile_animation_speed(coords, speed)

func _add_water_animation_source(tile_set: TileSet, texture_path: String, upper_terrain: int, lower_terrain: int, speed: float) -> void:
	var texture := ResourceLoader.load(texture_path) as Texture2D
	if texture == null:
		return
	for source_id in tile_set.get_source_ids():
		var existing := tile_set.get_source(source_id) as TileSetAtlasSource
		if existing != null and existing.texture != null and existing.texture.resource_path == texture_path:
			if texture.get_width() > 64:
				_configure_animated_atlas(existing, 4, speed)
				_apply_water_corner_collision(existing)
			else:
				_configure_animated_atlas(existing, speed, Vector2i.ZERO)
				for coords in _get_tile_coords(existing):
					var data := existing.get_tile_data(coords, 0)
					if data != null:
						data.set_collision_polygons_count(0, 1)
						data.set_collision_polygon_points(0, 0, _rectangle_polygon(16.0, 16.0, 0.0))
			return

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)
	source.resource_name = texture_path.get_file().get_basename()
	var is_corner_sheet := texture.get_width() >= 256
	var count_x := 4 if is_corner_sheet else 1
	var count_y := 4 if is_corner_sheet else 1
	for y in range(count_y):
		for x in range(count_x):
			var coords := Vector2i(x, y)
			source.create_tile(coords)
			source.set_tile_animation_columns(coords, 4 if is_corner_sheet else 0)
			source.set_tile_animation_frames_count(coords, 4)
			source.set_tile_animation_speed(coords, speed)
			var data := source.get_tile_data(coords, 0)
			if data == null:
				continue
			if is_corner_sheet:
				data.set_terrain_set(0)
				data.set_terrain(0, upper_terrain)
				var bits := [
					["top_left_corner", TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER],
					["top_right_corner", TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER],
					["bottom_left_corner", TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER],
					["bottom_right_corner", TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]
				]
				for bit_index in range(bits.size()):
					var upper := _water_corner_pattern(coords)[bit_index]
					data.set_terrain_peering_bit(int(bits[bit_index][1]), upper_terrain if upper else lower_terrain)
			else:
				data.set_terrain_set(0)
				data.set_terrain(0, upper_terrain)
				for side in [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]:
					data.set_terrain_peering_bit(side, upper_terrain)
			if (not is_corner_sheet) or upper_terrain == 5:
				data.set_collision_polygons_count(0, 1)
				data.set_collision_polygon_points(0, 0, _rectangle_polygon(16.0, 16.0, 0.0))
			elif lower_terrain == 5:
				var polygons: Array[PackedVector2Array] = []
				var pattern := _water_corner_pattern(coords)
				var positions := [Vector2(-8, -8), Vector2(0, -8), Vector2(-8, 0), Vector2(0, 0)]
				for bit_index in range(4):
					if not pattern[bit_index]:
						var origin: Vector2 = positions[bit_index]
						polygons.append(PackedVector2Array([origin, origin + Vector2(8, 0), origin + Vector2(8, 8), origin + Vector2(0, 8)]))
				data.set_collision_polygons_count(0, polygons.size())
				for index in range(polygons.size()):
					data.set_collision_polygon_points(0, index, polygons[index])
	var added_id := tile_set.add_source(source)
	if added_id >= 0:
		print("Cozy Village: добавлена анимация воды ", texture_path)

func _water_corner_pattern(coords: Vector2i) -> Array:
	var patterns := [
		[false, false, false, true], [false, false, true, true],
		[false, false, true, false], [true, true, true, false],
		[false, true, false, true], [true, true, true, true],
		[true, false, true, false], [true, true, false, true],
		[false, true, false, false], [true, true, false, false],
		[true, false, false, false], [true, false, true, true],
		[false, false, false, false], [false, true, true, false],
		[true, false, false, true], [false, true, true, true]
	]
	return patterns[coords.y * 4 + coords.x]

func _get_tile_coords(source: TileSetAtlasSource) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid := source.get_atlas_grid_size()
	for y in range(grid.y):
		for x in range(grid.x):
			var coords := Vector2i(x, y)
			if source.get_tile_at_coords(coords) == coords:
				result.append(coords)
	return result

func _scan_placeables(source_path: String, output_path: String) -> void:
	var directory := DirAccess.open(source_path)
	if directory == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var path := source_path.path_join(entry)
		if directory.current_is_dir():
			var lower_path := path.to_lower()
			if lower_path.contains("/05_interiors/floors") or lower_path.contains("/05_interiors/walls"):
				continue
			_scan_placeables(path, output_path.path_join(entry))
		elif entry.get_extension().to_lower() == "png" and _is_placeable(path):
			_create_placeable_scene(path, output_path)
	directory.list_dir_end()

func _is_placeable(path: String) -> bool:
	var lower := path.to_lower()
	var file := lower.get_file()
	if file.begins_with("_") or "autotile" in file or "layout_guide" in file or "_stages_" in file or "_all_" in file:
		return false
	if "_sheet" in file:
		return lower.contains("/07_animals/") or lower.contains("/08_characters/")
	return true

func _create_placeable_scene(path: String, output_directory: String) -> void:
	var output_path := output_directory.path_join(path.get_file().get_basename() + ".tscn")
	if FileAccess.file_exists(output_path):
		return
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		return
	var visual_size := Vector2i(texture.get_width(), texture.get_height())
	var animation := _build_animations(texture, path)
	var body := StaticBody2D.new()
	body.name = path.get_file().get_basename().replace(" ", "_")
	body.set_script(PLACEABLE_SCRIPT)
	body.collision_layer = 2
	body.collision_mask = 1
	if not animation.is_empty():
		var animated := AnimatedSprite2D.new()
		animated.name = "Visual"
		animated.sprite_frames = animation.frames
		animated.animation = str(animation.first)
		animated.autoplay = str(animation.first)
		animated.centered = true
		animated.position = Vector2(0, -float(animation.size.y) * 0.5)
		animated.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.add_child(animated)
		animated.owner = body
		visual_size = animation.size
	else:
		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = texture
		sprite.centered = true
		sprite.position = Vector2(0, -float(visual_size.y) * 0.5)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.add_child(sprite)
		sprite.owner = body
	var profile := _scene_collision(path, visual_size)
	if not profile.is_empty():
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var rectangle := RectangleShape2D.new()
		rectangle.size = profile.size
		collision.shape = rectangle
		collision.position = profile.position
		body.add_child(collision)
		collision.owner = body
	var packed := PackedScene.new()
	if packed.pack(body) == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
		if ResourceSaver.save(packed, output_path) == OK:
			_generated_scenes += 1
	body.free()

func _build_animations(texture: Texture2D, path: String) -> Dictionary:
	var lower := path.to_lower()
	var columns := 0
	var rows := 1
	var kind := "strip"
	if lower.contains("/07_animals/") and lower.get_file().ends_with("_sheet.png"):
		columns = 6
		rows = 2 if ("chicken" in lower or "duck" in lower or "chick" in lower) else 4
		kind = "walk_idle"
	elif lower.contains("/08_characters/") and "_walk_idle_sheet" in lower:
		columns = 6
		rows = 4
		kind = "walk_idle"
	elif lower.contains("/08_characters/") and "_action_" in lower:
		columns = 3
		rows = 4
		kind = "action"
	else:
		var regex := RegEx.new()
		regex.compile("_anim_(\\d+)f")
		var match_result := regex.search(lower)
		if match_result != null:
			columns = int(match_result.get_string(1))
		elif lower.get_file().ends_with("_2f.png"):
			columns = 2
		else:
			return {}
	if columns < 2 or texture.get_width() % columns != 0 or texture.get_height() % rows != 0:
		return {}
	var size := Vector2i(texture.get_width() / columns, texture.get_height() / rows)
	var frames := SpriteFrames.new()
	frames.clear_all()
	var first := ""
	if kind == "walk_idle":
		var directions := ["down", "up", "right", "left"] if rows == 4 else ["right", "left"]
		for row in range(rows):
			var walk := "walk_" + directions[row]
			_add_animation(frames, walk, texture, size, row, 0, 4, 7.0)
			if first.is_empty():
				first = walk
			if columns >= 6:
				_add_animation(frames, "idle_" + directions[row], texture, size, row, 4, 2, 2.5)
	elif kind == "action":
		var directions := ["down", "up", "right", "left"]
		for row in range(rows):
			var action := "action_" + directions[row]
			_add_animation(frames, action, texture, size, row, 0, columns, 9.0)
			if first.is_empty():
				first = action
	else:
		_add_animation(frames, "default", texture, size, 0, 0, columns, 6.0)
		first = "default"
	return {"frames": frames, "first": first, "size": size}

func _add_animation(frames: SpriteFrames, name: String, texture: Texture2D, size: Vector2i, row: int, start: int, count: int, speed: float) -> void:
	if frames.has_animation(name):
		return
	frames.add_animation(name)
	frames.set_animation_loop(name, true)
	frames.set_animation_speed(name, speed)
	for column in range(start, start + count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(column * size.x, row * size.y), Vector2(size.x, size.y))
		frames.add_frame(name, atlas)

func _scene_collision(path: String, size: Vector2i) -> Dictionary:
	var lower := path.to_lower()
	var w := float(size.x)
	var h := float(size.y)
	var cw := 0.0
	var ch := 0.0
	var cy := 0.0
	if lower.contains("/trees/"):
		cw = clampf(w * 0.24, 5.0, 12.0)
		ch = clampf(h * 0.22, 7.0, 13.0)
	elif lower.contains("/rocks/") or "rock" in lower:
		cw = w * 0.82
		ch = maxf(6.0, h * 0.48)
		cy = -h * 0.24
	elif lower.contains("/buildings/") or lower.contains("/03_buildings/"):
		cw = w * 0.88
		ch = maxf(8.0, h * 0.28)
	elif lower.contains("/animals/"):
		cw = w * 0.72
		ch = maxf(6.0, h * 0.45)
	elif lower.contains("/characters/"):
		cw = w * 0.48
		ch = maxf(6.0, h * 0.2)
	elif lower.contains("/props/") or lower.contains("/04_props/") or lower.contains("/furniture/") or lower.contains("/beach_fishing/") or lower.contains("/09_beach_fishing/"):
		if "banner" in lower or "sign" in lower or "flowerpot" in lower or "flower" in lower or "grass" in lower:
			return {}
		cw = w * 0.72
		ch = maxf(5.0, h * 0.32)
	else:
		return {}
	cy -= ch * 0.5
	return {"size": Vector2(cw, ch), "position": Vector2(0, cy)}
