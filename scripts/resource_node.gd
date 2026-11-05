@tool
extends StaticBody2D
class_name ResourceNode

const WORLD_Z_SORT_OFFSET := 2048

signal resource_broken(kind: String, drop_position: Vector2, amount: int)

@export_enum("tree", "rock", "stump") var resource_type := "tree":
	set(value):
		resource_type = value
		if is_inside_tree():
			_update_visual()
			queue_redraw()

@export var max_health := 90.0
@export var health := 90.0
@export var wood_drop_amount := 5
@export var stone_drop_amount := 4
@export var hit_radius := 29.0
@export var swing_strength := 1.0
@export var destruction_duration := 0.48
@export var fall_angle_degrees := 78.0
@export var preserve_visual_texture := false
@export var damage_resistances: Dictionary = {
	"cutting": 1.0,
	"piercing": 1.0,
	"crushing": 1.0,
}

@export_group("Процедурный пень")
## Высота оставшейся части ствола после рубки, в локальных пикселях.
@export_range(4.0, 64.0, 1.0) var stump_height := 16.0:
	set(value):
		stump_height = clampf(value, 4.0, 64.0)
		if is_inside_tree():
			queue_redraw()
@export_range(6.0, 48.0, 1.0) var stump_width := 15.0:
	set(value):
		stump_width = clampf(value, 6.0, 48.0)
		if is_inside_tree():
			queue_redraw()

@export_group("Звуки")
@export_subgroup("Дерево")
## Случайный звук при каждом успешном попадании по дереву.
@export var tree_hit_sounds: Array[AudioStream] = []
## Звук запуска анимации падения дерева.
@export var tree_destroy_sound: AudioStream
@export_subgroup("Камень")
## Случайный звук при каждом успешном попадании по камню.
@export var rock_hit_sounds: Array[AudioStream] = []
## Звук разрушения камня.
@export var rock_destroy_sound: AudioStream

var visual: Sprite2D
var crack_overlay: Node2D
var flash_timer := 0.0
var fall_direction := 1.0
var sway_velocity := 0.0
var destroying := false
var debug_selected := false

func configure(kind: String, starting_health: float) -> void:
	resource_type = kind
	max_health = starting_health
	health = starting_health
	hit_radius = 29.0 if kind == "tree" else 23.0
	wood_drop_amount = 5
	stone_drop_amount = 4
	_update_visual()
	queue_redraw()

func _ready() -> void:
	z_as_relative = false
	if resource_type == "rock" and max_health == 90.0:
		max_health = 110.0
		health = max_health
	if resource_type == "tree":
		hit_radius = maxf(hit_radius, 29.0)
	else:
		hit_radius = maxf(hit_radius, 23.0)

	visual = get_node_or_null("Visual") as Sprite2D
	if visual == null:
		visual = Sprite2D.new()
		visual.name = "Visual"
		add_child(visual)
	crack_overlay = get_node_or_null("CrackOverlay") as Node2D
	if crack_overlay == null:
		crack_overlay = Node2D.new()
		crack_overlay.name = "CrackOverlay"
		crack_overlay.z_index = 1
		add_child(crack_overlay)
	_update_visual()

	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 12.0 if resource_type == "tree" else 16.0
		collision.shape = circle
		collision.position = Vector2(0, 8)
		add_child(collision)
	if not Engine.is_editor_hint():
		collision_layer = 2
		collision_mask = 0
	queue_redraw()

func _update_visual() -> void:
	if visual == null:
		return
	if resource_type == "stump":
		visual.visible = false
		if crack_overlay != null:
			crack_overlay.visible = false
		return
	visual.visible = true
	if crack_overlay != null:
		crack_overlay.visible = true
	if preserve_visual_texture and visual.texture != null:
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.z_index = -1
		_update_crack_overlay()
		return

	var texture_path := "res://Assets/Resources/Trees/tree.svg"
	match resource_type:
		"rock":
			texture_path = "res://Assets/Resources/Rocks/rock.svg"
			visual.position = Vector2(0, -28)
		"stump":
			texture_path = "res://Assets/CozyVillageFarm/02_Nature/Trees/special/stump.png" if preserve_visual_texture else "res://Assets/Resources/Stumps/stump.svg"
			visual.position = Vector2(0, -20)
		_:
			texture_path = "res://Assets/Resources/Trees/tree.svg"
			visual.position = Vector2(0, -48)
	visual.texture = load(texture_path) as Texture2D
	if preserve_visual_texture and visual.texture != null:
		visual.position = Vector2(0, -float(visual.texture.get_height()) * 0.5)
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.z_index = -1
	_update_crack_overlay()

