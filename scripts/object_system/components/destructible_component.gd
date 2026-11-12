@tool
extends ObjectComponent
class_name DestructibleComponent

signal destroyed(source: Node)
signal repaired

@export var destroy_on_zero_health: bool = true
@export var disable_collision_on_destroy: bool = true
@export var disable_damage_on_destroy: bool = true
@export var hide_on_destroy: bool = true
@export var remove_on_destroy: bool = false
@export_range(0.0, 300.0, 0.01, "or_greater") var destroy_delay: float = 0.0
@export var restore_health_on_repair: bool = true

var _is_destroyed := false
var _generation := 0
var _health: HealthComponent
var _damageable: DamageableComponent
var _collision_object_snapshots: Array[Dictionary] = []
var _collision_shape_snapshots: Array[Dictionary] = []
var _damageable_previous_state := true
var _has_damageable_snapshot := false
var _visibility_previous_state := true
var _has_visibility_snapshot := false


func _ready() -> void:
	_bind_health()
	if destroy_on_zero_health and _health != null and not _health.is_alive():
		destroy()


func _on_configured() -> void:
	destroy_on_zero_health = _read_bool("destroy_on_zero_health", destroy_on_zero_health)
	disable_collision_on_destroy = _read_bool("disable_collision_on_destroy", disable_collision_on_destroy)
	disable_damage_on_destroy = _read_bool("disable_damage_on_destroy", disable_damage_on_destroy)
	hide_on_destroy = _read_bool("hide_on_destroy", hide_on_destroy)
	remove_on_destroy = _read_bool("remove_on_destroy", remove_on_destroy)
	destroy_delay = maxf(0.0, _read_number("destroy_delay", destroy_delay))
	restore_health_on_repair = _read_bool("restore_health_on_repair", restore_health_on_repair)


func destroy(source: Node = null) -> bool:
	if _is_destroyed:
		return false
	var target := get_object_root()
	if target == null:
		return false

	_is_destroyed = true
	_generation += 1
	_capture_state(target)

	if disable_collision_on_destroy:
		_disable_collision()
	if disable_damage_on_destroy and _damageable != null:
		_damageable_previous_state = _damageable.can_receive_damage
		_has_damageable_snapshot = true
		_damageable.set_damage_enabled(false)

	target.set_meta("object_destroyed", true)
	destroyed.emit(source)

	# Tree-like objects may fall first. Their regular visuals and embedded remains
	# are switched only when the animation is complete, preventing an instant pop.
	var active_hit_tween: Variant = target.get_meta("object_builder_hit_tween", null)
	if active_hit_tween is Tween:
		(active_hit_tween as Tween).kill()
	target.remove_meta("object_builder_hit_tween")

	var fall_component := ObjectFactory.get_component(target, "falls_when_destroyed")
	if fall_component != null and fall_component.has_method("play_fall_animation"):
		var fall_value: Variant = fall_component.call("play_fall_animation", target)
		if fall_value is Tween:
			(fall_value as Tween).finished.connect(
				_finish_destroy_sequence.bind(target, _generation),
				CONNECT_ONE_SHOT
			)
			return true

	_finish_destroy_sequence(target, _generation)
	return true


