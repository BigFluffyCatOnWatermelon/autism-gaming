@tool
extends "res://addons/web_object_builder/mechanics/object_identity/components/mechanic_component.gd"

const GameplayTables = preload("res://scripts/object_system/object_gameplay_table_service.gd")

var _regrowth_left := 0.0
var _regrowth_active := false


func _on_configured() -> void:
	_load_options({
		"parts_json": "[]",
		"stage_thresholds": "0.75,0.5,0.25",
		"debris_scene_path": "",
		"debris_count": 4,
		"loot_table_path": "",
		"loot_table_json": "[]",
		"animation_player_path": "AnimationPlayer",
		"destroy_animation": "destroy",
		"remains_scene_path": "",
		"repair_amount": 25.0,
		"regrowth_seconds": 30.0,
		"explosion_radius": 96.0,
		"explosion_damage": 25.0,
		"fall_angle_degrees": 78.0,
		"fall_duration": 0.48
	})


func _feature_enabled() -> bool:
	return get_shared_enabled_state(true)


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
		"count": clampi(int(get_option("debris_count", 4)), 0, 256) if _feature_enabled() else 0,
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
	for entry in GameplayTables.load_loot_table(str(get_option("loot_table_path", "")), get_option("loot_table_json", "[]")):
		var roll := randf() if rng == null else rng.randf()
		if roll > float(entry.chance):
			continue
		var minimum := int(entry.min)
		var maximum := int(entry.max)
		var quantity := randi_range(minimum, maximum) if rng == null else rng.randi_range(minimum, maximum)
		if quantity > 0:
			result.append({"item_id": str(entry.item_id), "amount": quantity})
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
	var object_root := get_object_root()
	if not is_instance_valid(object_root):
		object_root = parent
	var embedded := reveal_embedded_remains(object_root)
	if not embedded.is_empty():
		_emit(embedded.size())
		return embedded[0]

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


## Reveals the sprite layers embedded by the Web Object Builder.
## They are saved hidden in the game scene and become visible only when this
## method is called by the destruction mechanic.
func reveal_embedded_remains(object_root: Node = null) -> Array[Node]:
	var root := object_root
	if not is_instance_valid(root):
		root = get_object_root()
	if not is_instance_valid(root):
		return []
	var revealed: Array[Node] = []
	for candidate in root.find_children("*", "Sprite2D", true, false):
		if candidate.owner != root:
			continue
		var sprite := candidate as Sprite2D
		if bool(sprite.get_meta("object_builder_embedded_remains", false)):
			sprite.visible = true
			revealed.append(sprite)
			continue
		# Hide only visuals managed by Object Builder. User-authored sprites
		# and nested scene instances are left untouched.
		if (
			bool(sprite.get_meta("object_builder_sprite", false))
			or bool(sprite.get_meta("object_builder_sprite_layer", false))
		):
			if not sprite.has_meta("object_builder_remains_previous_visible"):
				sprite.set_meta("object_builder_remains_previous_visible", sprite.visible)
			sprite.visible = false
	return revealed


func restore_embedded_remains(object_root: Node = null) -> void:
	var root := object_root
	if not is_instance_valid(root):
		root = get_object_root()
	if not is_instance_valid(root):
		return
	for candidate in root.find_children("*", "Sprite2D", true, false):
		if candidate.owner != root:
			continue
		var sprite := candidate as Sprite2D
		if bool(sprite.get_meta("object_builder_embedded_remains", false)):
			sprite.visible = false
		elif sprite.has_meta("object_builder_remains_previous_visible"):
			sprite.visible = bool(sprite.get_meta("object_builder_remains_previous_visible", true))
			sprite.remove_meta("object_builder_remains_previous_visible")


func repair_health(health_component: Node = null, amount: float = -1.0) -> float:
	var root := get_object_root()
	var target := health_component
	if target == null:
		target = ObjectFactory.get_component(root, "health")
	if not is_instance_valid(target) or not target.has_method("heal"):
		return 0.0
	var requested := _number("repair_amount", 25.0) if amount < 0.0 else amount
	if requested <= 0.0 or is_nan(requested) or is_inf(requested):
		return 0.0
	var restored := float(target.call("heal", requested))
	if restored > 0.0:
		_emit({"event": "repaired_health", "amount": restored})
	return restored