func _update_crack_overlay() -> void:
	if crack_overlay == null:
		return
	for child in crack_overlay.get_children():
		child.queue_free()
	if resource_type != "rock" or visual == null or visual.texture == null:
		return
	var damage_ratio := 1.0 - clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	var crack_count := 0
	if damage_ratio >= 0.12:
		crack_count = 1
	if damage_ratio >= 0.38:
		crack_count = 2
	if damage_ratio >= 0.66:
		crack_count = 3
	if crack_count == 0:
		return
	var texture_size := visual.texture.get_size()
	var scale_factor := minf(texture_size.x, texture_size.y) / 32.0
	var half_width := texture_size.x * 0.34
	var half_height := texture_size.y * 0.34
	var crack_paths := [
		PackedVector2Array([Vector2(-half_width * 0.55, -half_height), Vector2(-half_width * 0.12, -half_height * 0.22), Vector2(-half_width * 0.42, half_height * 0.15)]),
		PackedVector2Array([Vector2(half_width * 0.65, -half_height * 0.76), Vector2(half_width * 0.12, -half_height * 0.08), Vector2(half_width * 0.48, half_height * 0.68)]),
		PackedVector2Array([Vector2(-half_width, half_height * 0.38), Vector2(-half_width * 0.12, half_height * 0.12), Vector2(half_width * 0.08, half_height * 0.62)])
	]
	crack_overlay.position = visual.position
	for index in range(crack_count):
		var crack := Line2D.new()
		crack.name = "Crack_%d" % index
		crack.points = crack_paths[index]
		crack.width = maxf(1.0, scale_factor)
		crack.default_color = Color("#343b39")
		crack.begin_cap_mode = Line2D.LINE_CAP_ROUND
		crack.end_cap_mode = Line2D.LINE_CAP_ROUND
		crack_overlay.add_child(crack)

func apply_damage(amount: float, damage_type: String = "crushing") -> bool:
	if amount <= 0.0 or destroying or resource_type == "stump":
		return false
	var resistance := float(damage_resistances.get(damage_type, 1.0))
	var final_damage := maxf(0.0, amount * resistance)
	if final_damage <= 0.0:
		return false
	health = maxf(0.0, health - final_damage)
	flash_timer = 0.13
	if resource_type == "tree":
		var direction := -1.0 if randf() < 0.5 else 1.0
		rotation += direction * deg_to_rad(4.0) * swing_strength
		sway_velocity += direction * deg_to_rad(38.0) * swing_strength
	if visual != null:
		visual.modulate = Color(1.55, 1.55, 1.55, 1.0)
	_update_crack_overlay()
	_play_hit_sound()
	_spawn_hit_particles(_get_visual_hit_position())
	queue_redraw()
	return health <= 0.0


func set_debug_selected(value: bool) -> void:
	debug_selected = value
	queue_redraw()

func begin_destroy() -> void:
	if destroying or resource_type == "stump":
		return
	destroying = true
	_play_destroy_sound()
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", true)
	if resource_type == "tree":
		fall_direction = -1.0 if randf() < 0.5 else 1.0
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(self, "rotation", deg_to_rad(fall_angle_degrees) * fall_direction, destruction_duration)
		tween.tween_callback(_finish_tree_fall)
	else:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(0.18, 0.18), destruction_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "modulate:a", 0.0, destruction_duration)
		tween.chain().tween_callback(_finish_rock_break)