func _finish_destroy_sequence(target: Node, generation: int) -> void:
	if generation != _generation or not _is_destroyed:
		return
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return

	var fall_component := ObjectFactory.get_component(target, "falls_when_destroyed")
	var remains_component := ObjectFactory.get_component(target, "leaves_remains")
	var has_embedded_remains := _reveal_embedded_remains(target)
	if not has_embedded_remains and remains_component != null and remains_component.has_method("reveal_embedded_remains"):
		var revealed_value: Variant = remains_component.call("reveal_embedded_remains", target)
		has_embedded_remains = revealed_value is Array and not revealed_value.is_empty()

	var spawned_remains: Node
	if not has_embedded_remains and remains_component != null and remains_component.has_method("spawn_remains"):
		var spawn_parent := target.get_parent()
		if spawn_parent == null and target.get_tree() != null:
			spawn_parent = target.get_tree().current_scene
		if spawn_parent != null:
			var remains_origin := Vector2.ZERO
			if target is Node2D:
				remains_origin = (target as Node2D).global_position
			var remains_value: Variant = remains_component.call("spawn_remains", spawn_parent, remains_origin)
			spawned_remains = remains_value as Node

	# Embedded remains replace the source visuals in-place. A separate remains
	# scene replaces them beside the source, while a tree without either gets a
	# procedural stump. Never leave the intact source sprite visible beside them.
	if not has_embedded_remains:
		if fall_component != null and spawned_remains == null:
			if _spawn_procedural_stump(target):
				_hide_destroyed_sprite_nodes(target)
			else:
				_hide_destroyed_visuals(target)
		elif hide_on_destroy:
			_hide_destroyed_visuals(target)

	if remove_on_destroy and not has_embedded_remains:
		_schedule_removal(target)


func _spawn_procedural_stump(target: Node) -> bool:
	if not target is Node2D:
		return false
	var existing := target.find_child("ProceduralStump", true, false) as Sprite2D
	if existing != null:
		existing.visible = true
		return true

	var minimum_x := INF
	var maximum_x := -INF
	var maximum_y := -INF
	for candidate in target.find_children("*", "Sprite2D", true, false):
		var sprite := candidate as Sprite2D
		if sprite == null or sprite.name == "ProceduralStump" or sprite.texture == null:
			continue
		var rect := sprite.get_rect()
		for corner in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]:
			var local_point := (target as Node2D).to_local(sprite.to_global(corner))
			minimum_x = minf(minimum_x, local_point.x)
			maximum_x = maxf(maximum_x, local_point.x)
			maximum_y = maxf(maximum_y, local_point.y)
	if maximum_y == -INF:
		minimum_x = -10.0
		maximum_x = 10.0
		maximum_y = 0.0
	var bottom_center := Vector2((minimum_x + maximum_x) * 0.5, maximum_y)

	# A small nearest-filtered stump texture keeps the fallback consistent with
	# the project's pixel-art rendering and remains editable as a normal Sprite2D.
	var image := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var bark := Color("#805238")
	var bark_shadow := bark.darkened(0.32)
	var bark_light := bark.lightened(0.18)
	for y in range(6, 16):
		for x in range(7, 17):
			image.set_pixel(x, y, bark_shadow if x == 7 or x == 16 else bark)
	for y in range(1, 9):
		for x in range(3, 21):
			var dx := (float(x) - 11.5) / 8.5
			var dy := (float(y) - 4.5) / 3.8
			var radius := dx * dx + dy * dy
			if radius <= 1.0:
				image.set_pixel(x, y, bark_shadow if radius > 0.78 else bark_light)
	for y in range(2, 8):
		for x in range(5, 19):
			var radius := Vector2((float(x) - 11.5) / 6.5, (float(y) - 4.5) / 2.6).length()
			if absf(radius - 0.55) < 0.12:
				image.set_pixel(x, y, bark_shadow)

	var stump := Sprite2D.new()
	stump.name = "ProceduralStump"
	stump.texture = ImageTexture.create_from_image(image)
	stump.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stump.centered = true
	stump.position = bottom_center - Vector2(0.0, 8.0)
	stump.z_index = 2
	stump.set_meta("object_builder_procedural_stump", true)
	target.add_child(stump)
	stump.owner = target
	return true


func _hide_destroyed_sprite_nodes(target: Node) -> void:
	for candidate in target.find_children("*", "CanvasItem", true, false):
		if not candidate is CanvasItem:
			continue
		var canvas_item := candidate as CanvasItem
		if bool(canvas_item.get_meta("object_builder_procedural_stump", false)):
			continue
		if not (canvas_item is Sprite2D or canvas_item is AnimatedSprite2D):
			continue
		if not canvas_item.has_meta("object_builder_remains_previous_visible"):
			canvas_item.set_meta("object_builder_remains_previous_visible", canvas_item.visible)
		canvas_item.visible = false


