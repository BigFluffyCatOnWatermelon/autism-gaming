extends Node2D

const GameConfigScript = preload("res://scripts/game_config.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const PlayerControllerScript = preload("res://scripts/player_controller.gd")
const ResourceNodeScript = preload("res://scripts/resource_node.gd")
const ResourceDropScript = preload("res://scripts/resource_drop.gd")
const ArrowProjectileScript = preload("res://scripts/arrow_projectile.gd")
const ObjectsScene = preload("res://scenes/objects.tscn")
const UIScene = preload("res://scenes/ui.tscn")

const DAMAGE_LABELS := {
	"cutting": {"name": "режущий", "color": Color("#ffe0a0")},
	"piercing": {"name": "колющий", "color": Color("#bfe8ff")},
	"crushing": {"name": "дробящий", "color": Color("#d8d2ff")},
}

var config: Dictionary = {}
var defaults_config: Dictionary = {}
var player
var ui
var ground: TileMapLayer
var world_objects: Node2D
var resources: Array = []
var drops: Array = []
var projectiles: Array[Dictionary] = []
var embedded_arrows: Array[Node2D] = []
var attack_cooldowns: Dictionary = {}
var selected_slot := 0
var backpack_slots := 12
var inventory: Array[Dictionary] = []
var inventory_dirty := true
var arrow_count := 0
var wood_count := 0
var stone_count := 0
var screen_shake_enabled := true
var camera_shake_timer := 0.0
var rng := RandomNumberGenerator.new()
var debug_entries: Array[Dictionary] = []
var debug_selected_id := ""
var debug_refresh_timer := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	config = GameConfigScript.make_default()
	defaults_config = config.duplicate(true)
	backpack_slots = int(config.inventory.base_backpack_slots)
	rng.seed = int(config.world.seed)
	_initialize_inventory()
	_configure_input()
	_create_ground()
	_create_player()
	_create_resources()
	_create_ui()
	_load_settings()
	_log("Мир загружен. Добро пожаловать!")

func _initialize_inventory() -> void:
	inventory.clear()
	for _index in range(9 + int(config.inventory.max_backpack_slots)):
		inventory.append({"id": "", "amount": 0})
	inventory[0] = {"id": "sword", "amount": 1}
	inventory[1] = {"id": "pickaxe", "amount": 1}
	inventory[2] = {"id": "axe", "amount": 1}
	inventory[3] = {"id": "bow", "amount": 1}
	inventory[4] = {"id": "arrows", "amount": int(config.inventory.starting_arrows)}
	_update_resource_counts()

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
	_add_key_action("drop_item", [KEY_Q])
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
		player = PlayerControllerScript.new()
		player.name = "Player"
		add_child(player)
	player.configure(config)
	var camera: Camera2D = player.camera
	var half_width := int(config.world.width / 2)
	var half_height := int(config.world.height / 2)
	camera.limit_left = -half_width
	camera.limit_right = half_width
	camera.limit_top = -half_height
	camera.limit_bottom = half_height
	camera.limit_smoothed = true

func _create_resources() -> void:
	world_objects = get_node_or_null("Objects") as Node2D
	if world_objects == null:
		world_objects = ObjectsScene.instantiate() as Node2D
		world_objects.name = "Objects"
		add_child(world_objects)

	resources.clear()
	var occupied_positions: Array[Vector2] = []
	var existing_trees := 0
	var existing_rocks := 0
	for child in world_objects.get_children():
		var resource := child as ResourceNode
		if resource == null or resource.resource_type == "stump":
			continue
		_register_resource(resource)
		occupied_positions.append(resource.global_position)
		if resource.resource_type == "tree":
			existing_trees += 1
		elif resource.resource_type == "rock":
			existing_rocks += 1

	var target_trees := maxi(1, int(config.world.get("tree_count", 100)))
	var target_rocks := maxi(1, int(config.world.get("rock_count", 75)))
	while existing_trees < target_trees:
		_spawn_world_resource("tree", existing_trees + 1, occupied_positions)
		existing_trees += 1
	while existing_rocks < target_rocks:
		_spawn_world_resource("rock", existing_rocks + 1, occupied_positions)
		existing_rocks += 1

func _spawn_world_resource(kind: String, index: int, occupied_positions: Array[Vector2]) -> void:
	var resource := ResourceNodeScript.new() as ResourceNode
	var max_health := float(config.resources.tree_health) if kind == "tree" else float(config.resources.rock_health)
	resource.configure(kind, max_health)
	resource.name = "%s_%03d" % [kind.capitalize(), index]
	resource.position = _find_resource_spawn_position(occupied_positions)
	world_objects.add_child(resource)
	_register_resource(resource)
	occupied_positions.append(resource.global_position)

func _find_resource_spawn_position(occupied_positions: Array[Vector2]) -> Vector2:
	var half_width := float(config.world.width) * 0.5
	var half_height := float(config.world.height) * 0.5
	var edge_margin := 96.0
	var clear_radius := float(config.world.get("keep_spawn_clear_radius", 230.0))
	var minimum_spacing := 88.0
	var candidate := Vector2.ZERO
	for _attempt in range(300):
		candidate = Vector2(
			rng.randf_range(-half_width + edge_margin, half_width - edge_margin),
			rng.randf_range(-half_height + edge_margin, half_height - edge_margin)
		)
		if candidate.length() < clear_radius:
			continue
		var overlaps := false
		for other_position in occupied_positions:
			if candidate.distance_to(other_position) < minimum_spacing:
				overlaps = true
				break
		if not overlaps:
			return candidate
	return candidate

func _register_resource(resource: ResourceNode) -> void:
	if not is_instance_valid(resource):
		return
	if not resources.has(resource):
		resources.append(resource)
	var callback := Callable(self, "_on_resource_broken").bind(resource)
	if not resource.resource_broken.is_connected(callback):
		resource.resource_broken.connect(callback)

func _create_ui() -> void:
	ui = get_node_or_null("UI")
	if ui == null:
		ui = UIScene.instantiate()
		ui.name = "UI"
		add_child(ui)
	ui.slot_selected.connect(_on_slot_selected)
	ui.backpack_expand_requested.connect(_expand_backpack)
	ui.settings_changed.connect(_on_settings_changed)
	ui.debug_value_changed.connect(_on_debug_value_changed)
	ui.debug_mode_requested.connect(_on_debug_mode_requested)
	ui.inventory_slot_dropped.connect(_move_inventory_slot)
	ui.debug_object_selected.connect(_on_debug_object_selected)
	ui.debug_clone_requested.connect(_clone_debug_selection)
	ui.debug_delete_requested.connect(_delete_debug_selection)
	ui.debug_reset_requested.connect(_reset_debug_selection)
	ui.debug_cheats_changed.connect(_on_debug_cheats_changed)
	ui.set_backpack_slots(backpack_slots, int(config.inventory.max_backpack_slots))
	ui.set_hotbar_selection(selected_slot)
	ui.set_inventory_data(inventory, backpack_slots, int(config.inventory.max_backpack_slots), config.items)
	ui.set_player_data(player.current_health, float(config.player.max_health), player.current_stamina, float(config.player.max_stamina), arrow_count)

func _process(delta: float) -> void:
	_handle_hotkeys()
	_update_attack_cooldowns(delta)
	_handle_held_combat()
	_update_projectiles(delta)
	_update_drops()
	_update_camera(delta)
	_update_z_order()
	_update_held_item()
	_update_resource_counts()
	if ui != null and player != null:
		ui.set_player_data(
			player.current_health,
			float(config.player.max_health),
			player.current_stamina,
			float(config.player.max_stamina),
			arrow_count
		)
		if inventory_dirty:
			ui.set_inventory_data(inventory, backpack_slots, int(config.inventory.max_backpack_slots), config.items)
			inventory_dirty = false
		if ui.current_panel == "debug":
			debug_refresh_timer -= delta
			if debug_refresh_timer <= 0.0:
				_refresh_debug_entries()
				debug_refresh_timer = 0.4
			var magnet_radius := _get_magnet_radius()
			ui.set_debug_stats(
				"FPS: %d  ·  XY: %.0f, %.0f  ·  HP: %.0f/%.0f  ·  STA: %.0f/%.0f  ·  Бег: %s  ·  Предмет: %s  ·  Стрелы: %d  ·  Магнит: %.0f px  ·  Объекты рядом: %d" % [
					Engine.get_frames_per_second(),
					player.global_position.x,
					player.global_position.y,
					player.current_health,
					float(config.player.max_health),
					player.current_stamina,
					float(config.player.max_stamina),
					"да" if player.running else "нет",
					str(config.items.get(_get_selected_item_id(), {}).get("label", "—")),
					arrow_count,
					magnet_radius,
					_count_nearby_resources()
				]
			)

func _handle_held_combat() -> void:
	if player == null or ui == null or ui.has_modal_open():
		return
	var primary_pressed := Input.is_action_pressed("attack_primary")
	var secondary_pressed := Input.is_action_pressed("attack_secondary")
	if not primary_pressed and not secondary_pressed:
		return

	var selected_item := _get_selected_item_id()
	if selected_item == "bow" or selected_item == "arrows":
		_fire_arrow(config.weapons.get("bow", {}))
		return
	if selected_item.is_empty():
		return
	# Melee weapons and tools repeat while held, respecting their individual cooldown.
	_attack(secondary_pressed and not primary_pressed)

func _update_held_item() -> void:
	if player == null or not player.has_method("set_held_item"):
		return
	var selected_item := _get_selected_item_id()
	if selected_item == "arrows":
		# Ammunition stays in the inventory slot; it is not displayed as an equipped bow.
		selected_item = ""
	var aim_direction: Vector2 = (get_global_mouse_position() - player.global_position).normalized()
	player.set_held_item(selected_item, aim_direction)

func _handle_hotkeys() -> void:
	if Input.is_action_just_pressed("inventory"):
		ui.toggle_panel("inventory")
	if Input.is_action_just_pressed("settings"):
		if ui.has_modal_open():
			var was_debug_open: bool = ui.current_panel == "debug"
			ui.close_panels()
			ui.set_debug_mode_enabled(false)
			if was_debug_open:
				_clear_debug_selection()
		else:
			ui.toggle_panel("settings")
	if Input.is_action_just_pressed("debug"):
		ui.toggle_panel("debug")
		ui.set_debug_mode_enabled(ui.current_panel == "debug")
		if ui.current_panel == "debug":
			player.set_debug_selected(true)
			debug_selected_id = str(player.get_instance_id())
			_refresh_debug_entries()
			_update_debug_inspector()
			ui.set_debug_cheats(player.debug_infinite_stamina, player.debug_invulnerable)
		else:
			_clear_debug_selection()
	if Input.is_action_just_pressed("logs"):
		ui.toggle_panel("logs")
	if Input.is_action_just_pressed("drop_item") and not ui.has_modal_open():
		_drop_selected_item()
	for index in range(9):
		if Input.is_action_just_pressed("slot_%d" % (index + 1)):
			_on_slot_selected(index)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ui != null and ui.current_panel == "debug":
			_select_debug_target(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if ui != null and ui.has_modal_open():
			return
		_attack(false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if ui != null and ui.has_modal_open():
			return
		_attack(true)

func _on_slot_selected(index: int) -> void:
	if index < 0 or index >= int(config.inventory.hotbar_slots):
		return
	selected_slot = index
	ui.set_hotbar_selection(selected_slot)
	var label := _get_selected_item_id()
	if label.is_empty():
		_log("Пустой слот.")
	else:
		if label == "arrows":
			_log("Выбраны стрелы. Для стрельбы выбери слот лука.")
		else:
			_log("Выбрано: " + str(config.items.get(label, {}).get("label", label)))
	_update_held_item()

func _expand_backpack() -> void:
	var maximum := int(config.inventory.max_backpack_slots)
	if backpack_slots >= maximum:
		_log("Рюкзак уже максимального размера.")
		return
	backpack_slots = mini(maximum, backpack_slots + int(config.inventory.expansion_step))
	ui.set_backpack_slots(backpack_slots, maximum)
	_log("Вместимость рюкзака увеличена до %d ячеек." % backpack_slots)
	inventory_dirty = true

func _move_inventory_slot(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= inventory.size():
		return
	if to_index == -1:
		_drop_inventory_item(from_index, get_global_mouse_position())
		return
	if to_index < 0 or to_index >= inventory.size():
		return
	if from_index == to_index or not _inventory_slot_unlocked(to_index):
		return
	var source: Dictionary = inventory[from_index].duplicate(true)
	var destination: Dictionary = inventory[to_index].duplicate(true)
	if str(source.get("id", "")).is_empty():
		return
	if str(source.get("id", "")) == str(destination.get("id", "")) and not str(destination.get("id", "")).is_empty():
		var capacity := int(config.inventory.max_stack) - int(destination.get("amount", 0))
		var moved := mini(capacity, int(source.get("amount", 0)))
		if moved <= 0:
			return
		destination["amount"] = int(destination.get("amount", 0)) + moved
		source["amount"] = int(source.get("amount", 0)) - moved
		if int(source["amount"]) <= 0:
			source = {"id": "", "amount": 0}
		inventory[from_index] = source
		inventory[to_index] = destination
	else:
		inventory[from_index] = destination
		inventory[to_index] = source
	inventory_dirty = true
	_update_resource_counts()

func _drop_selected_item() -> void:
	if player == null:
		return
	var direction: Vector2 = get_global_mouse_position() - player.global_position
	if direction.length_squared() < 0.001:
		direction = player.last_move_direction
	if direction.length_squared() < 0.001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var spawn_position: Vector2 = player.global_position + direction * (_get_magnet_radius() + 32.0)
	_drop_inventory_item(selected_slot, spawn_position)

func _drop_inventory_item(slot_index: int, drop_position: Vector2) -> void:
	if player == null or world_objects == null or not _inventory_slot_unlocked(slot_index):
		return
	var stack: Dictionary = inventory[slot_index]
	var item_id := str(stack.get("id", ""))
	var amount := int(stack.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return
	var direction: Vector2 = drop_position - player.global_position
	if direction.length_squared() < 0.001:
		direction = player.last_move_direction
	if direction.length_squared() < 0.001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	if drop_position.distance_to(player.global_position) < _get_magnet_radius() + 12.0:
		drop_position = player.global_position + direction * (_get_magnet_radius() + 32.0)
	var dropped := ResourceDropScript.new() as ResourceDrop
	dropped.name = "Dropped_%s_%03d" % [item_id, drops.size() + 1]
	dropped.configure(item_id, amount, direction * 220.0, config.drops)
	world_objects.add_child(dropped)
	dropped.global_position = drop_position
	dropped.protect_from_player(player.global_position, 24.0)
	drops.append(dropped)
	inventory[slot_index] = {"id": "", "amount": 0}
	inventory_dirty = true
	_update_resource_counts()
	_log("Выброшено: %s ×%d." % [str(config.items.get(item_id, {}).get("label", item_id)), amount])

func _inventory_slot_unlocked(index: int) -> bool:
	if index < int(config.inventory.hotbar_slots):
		return true
	return index < int(config.inventory.hotbar_slots) + backpack_slots

func _inventory_add(item_id: String, quantity: int) -> int:
	var remaining := maxi(0, quantity)
	if item_id.is_empty() or remaining == 0:
		return remaining
	var max_stack := int(config.inventory.max_stack)
	for index in range(inventory.size()):
		if not _inventory_slot_unlocked(index):
			continue
		var slot: Dictionary = inventory[index]
		if str(slot.get("id", "")) != item_id:
			continue
		var room := max_stack - int(slot.get("amount", 0))
		if room <= 0:
			continue
		var moved := mini(room, remaining)
		slot["amount"] = int(slot.get("amount", 0)) + moved
		inventory[index] = slot
		remaining -= moved
		if remaining <= 0:
			inventory_dirty = true
			_update_resource_counts()
			return 0
	for index in range(inventory.size()):
		if not _inventory_slot_unlocked(index):
			continue
		if str(inventory[index].get("id", "")).is_empty():
			var moved := mini(max_stack, remaining)
			inventory[index] = {"id": item_id, "amount": moved}
			remaining -= moved
			if remaining <= 0:
				break
	inventory_dirty = true
	_update_resource_counts()
	return remaining

func _consume_item(item_id: String, quantity: int) -> bool:
	if _get_item_count(item_id) < quantity:
		return false
	var remaining := quantity
	for index in range(inventory.size()):
		if str(inventory[index].get("id", "")) != item_id:
			continue
		var stack: Dictionary = inventory[index]
		var used := mini(remaining, int(stack.get("amount", 0)))
		stack["amount"] = int(stack.get("amount", 0)) - used
		remaining -= used
		if int(stack["amount"]) <= 0:
			stack = {"id": "", "amount": 0}
		inventory[index] = stack
		if remaining <= 0:
			break
	inventory_dirty = true
	_update_resource_counts()
	return true

func _get_item_count(item_id: String) -> int:
	var total := 0
	for slot in inventory:
		if str(slot.get("id", "")) == item_id:
			total += int(slot.get("amount", 0))
	return total

func _get_selected_item_id() -> String:
	if selected_slot < 0 or selected_slot >= inventory.size():
		return ""
	return str(inventory[selected_slot].get("id", ""))

func _update_resource_counts() -> void:
	arrow_count = _get_item_count("arrows")
	wood_count = _get_item_count("wood")
	stone_count = _get_item_count("stone")

func _update_attack_cooldowns(delta: float) -> void:
	for key in attack_cooldowns.keys():
		attack_cooldowns[key] = maxf(0.0, float(attack_cooldowns[key]) - delta)

func _attack(secondary: bool) -> void:
	if player == null:
		return
	var weapon_id := _get_selected_item_id()
	if weapon_id == "arrows" or weapon_id == "bow":
		_fire_arrow(config.weapons.get("bow", {}))
		return
	if weapon_id.is_empty():
		return
	var weapon: Dictionary = config.weapons.get(weapon_id, {})
	if weapon.is_empty():
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
	var aim_vector: Vector2 = get_global_mouse_position() - player.global_position
	if aim_vector.length_squared() < 0.001:
		return
	var stamina_cost := float(attack.get("stamina_cost", config.combat.attack_stamina_cost))
	if player.current_stamina < stamina_cost and not player.debug_infinite_stamina:
		attack_cooldowns[cooldown_key] = 0.25
		_log("Недостаточно выносливости для атаки.")
		return
	if not player.debug_infinite_stamina:
		player.current_stamina -= stamina_cost
	attack_cooldowns[cooldown_key] = float(attack.get("cooldown", 0.4))

	var aim_direction: Vector2 = aim_vector.normalized()
	var aim_angle := aim_vector.angle()
	var agility := float(config.player.get("agility", 10.0))
	var skill_scale := clampf(1.0 + (agility - 10.0) * float(config.combat.effect_width_skill_scale), 0.65, 1.65)
	var attack_arc := clampf(float(attack.get("arc_degrees", config.combat.slash_arc_degrees)) + (agility - 10.0) * float(config.combat.arc_skill_bonus), 60.0, 175.0)
	var effect_width := float(attack.get("effect_width", 14.0)) * skill_scale
	_show_attack_effect(aim_direction, float(attack.get("reach", 70.0)), mode, attack_arc, effect_width)

	var hit_count := 0
	for target in resources.duplicate():
		if not is_instance_valid(target) or target.destroying:
			continue
		var offset: Vector2 = target.global_position - player.global_position
		var distance: float = offset.length()
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
			if target.resource_type == "stump" or not CombatSystemScript.can_damage_resource(weapon_id, material):
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

func _fire_arrow(weapon: Dictionary) -> void:
	if weapon.is_empty() or float(attack_cooldowns.get("bow", 0.0)) > 0.0:
		return
	if arrow_count <= 0:
		attack_cooldowns["bow"] = 0.4
		_log("Стрелы закончились.")
		return
	var aim_vector: Vector2 = get_global_mouse_position() - player.global_position
	if aim_vector.length_squared() < 0.001:
		return
	var stamina_cost := float(weapon.get("stamina_cost", 0.0))
	if player.current_stamina < stamina_cost and not player.debug_infinite_stamina:
		attack_cooldowns["bow"] = 0.25
		_log("Недостаточно выносливости для выстрела.")
		return
	if not _consume_item("arrows", 1):
		attack_cooldowns["bow"] = 0.4
		_log("Нет стрел в инвентаре.")
		return
	if not player.debug_infinite_stamina:
		player.current_stamina = maxf(0.0, player.current_stamina - stamina_cost)
	attack_cooldowns["bow"] = float(weapon.get("cooldown", 0.5))
	var direction := aim_vector.normalized()
	var arrow := ArrowProjectileScript.new() as Node2D
	arrow.name = "ArrowProjectile"
	arrow.rotation = direction.angle()
	arrow.global_position = player.global_position + direction * 22.0
	arrow.z_index = player.z_index + 4
	add_child(arrow)
	projectiles.append({
		"node": arrow,
		"velocity": direction * float(weapon.get("projectile_speed", config.combat.arrow_speed)),
		"remaining": float(weapon.get("projectile_range", config.combat.arrow_range)),
	})
	_update_resource_counts()
	inventory_dirty = true
	_log("Выстрел. Осталось стрел: %d." % arrow_count)

func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var arrow := shot.get("node") as Node2D
		if not is_instance_valid(arrow):
			projectiles.remove_at(index)
			continue

		var previous := arrow.global_position
		var remaining_distance := maxf(0.0, float(shot.get("remaining", 0.0)))
		var movement: Vector2 = shot["velocity"] * delta
		var movement_length := movement.length()
		if movement_length > remaining_distance and movement_length > 0.0:
			movement = movement.normalized() * remaining_distance
		arrow.global_position = previous + movement
		remaining_distance = maxf(0.0, remaining_distance - movement.length())
		shot["remaining"] = remaining_distance
		projectiles[index] = shot

		# Ordinary resources are ignored by arrows and never take projectile damage.
		if remaining_distance <= 0.001:
			_embed_arrow(arrow)
			projectiles.remove_at(index)

func _embed_arrow(arrow: Node2D) -> void:
	if arrow.has_method("embed"):
		arrow.call("embed")
	arrow.z_index = int(arrow.global_position.y / 16.0)
	embedded_arrows.append(arrow)
	while embedded_arrows.size() > 100:
		var oldest: Node2D = embedded_arrows.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

func _damage_target(target: ResourceNode, attack: Dictionary) -> void:
	if not is_instance_valid(target) or target.destroying:
		return
	var material := "wood" if target.resource_type == "tree" else "stone"
	var damage_type := str(attack.get("damage_type", "crushing"))
	var amount := CombatSystemScript.calculate_damage(attack, material, float(config.player.strength), config)
	if amount <= 0.0:
		return
	var destroyed := target.apply_damage(amount, damage_type)
	_spawn_damage_number(target.global_position + Vector2(0, -28), amount, damage_type)
	var type_info: Dictionary = DAMAGE_LABELS.get(damage_type, {"name": damage_type, "color": Color.WHITE})
	_log("%s: -%.0f HP (%s)." % [str(target.resource_type).capitalize(), amount, str(type_info["name"])])
	_camera_shake()
	if destroyed:
		target.begin_destroy()
		_log("%s разрушено." % str(target.resource_type).capitalize())

func _spawn_damage_number(world_position: Vector2, amount: float, damage_type: String) -> void:
	var label := Label.new()
	label.text = "-%d" % roundi(amount)
	label.position = world_position
	label.z_index = 1000
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", DAMAGE_LABELS.get(damage_type, {"color": Color.WHITE})["color"])
	label.add_theme_color_override("font_outline_color", Color("#202020"))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", world_position + Vector2(0, -30), 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.62)
	tween.chain().tween_callback(label.queue_free)

func _on_resource_broken(kind: String, drop_position: Vector2, amount: int, resource: ResourceNode) -> void:
	resources.erase(resource)
	var item_id := "wood" if kind == "wood" else "stone"
	for index in range(maxi(1, amount)):
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var speed := rng.randf_range(float(config.drops.scatter_speed_min), float(config.drops.scatter_speed_max))
		var drop := ResourceDropScript.new() as ResourceDrop
		drop.name = "Drop_%s_%03d" % [item_id, drops.size() + 1]
		drop.configure(item_id, 1, direction * speed, config.drops)
		world_objects.add_child(drop)
		drop.global_position = drop_position + Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0))
		drops.append(drop)
	_log("Выпало: %s ×%d." % [str(config.items[item_id].label), amount])
	if ui != null:
		inventory_dirty = true

func _update_drops() -> void:
	if player == null:
		return
	var magnet_radius := _get_magnet_radius()
	for drop in drops.duplicate():
		if not is_instance_valid(drop):
			drops.erase(drop)
			continue
		var distance: float = drop.global_position.distance_to(player.global_position)
		if drop.is_protected_from_player():
			drop.clear_magnet_target()
			continue
		if distance <= magnet_radius:
			drop.set_magnet_target(player)
		else:
			drop.clear_magnet_target()
		if distance <= float(drop.pickup_radius) and drop.can_collect():
			var available := int(drop.amount)
			var remaining := _inventory_add(str(drop.item_id), available)
			var collected := available - remaining
			if collected > 0:
				_log("Подобрано: %s ×%d." % [str(config.items[drop.item_id].label), collected])
			if remaining <= 0:
				drop.collect()
				drops.erase(drop)
				drop.queue_free()
			else:
				drop.amount = remaining

func _get_magnet_radius() -> float:
	return float(config.player.pickup_base_radius) + float(config.player.magnet) * float(config.player.pickup_magnet_per_level)

func _count_nearby_resources() -> int:
	var total := 0
	if world_objects == null or player == null:
		return total
	for child in world_objects.get_children():
		var resource := child as ResourceNode
		if resource != null and resource.global_position.distance_to(player.global_position) <= 240.0:
			total += 1
	return total

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

func _refresh_debug_entries() -> void:
	if ui == null:
		return
	debug_entries.clear()
	if is_instance_valid(player):
		debug_entries.append({"id": str(player.get_instance_id()), "kind": "player", "label": "Игрок", "node": player})
	if world_objects != null:
		for child in world_objects.get_children():
			var resource := child as ResourceNode
			if resource == null:
				continue
			var kind := str(resource.resource_type)
			var label := "Пень" if kind == "stump" else ("Дерево" if kind == "tree" else "Камень")
			debug_entries.append({"id": str(resource.get_instance_id()), "kind": kind, "label": "%s · %s" % [label, resource.name], "node": resource})
	for drop in drops:
		if is_instance_valid(drop):
			debug_entries.append({"id": str(drop.get_instance_id()), "kind": "drop", "label": "Предмет · %s ×%d" % [str(config.items.get(str(drop.item_id), {}).get("label", drop.item_id)), int(drop.amount)], "node": drop})
	for weapon_id in config.weapons.keys():
		debug_entries.append({"id": "weapon:" + str(weapon_id), "kind": "weapon", "label": "Оружие · " + str(weapon_id), "node": null})
	var ui_entries: Array[Dictionary] = []
	var selected_found := false
	for entry in debug_entries:
		ui_entries.append({"id": entry["id"], "kind": entry["kind"], "label": entry["label"]})
		if str(entry["id"]) == debug_selected_id:
			selected_found = true
	if not selected_found and not debug_selected_id.is_empty():
		_clear_debug_selection()
		ui_entries = []
		for entry in debug_entries:
			ui_entries.append({"id": entry["id"], "kind": entry["kind"], "label": entry["label"]})
	ui.set_debug_objects(ui_entries, debug_selected_id)

func _select_debug_target(world_position: Vector2) -> void:
	var nearest_id := ""
	var nearest_distance := 72.0
	if is_instance_valid(player) and world_position.distance_to(player.global_position) <= 30.0 and world_position.distance_to(player.global_position) < nearest_distance:
		nearest_id = str(player.get_instance_id())
		nearest_distance = world_position.distance_to(player.global_position)
	if world_objects != null:
		for child in world_objects.get_children():
			var resource := child as ResourceNode
			if resource == null:
				continue
			var selection_center: Vector2 = resource.global_position + Vector2(0, -8)
			var distance: float = world_position.distance_to(selection_center)
			var selection_radius: float = resource.hit_radius + 20.0
			if distance <= selection_radius and distance < nearest_distance:
				nearest_id = str(resource.get_instance_id())
				nearest_distance = distance
	for drop in drops:
		if is_instance_valid(drop):
			var distance: float = world_position.distance_to(drop.global_position)
			if distance <= 20.0 and distance < nearest_distance:
				nearest_id = str(drop.get_instance_id())
				nearest_distance = distance
	if nearest_id.is_empty():
		return
	debug_selected_id = nearest_id
	_update_debug_selection_highlight()
	_refresh_debug_entries()
	_update_debug_inspector()

func _on_debug_object_selected(object_id: String) -> void:
	debug_selected_id = object_id
	_update_debug_selection_highlight()
	_refresh_debug_entries()
	_update_debug_inspector()

func _update_debug_selection_highlight() -> void:
	if is_instance_valid(player):
		player.set_debug_selected(debug_selected_id == str(player.get_instance_id()))
	if world_objects != null:
		for child in world_objects.get_children():
			if child is ResourceNode:
				child.set_debug_selected(debug_selected_id == str(child.get_instance_id()))
	for drop in drops:
		if is_instance_valid(drop):
			drop.set_debug_selected(debug_selected_id == str(drop.get_instance_id()))

func _clear_debug_selection() -> void:
	debug_selected_id = ""
	_update_debug_selection_highlight()
	if ui != null:
		ui.set_debug_properties([])

func _find_debug_entry() -> Dictionary:
	for entry in debug_entries:
		if str(entry.get("id", "")) == debug_selected_id:
			return entry
	return {}

func _update_debug_inspector() -> void:
	if ui == null:
		return
	var entry := _find_debug_entry()
	if entry.is_empty():
		ui.set_debug_properties([])
		return
	var kind := str(entry.get("kind", ""))
	var node = entry.get("node")
	if kind == "player" and is_instance_valid(node):
		ui.set_debug_target("Игрок", node.current_health, float(config.player.max_health))
	elif (kind == "tree" or kind == "rock" or kind == "stump") and is_instance_valid(node):
		ui.set_debug_target(str(entry.get("label", kind)), node.health, node.max_health)
	elif kind == "drop" and is_instance_valid(node):
		ui.set_debug_target("Ресурс · %s ×%d" % [node.item_id, node.amount])
	else:
		ui.set_debug_target(str(entry.get("label", kind)))
	ui.set_debug_properties(_build_debug_properties(entry))

func _debug_property(path: String, label: String, value: float, minimum: float = -100000.0, maximum: float = 100000.0, step: float = 0.1) -> Dictionary:
	return {"path": path, "label": label, "value": value, "min": minimum, "max": maximum, "step": step}

func _build_debug_properties(entry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var kind := str(entry.get("kind", ""))
	var node = entry.get("node")
	if kind == "player" and is_instance_valid(node):
		result.append(_debug_property("player.current_health", "Текущее здоровье", node.current_health, 0.0, 5000.0, 1.0))
		result.append(_debug_property("player.max_health", "Макс. здоровье", config.player.max_health, 1.0, 5000.0, 1.0))
		result.append(_debug_property("player.current_stamina", "Выносливость", node.current_stamina, 0.0, 5000.0, 1.0))
		result.append(_debug_property("player.max_stamina", "Макс. выносливость", config.player.max_stamina, 1.0, 5000.0, 1.0))
		result.append(_debug_property("player.walk_speed", "Скорость ходьбы", config.player.walk_speed, 20.0, 1000.0, 5.0))
		result.append(_debug_property("player.run_multiplier", "Множитель бега", config.player.run_multiplier, 1.0, 5.0, 0.05))
		result.append(_debug_property("player.strength", "Сила атаки", config.player.strength, 0.0, 500.0, 1.0))
		result.append(_debug_property("player.magnet", "Навык «Магнит»", config.player.magnet, 0.0, 100.0, 0.5))
		result.append(_debug_property("player.pickup_base_radius", "Базовый радиус подбора", config.player.pickup_base_radius, 0.0, 500.0, 1.0))
		result.append(_debug_property("player.pickup_magnet_per_level", "Радиус за уровень Магнита", config.player.pickup_magnet_per_level, 0.0, 100.0, 1.0))
		result.append(_debug_property("transform.x", "Координата X", node.global_position.x, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.y", "Координата Y", node.global_position.y, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.scale_x", "Масштаб X", node.scale.x, 0.1, 5.0, 0.05))
		result.append(_debug_property("transform.scale_y", "Масштаб Y", node.scale.y, 0.1, 5.0, 0.05))
		result.append(_debug_property("transform.rotation", "Вращение", rad_to_deg(node.rotation), -360.0, 360.0, 1.0))
	elif (kind == "tree" or kind == "rock" or kind == "stump") and is_instance_valid(node):
		result.append(_debug_property("resource.health", "Текущее здоровье", node.health, 0.0, 5000.0, 1.0))
		result.append(_debug_property("resource.max_health", "Макс. здоровье", node.max_health, 1.0, 5000.0, 1.0))
		result.append(_debug_property("resource.wood_drop_amount", "Выпадение древесины", node.wood_drop_amount, 0.0, 1000.0, 1.0))
		result.append(_debug_property("resource.stone_drop_amount", "Выпадение камня", node.stone_drop_amount, 0.0, 1000.0, 1.0))
		result.append(_debug_property("resource.hit_radius", "Радиус попадания", node.hit_radius, 1.0, 300.0, 1.0))
		result.append(_debug_property("resource.swing_strength", "Сила раскачивания", node.swing_strength, 0.0, 10.0, 0.1))
		result.append(_debug_property("resource.destruction_duration", "Длительность разрушения", node.destruction_duration, 0.05, 5.0, 0.05))
		result.append(_debug_property("resource.fall_angle_degrees", "Угол падения дерева", node.fall_angle_degrees, 1.0, 120.0, 1.0))
		result.append(_debug_property("resource.resistance_cutting", "Сопротивление: режущий", node.damage_resistances.get("cutting", 1.0), 0.0, 5.0, 0.05))
		result.append(_debug_property("resource.resistance_piercing", "Сопротивление: колющий", node.damage_resistances.get("piercing", 1.0), 0.0, 5.0, 0.05))
		result.append(_debug_property("resource.resistance_crushing", "Сопротивление: дробящий", node.damage_resistances.get("crushing", 1.0), 0.0, 5.0, 0.05))
		result.append(_debug_property("transform.x", "Координата X", node.global_position.x, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.y", "Координата Y", node.global_position.y, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.scale_x", "Масштаб X", node.scale.x, 0.1, 5.0, 0.05))
		result.append(_debug_property("transform.scale_y", "Масштаб Y", node.scale.y, 0.1, 5.0, 0.05))
		result.append(_debug_property("transform.rotation", "Вращение", rad_to_deg(node.rotation), -360.0, 360.0, 1.0))
	elif kind == "drop" and is_instance_valid(node):
		result.append(_debug_property("drop.amount", "Количество", node.amount, 1.0, 9999.0, 1.0))
		result.append(_debug_property("drop.velocity_x", "Скорость X", node.velocity.x, -2000.0, 2000.0, 5.0))
		result.append(_debug_property("drop.velocity_y", "Скорость Y", node.velocity.y, -2000.0, 2000.0, 5.0))
		result.append(_debug_property("drop.gravity", "Гравитация прыжка", node.gravity, 0.0, 3000.0, 10.0))
		result.append(_debug_property("drop.friction", "Затухание движения", node.friction, 0.0, 3000.0, 10.0))
		result.append(_debug_property("drop.bounce_factor", "Сила отскока", node.bounce_factor, 0.0, 1.5, 0.01))
		result.append({"path": "drop.item_id", "label": "Тип ресурса", "value": 0 if node.item_id == "wood" else 1, "options": ["wood", "stone"]})
		result.append(_debug_property("drop.pickup_radius", "Радиус подбора", node.pickup_radius, 1.0, 200.0, 1.0))
		result.append(_debug_property("transform.x", "Координата X", node.global_position.x, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.y", "Координата Y", node.global_position.y, -5000.0, 5000.0, 1.0))
	elif kind == "weapon":
		var weapon_id := str(debug_selected_id.trim_prefix("weapon:"))
		var weapon: Dictionary = config.weapons.get(weapon_id, {})
		var damage_types := ["cutting", "piercing", "crushing"]
		if weapon_id == "sword":
			var slash: Dictionary = weapon.get("slash", {})
			var thrust: Dictionary = weapon.get("thrust", {})
			result.append(_debug_property("weapon.slash.damage", "Урон рубящего удара", slash.get("damage", 0.0), 0.0, 5000.0, 1.0))
			result.append(_debug_property("weapon.slash.cooldown", "Скорость рубящего удара", slash.get("cooldown", 0.5), 0.01, 10.0, 0.01))
			result.append(_debug_property("weapon.slash.reach", "Дальность рубящего удара", slash.get("reach", 0.0), 1.0, 500.0, 1.0))
			result.append(_debug_property("weapon.slash.stamina_cost", "Выносливость рубящего удара", slash.get("stamina_cost", 0.0), 0.0, 500.0, 1.0))
			result.append({"path": "weapon.slash.damage_type", "label": "Тип урона рубящего", "value": maxi(0, damage_types.find(str(slash.get("damage_type", "cutting")))), "options": damage_types})
			result.append(_debug_property("weapon.thrust.damage", "Урон выпада", thrust.get("damage", 0.0), 0.0, 5000.0, 1.0))
			result.append(_debug_property("weapon.thrust.cooldown", "Скорость выпада", thrust.get("cooldown", 0.31), 0.01, 10.0, 0.01))
			result.append(_debug_property("weapon.thrust.reach", "Дальность выпада", thrust.get("reach", 0.0), 1.0, 500.0, 1.0))
			result.append(_debug_property("weapon.thrust.stamina_cost", "Выносливость выпада", thrust.get("stamina_cost", 0.0), 0.0, 500.0, 1.0))
			result.append({"path": "weapon.thrust.damage_type", "label": "Тип урона выпада", "value": maxi(0, damage_types.find(str(thrust.get("damage_type", "piercing")))), "options": damage_types})
		else:
			result.append(_debug_property("weapon.damage", "Урон", weapon.get("damage", 0.0), 0.0, 5000.0, 1.0))
			result.append(_debug_property("weapon.cooldown", "Скорость атаки", weapon.get("cooldown", 0.5), 0.01, 10.0, 0.01))
			result.append({"path": "weapon.damage_type", "label": "Тип урона", "value": maxi(0, damage_types.find(str(weapon.get("damage_type", "crushing")))), "options": damage_types})
			result.append(_debug_property("weapon.reach", "Дальность атаки", weapon.get("reach", 0.0), 0.0, 1000.0, 1.0))
			result.append(_debug_property("weapon.stamina_cost", "Расход выносливости", weapon.get("stamina_cost", config.combat.attack_stamina_cost), 0.0, 500.0, 1.0))
			if weapon_id == "axe":
				result.append(_debug_property("weapon.wood_multiplier", "Эффективность по дереву", weapon.get("wood_multiplier", 0.0), 0.0, 10.0, 0.1))
			elif weapon_id == "pickaxe":
				result.append(_debug_property("weapon.stone_multiplier", "Эффективность по камню", weapon.get("stone_multiplier", 0.0), 0.0, 10.0, 0.1))
			elif weapon_id == "bow":
				result.append(_debug_property("weapon.projectile_speed", "Скорость стрелы", weapon.get("projectile_speed", 0.0), 1.0, 5000.0, 10.0))
				result.append(_debug_property("weapon.projectile_range", "Дальность стрелы", weapon.get("projectile_range", 0.0), 1.0, 5000.0, 10.0))
	return result

func _on_debug_value_changed(path: String, value: float) -> void:
	var entry := _find_debug_entry()
	if entry.is_empty():
		return
	var kind := str(entry.get("kind", ""))
	var node = entry.get("node")
	if path.begins_with("transform.") and is_instance_valid(node):
		match path:
			"transform.x":
				var position_x: Vector2 = node.global_position
				position_x.x = value
				node.global_position = position_x
			"transform.y":
				var position_y: Vector2 = node.global_position
				position_y.y = value
				node.global_position = position_y
			"transform.scale_x":
				var scale_x: Vector2 = node.scale
				scale_x.x = value
				node.scale = scale_x
			"transform.scale_y":
				var scale_y: Vector2 = node.scale
				scale_y.y = value
				node.scale = scale_y
			"transform.rotation":
				node.rotation = deg_to_rad(value)
	elif kind == "player" and is_instance_valid(node):
		match path:
			"player.current_health":
				node.current_health = clampf(value, 0.0, float(config.player.max_health))
			"player.max_health":
				config.player.max_health = value
				node.current_health = minf(node.current_health, value)
			"player.current_stamina":
				node.current_stamina = clampf(value, 0.0, float(config.player.max_stamina))
				if node.current_stamina <= 0.0:
					node.stamina_exhausted = true
			"player.max_stamina":
				config.player.max_stamina = value
				node.current_stamina = minf(node.current_stamina, value)
			"player.walk_speed":
				config.player.walk_speed = value
			"player.run_multiplier":
				config.player.run_multiplier = value
			"player.strength":
				config.player.strength = value
			"player.magnet":
				config.player.magnet = value
			"player.pickup_base_radius":
				config.player.pickup_base_radius = value
			"player.pickup_magnet_per_level":
				config.player.pickup_magnet_per_level = value
	elif (kind == "tree" or kind == "rock" or kind == "stump") and is_instance_valid(node):
		match path:
			"resource.health":
				node.health = clampf(value, 0.0, node.max_health)
				if node.health <= 0.0 and not node.destroying and node.resource_type != "stump":
					node.begin_destroy()
			"resource.max_health":
				node.max_health = value
				node.health = minf(node.health, value)
			"resource.wood_drop_amount":
				node.wood_drop_amount = roundi(value)
			"resource.stone_drop_amount":
				node.stone_drop_amount = roundi(value)
			"resource.hit_radius":
				node.hit_radius = value
			"resource.swing_strength":
				node.swing_strength = value
			"resource.destruction_duration":
				node.destruction_duration = value
			"resource.fall_angle_degrees":
				node.fall_angle_degrees = value
			"resource.resistance_cutting":
				node.damage_resistances["cutting"] = value
			"resource.resistance_piercing":
				node.damage_resistances["piercing"] = value
			"resource.resistance_crushing":
				node.damage_resistances["crushing"] = value
		node.queue_redraw()
	elif kind == "drop" and is_instance_valid(node):
		match path:
			"drop.amount":
				node.amount = maxi(1, roundi(value))
			"drop.velocity_x":
				var drop_velocity_x: Vector2 = node.velocity
				drop_velocity_x.x = value
				node.velocity = drop_velocity_x
			"drop.velocity_y":
				var drop_velocity_y: Vector2 = node.velocity
				drop_velocity_y.y = value
			"drop.item_id":
				node.item_id = "wood" if value < 0.5 else "stone"
			"drop.gravity":
				node.gravity = value
			"drop.friction":
				node.friction = value
			"drop.bounce_factor":
				node.bounce_factor = value
			"drop.pickup_radius":
				node.pickup_radius = value
	elif kind == "weapon":
		var weapon_id := str(debug_selected_id.trim_prefix("weapon:"))
		var weapon: Dictionary = config.weapons.get(weapon_id, {})
		var parts := path.split(".")
		if parts.size() == 2:
			if parts[1] == "damage_type":
				var damage_types := ["cutting", "piercing", "crushing"]
				weapon[parts[1]] = damage_types[clampi(roundi(value), 0, damage_types.size() - 1)]
			else:
				weapon[parts[1]] = value
		elif parts.size() == 3:
			var nested: Dictionary = weapon.get(parts[1], {})
			if parts[2] == "damage_type":
				var nested_types := ["cutting", "piercing", "crushing"]
				nested[parts[2]] = nested_types[clampi(roundi(value), 0, nested_types.size() - 1)]
			else:
				nested[parts[2]] = value
			weapon[parts[1]] = nested
		config.weapons[weapon_id] = weapon
	if node is CanvasItem:
		node.queue_redraw()
	_update_resource_counts()
	inventory_dirty = true
	_update_debug_inspector()

func _on_debug_mode_requested(enabled: bool) -> void:
	if ui == null:
		return
	if enabled:
		if ui.current_panel != "debug":
			ui.toggle_panel("debug")
			player.set_debug_selected(true)
			debug_selected_id = str(player.get_instance_id())
			_refresh_debug_entries()
			_update_debug_inspector()
			ui.set_debug_cheats(player.debug_infinite_stamina, player.debug_invulnerable)
	else:
		if ui.current_panel == "debug":
			ui.close_panels()
		_clear_debug_selection()
	ui.set_debug_mode_enabled(enabled)

func _on_debug_cheats_changed(infinite_stamina: bool, invulnerable: bool) -> void:
	player.debug_infinite_stamina = infinite_stamina
	player.debug_invulnerable = invulnerable

func _clone_debug_selection() -> void:
	var entry := _find_debug_entry()
	if entry.is_empty():
		return
	var source = entry.get("node")
	if not is_instance_valid(source) or source == player:
		_log("Этот объект нельзя клонировать.")
		return
	var clone = source.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
	if clone == null:
		return
	clone.name = str(source.name) + "_Copy"
	source.get_parent().add_child(clone)
	clone.global_position = source.global_position + Vector2(34, 0)
	if clone is ResourceNode:
		if clone.resource_type != "stump":
			_register_resource(clone)
	elif clone is ResourceDrop:
		clone.picked = false
		clone.clear_magnet_target()
		drops.append(clone)
	debug_selected_id = str(clone.get_instance_id())
	_refresh_debug_entries()
	_update_debug_selection_highlight()
	_update_debug_inspector()

func _delete_debug_selection() -> void:
	var entry := _find_debug_entry()
	if entry.is_empty():
		return
	var target = entry.get("node")
	if not is_instance_valid(target) or target == player:
		return
	if target is ResourceNode:
		resources.erase(target)
	if target is ResourceDrop:
		drops.erase(target)
	target.queue_free()
	_clear_debug_selection()
	_refresh_debug_entries()
	_log("Объект удалён из текущей игровой сессии.")

func _reset_debug_selection() -> void:
	var entry := _find_debug_entry()
	if entry.is_empty():
		return
	var kind := str(entry.get("kind", ""))
	var node = entry.get("node")
	if kind == "player" and is_instance_valid(node):
		config.player = defaults_config.player.duplicate(true)
		node.configure(config)
	elif (kind == "tree" or kind == "rock" or kind == "stump") and is_instance_valid(node):
		var original_kind := "tree" if kind == "stump" else kind
		node.resource_type = original_kind
		node.max_health = float(config.resources.tree_health if original_kind == "tree" else config.resources.rock_health)
		node.health = node.max_health
		node.wood_drop_amount = int(config.resources.tree_wood_drop)
		node.stone_drop_amount = int(config.resources.rock_stone_drop)
		node.hit_radius = float(config.resources.tree_hit_radius if original_kind == "tree" else config.resources.rock_hit_radius)
		node.swing_strength = 1.0
		node.destruction_duration = 0.48
		node.fall_angle_degrees = 78.0
		node.damage_resistances = {"cutting": 1.0, "piercing": 1.0, "crushing": 1.0}
		node.scale = Vector2.ONE
		node.rotation = 0.0
		node.modulate = Color.WHITE
		node.destroying = false
		var collision := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			collision.set_deferred("disabled", false)
	elif kind == "drop" and is_instance_valid(node):
		node.item_id = node.default_item_id
		node.amount = node.default_amount
		node.velocity = node.default_velocity
		node.gravity = float(config.drops.gravity)
		node.friction = float(config.drops.horizontal_friction)
		node.bounce_factor = float(config.drops.bounce_factor)
		node.pickup_radius = float(config.drops.pickup_distance)
	elif kind == "weapon":
		var weapon_id := str(debug_selected_id.trim_prefix("weapon:"))
		config.weapons[weapon_id] = defaults_config.weapons[weapon_id].duplicate(true)
	_refresh_debug_entries()
	_update_debug_inspector()
	_log("Параметры выбранного объекта сброшены.")

func _log(message: String) -> void:
	print("[game] " + message)
	if ui != null:
		ui.add_log(message)