func _finish_tree_fall() -> void:
	resource_broken.emit("wood", global_position + Vector2(0, -12), maxi(1, wood_drop_amount))
	resource_type = "stump"
	health = 0.0
	rotation = 0.0
	modulate = Color.WHITE
	if visual != null:
		visual.modulate = Color.WHITE
	destroying = false
	_update_visual()
	queue_redraw()

func _finish_rock_break() -> void:
	resource_broken.emit("stone", global_position, maxi(1, stone_drop_amount))
	queue_free()

func _get_stump_bottom_local_y() -> float:
	if visual == null:
		return 18.0
	var bounds := visual.get_rect()
	return visual.position.y + visual.scale.y * bounds.end.y


func _get_visual_bottom_y() -> float:
	if resource_type == "stump":
		return to_global(Vector2(0.0, _get_stump_bottom_local_y())).y
	if visual == null or visual.texture == null or not visual.visible:
		return global_position.y
	var rect := visual.get_rect()
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var bottom_y := -INF
	for corner in corners:
		bottom_y = maxf(bottom_y, visual.to_global(corner).y)
	return bottom_y


func _get_visual_hit_position() -> Vector2:
	if visual == null or visual.texture == null:
		return global_position
	return visual.to_global(visual.get_rect().get_center())


func _get_visual_base_color() -> Color:
	var fallback := Color("#8b6240") if resource_type == "tree" or resource_type == "stump" else Color("#858b91")
	if visual == null or visual.texture == null:
		return fallback
	var image := visual.texture.get_image()
	if image == null or image.is_empty():
		return fallback
	var source_rect := Rect2(Vector2.ZERO, Vector2(image.get_size()))
	if visual.region_enabled:
		source_rect = visual.region_rect
	var sample_points: Array[Vector2] = [
		Vector2(0.50, 0.78),
		Vector2(0.42, 0.84),
		Vector2(0.58, 0.84),
		Vector2(0.46, 0.92),
		Vector2(0.54, 0.92),
	]
	if resource_type == "rock":
		sample_points = [
			Vector2(0.50, 0.42),
			Vector2(0.35, 0.50),
			Vector2(0.65, 0.50),
			Vector2(0.50, 0.62),
		]
	var total := Color(0, 0, 0, 0)
	var sample_count := 0
	for sample_point in sample_points:
		var pixel_x := clampi(roundi(source_rect.position.x + sample_point.x * maxf(0.0, source_rect.size.x - 1.0)), 0, image.get_width() - 1)
		var pixel_y := clampi(roundi(source_rect.position.y + sample_point.y * maxf(0.0, source_rect.size.y - 1.0)), 0, image.get_height() - 1)
		var sampled_color := image.get_pixel(pixel_x, pixel_y)
		if sampled_color.a > 0.15:
			total += sampled_color
			sample_count += 1
	if sample_count == 0:
		return fallback
	var average := total / float(sample_count)
	return Color(average.r, average.g, average.b, 1.0)


func _spawn_hit_particles(world_position: Vector2) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var effects_root: Node = get_tree().current_scene
	if effects_root == null:
		effects_root = get_parent()
	if effects_root == null:
		return
	var particle_image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	particle_image.fill(Color.WHITE)
	var particles := CPUParticles2D.new()
	particles.name = "HitParticles"
	particles.amount = 12
	particles.lifetime = 0.32
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 34.0
	particles.initial_velocity_max = 104.0
	particles.gravity = Vector2(0, 185.0)
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.7
	particles.color = _get_visual_base_color()
	particles.texture = ImageTexture.create_from_image(particle_image)
	particles.z_as_relative = false
	particles.z_index = clampi(z_index + 4, -4096, 4096)
	effects_root.add_child(particles)
	particles.global_position = world_position
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _play_hit_sound() -> void:
	var sound_list: Array[AudioStream] = tree_hit_sounds if resource_type == "tree" else rock_hit_sounds
	if sound_list.is_empty():
		return
	_play_resource_sound(sound_list[randi_range(0, sound_list.size() - 1)])