func _hide_destroyed_visuals(target: Node) -> void:
	if target is CanvasItem:
		_visibility_previous_state = (target as CanvasItem).visible
		_has_visibility_snapshot = true
		(target as CanvasItem).visible = false
		return
	for candidate in target.find_children("*", "CanvasItem", true, false):
		if candidate is CanvasItem:
			var canvas_item := candidate as CanvasItem
			if (
				bool(canvas_item.get_meta("object_builder_sprite", false))
				or bool(canvas_item.get_meta("object_builder_sprite_layer", false))
				or canvas_item is Sprite2D
				or canvas_item is AnimatedSprite2D
			):
				if not canvas_item.has_meta("object_builder_remains_previous_visible"):
					canvas_item.set_meta("object_builder_remains_previous_visible", canvas_item.visible)
				canvas_item.visible = false


func repair() -> bool:
	if not _is_destroyed:
		return false

	_generation += 1
	_is_destroyed = false
	var target := get_object_root()
	if target != null:
		var fall_pivot: Variant = target.get_meta("object_builder_fall_pivot", null)
		if fall_pivot is Node2D and is_instance_valid(fall_pivot):
			var pivot := fall_pivot as Node2D
			pivot.rotation = float(pivot.get_meta("object_builder_hit_base_rotation", 0.0))
		if target is Node2D and target.has_meta("object_builder_fall_base_rotation"):
			target.remove_meta("object_builder_fall_base_rotation")
		target.remove_meta("object_builder_destruction_processed")
		_restore_embedded_remains(target)
		if disable_collision_on_destroy:
			_restore_collision()
		if _has_damageable_snapshot and is_instance_valid(_damageable):
			_damageable.set_damage_enabled(_damageable_previous_state)
		if _has_visibility_snapshot and target is CanvasItem:
			(target as CanvasItem).visible = _visibility_previous_state
		target.set_meta("object_destroyed", false)

	if restore_health_on_repair:
		if _health == null and target != null:
			_health = ObjectFactory.get_component(target, "health") as HealthComponent
		if _health != null:
			_health.reset_health()

	_clear_snapshots()
	repaired.emit()
	return true


func is_destroyed() -> bool:
	return _is_destroyed


func _bind_health() -> void:
	var target := get_object_root()
	if target == null:
		return
	_health = ObjectFactory.get_component(target, "health") as HealthComponent
	_damageable = ObjectFactory.get_component(target, "damageable") as DamageableComponent
	if _health != null:
		var callback := Callable(self, "_on_health_died")
		if not _health.died.is_connected(callback):
			_health.died.connect(callback)


func _on_health_died() -> void:
	if destroy_on_zero_health:
		destroy()


## Reveals Builder-generated remain layers without requiring an additional mechanic component.
## The parent object's existing managed visuals are hidden only when embedded layers exist.
func _reveal_embedded_remains(target: Node) -> bool:
	if target == null:
		return false
	var embedded: Array[CanvasItem] = []
	var managed_visuals: Array[CanvasItem] = []
	for candidate in target.find_children("*", "CanvasItem", true, false):
		if candidate.owner != target or not candidate is CanvasItem:
			continue
		var canvas_item := candidate as CanvasItem
		if bool(canvas_item.get_meta("object_builder_procedural_stump", false)):
			canvas_item.visible = false
		elif bool(canvas_item.get_meta("object_builder_embedded_remains", false)):
			embedded.append(canvas_item)
		elif (
			bool(canvas_item.get_meta("object_builder_sprite", false))
			or bool(canvas_item.get_meta("object_builder_sprite_layer", false))
			or bool(canvas_item.get_meta("object_builder_animated_sprite", false))
		):
			managed_visuals.append(canvas_item)
	if embedded.is_empty():
		return false
	for canvas_item in managed_visuals:
		if not canvas_item.has_meta("object_builder_remains_previous_visible"):
			canvas_item.set_meta("object_builder_remains_previous_visible", canvas_item.visible)
		canvas_item.visible = false
	for canvas_item in embedded:
		canvas_item.visible = true
	return true


