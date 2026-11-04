extends Node3D
## Runtime low-poly character rig with procedural locomotion and combat poses.

@export_enum("player", "hollow", "guard", "warden") var archetype := "player"

var _elapsed := 0.0
var _attack_pose_time := 0.0
var _attack_is_heavy := false
var _hit_flash_time := 0.0
var _death_tween: Tween
var _torso: MeshInstance3D
var _base_torso_material: StandardMaterial3D
var _right_arm: Node3D
var _left_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _cape: MeshInstance3D
var _sword: Node3D
var _cleaver: Node3D
var _club: Node3D
var _shield: Node3D
var _eyes: StandardMaterial3D
var _base_scale := Vector3.ONE

func _ready() -> void:
	_build_rig()
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	_attack_pose_time = maxf(0.0, _attack_pose_time - delta)
	_hit_flash_time = maxf(0.0, _hit_flash_time - delta)
	var actor := get_parent() as CharacterBody3D
	if actor == null:
		return
	if int(actor.get("state")) == 6:
		return
	var horizontal_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var moving := horizontal_speed > 0.32
	var run_blend := clampf(horizontal_speed / 5.8, 0.0, 1.0)
	var cycle_speed := lerpf(6.5, 11.5, run_blend)
	var gait := sin(_elapsed * cycle_speed) * run_blend
	var bob := absf(cos(_elapsed * cycle_speed)) * 0.045 * run_blend
	var breathing := sin(_elapsed * 2.1) * 0.018
	position.y = bob + breathing
	if _torso != null:
		_torso.rotation.x = sin(_elapsed * cycle_speed * 2.0) * 0.035 * run_blend
		_torso.rotation.z = sin(_elapsed * 1.4) * 0.012
	_left_leg.rotation.x = gait * 0.72
	_right_leg.rotation.x = -gait * 0.72
	var actor_state := int(actor.get("state"))
	var is_player := actor.has_method("_request_attack")
	var right_pose := 0.0
	var left_pose := 0.0
	var torso_lean := 0.0
	if is_player:
		match actor_state:
			1: # attack wind-up
				right_pose = -1.22 if not _attack_is_heavy else -1.55
				torso_lean = -0.10
			2: # attack active / follow-through
				right_pose = 1.05 if not _attack_is_heavy else 1.30
				torso_lean = 0.12
			3: # recovery
				right_pose = 0.22
			4: # dodge
				torso_lean = 0.48
				right_pose = -0.65
				left_pose = -0.4
			5: # stagger
				torso_lean = -0.32
				right_pose = 0.9
				left_pose = 0.65
		if bool(actor.get("blocking")):
			left_pose = -1.0
	else:
		match actor_state:
			2: # readable enemy wind-up
				right_pose = -1.38
				left_pose = -0.65
				torso_lean = -0.08
			5: # stagger
				right_pose = 0.8
				left_pose = 0.6
				torso_lean = -0.28
		if _attack_pose_time > 0.0:
			var attack_weight := clampf(_attack_pose_time / 0.26, 0.0, 1.0)
			right_pose = lerpf(0.8, -0.95 if not _attack_is_heavy else -1.4, attack_weight)
			torso_lean = 0.16 * attack_weight
	if moving and actor_state == 0:
		right_pose += sin(_elapsed * cycle_speed) * 0.24 * run_blend
		left_pose -= sin(_elapsed * cycle_speed) * 0.2 * run_blend
		torso_lean += run_blend * 0.025
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, right_pose, minf(1.0, delta * 13.0))
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, left_pose, minf(1.0, delta * 13.0))
	rotation.x = lerpf(rotation.x, torso_lean, minf(1.0, delta * 10.0))
	if _cape != null:
		_cape.rotation.x = -0.12 + sin(_elapsed * 3.0) * 0.055 + run_blend * 0.12
		_cape.rotation.z = sin(_elapsed * 2.2) * 0.035
	_update_weapon(actor)

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.72, glow: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if glow.a > 0.0 or glow.r > 0.0 or glow.g > 0.0 or glow.b > 0.0:
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = 1.6
	return material