## Repairs a destroyed object as well as restoring health on a damaged one.
## The destructible component owns collision/visual snapshots and restores them.
func repair_object(amount: float = -1.0) -> bool:
	var root := get_object_root()
	if root == null:
		return false
	var destructible := ObjectFactory.get_component(root, "destructible")
	var was_destroyed := destructible != null and destructible.has_method("is_destroyed") and bool(destructible.call("is_destroyed"))
	if was_destroyed:
		if not destructible.has_method("repair") or not bool(destructible.call("repair")):
			return false
	var restored := repair_health(null, amount)
	return was_destroyed or restored > 0.0


func start_regrowth(duration: float = -1.0) -> void:
	var requested := _number("regrowth_seconds", 30.0) if duration < 0.0 else duration
	_regrowth_left = maxf(0.0, requested)
	_regrowth_active = true
	_emit(_regrowth_left)


func tick_regrowth(delta: float) -> bool:
	if not _regrowth_active:
		return false
	if delta > 0.0 and is_finite(delta):
		_regrowth_left = maxf(0.0, _regrowth_left - delta)
	if _regrowth_left > 0.0:
		return false
	_regrowth_active = false
	var root := get_object_root()
	var destructible := ObjectFactory.get_component(root, "destructible") if root != null else null
	if destructible != null and destructible.has_method("repair"):
		destructible.call("repair")
	elif root != null:
		var health := ObjectFactory.get_component(root, "health")
		if health != null and health.has_method("reset_health"):
			health.call("reset_health")
	_emit("regrowth_complete")
	return true


func export_runtime_state() -> Dictionary:
	var state := super.export_runtime_state()
	state["regrowth_left"] = _regrowth_left
	state["regrowth_active"] = _regrowth_active
	return state


func import_runtime_state(state: Dictionary) -> bool:
	var options := state.duplicate(true)
	var regrowth_left := float(options.get("regrowth_left", 0.0))
	var regrowth_active := bool(options.get("regrowth_active", false))
	options.erase("regrowth_left")
	options.erase("regrowth_active")
	if not is_finite(regrowth_left) or regrowth_left < 0.0:
		return fail("Состояние восстановления содержит некорректный таймер.")
	if not super.import_runtime_state(options):
		return false
	_regrowth_left = regrowth_left
	_regrowth_active = regrowth_active
	return true


func get_explosion_payload() -> Dictionary:
	return _emit({
		"radius": maxf(0.0, _number("explosion_radius", 96.0)),
		"damage": maxf(0.0, _number("explosion_damage", 25.0))
	})


## Starts a material-aware toppling animation. The caller finalizes the destroyed
## object's visuals only after the returned tween finishes.
func play_hit_reaction(material: String = "wood") -> bool:
	var root := get_object_root()
	if not root is Node2D:
		return false
	var pivot := _get_fall_pivot(root as Node2D)
	if pivot == null:
		return false
	var base_rotation := pivot.rotation
	pivot.set_meta("object_builder_hit_base_rotation", base_rotation)
	var previous_tween: Variant = root.get_meta("object_builder_hit_tween", null)
	if previous_tween is Tween and (previous_tween as Tween).is_running():
		(previous_tween as Tween).kill()
	var strength := deg_to_rad(3.6) if material == "wood" else (deg_to_rad(1.5) if material == "stone" else deg_to_rad(2.0))
	var direction := -1.0 if randf() < 0.5 else 1.0
	var tween := pivot.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(pivot, "rotation", base_rotation + strength * direction, 0.055)
	tween.tween_property(pivot, "rotation", base_rotation - strength * direction * 0.42, 0.10)
	tween.tween_property(pivot, "rotation", base_rotation, 0.17)
	root.set_meta("object_builder_hit_tween", tween)
	return true