func _restore_embedded_remains(target: Node) -> void:
	if target == null:
		return
	for candidate in target.find_children("*", "CanvasItem", true, false):
		if not candidate is CanvasItem:
			continue
		var canvas_item := candidate as CanvasItem
		# Runtime-created procedural remains do not have a PackedScene owner.
		# They must still be found and hidden when the object is repaired.
		if bool(canvas_item.get_meta("object_builder_procedural_stump", false)):
			canvas_item.visible = false
			continue
		# Restore every visual hidden by this component, including runtime children
		# that have no PackedScene owner after being attached to an instance.
		if canvas_item.has_meta("object_builder_remains_previous_visible"):
			canvas_item.visible = bool(canvas_item.get_meta("object_builder_remains_previous_visible", true))
			canvas_item.remove_meta("object_builder_remains_previous_visible")
			continue
		if candidate.owner != target:
			continue
		if bool(canvas_item.get_meta("object_builder_embedded_remains", false)):
			canvas_item.visible = false


func _capture_state(target: Node) -> void:
	_clear_snapshots()
	if disable_collision_on_destroy:
		_capture_collision_nodes(target)
	if hide_on_destroy and target is CanvasItem:
		_visibility_previous_state = (target as CanvasItem).visible
		_has_visibility_snapshot = true


func _capture_collision_nodes(node: Node) -> void:
	if node is CollisionObject2D:
		var collision_object := node as CollisionObject2D
		_collision_object_snapshots.append({
			"node": collision_object,
			"collision_layer": collision_object.collision_layer,
			"collision_mask": collision_object.collision_mask
		})
	if node is CollisionShape2D:
		var collision_shape := node as CollisionShape2D
		_collision_shape_snapshots.append({
			"node": collision_shape,
			"disabled": collision_shape.disabled
		})
	elif node is CollisionPolygon2D:
		var collision_polygon := node as CollisionPolygon2D
		_collision_shape_snapshots.append({
			"node": collision_polygon,
			"disabled": collision_polygon.disabled
		})
	for child in node.get_children():
		if child is Node:
			_capture_collision_nodes(child as Node)


func _disable_collision() -> void:
	for snapshot in _collision_object_snapshots:
		var node := snapshot.get("node") as CollisionObject2D
		if is_instance_valid(node):
			node.collision_layer = 0
			node.collision_mask = 0
	for snapshot in _collision_shape_snapshots:
		var node: Node = snapshot.get("node") as Node
		if is_instance_valid(node):
			node.set("disabled", true)


func _restore_collision() -> void:
	for snapshot in _collision_object_snapshots:
		var node := snapshot.get("node") as CollisionObject2D
		if is_instance_valid(node):
			node.collision_layer = int(snapshot.get("collision_layer", 1))
			node.collision_mask = int(snapshot.get("collision_mask", 1))
	for snapshot in _collision_shape_snapshots:
		var node: Node = snapshot.get("node") as Node
		if is_instance_valid(node):
			node.set("disabled", bool(snapshot.get("disabled", false)))


func _schedule_removal(target: Node) -> void:
	if destroy_delay <= 0.0 or not target.is_inside_tree():
		target.queue_free()
		return
	var timer := get_tree().create_timer(destroy_delay)
	timer.timeout.connect(_remove_destroyed_owner.bind(_generation))


func _remove_destroyed_owner(generation: int) -> void:
	if generation != _generation or not _is_destroyed:
		return
	var target := get_object_root()
	if target != null and is_instance_valid(target):
		target.queue_free()


func _clear_snapshots() -> void:
	_collision_object_snapshots.clear()
	_collision_shape_snapshots.clear()
	_has_damageable_snapshot = false
	_has_visibility_snapshot = false


func _read_number(key: String, fallback: float) -> float:
	var value: Variant = settings.get(key, fallback)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return number


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = settings.get(key, fallback)
	return value if typeof(value) == TYPE_BOOL else fallback
