@tool
extends "res://addons/object_builder/mechanics/object_identity/components/mechanic_component.gd"

var _regrowth_left := 0.0
var _regrowth_active := false


func _on_configured() -> void:
	_load_options({
		"parts_json": "[]",
		"stage_thresholds": "0.75,0.5,0.25",
		"debris_scene_path": "",
		"debris_count": 4,
		"loot_table_json": "[]",
		"animation_player_path": "AnimationPlayer",
		"destroy_animation": "destroy",
		"remains_scene_path": "",
		"repair_amount": 25.0,
		"regrowth_seconds": 30.0,
		"explosion_radius": 96.0,
		"explosion_damage": 25.0
	})


func get_parts_plan() -> Array[Dictionary]:
	return _json_array("parts_json")


func get_destruction_stage(integrity_ratio: float) -> int:
	var ratio := clampf(integrity_ratio, 0.0, 1.0)
	var stage := 0
	for entry in str(get_option("stage_thresholds", "0.75,0.5,0.25")).split(",", false):
		var threshold_text := str(entry).strip_edges()
		if threshold_text.is_valid_float() and ratio <= clampf(threshold_text.to_float(), 0.0, 1.0):
			stage += 1
	return stage


func get_debris_spawn_data(origin: Vector2 = Vector2.ZERO) -> Dictionary:
	return {
		"scene_path": str(get_option("debris_scene_path", "")),
		"count": clampi(int(get_option("debris_count", 4)), 0, 256),
		"global_position": origin
	}


func spawn_debris(parent: Node, origin: Vector2 = Vector2.ZERO) -> Array[Node]:
	var result: Array[Node] = []
	if not is_instance_valid(parent):
		return result
	var path := str(get_option("debris_scene_path", "")).strip_edges()
	var scene := _load_scene(path)
	if scene == null:
		return result
	var amount := clampi(int(get_option("debris_count", 4)), 0, 256)
	for _index in range(amount):
		var instance := scene.instantiate()
		parent.add_child(instance)
		if instance is Node2D:
			(instance as Node2D).global_position = origin
		result.append(instance)
	_emit(result.size())
	return result


func roll_loot(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _json_array("loot_table_json"):
		var item_id := str(entry.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			continue
		var chance := clampf(_numeric(entry.get("chance", 1.0), 1.0), 0.0, 1.0)
		var roll := randf() if rng == null else rng.randf()
		if roll > chance:
			continue
		var minimum := maxi(0, int(entry.get("minimum", 1)))
		var maximum := maxi(minimum, int(entry.get("maximum", minimum)))
		var quantity := randi_range(minimum, maximum) if rng == null else rng.randi_range(minimum, maximum)
		if quantity > 0:
			result.append({"item_id": item_id, "amount": quantity})
	return result


func play_destroy_animation(object_root: Node) -> bool:
	if not is_instance_valid(object_root):
		return false
	var path := str(get_option("animation_player_path", "AnimationPlayer")).strip_edges()
	var player: Node = object_root if path.is_empty() else object_root.get_node_or_null(NodePath(path))
	var animation := str(get_option("destroy_animation", "destroy")).strip_edges()
	if not player is AnimationPlayer or animation.is_empty():
		return false
	var animation_player := player as AnimationPlayer
	if not animation_player.has_animation(animation):
		return false
	animation_player.play(animation)
	return true


func spawn_remains(parent: Node, origin: Vector2 = Vector2.ZERO) -> Node:
	if not is_instance_valid(parent):
		return null
	var path := str(get_option("remains_scene_path", "")).strip_edges()
	var scene := _load_scene(path)
	if scene == null:
		return null
	var instance := scene.instantiate()
	parent.add_child(instance)
	if instance is Node2D:
		(instance as Node2D).global_position = origin
	_emit(instance)
	return instance


func repair_health(health_component: Node = null, amount: float = -1.0) -> float:
	var target := health_component
	if target == null:
		target = ObjectFactory.get_component(get_object_root(), "health")
	if not is_instance_valid(target) or not target.has_method("heal"):
		return 0.0
	var requested := _number("repair_amount", 25.0) if amount < 0.0 else amount
	if requested <= 0.0 or is_nan(requested) or is_inf(requested):
		return 0.0
	return float(target.call("heal", requested))


func start_regrowth(duration: float = -1.0) -> void:
	var requested := _number("regrowth_seconds", 30.0) if duration < 0.0 else duration
	_regrowth_left = maxf(0.0, requested)
	_regrowth_active = true
	_emit(_regrowth_left)


func tick_regrowth(delta: float) -> bool:
	if not _regrowth_active:
		return false
	if delta > 0.0 and not is_nan(delta) and not is_inf(delta):
		_regrowth_left = maxf(0.0, _regrowth_left - delta)
	if _regrowth_left > 0.0:
		return false
	_regrowth_active = false
	_emit("regrowth_complete")
	return true


func get_explosion_payload() -> Dictionary:
	return _emit({
		"radius": maxf(0.0, _number("explosion_radius", 96.0)),
		"damage": maxf(0.0, _number("explosion_damage", 25.0))
	})


func spawn_break_parts(parent: Node, origin: Vector2 = Vector2.ZERO) -> Array[Node]:
	var result: Array[Node] = []
	if not is_instance_valid(parent):
		return result
	for entry in get_parts_plan():
		var path := str(entry.get("scene_path", "")).strip_edges()
		var scene := _load_scene(path)
		if scene == null:
			continue
		var instance := scene.instantiate()
		parent.add_child(instance)
		if instance is Node2D:
			var offset := Vector2(_numeric(entry.get("offset_x", 0.0), 0.0), _numeric(entry.get("offset_y", 0.0), 0.0))
			(instance as Node2D).global_position = origin + offset
		result.append(instance)
	_emit(result.size())
	return result


func _json_array(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(str(get_option(key, "[]")))
	if typeof(parsed) != TYPE_ARRAY:
		return result
	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


func _load_scene(path: String) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as PackedScene


func _numeric(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var result := float(value)
		if not is_nan(result) and not is_inf(result):
			return result
	elif typeof(value) == TYPE_STRING and str(value).is_valid_float():
		return str(value).to_float()
	return fallback


func _number(key: String, fallback: float) -> float:
	return _numeric(get_option(key, fallback), fallback)


func _emit(value: Variant) -> Variant:
	action_completed.emit(value)
	return value