func play_fall_animation(object_root: Node = null) -> Tween:
	var root := object_root
	if not is_instance_valid(root):
		root = get_object_root()
	if not root is Node2D:
		return null
	var node := root as Node2D
	var pivot := _get_fall_pivot(node)
	if pivot == null:
		return null
	var base_rotation := float(pivot.get_meta(
		"object_builder_hit_base_rotation",
		pivot.rotation
	))
	pivot.set_meta("object_builder_hit_base_rotation", base_rotation)
	node.set_meta("object_builder_fall_base_rotation", base_rotation)
	var angle := deg_to_rad(clampf(_number("fall_angle_degrees", 78.0), 1.0, 120.0))
	var duration := clampf(_number("fall_duration", 0.48), 0.05, 5.0)
	var direction := -1.0 if randf() < 0.5 else 1.0
	var tween := pivot.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(pivot, "rotation", base_rotation + angle * direction, duration)
	# The parent visual is replaced by the embedded stump/remains after the fall.
	tween.tween_interval(0.04)
	tween.tween_callback(func() -> void:
		if is_instance_valid(pivot):
			pivot.rotation = base_rotation
	)
	_emit({"event": "fall_started", "angle_degrees": rad_to_deg(angle), "duration": duration})
	return tween


func _get_fall_pivot(root: Node2D) -> Node2D:
	var cached: Variant = root.get_meta("object_builder_fall_pivot", null)
	if cached is Node2D and is_instance_valid(cached):
		return cached as Node2D

	var visual_root := root.get_node_or_null("Визуальные элементы") as Node2D
	if visual_root == null:
		return root
	var bounds := _get_visual_bounds_in_root(root, visual_root)
	var pivot := Node2D.new()
	pivot.name = "ObjectFallPivot"
	root.add_child(pivot)
	root.move_child(pivot, 0)
	pivot.position = bounds.get("bottom_center", visual_root.position + Vector2(0.0, 32.0))
	visual_root.reparent(pivot, true)
	root.set_meta("object_builder_fall_pivot", pivot)
	return pivot


func _get_visual_bounds_in_root(root: Node2D, visual_root: Node2D) -> Dictionary:
	var minimum_x := INF
	var maximum_x := -INF
	var maximum_y := -INF
	for candidate in visual_root.find_children("*", "Sprite2D", true, false):
		var sprite := candidate as Sprite2D
		if sprite == null or sprite.texture == null or not sprite.visible:
			continue
		var rect := sprite.get_rect()
		for corner in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]:
			var local_point := root.to_local(sprite.to_global(corner))
			minimum_x = minf(minimum_x, local_point.x)
			maximum_x = maxf(maximum_x, local_point.x)
			maximum_y = maxf(maximum_y, local_point.y)
	for candidate in visual_root.find_children("*", "AnimatedSprite2D", true, false):
		var animated := candidate as AnimatedSprite2D
		if animated == null or animated.sprite_frames == null:
			continue
		if not animated.sprite_frames.has_animation(animated.animation):
			continue
		var frame_count := animated.sprite_frames.get_frame_count(animated.animation)
		if frame_count <= 0:
			continue
		var texture := animated.sprite_frames.get_frame_texture(
			animated.animation,
			clampi(animated.frame, 0, frame_count - 1)
		)
		if texture == null:
			continue
		var size := texture.get_size()
		var origin := animated.offset - (size * 0.5 if animated.centered else Vector2.ZERO)
		var rect := Rect2(origin, size)
		for corner in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]:
			var local_point := root.to_local(animated.to_global(corner))
			minimum_x = minf(minimum_x, local_point.x)
			maximum_x = maxf(maximum_x, local_point.x)
			maximum_y = maxf(maximum_y, local_point.y)
	if minimum_x == INF or maximum_x == -INF or maximum_y == -INF:
		return {"bottom_center": visual_root.position + Vector2(0.0, 32.0)}
	return {"bottom_center": Vector2((minimum_x + maximum_x) * 0.5, maximum_y)}


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
