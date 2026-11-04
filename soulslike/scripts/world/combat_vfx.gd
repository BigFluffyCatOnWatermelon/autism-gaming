extends Node3D
## Small, readable 3D combat effects built from emissive meshes and short tweens.

func _ready() -> void:
	add_to_group("combat_vfx")

func _material(color: Color, glow: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = 2.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _spawn_ring(at: Vector3, color: Color, radius: float = 0.45, vertical: bool = false) -> void:
	var effect := Node3D.new()
	effect.position = at
	add_child(effect)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.72
	mesh.outer_radius = radius
	mesh.rings = 8
	mesh.ring_segments = 20
	ring.mesh = mesh
	ring.material_override = _material(Color(color.r, color.g, color.b, 0.9), color)
	if vertical:
		ring.rotation.x = PI * 0.5
	effect.add_child(ring)
	effect.scale = Vector3.ONE * 0.35
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 1.75, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "rotation:y", TAU * 0.65, 0.28)
	tween.tween_callback(effect.queue_free)

func spawn_hit(at: Vector3, critical: bool = false, shielded: bool = false) -> void:
	var color := Color(0.25, 0.72, 1.0, 1.0) if shielded else (Color(1.0, 0.55, 0.12, 1.0) if critical else Color(0.9, 0.82, 0.68, 1.0))
	_spawn_ring(at, color, 0.36 if not critical else 0.55)
	_spawn_sparks(at, color, 5 if not critical else 9, 1.2 if not critical else 2.0)

func spawn_parry(at: Vector3) -> void:
	var color := Color(0.35, 0.8, 1.0, 1.0)
	_spawn_ring(at, color, 0.55, true)
	_spawn_sparks(at, color, 12, 2.2)

func spawn_dodge(at: Vector3, direction: Vector3) -> void:
	var color := Color(0.46, 0.58, 0.72, 1.0)
	_spawn_ring(at + Vector3.UP * 0.08, color, 0.58)
	var offset := direction.normalized() * -0.85
	_spawn_ring(at + offset + Vector3.UP * 0.05, color, 0.42)

func spawn_heal(at: Vector3) -> void:
	var color := Color(0.42, 0.95, 0.44, 1.0)
	_spawn_ring(at + Vector3.UP * 0.65, color, 0.42, true)
	_spawn_sparks(at + Vector3.UP * 0.6, color, 10, 1.4)

func spawn_death(at: Vector3) -> void:
	var color := Color(0.85, 0.12, 0.055, 1.0)
	_spawn_ring(at + Vector3.UP * 0.1, color, 0.7, true)
	_spawn_sparks(at + Vector3.UP, color, 16, 2.7)

func _spawn_sparks(at: Vector3, color: Color, count: int, speed: float) -> void:
	for index in range(count):
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.035 if count < 10 else 0.045
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 6
		mesh.rings = 4
		spark.mesh = mesh
		spark.material_override = _material(color, color)
		spark.position = at
		add_child(spark)
		var angle := TAU * float(index) / float(count) + randf_range(-0.18, 0.18)
		var direction := Vector3(cos(angle), randf_range(-0.35, 0.85), sin(angle)).normalized()
		var distance := randf_range(0.35, 0.9) * speed
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", at + direction * distance, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.34).set_trans(Tween.TRANS_CUBIC)
		tween.chain().tween_callback(spark.queue_free)