func _play_destroy_sound() -> void:
	var sound: AudioStream = tree_destroy_sound if resource_type == "tree" else rock_destroy_sound
	_play_resource_sound(sound)


func _play_resource_sound(sound: AudioStream) -> void:
	if sound == null or Engine.is_editor_hint() or not is_inside_tree():
		return
	var audio_root: Node = get_tree().current_scene
	if audio_root == null:
		audio_root = get_parent()
	if audio_root == null:
		return
	var audio := AudioStreamPlayer2D.new()
	audio.name = "ResourceSound"
	audio.stream = sound
	audio.volume_db = -3.0
	audio.pitch_scale = randf_range(0.94, 1.06)
	audio.max_distance = 900.0
	audio.finished.connect(audio.queue_free)
	audio_root.add_child(audio)
	audio.global_position = global_position
	audio.play()


func _draw_procedural_stump() -> void:
	var bottom_y := _get_stump_bottom_local_y()
	var top_y := bottom_y - maxf(4.0, stump_height)
	var half_width := maxf(3.0, stump_width * 0.5)
	var cap_height := maxf(2.0, minf(5.0, stump_height * 0.22))
	var bark := _get_visual_base_color()
	var bark_shadow := bark.darkened(0.32)
	var bark_highlight := bark.lightened(0.18)

	var trunk := PackedVector2Array([
		Vector2(-half_width * 0.76, top_y),
		Vector2(half_width * 0.76, top_y),
		Vector2(half_width, bottom_y - 2.0),
		Vector2(half_width * 0.76, bottom_y),
		Vector2(-half_width * 0.76, bottom_y),
		Vector2(-half_width, bottom_y - 2.0),
	])
	draw_colored_polygon(trunk, bark_shadow)
	draw_line(Vector2(-half_width * 0.28, top_y + cap_height * 0.7), Vector2(-half_width * 0.22, bottom_y - 1.0), bark_highlight, 1.0)
	draw_line(Vector2(half_width * 0.30, top_y + cap_height * 0.7), Vector2(half_width * 0.24, bottom_y - 1.0), bark.darkened(0.12), 1.0)

	var cap_points := PackedVector2Array()
	for point_index in range(16):
		var angle := TAU * float(point_index) / 16.0
		var uneven_edge := 1.0 + sin(float(point_index) * 2.1) * 0.045
		cap_points.append(Vector2(cos(angle) * half_width * 0.88 * uneven_edge, top_y + sin(angle) * cap_height * uneven_edge))
	draw_colored_polygon(cap_points, bark_highlight)
	var cap_outline := cap_points.duplicate()
	cap_outline.append(cap_points[0])
	draw_polyline(cap_outline, bark_shadow, 1.2, true)

	for ring_index in range(1, 3):
		var ring_points := PackedVector2Array()
		var ring_scale := 0.22 + float(ring_index) * 0.19
		for point_index in range(17):
			var angle := TAU * float(point_index) / 16.0
			ring_points.append(Vector2(cos(angle) * half_width * ring_scale, top_y + sin(angle) * cap_height * ring_scale))
		draw_polyline(ring_points, bark_shadow, 0.8, true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		z_as_relative = false
		z_index = clampi(floori(_get_visual_bottom_y()) + WORLD_Z_SORT_OFFSET + 1, -4096, 4096)
		return
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		if flash_timer == 0.0 and visual != null:
			visual.modulate = Color.WHITE
	if not destroying and resource_type == "tree":
		sway_velocity -= rotation * 26.0 * delta
		sway_velocity *= exp(-7.5 * delta)
		rotation += sway_velocity * delta
	z_as_relative = false
	z_index = clampi(floori(_get_visual_bottom_y()) + WORLD_Z_SORT_OFFSET + 1, -4096, 4096)

func _draw() -> void:
	if resource_type == "stump":
		_draw_procedural_stump()
	if debug_selected:
		draw_arc(Vector2(0, -30), 48.0 if resource_type == "tree" else 34.0, 0.0, TAU, 40, Color("#8ee6ff"), 2.0, true)
