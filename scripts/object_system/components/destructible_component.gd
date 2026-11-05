@tool
extends ObjectComponent
class_name DestructibleComponent

signal destroyed(source: Node)
signal repaired

@export var destroy_on_zero_health: bool = true
@export var disable_collision_on_destroy: bool = true
@export var disable_damage_on_destroy: bool = true
@export var hide_on_destroy: bool = false
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
	if hide_on_destroy and target is CanvasItem:
		_visibility_previous_state = (target as CanvasItem).visible
		_has_visibility_snapshot = true
		(target as CanvasItem).visible = false

	target.set_meta("object_destroyed", true)
	destroyed.emit(source)

	if remove_on_destroy:
		_schedule_removal(target)
	return true


func repair() -> bool:
	if not _is_destroyed:
		return false

	_generation += 1
	_is_destroyed = false
	var target := get_object_root()
	if target != null:
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
