@tool
extends ObjectComponent
class_name AudioEffectsMechanicComponent

signal screen_shake_requested(intensity: float, duration: float)
signal effect_emitted(effect_id: String, payload: Dictionary)
signal action_failed(reason: String)

var _target: Node
var _audio_player: Node
var _trail: Line2D
var _trail_history: Array[Vector2] = []
var _light: PointLight2D


func configure_mechanic(values: Dictionary) -> bool:
	for raw_key in values:
		var key := str(raw_key)
		if not settings.has(key) or typeof(values[raw_key]) != typeof(settings[key]):
			return _fail("Неизвестная настройка или неверный тип: " + key)
	for raw_key in values:
		settings[str(raw_key)] = values[raw_key]
	return true


func bind_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return _fail("Для эффектов нужен действительный целевой узел.")
	_target = target
	return true


func play_event(event_id: String = "") -> bool:
	if not is_instance_valid(_target):
		return _fail("Аудиокомпонент не привязан к объекту.")
	var stream_path := str(_option("stream_path", ""))
	return _play_stream(stream_path, event_id)


func play_for_surface(surface_id: String) -> bool:
	var streams := _parse_json_dictionary(str(_option("surface_streams_json", "{}")))
	var stream_path := str(streams.get(surface_id.strip_edges().to_lower(), ""))
	if stream_path.is_empty():
		return _fail("Для поверхности не настроен звук: " + surface_id)
	return _play_stream(stream_path, "footstep:" + surface_id)


func start_ambient() -> bool:
	if not _has_mechanic("plays_ambient_sound"):
		return _fail("Фоновый звук не включён.")
	return play_event("ambient")


func stop_audio() -> void:
	if is_instance_valid(_audio_player) and _audio_player.has_method("stop"):
		_audio_player.call("stop")


func emit_particles(amount_override: int = -1) -> bool:
	if not _has_mechanic("emits_particles") or not is_instance_valid(_target):
		return _fail("Эффект частиц не включён или объект не привязан.")
	var particle_node: Node
	var scene_path := str(_option("particle_scene_path", ""))
	if not scene_path.is_empty():
		var resource := ResourceLoader.load(scene_path)
		if resource is PackedScene:
			particle_node = (resource as PackedScene).instantiate()
	if particle_node == null:
		var particles := CPUParticles2D.new()
		particles.name = "ObjectBuilderParticles"
		particles.amount = maxi(1, amount_override if amount_override > 0 else int(_option("particle_amount", 24)))
		particles.lifetime = maxf(0.05, float(_option("particle_lifetime", 0.8)))
		particles.one_shot = bool(_option("particle_one_shot", true))
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
		particles.spread = clampf(float(_option("particle_spread", 45.0)), 0.0, 180.0)
		particles.initial_velocity_min = maxf(0.0, float(_option("particle_velocity_min", 20.0)))
		particles.initial_velocity_max = maxf(particles.initial_velocity_min, float(_option("particle_velocity_max", 80.0)))
		particles.emitting = true
		particle_node = particles
	_target.add_child(particle_node)
	effect_emitted.emit("particles", {"node": particle_node, "amount": amount_override})
	return true


func start_trail() -> bool:
	if not _has_mechanic("has_trail_effect") or not (_target is Node2D):
		return _fail("След требует включённой механики и целевого Node2D.")
	if is_instance_valid(_trail):
		return true
	_trail = Line2D.new()
	_trail.name = "ObjectBuilderTrail"
	_trail.width = maxf(0.1, float(_option("trail_width", 4.0)))
	_trail.default_color = Color.from_string(str(_option("trail_color", "#ffffff88")), Color.WHITE)
	_trail.antialiased = true
	_trail.z_index = int(_option("trail_z_index", -1))
	_target.add_child(_trail)
	_trail_history.clear()
	set_process(true)
	return true


func stop_trail() -> void:
	set_process(false)
	_trail_history.clear()
	if is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null


func enable_light() -> bool:
	if not _has_mechanic("has_light_effect") or not (_target is Node2D):
		return _fail("Свечение требует включённой механики и целевого Node2D.")
	if is_instance_valid(_light):
		_light.enabled = true
		return true
	_light = PointLight2D.new()
	_light.name = "ObjectBuilderLight"
	_light.color = Color.from_string(str(_option("light_color", "#fff2c4")), Color.WHITE)
	_light.energy = maxf(0.0, float(_option("light_energy", 1.0)))
	_light.texture_scale = maxf(0.01, float(_option("light_scale", 1.0)))
	_light.texture = _load_light_texture(str(_option("light_texture_path", "")))
	_light.enabled = true
	_target.add_child(_light)
	effect_emitted.emit("light_enabled", {"energy": _light.energy})
	return true


