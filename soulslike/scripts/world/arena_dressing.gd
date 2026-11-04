extends Node3D
## Deterministic low-poly set dressing for the Ashen Outskirts arena.

var _rng := RandomNumberGenerator.new()
var _torches: Array[Dictionary] = []
var _clock := 0.0
var _stone: StandardMaterial3D
var _stone_light: StandardMaterial3D
var _dead_wood: StandardMaterial3D
var _fire: StandardMaterial3D
var _rubble_mesh: BoxMesh
var _column_mesh: CylinderMesh

func _ready() -> void:
	_rng.seed = 482731
	_stone = _mat(Color(0.17, 0.18, 0.19), 0.24, 0.96)
	_stone_light = _mat(Color(0.25, 0.25, 0.24), 0.18, 0.98)
	_dead_wood = _mat(Color(0.09, 0.065, 0.048), 0.05, 1.0)
	_fire = _mat(Color(1.0, 0.28, 0.045), 0.0, 0.28, Color(1.0, 0.12, 0.015, 1.0))
	_column_mesh = CylinderMesh.new()
	_column_mesh.top_radius = 0.42
	_column_mesh.bottom_radius = 0.54
	_column_mesh.height = 3.2
	_column_mesh.radial_segments = 8
	_rubble_mesh = BoxMesh.new()
	_rubble_mesh.size = Vector3(1, 1, 1)
	_build_ruins()
	_build_graves()
	_build_rubble()
	_build_dead_trees()
	_build_torches()

func _process(delta: float) -> void:
	_clock += delta
	for entry in _torches:
		var light := entry["light"] as OmniLight3D
		var flame := entry["flame"] as MeshInstance3D
		var phase := float(entry["phase"])
		light.light_energy = 1.35 + sin(_clock * 8.5 + phase) * 0.28 + sin(_clock * 17.0 + phase) * 0.12
		flame.scale = Vector3(0.24, 0.54 + sin(_clock * 11.0 + phase) * 0.09, 0.24)

