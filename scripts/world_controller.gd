extends Node2D

const GameConfigScript = preload("res://scripts/game_config.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const PlayerControllerScript = preload("res://scripts/player_controller.gd")
const ResourceNodeScript = preload("res://scripts/resource_node.gd")
const GameUIScript = preload("res://scripts/game_ui.gd")
const PlayerScene = preload("res://scenes/player.tscn")
const UIScene = preload("res://scenes/game_ui.tscn")

const HOTBAR_ITEMS := ["sword", "pickaxe", "axe", "bow", "arrows", "", "", "", ""]
const DAMAGE_LABELS := {"cutting": "режущий", "piercing": "колющий", "crushing": "дробящий"}

var config: Dictionary
var player
var ui
var ground: TileMapLayer
var world_objects: Node2D
var resources: Array = []
var projectiles: Array = []
var attack_cooldowns: Dictionary = {}
var selected_slot := 0
var backpack_slots := 12
var arrow_count := 30
var wood_count := 0
var debug_selected
var screen_shake_enabled := true
var camera_shake_timer := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	config = GameConfigScript.make_default()
	arrow_count = int(config.inventory.starting_arrows)
	backpack_slots = int(config.inventory.base_backpack_slots)
	rng.seed = int(config.world.seed)
	_configure_input()
	_create_ground()
	_create_player()
	_create_resources()
	_create_ui()
	_load_settings()
	_log("Мир загружен. Добро пожаловать!")

func _configure_input() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("run", [KEY_SHIFT])
	_add_key_action("crouch", [KEY_CTRL])
	_add_key_action("dodge", [KEY_SPACE])
	_add_key_action("inventory", [KEY_B])
	_add_key_action("settings", [KEY_ESCAPE])
	_add_key_action("debug", [KEY_F3])
	_add_key_action("logs", [KEY_F2])
	for index in range(9):
		_add_key_action("slot_%d" % (index + 1), [KEY_1 + index])
	_add_mouse_action("attack_primary", MOUSE_BUTTON_LEFT)
	_add_mouse_action("attack_secondary", MOUSE_BUTTON_RIGHT)

func _add_key_action(action_name: String, key_codes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key_code in key_codes:
		var event := InputEventKey.new()
		event.physical_keycode = int(key_code)
		InputMap.action_add_event(action_name, event)

func _add_mouse_action(action_name: String, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)

func _create_ground() -> void:
	ground = TileMapLayer.new()
	ground.name = "GrassGround"
	ground.z_index = -100
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://public/assets/grass.png")
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	ground.tile_set = tile_set
	add_child(ground)
	for x in range(-57, 57):
		for y in range(-57, 57):
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)

func _create_player() -> void:
	player = get_node_or_null("Player")
	if player == null:
		player = PlayerScene.instantiate()
		player.name = "Player"
		add_child(player)
	player.configure(config)
	player.global_position = Vector2.ZERO
	var camera: Camera2D = player.camera
	var half_width := int(config.world.width / 2)
	var half_height := int(config.world.height / 2)
	camera.limit_left = -half_width
	camera.limit_right = half_width
	camera.limit_top = -half_height
	camera.limit_bottom = half_height
	camera.limit_smoothed = true

func _create_resources() -> void:
	world_objects = get_node_or_null("WorldObjects") as Node2D
	if world_objects == null:
		world_objects = Node2D.new()
		world_objects.name = "WorldObjects"
		add_child(world_objects)
	for node in world_objects.get_children():
		if node.has_method("apply_damage"):
			resources.append(node)
	if not resources.is_empty():
		return
	for _index in range(int(config.world.tree_count)):
		_spawn_resource("tree")
	for _index in range(int(config.world.rock_count)):
		_spawn_resource("rock")

func _spawn_resource(kind: String) -> void:
	var position := _random_resource_position()
	var node = ResourceNodeScript.new()
	node.configure(kind, 90.0 if kind == "tree" else 110.0)
	node.name = ("Tree" if kind == "tree" else "Rock") + "_" + str(resources.size() + 1)
	world_objects.add_child(node)
	node.global_position = position
	resources.append(node)

func _random_resource_position() -> Vector2:
	var half_width := float(config.world.width) * 0.5 - 100.0
	var half_height := float(config.world.height) * 0.5 - 100.0
	for _attempt in range(80):
		var candidate := Vector2(
			rng.randf_range(-half_width, half_width),
			rng.randf_range(-half_height, half_height)
		)
		if candidate.length() < float(config.world.keep_spawn_clear_radius):
			continue
		var too_close := false
		for other in resources:
			if candidate.distance_to(other.global_position) < 68.0:
				too_close = true
				break
		if not too_close:
			return candidate
	return Vector2(rng.randf_range(500, half_width), rng.randf_range(500, half_height))

func _create_ui() -> void:
	ui = get_node_or_null("GameUI")
	if ui == null:
		ui = UIScene.instantiate()
		ui.name = "GameUI"
		add_child(ui)
	ui.slot_selected.connect(_on_slot_selected)
	ui.backpack_expand_requested.connect(_expand_backpack)
	ui.settings_changed.connect(_on_settings_changed)
	ui.debug_value_changed.connect(_on_debug_value_changed)
	ui.set_backpack_slots(backpack_slots, int(config.inventory.max_backpack_slots))
	ui.set_hotbar_selection(selected_slot)
	ui.set_player_data(player.current_health, float(config.player.max_health), player.current_stamina, float(config.player.max_stamina), arrow_count)

func _process(delta: float) -> void:
	_handle_hotkeys()
	_update_attack_cooldowns(delta)
	_update_projectiles(delta)
	_update_camera(delta)
	_update_z_order()
	if player != null and player.has_method("set_held_item"):
		var selected_item := str(HOTBAR_ITEMS[selected_slot])
		var aim_direction := (get_global_mouse_position() - player.global_position).normalized()
		player.set_held_item(selected_item, aim_direction)
	if ui != null and player != null:
		ui.set_player_data(
			player.current_health,
			float(config.player.max_health),
			player.current_stamina,
			float(config.player.max_stamina),
			arrow_count
		)
		if ui.current_panel == "debug" and debug_selected == null:
			ui.set_debug_target("Игрок", player.current_health, float(config.player.max_health))

func _handle_hotkeys() -> void:
	if Input.is_action_just_pressed("inventory"):
		ui.toggle_panel("inventory")
	if Input.is_action_just_pressed("settings"):
		if ui.has_modal_open():
			ui.close_panels()
		else:
			ui.toggle_panel("settings")
	if Input.is_action_just_pressed("debug"):
		ui.toggle_panel("debug")
		debug_selected = player
		ui.set_debug_values(float(config.player.walk_speed), float(config.player.strength))
		ui.set_debug_target("Игрок", player.current_health, float(config.player.max_health))
	if Input.is_action_just_pressed("logs"):
		ui.toggle_panel("logs")
	for index in range(9):
		if Input.is_action_just_pressed("slot_%d" % (index + 1)):
			_on_slot_selected(index)

func _unhandled_input(event: InputEvent) -> void:
	if ui != null and ui.has_modal_open():
		if event is InputEventMouseButton and event.pressed and ui.current_panel == "debug" and event.button_index == MOUSE_BUTTON_LEFT:
			_select_debug_target(get_global_mouse_position())
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_attack(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_attack(true)

func _on_slot_selected(index: int) -> void:
	if index < 0 or index >= HOTBAR_ITEMS.size():
		return
	selected_slot = index
	ui.set_hotbar_selection(selected_slot)
	var label: String = str(HOTBAR_ITEMS[index])
	if player != null and player.has_method("set_held_item"):
		var aim_direction := (get_global_mouse_position() - player.global_position).normalized()
		player.set_held_item(label, aim_direction)
	if label == "":
		_log("Пустой слот.")
	else:
		_log("Выбрано: " + label)

func _update_attack_cooldowns(delta: float) -> void:
	for key in attack_cooldowns.keys():
		attack_cooldowns[key] = maxf(0.0, float(attack_cooldowns[key]) - delta)

func _expand_backpack() -> void:
	var maximum := int(config.inventory.max_backpack_slots)
	if backpack_slots >= maximum:
		_log("Рюкзак уже максимального размера.")
		return
	backpack_slots = mini(maximum, backpack_slots + int(config.inventory.expansion_step))
	ui.set_backpack_slots(backpack_slots, maximum)
	_log("Вместимость рюкзака увеличена до %d ячеек (пока бесплатно)." % backpack_slots)

func _on_settings_changed(screen_shake: bool, camera_zoom: float) -> void:
	screen_shake_enabled = screen_shake
	config.settings.screen_shake = screen_shake
	config.camera.base_zoom = camera_zoom
	var save := ConfigFile.new()
	save.set_value("camera", "screen_shake", screen_shake)
	save.set_value("camera", "base_zoom", camera_zoom)
	var error := save.save("user://settings.cfg")
	if error != OK:
		_log("Не удалось сохранить настройки: %s" % error)

func _load_settings() -> void:
	var save := ConfigFile.new()
	if save.load("user://settings.cfg") == OK:
		screen_shake_enabled = bool(save.get_value("camera", "screen_shake", true))
		config.camera.base_zoom = float(save.get_value("camera", "base_zoom", config.camera.base_zoom))
	ui.set_settings(screen_shake_enabled, float(config.camera.base_zoom))

func _on_debug_value_changed(path: String, value: float) -> void:
	match path:
		"player.walk_speed":
			config.player.walk_speed = value
		"player.strength":
			config.player.strength = value
		_:
			return
	_log("Отладчик: %s = %.1f" % [path, value])

func _select_debug_target(world_position: Vector2) -> void:
	var nearest
	var nearest_distance := 44.0
	var player_distance: float = world_position.distance_to(player.global_position)
	if player_distance < nearest_distance:
		nearest = player
		nearest_distance = player_distance
	for resource in resources:
		var distance: float = world_position.distance_to(resource.global_position)
		if distance < nearest_distance:
			nearest = resource
			nearest_distance = distance
	debug_selected = nearest
	if nearest == player:
		ui.set_debug_target("Игрок", player.current_health, float(config.player.max_health))
		ui.set_debug_values(float(config.player.walk_speed), float(config.player.strength))
	elif nearest != null:
		ui.set_debug_target(str(nearest.resource_type).capitalize(), nearest.health, nearest.max_health)
		_log("Отладчик: выбран объект " + str(nearest.resource_type))
	else:
		ui.set_debug_target("ничего не выбрано")

func _attack(secondary: bool) -> void:
	if player == null:
		return
	var weapon_id: String = str(HOTBAR_ITEMS[selected_slot])
	if weapon_id == "arrows":
		weapon_id = "bow"
	if weapon_id == "":
		return
	var aim_vector: Vector2 = get_global_mouse_position() - player.global_position
	if aim_vector.length_squared() < 0.001:
		return
	var aim_direction: Vector2 = aim_vector.normalized()
	var aim_angle: float = aim_vector.angle()
	var weapon: Dictionary = config.weapons.get(weapon_id, {})
	if weapon.is_empty():
		return
	if weapon_id == "bow":
		_fire_arrow(aim_direction, weapon)
		return

	var attack: Dictionary = weapon
	var mode := "tool"
	var cooldown_key := weapon_id
	if weapon_id == "sword":
		if secondary:
			attack = weapon.thrust
			mode = "thrust"
			cooldown_key = "sword_thrust"
		else:
			attack = weapon.slash
			mode = "slash"
			cooldown_key = "sword_slash"
	elif weapon_id == "axe":
		mode = "swing"
		cooldown_key = "axe_swing"
	attack = attack.duplicate(true)
	attack["weapon_id"] = weapon_id
	if float(attack_cooldowns.get(cooldown_key, 0.0)) > 0.0:
		return
	var stamina_cost := float(attack.get("stamina_cost", config.combat.attack_stamina_cost))
	if player.current_stamina < stamina_cost:
		_log("Недостаточно выносливости для атаки.")
		return
	player.current_stamina -= stamina_cost
	attack_cooldowns[cooldown_key] = float(attack.get("cooldown", 0.4))
	var agility := float(config.player.get("agility", 10.0))
	var skill_scale := clampf(1.0 + (agility - 10.0) * float(config.combat.effect_width_skill_scale), 0.65, 1.65)
	var attack_arc := clampf(float(attack.get("arc_degrees", config.combat.slash_arc_degrees)) + (agility - 10.0) * float(config.combat.arc_skill_bonus), 60.0, 175.0)
	var effect_width := float(attack.get("effect_width", 14.0)) * skill_scale
	_show_attack_effect(aim_direction, float(attack.get("reach", 70.0)), mode, attack_arc, effect_width)

	var hit_count := 0
	for target in resources.duplicate():
		var offset: Vector2 = target.global_position - player.global_position
		var distance := offset.length()
		var reach := float(attack.get("reach", 70.0))
		var is_hit := false
		if mode == "slash" or mode == "swing":
			is_hit = CombatSystemScript.point_in_arc(player.global_position, target.global_position, aim_angle, reach + target.hit_radius, attack_arc)
		else:
			var start: Vector2 = player.global_position + aim_direction * 12.0
			var finish: Vector2 = player.global_position + aim_direction * reach
			var hit_width := float(attack.get("width", 22.0)) * skill_scale
			is_hit = distance <= reach + target.hit_radius and CombatSystemScript.distance_to_segment(target.global_position, start, finish) <= hit_width + target.hit_radius * 0.35
		if is_hit:
			var material := "wood" if target.resource_type == "tree" else "stone"
			if not CombatSystemScript.can_damage_resource(weapon_id, material):
				continue
			_damage_target(target, attack)
			hit_count += 1
	if hit_count == 0:
		_log("Удар: %s" % weapon_id)

func _show_attack_effect(direction: Vector2, reach: float, mode: String, arc_degrees: float, effect_width: float) -> void:
	var visual_reach := maxf(22.0, reach * float(config.combat.effect_reach_scale))
	var base_color := Color("#cceaff") if mode == "thrust" else (Color("#e8b96f") if mode == "swing" else Color("#e9edbd"))
	for layer_index in range(3):
		var effect := Line2D.new()
		effect.width = effect_width * [2.5, 1.55, 0.72][layer_index]
		effect.default_color = Color(base_color.r, base_color.g, base_color.b, [0.10, 0.22, 0.72][layer_index])
		effect.antialiased = true
		effect.begin_cap_mode = Line2D.LINE_CAP_ROUND
		effect.end_cap_mode = Line2D.LINE_CAP_ROUND
		effect.position = player.global_position
		effect.z_index = player.z_index + 5
		if mode == "slash" or mode == "swing":
			var points := PackedVector2Array()
			var center_angle := direction.angle()
			for step in range(13):
				var angle := center_angle + deg_to_rad(-arc_degrees * 0.5 + arc_degrees * float(step) / 12.0)
				points.append(Vector2.from_angle(angle) * (visual_reach - 6.0))
			effect.points = points
		else:
			effect.points = PackedVector2Array([direction * 12.0, direction * visual_reach])
		add_child(effect)
		var tween := create_tween()
		tween.tween_property(effect, "modulate:a", 0.0, 0.15 + float(layer_index) * 0.025)
		tween.tween_callback(effect.queue_free)

func _damage_target(target, attack: Dictionary) -> void:
	var material := "wood" if target.resource_type == "tree" else "stone"
	var amount := CombatSystemScript.calculate_damage(attack, material, float(config.player.strength), config)
	if amount <= 0.0:
		return
	var destroyed: bool = target.apply_damage(amount)
	var type_name := str(DAMAGE_LABELS.get(str(attack.get("damage_type", "cutting")), ""))
	_log("%s: -%.0f HP (%s)." % [str(target.resource_type).capitalize(), amount, type_name])
	_camera_shake()
	if destroyed:
		if target.resource_type == "tree":
			wood_count += 1
		resources.erase(target)
		_log("%s разрушено." % str(target.resource_type).capitalize())
		target.queue_free()

func _fire_arrow(direction: Vector2, weapon: Dictionary) -> void:
	if arrow_count <= 0:
		_log("Стрелы закончились.")
		return
	if float(attack_cooldowns.get("bow", 0.0)) > 0.0:
		return
	attack_cooldowns["bow"] = float(weapon.cooldown)
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://public/assets/items.png")
	atlas.region = Rect2(128, 0, 32, 32)
	var arrow := Sprite2D.new()
	arrow.texture = atlas
	arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrow.scale = Vector2(0.8, 0.8)
	arrow.rotation = direction.angle()
	arrow.position = player.global_position + direction * 22.0
	arrow.z_index = 700
	add_child(arrow)
	arrow_count -= 1
	projectiles.append({
		"node": arrow,
		"velocity": direction * float(weapon.projectile_speed),
		"remaining": float(weapon.projectile_range),
		"damage": float(weapon.damage),
		"damage_type": str(weapon.damage_type),
		"weapon_id": "bow",
	})
	_log("Выстрел. Осталось стрел: %d." % arrow_count)

func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var arrow: Sprite2D = shot["node"]
		if not is_instance_valid(arrow):
			projectiles.remove_at(index)
			continue
		var movement: Vector2 = shot["velocity"] * delta
		arrow.global_position += movement
		shot["remaining"] = float(shot["remaining"]) - movement.length()
		var hit_target
		for target in resources:
			if target.global_position.distance_to(arrow.global_position) <= target.hit_radius * 0.65 + 7.0:
				hit_target = target
				break
		if hit_target != null:
			var attack := {"damage": shot["damage"], "damage_type": shot["damage_type"], "weapon_id": "bow"}
			_damage_target(hit_target, attack)
			arrow.queue_free()
			projectiles.remove_at(index)
		elif float(shot["remaining"]) <= 0.0:
			arrow.queue_free()
			projectiles.remove_at(index)

func _update_camera(delta: float) -> void:
	var camera: Camera2D = player.camera
	var target_zoom := float(config.camera.base_zoom)
	if player.running:
		target_zoom = float(config.camera.run_zoom)
	elif player.crouching:
		target_zoom = float(config.camera.crouch_zoom)
	var amount := clampf(delta * float(config.camera.zoom_lerp_speed), 0.0, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, amount)
	if camera_shake_timer > 0.0:
		camera_shake_timer -= delta
		var strength := float(config.camera.shake_strength)
		camera.offset = Vector2(rng.randf_range(-strength, strength), rng.randf_range(-strength, strength))
	else:
		camera.offset = Vector2.ZERO

func _camera_shake() -> void:
	if screen_shake_enabled:
		camera_shake_timer = float(config.camera.shake_duration_ms) / 1000.0

func _update_z_order() -> void:
	if player != null:
		player.z_index = int(player.global_position.y / 16.0) + 1

func _log(message: String) -> void:
	print("[game] " + message)
	if ui != null:
		ui.add_log(message)