func disable_light() -> void:
	if is_instance_valid(_light):
		_light.enabled = false


func request_screen_shake(intensity: float = -1.0, duration: float = -1.0) -> bool:
	if not _has_mechanic("supports_screen_shake"):
		return _fail("Тряска камеры не включена.")
	var resolved_intensity := intensity if intensity >= 0.0 else float(_option("shake_intensity", 4.0))
	var resolved_duration := duration if duration >= 0.0 else float(_option("shake_duration", 0.15))
	if not is_finite(resolved_intensity) or not is_finite(resolved_duration) or resolved_intensity < 0.0 or resolved_duration < 0.0:
		return _fail("Параметры тряски должны быть конечными и неотрицательными.")
	screen_shake_requested.emit(resolved_intensity, resolved_duration)
	return true


func get_effect_nodes() -> Dictionary:
	return {
		"audio": _audio_player,
		"trail": _trail,
		"light": _light
	}


func export_runtime_state() -> Dictionary:
	return {
		"trail_history": _trail_history.duplicate(),
		"light_enabled": is_instance_valid(_light) and _light.enabled
	}


func import_runtime_state(state: Dictionary) -> bool:
	var history: Variant = state.get("trail_history", [])
	if not history is Array:
		return _fail("Состояние эффектов содержит некорректную историю следа.")
	_trail_history.clear()
	for point in history:
		if point is Vector2:
			_trail_history.append(point)
	if bool(state.get("light_enabled", false)) and _has_mechanic("has_light_effect"):
		enable_light()
	return true


func _process(_delta: float) -> void:
	if not is_instance_valid(_trail) or not (_target is Node2D):
		return
	var target_2d := _target as Node2D
	_trail_history.append(target_2d.global_position)
	var maximum_points := maxi(2, int(_option("trail_length", 16)))
	while _trail_history.size() > maximum_points:
		_trail_history.pop_front()
	var points := PackedVector2Array()
	for global_point in _trail_history:
		points.append(target_2d.to_local(global_point))
	_trail.points = points


func _play_stream(stream_path: String, event_id: String) -> bool:
	if stream_path.strip_edges().is_empty():
		return _fail("Не задан путь к аудиофайлу.")
	var loaded_resource := ResourceLoader.load(stream_path)
	if not loaded_resource is AudioStream:
		return _fail("Не удалось загрузить AudioStream: " + stream_path)
	var stream := (loaded_resource as AudioStream).duplicate(true) as AudioStream
	if event_id == "ambient" and bool(_option("ambient_loop", true)):
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	if not is_instance_valid(_audio_player):
		if _target is Node2D:
			_audio_player = AudioStreamPlayer2D.new()
			_audio_player.name = "ObjectBuilderAudio"
			(_audio_player as AudioStreamPlayer2D).max_distance = maxf(1.0, float(_option("max_distance", 1200.0)))
			(_audio_player as AudioStreamPlayer2D).attenuation = maxf(0.0, float(_option("attenuation", 1.0)))
		else:
			_audio_player = AudioStreamPlayer.new()
			_audio_player.name = "ObjectBuilderAudio"
		_target.add_child(_audio_player)
	var player: AudioStreamPlayer
	if _audio_player is AudioStreamPlayer2D:
		var player_2d := _audio_player as AudioStreamPlayer2D
		player_2d.stream = stream
		player_2d.volume_db = clampf(float(_option("volume_db", 0.0)), -80.0, 24.0)
		player_2d.pitch_scale = clampf(float(_option("pitch_scale", 1.0)), 0.01, 4.0)
		player_2d.bus = str(_option("bus", "Master"))
		player_2d.play()
	else:
		player = _audio_player as AudioStreamPlayer
		player.stream = stream
		player.volume_db = clampf(float(_option("volume_db", 0.0)), -80.0, 24.0)
		player.pitch_scale = clampf(float(_option("pitch_scale", 1.0)), 0.01, 4.0)
		player.bus = str(_option("bus", "Master"))
		player.play()
	effect_emitted.emit("audio", {"event": event_id, "path": stream_path})
	return true

func _load_light_texture(path: String) -> Texture2D:
	if not path.is_empty():
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture


func _has_mechanic(mechanic_id: String) -> bool:
	var root := get_object_root()
	return root != null and ObjectFactory.get_component(root, mechanic_id) != null


func _option(key: String, fallback: Variant = null) -> Variant:
	return get_setting(key, fallback)


func _parse_json_dictionary(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func _fail(reason: String) -> bool:
	action_failed.emit(reason)
	return false