func _mat(color: Color, metallic: float, roughness: float, glow: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if glow.a > 0.0:
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = 2.6
	return material

func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, position_3d: Vector3, size: Vector3 = Vector3.ONE, rotation_3d: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	item.position = position_3d
	item.scale = size
	item.rotation = rotation_3d
	parent.add_child(item)
	return item

func _block(parent: Node3D, at: Vector3, size: Vector3, material: Material, angle: float = 0.0) -> void:
	_add_mesh(parent, _rubble_mesh, material, at, size, Vector3(0, angle, _rng.randf_range(-0.08, 0.08)))

func _build_ruins() -> void:
	for side in [-1.0, 1.0]:
		for z in [-15.0, -7.0, 2.0, 12.0]:
			var root := Node3D.new()
			root.position = Vector3(side * 14.5, 0, z)
			add_child(root)
			_add_mesh(root, _column_mesh, _stone, Vector3.ZERO, Vector3.ONE)
			var base := CylinderMesh.new()
			base.top_radius = 0.68
			base.bottom_radius = 0.72
			base.height = 0.28
			base.radial_segments = 8
			_add_mesh(root, base, _stone_light, Vector3(0, -1.45, 0))
			var cap := CylinderMesh.new()
			cap.top_radius = 0.6
			cap.bottom_radius = 0.6
			cap.height = 0.18
			cap.radial_segments = 8
			_add_mesh(root, cap, _stone_light, Vector3(0, 1.57, 0))
			if int(absf(z)) % 2 == 0:
				_block(root, Vector3(side * -0.58, 1.08, 0.0), Vector3(1.2, 0.35, 0.55), _stone, 0.28)
	# Broken arch fragments frame the distant boss approach.
	for side in [-1.0, 1.0]:
		var support := Node3D.new()
		support.position = Vector3(side * 9.2, 0, -19.0)
		add_child(support)
		_add_mesh(support, _column_mesh, _stone, Vector3.ZERO, Vector3(0.8, 1.0, 0.8))
		_block(support, Vector3(-side * 0.65, 2.8, 0), Vector3(2.2, 0.4, 0.7), _stone_light, side * 0.22)

func _build_graves() -> void:
	var positions := [Vector3(-18, 0, -5), Vector3(18, 0, -7), Vector3(-18, 0, 8), Vector3(17, 0, 14), Vector3(-10, 0, -20), Vector3(11, 0, -21)]
	for index in range(positions.size()):
		var grave := Node3D.new()
		grave.position = positions[index]
		grave.rotation.y = _rng.randf_range(-0.5, 0.5)
		add_child(grave)
		_block(grave, Vector3(0, 0.12, 0), Vector3(1.15, 0.24, 0.72), _stone_light)
		_block(grave, Vector3(0, 0.78, 0.12), Vector3(0.78, 1.12, 0.22), _stone, _rng.randf_range(-0.12, 0.12))
		_block(grave, Vector3(0, 1.48, 0.12), Vector3(0.92, 0.16, 0.24), _stone_light)
		_block(grave, Vector3(0, 1.82, 0.12), Vector3(0.16, 0.58, 0.22), _stone_light)

func _build_rubble() -> void:
	for center in [Vector3(-11, 0, -11), Vector3(11, 0, -12), Vector3(-15, 0, 2), Vector3(15, 0, 4), Vector3(-5, 0, -21), Vector3(7, 0, -21), Vector3(-12, 0, 18), Vector3(12, 0, 18)]:
		for index in range(9):
			var at := center + Vector3(_rng.randf_range(-1.35, 1.35), _rng.randf_range(0.08, 0.35), _rng.randf_range(-1.0, 1.0))
			var extent := Vector3(_rng.randf_range(0.3, 0.9), _rng.randf_range(0.2, 0.58), _rng.randf_range(0.3, 0.8))
			_block(self, at, extent, _stone if index % 2 == 0 else _stone_light, _rng.randf_range(-0.8, 0.8))

func _build_dead_trees() -> void:
	for at in [Vector3(-20, 0, -14), Vector3(20, 0, -17), Vector3(-21, 0, 14), Vector3(21, 0, 17)]:
		var tree := Node3D.new()
		tree.position = at
		tree.rotation.y = _rng.randf_range(-0.8, 0.8)
		add_child(tree)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.12
		trunk.bottom_radius = 0.24
		trunk.height = 3.5
		_add_mesh(tree, trunk, _dead_wood, Vector3(0, 1.65, 0), Vector3.ONE, Vector3(0, 0, _rng.randf_range(-0.18, 0.18)))
		for branch in range(3):
			var limb := CylinderMesh.new()
			limb.top_radius = 0.045
			limb.bottom_radius = 0.1
			limb.height = 1.8
			var direction := -1.0 if branch % 2 == 0 else 1.0
			_add_mesh(tree, limb, _dead_wood, Vector3(direction * 0.42, 2.45 - branch * 0.34, 0), Vector3.ONE, Vector3(0, 0, direction * 0.72))

func _build_torches() -> void:
	for at in [Vector3(-11.0, 0, -4.0), Vector3(11.0, 0, -4.0), Vector3(-13.0, 0, -18.0), Vector3(13.0, 0, -18.0)]:
		var torch := Node3D.new()
		torch.position = at
		add_child(torch)
		var post := CylinderMesh.new()
		post.top_radius = 0.075
		post.bottom_radius = 0.12
		post.height = 2.25
		_add_mesh(torch, post, _dead_wood, Vector3(0, 1.05, 0))
		var brazier := SphereMesh.new()
		brazier.radius = 0.2
		brazier.height = 0.3
		_add_mesh(torch, brazier, _stone_light, Vector3(0, 2.16, 0), Vector3(1.2, 0.7, 1.2))
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.22
		flame_mesh.height = 0.72
		var flame := _add_mesh(torch, flame_mesh, _fire, Vector3(0, 2.5, 0), Vector3(0.24, 0.54, 0.24))
		var light := OmniLight3D.new()
		light.position = Vector3(0, 2.55, 0)
		light.light_color = Color(1.0, 0.29, 0.11)
		light.light_energy = 1.4
		light.omni_range = 9.0
		torch.add_child(light)
		_torches.append({"flame": flame, "light": light, "phase": _rng.randf_range(0.0, TAU)})