func _mesh(parent: Node3D, node_name: String, mesh: Mesh, material: Material, at: Vector3, size: Vector3 = Vector3.ONE, angles: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = size
	instance.rotation = angles
	parent.add_child(instance)
	return instance

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	return mesh

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _build_rig() -> void:
	var armor := _mat(Color(0.19, 0.23, 0.29), 0.78, 0.38)
	var dark_armor := _mat(Color(0.075, 0.09, 0.12), 0.72, 0.48)
	var cloth := _mat(Color(0.22, 0.075, 0.085), 0.05, 0.94)
	var trim := _mat(Color(0.62, 0.43, 0.19), 0.82, 0.3)
	var leather := _mat(Color(0.105, 0.062, 0.045), 0.08, 0.92)
	var skin := _mat(Color(0.35, 0.31, 0.27), 0.0, 0.96)
	var blade := _mat(Color(0.58, 0.66, 0.72), 0.91, 0.24)
	var eye_glow := Color(1.0, 0.18, 0.045, 1.0)
	var eye_material := _mat(Color(0.9, 0.19, 0.055), 0.15, 0.2, eye_glow)
	var torso_color := armor
	if archetype == "hollow":
		armor = _mat(Color(0.16, 0.17, 0.18), 0.22, 0.9)
		dark_armor = _mat(Color(0.075, 0.07, 0.065), 0.1, 0.98)
		cloth = _mat(Color(0.20, 0.13, 0.085), 0.0, 1.0)
		trim = _mat(Color(0.28, 0.2, 0.13), 0.18, 0.9)
		skin = _mat(Color(0.24, 0.23, 0.21), 0.0, 1.0)
		eye_glow = Color(0.78, 0.08, 0.025, 1.0)
		eye_material = _mat(eye_glow, 0.0, 0.3, eye_glow)
	elif archetype == "guard":
		armor = _mat(Color(0.12, 0.17, 0.22), 0.84, 0.34)
		dark_armor = _mat(Color(0.045, 0.06, 0.08), 0.75, 0.45)
		cloth = _mat(Color(0.105, 0.14, 0.18), 0.05, 0.92)
	elif archetype == "warden":
		armor = _mat(Color(0.095, 0.085, 0.09), 0.9, 0.3)
		dark_armor = _mat(Color(0.025, 0.022, 0.03), 0.8, 0.42)
		cloth = _mat(Color(0.22, 0.025, 0.035), 0.08, 0.86)
		trim = _mat(Color(0.56, 0.27, 0.075), 0.9, 0.25)
		blade = _mat(Color(0.36, 0.42, 0.49), 0.94, 0.2)
		eye_glow = Color(1.0, 0.025, 0.008, 1.0)
		eye_material = _mat(eye_glow, 0.1, 0.16, eye_glow)
		torso_color = armor
	else:
		torso_color = armor
	_eyes = eye_material

	# Layered cuirass, collar, belt and hanging tabard.
	_torso = _mesh(self, "Torso", _capsule(0.31 if archetype != "warden" else 0.46, 1.08 if archetype != "warden" else 1.38), armor, Vector3(0, 1.18 if archetype != "warden" else 1.48, 0), Vector3(1.0, 1.0, 0.78))
	_mesh(self, "Chestplate", _box(Vector3(0.56 if archetype != "warden" else 0.82, 0.57 if archetype != "warden" else 0.76, 0.24)), dark_armor, Vector3(0, 1.40 if archetype != "warden" else 1.76, -0.225))
	_mesh(self, "ChestTrim", _box(Vector3(0.46 if archetype != "warden" else 0.66, 0.035, 0.035)), trim, Vector3(0, 1.19 if archetype != "warden" else 1.45, -0.365))
	_mesh(self, "ChestSigil", _sphere(0.075 if archetype != "warden" else 0.12), eye_material, Vector3(0, 1.42 if archetype != "warden" else 1.82, -0.38))
	_mesh(self, "Belt", _box(Vector3(0.62 if archetype != "warden" else 0.86, 0.12, 0.35)), leather, Vector3(0, 0.89 if archetype != "warden" else 1.12, 0))
	_mesh(self, "Buckle", _box(Vector3(0.12, 0.14, 0.04)), trim, Vector3(0, 0.89 if archetype != "warden" else 1.12, -0.195))
	_base_torso_material = _torso.material_override as StandardMaterial3D
	_cape = _mesh(self, "Cloak", _box(Vector3(0.62 if archetype != "warden" else 0.96, 0.95 if archetype != "warden" else 1.2, 0.075)), cloth, Vector3(0, 1.15 if archetype != "warden" else 1.50, 0.22), Vector3.ONE, Vector3(-0.12, 0, 0))
	if archetype == "warden":
		_mesh(self, "ShoulderMantle", _sphere(0.45), dark_armor, Vector3(0, 2.02, 0))
		_mesh(self, "MantleTrim", _box(Vector3(0.96, 0.08, 0.4)), trim, Vector3(0, 2.10, -0.02))

	# Head and distinctive helmet silhouette.
	var head_y := 1.88 if archetype != "warden" else 2.42
	_mesh(self, "Neck", _capsule(0.105, 0.25), leather, Vector3(0, head_y - 0.21, 0))
	_mesh(self, "Head", _sphere(0.22 if archetype != "warden" else 0.34), skin if archetype == "hollow" else dark_armor, Vector3(0, head_y, 0))
	_mesh(self, "Helmet", _sphere(0.255 if archetype != "warden" else 0.38), armor, Vector3(0, head_y + 0.075, 0), Vector3(1.0, 0.84, 0.94))
	_mesh(self, "Visor", _box(Vector3(0.34 if archetype != "warden" else 0.52, 0.09, 0.09)), dark_armor, Vector3(0, head_y - 0.015, -0.205))
	for side in [-1.0, 1.0]:
		_mesh(self, "Eye_%s" % side, _sphere(0.035 if archetype != "warden" else 0.055), eye_material, Vector3(side * 0.09, head_y + 0.005, -0.254))
	if archetype == "warden":
		for side in [-1.0, 1.0]:
			_mesh(self, "CrownHorn_%s" % side, _capsule(0.07, 0.75), trim, Vector3(side * 0.31, 2.86, 0), Vector3(1.0, 0.72, 0.9), Vector3(0, 0, side * -0.55))
	else:
		_mesh(self, "HelmetCrest", _box(Vector3(0.07, 0.35, 0.1)), trim, Vector3(0, head_y + 0.32, 0.02), Vector3.ONE, Vector3(-0.18, 0, 0))

	# Shoulder plates and articulated limbs.
	for side in [-1.0, 1.0]:
		_mesh(self, "Pauldron_%s" % side, _sphere(0.24 if archetype != "warden" else 0.34), armor, Vector3(side * (0.39 if archetype != "warden" else 0.57), 1.48 if archetype != "warden" else 1.95, 0))
		_mesh(self, "PauldronRim_%s" % side, _sphere(0.18 if archetype != "warden" else 0.26), trim, Vector3(side * (0.40 if archetype != "warden" else 0.58), 1.52 if archetype != "warden" else 2.00, -0.045))
	_left_arm = _build_arm("LeftArm", -1.0, armor, leather, skin)
	_right_arm = _build_arm("RightArm", 1.0, armor, leather, skin)
	_left_leg = _build_leg("LeftLeg", -1.0, dark_armor, leather)
	_right_leg = _build_leg("RightLeg", 1.0, dark_armor, leather)
	_sword = _make_sword(_right_arm, blade, trim, leather, false)
	_cleaver = _make_sword(_right_arm, blade, trim, leather, true)
	_club = _make_club(_right_arm, leather, trim)
	_shield = _make_shield(_left_arm, armor, trim)
	_shield.visible = archetype == "guard"
	_sword.visible = archetype != "player"
	_cleaver.visible = false
	_club.visible = archetype == "hollow"
	_apply_proportions()

func _build_arm(label: String, side: float, armor: Material, leather: Material, skin: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = Vector3(side * 0.39, 1.43, 0)
	add_child(pivot)
	_mesh(pivot, "UpperArm", _capsule(0.125, 0.52), armor, Vector3(0, -0.22, 0))
	_mesh(pivot, "Elbow", _sphere(0.13), leather, Vector3(0, -0.43, -0.015))
	_mesh(pivot, "Forearm", _capsule(0.105, 0.42), armor, Vector3(0, -0.59, -0.015))
	_mesh(pivot, "Bracer", _box(Vector3(0.22, 0.20, 0.21)), leather, Vector3(0, -0.59, -0.04))
	_mesh(pivot, "Hand", _sphere(0.115), skin, Vector3(0, -0.82, -0.04))
	return pivot

func _build_leg(label: String, side: float, armor: Material, leather: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = Vector3(side * 0.19, 0.82, 0)
	add_child(pivot)
	_mesh(pivot, "Thigh", _capsule(0.15, 0.58), armor, Vector3(0, -0.23, 0))
	_mesh(pivot, "Knee", _sphere(0.15), armor, Vector3(0, -0.48, -0.035))
	_mesh(pivot, "Greave", _capsule(0.12, 0.46), leather, Vector3(0, -0.69, 0))
	_mesh(pivot, "Boot", _box(Vector3(0.25, 0.17, 0.38)), armor, Vector3(0, -0.91, -0.09))
	return pivot

func _make_sword(parent: Node3D, blade_material: Material, trim_material: Material, grip_material: Material, heavy: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "GraveCleaver" if heavy else "AshenLongsword"
	root.position = Vector3(0, -0.83, -0.10)
	root.rotation.z = -0.10
	parent.add_child(root)
	var grip_length := 0.3 if not heavy else 0.42
	_mesh(root, "Grip", _capsule(0.045, grip_length), grip_material, Vector3(0, -0.10, 0))
	_mesh(root, "Pommel", _sphere(0.065), trim_material, Vector3(0, -0.25 - grip_length * 0.5, 0))
	_mesh(root, "Crossguard", _box(Vector3(0.34 if not heavy else 0.42, 0.07, 0.10)), trim_material, Vector3(0, -0.31 - grip_length * 0.5, 0))
	if heavy:
		_mesh(root, "Blade", _box(Vector3(0.30, 0.72, 0.075)), blade_material, Vector3(0, -0.73 - grip_length * 0.5, 0))
		_mesh(root, "BladeSpine", _box(Vector3(0.045, 0.62, 0.012)), trim_material, Vector3(0, -0.73 - grip_length * 0.5, -0.044))
	else:
		_mesh(root, "Blade", _box(Vector3(0.11, 0.82, 0.055)), blade_material, Vector3(0, -0.83 - grip_length * 0.5, 0))
		_mesh(root, "Fuller", _box(Vector3(0.022, 0.64, 0.012)), trim_material, Vector3(0, -0.83 - grip_length * 0.5, -0.033))
	return root

func _make_club(parent: Node3D, grip: Material, metal: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "HollowClub"
	root.position = Vector3(0, -0.84, -0.08)
	parent.add_child(root)
	_mesh(root, "Branch", _capsule(0.08, 0.95), grip, Vector3(0, -0.34, 0), Vector3(1, 1, 1), Vector3(0, 0, 0.08))
	_mesh(root, "KnottedHead", _sphere(0.22), metal, Vector3(0.1, -0.72, 0))
	return root

func _make_shield(parent: Node3D, armor: Material, trim: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "TowerShield"
	root.position = Vector3(0, -0.86, -0.18)
	root.rotation = Vector3(0.08, 0, -0.05)
	parent.add_child(root)
	_mesh(root, "ShieldFace", _box(Vector3(0.52, 0.86, 0.12)), armor, Vector3(0, -0.35, -0.03))
	_mesh(root, "ShieldRim", _box(Vector3(0.57, 0.055, 0.16)), trim, Vector3(0, 0.08, -0.04))
	_mesh(root, "ShieldBoss", _sphere(0.12), trim, Vector3(0, -0.34, -0.11))
	_mesh(root, "ShieldPoint", _box(Vector3(0.13, 0.22, 0.11)), trim, Vector3(0, -0.83, -0.03))
	return root

func _apply_proportions() -> void:
	if archetype == "warden":
		_base_scale = Vector3(1.3, 1.38, 1.3)
	elif archetype == "hollow":
		_base_scale = Vector3(0.96, 0.96, 0.96)
	scale = _base_scale

func _update_weapon(actor: CharacterBody3D) -> void:
	if archetype != "player":
		return
	var weapon: Resource = actor.get("current_weapon")
	var weapon_name := str(weapon.get("display_name")) if weapon != null else "Ashen Longsword"
	_sword.visible = weapon_name != "Grave Cleaver"
	_cleaver.visible = weapon_name == "Grave Cleaver"

func play_attack(heavy: bool = false) -> void:
	_attack_is_heavy = heavy
	_attack_pose_time = 0.34 if heavy else 0.25

func play_hit() -> void:
	_hit_flash_time = 0.16
	if _torso != null:
		var flash := _mat(Color(1.0, 0.43, 0.28), 0.55, 0.3, Color(1.0, 0.08, 0.025, 1.0))
		_torso.material_override = flash
		var tween := create_tween()
		tween.tween_interval(0.12)
		tween.tween_callback(func() -> void:
			if is_instance_valid(_torso) and _torso.material_override == flash:
				_torso.material_override = _base_torso_material
		)

func play_death() -> void:
	if _death_tween != null and _death_tween.is_running():
		return
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(self, "scale", Vector3(scale.x * 1.1, 0.06, scale.z * 1.1), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(self, "rotation:z", 0.75, 0.7).set_trans(Tween.TRANS_CUBIC)

func reset_visual() -> void:
	if _death_tween != null:
		_death_tween.kill()
	scale = _base_scale
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	_attack_pose_time = 0.0
	_hit_flash_time = 0.0
	if _torso != null:
		_torso.material_override = _base_torso_material

func enrage() -> void:
	var hot := _mat(Color(0.17, 0.055, 0.06), 0.9, 0.25, Color(0.95, 0.025, 0.006, 1.0))
	if _torso != null:
		_torso.material_override = hot
	if _eyes != null:
		_eyes.emission_energy_multiplier = 4.0
