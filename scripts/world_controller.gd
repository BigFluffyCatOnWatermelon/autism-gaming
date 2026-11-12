extends Node2D

const GameConfigScript = preload("res://scripts/game_config.gd")
const ItemCatalogServiceScript = preload("res://scripts/item_catalog_service.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const PlayerControllerScript = preload("res://scripts/player_controller.gd")
const ResourceDropScript = preload("res://scripts/resource_drop.gd")
const ArrowProjectileScript = preload("res://scripts/arrow_projectile.gd")
const ObjectFactoryScript = preload("res://scripts/object_system/object_factory.gd")
const ItemStackServiceScript = preload("res://scripts/object_system/object_item_stack_service.gd")
const ObjectsScene = preload("res://scenes/objects.tscn")
const UIScene = preload("res://scenes/ui.tscn")

const WORLD_Z_SORT_OFFSET := 2048

const DAMAGE_LABELS := {
	"cutting": {"name": "режущий", "color": Color("#ffe0a0")},
	"piercing": {"name": "колющий", "color": Color("#bfe8ff")},
	"crushing": {"name": "дробящий", "color": Color("#d8d2ff")},
}

var config: Dictionary = {}
var defaults_config: Dictionary = {}
var player
var ui
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
var debug_selected_inventory_slot := -1
var debug_object_selection_enabled := true
var debug_refresh_timer := 0.0
var _pickup_scan_timer := 0.0
var _mechanic_signal_scan_timer := 0.0
var _camera_shake_strength_override := -1.0
var _world_time_day := 1
var _world_time_hour := 8.0
var _last_dispatched_world_day := -1
var _last_dispatched_world_hour := -1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	config = GameConfigScript.make_default()
	_world_time_day = maxi(1, int(config.world.get("start_day", 1)))
	_world_time_hour = fposmod(float(config.world.get("start_hour", 8.0)), 24.0)
	defaults_config = config.duplicate(true)
	backpack_slots = int(config.inventory.base_backpack_slots)
	rng.seed = int(config.world.seed)
	_initialize_inventory()
	_configure_input()
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
	_add_key_action("interact", [KEY_E])
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

func _create_resources() -> void:
	world_objects = get_node_or_null("Objects") as Node2D
	if world_objects == null:
		world_objects = ObjectsScene.instantiate() as Node2D
		if world_objects == null:
			push_error("Не удалось создать пустой контейнер Objects.")
			return
		world_objects.name = "Objects"
		add_child(world_objects)

	# Resource scenes can be dropped into Objects, Terrain or directly into World.
	# Search the complete world subtree so their parent node does not affect combat.
	resources.clear()
	_register_resources_recursive(self)
	_watch_resource_tree(self)
	print("Разрушаемые объекты зарегистрированы: ", resources.size())


func _register_resources_recursive(root: Node) -> void:
	var resource := root as ResourceNode
	if resource != null and resource.resource_type != "stump":
		_register_resource(resource)
	for child in root.get_children():
		_register_resources_recursive(child)


func _watch_resource_tree(root: Node) -> void:
	var callback := Callable(self, "_on_resource_child_entered_tree")
	if not root.child_entered_tree.is_connected(callback):
		root.child_entered_tree.connect(callback)
	for child in root.get_children():
		_watch_resource_tree(child)


func _on_resource_child_entered_tree(child: Node) -> void:
	# Also support scenes instantiated after the world has already started.
	_register_resources_recursive(child)
	_watch_resource_tree(child)


func _get_resource_nodes() -> Array[ResourceNode]:
	var result: Array[ResourceNode] = []
	_collect_resource_nodes(self, result)
	return result


func _collect_resource_nodes(root: Node, result: Array[ResourceNode]) -> void:
	for child in root.get_children():
		var resource := child as ResourceNode
		if resource != null:
			result.append(resource)
		_collect_resource_nodes(child, result)


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
	ui.debug_selection_mode_changed.connect(_on_debug_selection_mode_changed)
	ui.inventory_slot_dropped.connect(_move_inventory_slot)
	ui.debug_object_selected.connect(_on_debug_object_selected)
	ui.debug_clone_requested.connect(_clone_debug_selection)
	ui.debug_delete_requested.connect(_delete_debug_selection)
	ui.debug_reset_requested.connect(_reset_debug_selection)
	ui.debug_cheats_changed.connect(_on_debug_cheats_changed)
	ui.debug_default_requested.connect(_save_item_catalog_default)
	ui.debug_item_save_requested.connect(_save_selected_item_catalog)
	ui.debug_inventory_item_selected.connect(_on_debug_inventory_item_selected)
	ui.debug_spawn_item_requested.connect(_spawn_debug_item)
	ui.set_debug_item_catalog(config.items, config.item_categories)
	ui.set_backpack_slots(backpack_slots, int(config.inventory.max_backpack_slots))
	ui.set_hotbar_selection(selected_slot)
	ui.set_inventory_data(inventory, backpack_slots, int(config.inventory.max_backpack_slots), config.items)
	ui.set_player_data(player.current_health, float(config.player.max_health), player.current_stamina, float(config.player.max_stamina), arrow_count)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_finite(delta) or delta <= 0.0:
		return
	_update_ai_mechanics(delta)


func _update_health_regeneration(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	for health_component in _get_world_components("health"):
		if health_component != null and is_instance_valid(health_component) and health_component.has_method("tick_regeneration"):
			health_component.call("tick_regeneration", delta)


func _update_destruction_regrowth(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	for regrowth_component in _get_world_components("can_regrow"):
		if regrowth_component == null or not is_instance_valid(regrowth_component):
			continue
		var root := ObjectFactoryScript.get_object_root(regrowth_component)
		if root == null or not is_instance_valid(root) or root.is_queued_for_deletion():
			continue
		if not bool(root.get_meta("object_destroyed", false)):
			continue
		if regrowth_component.has_method("tick_regrowth"):
			regrowth_component.call("tick_regrowth", delta)


func _update_ai_mechanics(delta: float) -> void:
	for ai_component in _get_world_components("has_ai"):
		if ai_component == null or not is_instance_valid(ai_component) or not ai_component.has_method("get_ai_intent"):
			continue
		var root := ObjectFactoryScript.get_object_root(ai_component)
		if root == null or not is_instance_valid(root) or root.is_queued_for_deletion():
			continue
		var intent_value: Variant = ai_component.call("get_ai_intent", delta, [], [])
		if not intent_value is Dictionary:
			continue
		var intent: Dictionary = intent_value
		var state := str(intent.get("state", "idle"))
		if state not in ["patrol", "wander", "chase", "follow", "flee", "assist"]:
			continue
		var direction_value: Variant = intent.get("direction", Vector2.ZERO)
		if not direction_value is Vector2:
			continue
		var direction: Vector2 = direction_value
		if direction.length_squared() <= 0.0001:
			continue
		var movement := ObjectFactoryScript.get_component(root, "can_move")
		if movement == null:
			movement = ObjectFactoryScript.get_component(root, "can_walk")
		if movement == null:
			continue
		var preferred_speed := float(intent.get("preferred_speed", -1.0))
		if preferred_speed >= 0.0 and movement.has_method("move_direction_with_speed"):
			movement.call("move_direction_with_speed", direction, preferred_speed, delta)
		elif movement.has_method("move_direction"):
			movement.call("move_direction", direction, delta)
		elif movement.has_method("walk"):
			movement.call("walk", direction, delta)


func _process(delta: float) -> void:
	_handle_hotkeys()
	_update_attack_cooldowns(delta)
	_handle_held_combat()
	_update_projectiles(delta)
	_update_drops()
	_update_health_regeneration(delta)
	_update_destruction_regrowth(delta)
	_update_animal_mechanics(delta)
	_update_world_clock(delta)
	_update_construction_mechanics(delta)
	_mechanic_signal_scan_timer -= delta
	if _mechanic_signal_scan_timer <= 0.0:
		_bind_world_mechanic_signals()
		_mechanic_signal_scan_timer = 0.5
	_pickup_scan_timer -= delta
	if _pickup_scan_timer <= 0.0:
		_update_component_pickups()
		_pickup_scan_timer = 0.12
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
	if player == null or ui == null:
		return
	if ui.has_modal_open() and not _debug_world_interaction_allowed():
		return
	var primary_pressed := Input.is_action_pressed("attack_primary")
	var secondary_pressed := Input.is_action_pressed("attack_secondary")
	if not primary_pressed and not secondary_pressed:
		return

	var selected_item := _get_selected_item_id()
	if selected_item == "bow":
		_fire_arrow(config.weapons.get("bow", {}))
		return
	if selected_item == "arrows":
		# Ammunition is not a weapon; selecting arrows never fires.
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
	var aim_direction: Vector2 = (get_global_mouse_position() - player.get_aim_position()).normalized()
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
			ui.set_debug_selection_mode_enabled(true)
			player.set_debug_selected(true)
			debug_selected_id = str(player.get_instance_id())
			_refresh_debug_entries()
			_update_debug_inspector()
			ui.set_debug_cheats(player.debug_infinite_stamina, player.debug_invulnerable)
		else:
			_clear_debug_selection()
	if Input.is_action_just_pressed("logs"):
		ui.toggle_panel("logs")
	if Input.is_action_just_pressed("interact"):
		if ui == null or not ui.has_modal_open() or _debug_world_interaction_allowed():
			_try_interact_with_nearest()
	if Input.is_action_just_pressed("drop_item") and not ui.has_modal_open():
		_drop_selected_item()
	for index in range(9):
		if Input.is_action_just_pressed("slot_%d" % (index + 1)):
			_on_slot_selected(index)

func _unhandled_input(event: InputEvent) -> void:
	var debug_panel_open: bool = ui != null and ui.current_panel == "debug"
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if debug_panel_open and debug_object_selection_enabled:
			_select_debug_target(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if ui != null and ui.has_modal_open() and not _debug_world_interaction_allowed():
			return
		_attack(false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if ui != null and ui.has_modal_open() and not _debug_world_interaction_allowed():
			return
		_attack(true)


func _debug_world_interaction_allowed() -> bool:
	if ui == null or ui.current_panel != "debug" or debug_object_selection_enabled:
		return false
	var debug_panel := ui.panels.get("debug") as Control
	if debug_panel == null:
		return true
	return not debug_panel.get_global_rect().has_point(get_viewport().get_mouse_position())

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
	var ground_position: Vector2 = player.get_ground_position()
	var direction: Vector2 = get_global_mouse_position() - ground_position
	if direction.length_squared() < 0.001:
		direction = player.last_move_direction
	if direction.length_squared() < 0.001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	# Tosses start at the feet, on the same ground plane used for pickup.
	var spawn_position: Vector2 = ground_position + direction * 8.0
	_drop_inventory_item(selected_slot, spawn_position)

func _drop_inventory_item(slot_index: int, drop_position: Vector2) -> void:
	if player == null or world_objects == null or not _inventory_slot_unlocked(slot_index):
		return
	var stack: Dictionary = inventory[slot_index]
	var item_id := str(stack.get("id", ""))
	var amount := int(stack.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return
	var ground_position: Vector2 = player.get_ground_position()
	var direction: Vector2 = drop_position - ground_position
	if direction.length_squared() < 0.001:
		direction = player.last_move_direction
	if direction.length_squared() < 0.001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	# Cursor position determines direction only; the drop always starts at the feet.
	drop_position = ground_position + direction * 8.0
	var dropped := ResourceDropScript.new() as ResourceDrop
	dropped.name = "Dropped_%s_%03d" % [item_id, drops.size() + 1]
	var definition := config.item_definitions.get(item_id) as ItemDefinition
	dropped.configure(item_id, amount, direction * 220.0, config.drops, definition)
	world_objects.add_child(dropped)
	dropped.global_position = drop_position
	dropped.protect_from_player(ground_position, 14.0)
	drops.append(dropped)
	inventory[slot_index] = {"id": "", "amount": 0}
	inventory_dirty = true
	_update_resource_counts()
	_log("Выброшено: %s ×%d." % [str(config.items.get(item_id, {}).get("label", item_id)), amount])

func _spawn_debug_item(item_id: String, amount: int) -> void:
	var definition := config.item_definitions.get(item_id) as ItemDefinition
	if definition == null or player == null:
		_log("Неизвестный предмет: %s." % item_id)
		return
	if world_objects == null:
		world_objects = self
	var spawn_position: Vector2 = get_global_mouse_position()
	var direction: Vector2 = spawn_position - player.get_ground_position()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()

	var remaining := maxi(1, amount)
	var spawned_nodes: Array[ResourceDrop] = []
	var stack_limit := maxi(1, definition.stack_limit)
	while remaining > 0:
		var stack_amount := mini(stack_limit, remaining)
		var spawned := ResourceDropScript.new() as ResourceDrop
		spawned.name = "DebugSpawn_%s_%03d" % [item_id, drops.size() + 1]
		spawned.configure(item_id, stack_amount, direction * 70.0, config.drops, definition)
		world_objects.add_child(spawned)
		var offset_index := spawned_nodes.size()
		spawned.global_position = spawn_position + Vector2(offset_index * 10.0, offset_index * 6.0)
		spawned.protect_from_player(player.get_ground_position(), 14.0)
		drops.append(spawned)
		spawned_nodes.append(spawned)
		remaining -= stack_amount

	if not spawned_nodes.is_empty():
		debug_selected_id = str(spawned_nodes.back().get_instance_id())
	_refresh_debug_entries()
	_update_debug_selection_highlight()
	_update_debug_inspector()
	var object_count := spawned_nodes.size()
	_log("В мир добавлено: %s ×%d (%d отдельных объектов)." % [definition.display_name, amount, object_count])


func _save_selected_item_catalog() -> void:
	var entry := _find_debug_entry()
	var node = entry.get("node")
	var item_id := str(entry.get("item_id", ""))
	if item_id.is_empty() and is_instance_valid(node) and node is ResourceDrop:
		item_id = str(node.item_id)
	if item_id.is_empty():
		_log("Сначала выбери предмет в инвентаре или в мире.")
		return
	var definition := config.item_definitions.get(item_id) as ItemDefinition
	var catalog := config.item_catalog_by_id.get(item_id) as ItemCatalog
	if definition == null or catalog == null or catalog.resource_path.is_empty():
		_log("У выбранного предмета нет доступного файла каталога.")
		return
	var save_error := ResourceSaver.save(catalog, catalog.resource_path)
	if save_error != OK:
		_log("Не удалось сохранить %s (код %d)." % [catalog.resource_path, save_error])
		return
	_sync_item_definition_to_runtime(item_id, definition)
	defaults_config = config.duplicate(true)
	_log("Предмет сохранён в базу: %s." % catalog.resource_path)
	_refresh_debug_entries()
	_update_debug_inspector()
func _sync_item_definition_to_runtime(item_id: String, definition: ItemDefinition) -> void:
	config.items[item_id] = ItemCatalogServiceScript.rebuild_item_data(definition)
	if not definition.combat_stats.is_empty():
		config.weapons[item_id] = definition.combat_stats.duplicate(true)
	for drop in drops:
		if is_instance_valid(drop) and str(drop.item_id) == item_id:
			drop.set_item_definition(item_id, definition, drop.amount)
			drop.default_definition = definition.duplicate(true)
			drop.default_item_id = item_id


func _save_item_catalog_default(path: String, value: Variant) -> void:
	var entry := _find_debug_entry()
	var node = entry.get("node")
	var item_id := str(entry.get("item_id", ""))
	if item_id.is_empty() and is_instance_valid(node) and node is ResourceDrop:
		item_id = str(node.item_id)
	if item_id.is_empty():
		_log("Сначала выбери предмет в инвентаре или в мире.")
		return
	var definition := config.item_definitions.get(item_id) as ItemDefinition
	var catalog := config.item_catalog_by_id.get(item_id) as ItemCatalog
	if definition == null or catalog == null or catalog.resource_path.is_empty():
		_log("Для этого предмета не найден файл каталога.")
		return

	var old_combat := definition.combat_stats.duplicate(true)
	var old_properties := definition.properties.duplicate(true)
	var old_stack_limit := definition.stack_limit
	if path == "item.stack_limit":
		definition.stack_limit = maxi(1, roundi(float(value)))
	elif path.begins_with("item.combat."):
		var parts := path.trim_prefix("item.combat.").split(".")
		var stored_value: Variant = value
		if parts.size() > 0 and parts[parts.size() - 1] == "damage_type":
			var damage_types := ["cutting", "piercing", "crushing"]
			stored_value = damage_types[clampi(roundi(float(value)), 0, damage_types.size() - 1)]
		if not _set_nested_item_dictionary(definition.combat_stats, parts, stored_value):
			_log("Неизвестная характеристика: %s." % path)
			return
	elif path.begins_with("item.properties."):
		var parts := path.trim_prefix("item.properties.").split(".")
		if not _set_nested_item_dictionary(definition.properties, parts, value):
			_log("Неизвестная характеристика: %s." % path)
			return
	else:
		_log("Этот параметр не хранится в каталоге предметов.")
		return

	var save_error := ResourceSaver.save(catalog, catalog.resource_path)
	if save_error != OK:
		definition.combat_stats = old_combat
		definition.properties = old_properties
		definition.stack_limit = old_stack_limit
		config.items[item_id] = ItemCatalogServiceScript.rebuild_item_data(definition)
		if not definition.combat_stats.is_empty():
			config.weapons[item_id] = definition.combat_stats.duplicate(true)
		_log("Не удалось записать %s (код %d)." % [catalog.resource_path, save_error])
		return

	_sync_item_definition_to_runtime(item_id, definition)
	defaults_config = config.duplicate(true)
	_log("Значение сохранено в базе: %s." % catalog.resource_path)
	_refresh_debug_entries()
	_update_debug_inspector()
func _set_nested_item_dictionary(target: Dictionary, path_parts: PackedStringArray, value: Variant) -> bool:
	if path_parts.is_empty():
		return false
	var current: Dictionary = target
	for index in range(path_parts.size() - 1):
		var next_value: Variant = current.get(path_parts[index])
		if not next_value is Dictionary:
			return false
		current = next_value
	current[path_parts[path_parts.size() - 1]] = value
	return true


func _inventory_slot_unlocked(index: int) -> bool:
	if index < int(config.inventory.hotbar_slots):
		return true
	return index < int(config.inventory.hotbar_slots) + backpack_slots

func _inventory_add(item_id: String, quantity: int) -> int:
	var remaining := maxi(0, quantity)
	if item_id.is_empty() or remaining == 0:
		return remaining
	var max_stack := maxi(1, int(config.items.get(item_id, {}).get("max_stack", config.inventory.max_stack)))
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

## Inventory adapter used by Object Builder construction and transfer mechanics.
## Exposes the same item-stack data contract as object inventories and containers.
func get_item_count(item_id: String) -> int:
	return _get_item_count(item_id)


func get_item_stacks(_options: Dictionary = {}) -> Array[Dictionary]:
	return ItemStackServiceScript.normalize_items(get_inventory())


func get_total_weight() -> float:
	return ItemStackServiceScript.total_weight(get_inventory())


func remove_item(item_id: String, amount: int = 1, _allow_bound: bool = false) -> bool:
	return _consume_item(item_id, amount)


func remove_item_data(item_id: String, amount: int = 1, _options: Dictionary = {}) -> Dictionary:
	var remove_result := ItemStackServiceScript.remove_stack(
		get_item_stacks(),
		item_id,
		amount,
		false,
		false
	)
	if not bool(remove_result.get("ok", false)):
		return {"ok": false, "removed": 0, "remainder": maxi(0, amount), "items": []}
	if not _consume_item(item_id, amount):
		return {"ok": false, "removed": 0, "remainder": amount, "items": []}
	return {
		"ok": true,
		"removed": int(remove_result.get("removed", amount)),
		"remainder": 0,
		"items": remove_result.get("removed_items", [])
	}


func add_item(
	item_id: String,
	amount: int = 1,
	max_stack: int = -1,
	weight: float = 0.0,
	tags: Array = [],
	rarity: String = "common"
) -> Dictionary:
	return add_item_data({
		"item_id": item_id,
		"amount": amount,
		"max_stack": max_stack if max_stack > 0 else int(config.items.get(item_id, {}).get("max_stack", config.inventory.max_stack)),
		"weight": weight,
		"tags": tags,
		"rarity": rarity
	})


func add_item_data(item_data: Dictionary, amount_override: int = -1, _options: Dictionary = {}) -> Dictionary:
	var stack := ItemStackServiceScript.normalize_item(item_data, 1)
	if stack.is_empty():
		return {"ok": false, "accepted": 0, "remainder": maxi(0, int(item_data.get("amount", 0))), "error": "Некорректная запись предмета."}
	if amount_override >= 0:
		stack["amount"] = amount_override
	var requested := int(stack.get("amount", 0))
	if requested <= 0:
		return {"ok": false, "accepted": 0, "remainder": maxi(0, requested), "error": "Количество предмета должно быть положительным."}
	var remaining := _inventory_add(str(stack.get("item_id", "")), requested)
	return {"ok": remaining == 0, "accepted": requested - remaining, "remainder": remaining}


func _has_mechanic(mechanic_id: String) -> bool:
	return mechanic_id.strip_edges().to_lower() in ["has_inventory", "supports_quick_transfer"]


func transfer_object_inventory_to_player(
	source_root: Node,
	item_id: String,
	amount: int
) -> Dictionary:
	if source_root == null or not is_instance_valid(source_root):
		return {"ok": false, "transferred": 0, "remainder": maxi(0, amount)}
	var source_inventory := ObjectFactoryScript.get_component(source_root, "has_inventory")
	if source_inventory == null or not source_inventory.has_method("transfer_to"):
		return {"ok": false, "transferred": 0, "remainder": amount}
	var transfer_value: Variant = source_inventory.call("transfer_to", self, item_id, amount)
	return transfer_value if transfer_value is Dictionary else {"ok": false, "transferred": 0, "remainder": amount}


func transfer_player_item_to_object_inventory(
	target_root: Node,
	item_id: String,
	amount: int
) -> Dictionary:
	if target_root == null or not is_instance_valid(target_root) or amount <= 0:
		return {"ok": false, "transferred": 0, "remainder": maxi(0, amount)}
	var target_inventory := ObjectFactoryScript.get_component(target_root, "has_inventory")
	if target_inventory == null or not target_inventory.has_method("add_item_data"):
		return {"ok": false, "transferred": 0, "remainder": amount}
	var available := mini(amount, _get_item_count(item_id))
	if available <= 0:
		return {"ok": false, "transferred": 0, "remainder": amount}
	var item_settings: Dictionary = config.items.get(item_id, {})
	var item_stack := {
		"item_id": item_id,
		"amount": available,
		"max_stack": maxi(1, int(item_settings.get("max_stack", config.inventory.max_stack))),
		"weight": maxf(0.0, float(item_settings.get("weight", 0.0))),
		"tags": item_settings.get("tags", []).duplicate(true) if item_settings.get("tags", []) is Array else [],
		"rarity": str(item_settings.get("rarity", "common"))
	}
	var added_value: Variant = target_inventory.call("add_item_data", item_stack, available)
	if not added_value is Dictionary:
		return {"ok": false, "transferred": 0, "remainder": amount}
	var accepted := clampi(int(added_value.get("accepted", 0)), 0, available)
	if accepted <= 0:
		return {"ok": false, "transferred": 0, "remainder": amount}
	if not _consume_item(item_id, accepted):
		if target_inventory.has_method("remove_item_data"):
			target_inventory.call("remove_item_data", item_id, accepted, {"allow_bound": true})
		elif target_inventory.has_method("remove_item"):
			target_inventory.call("remove_item", item_id, accepted, true)
		return {"ok": false, "transferred": 0, "remainder": amount}
	return {"ok": accepted == amount, "transferred": accepted, "remainder": amount - accepted}


func get_inventory() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in inventory:
		var item_id := str(slot.get("id", ""))
		var amount := int(slot.get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			continue
		var item_data: Dictionary = config.items.get(item_id, {})
		result.append({
			"item_id": item_id,
			"amount": amount,
			"max_stack": maxi(1, int(item_data.get("max_stack", config.inventory.max_stack))),
			"weight": maxf(0.0, float(item_data.get("weight", 0.0))),
			"tags": item_data.get("tags", []).duplicate(true) if item_data.get("tags", []) is Array else [],
			"rarity": str(item_data.get("rarity", "common"))
		})
	return result


func deposit_item_to_container(
	container_root: Node,
	item_id: String,
	amount: int,
	actor_id: String = "player",
	faction_id: String = ""
) -> Dictionary:
	if container_root == null or not is_instance_valid(container_root) or amount <= 0:
		return {"ok": false, "accepted": 0, "remainder": maxi(0, amount)}
	var container := ObjectFactoryScript.get_component(container_root, "stores_items")
	if container == null or not container.has_method("add_item_data"):
		return {"ok": false, "accepted": 0, "remainder": amount}
	var available := mini(amount, _get_item_count(item_id))
	if available <= 0:
		return {"ok": false, "accepted": 0, "remainder": amount}
	var item_settings: Dictionary = config.items.get(item_id, {})
	var item_stack := {
		"item_id": item_id,
		"amount": available,
		"max_stack": maxi(1, int(item_settings.get("max_stack", config.inventory.max_stack))),
		"weight": maxf(0.0, float(item_settings.get("weight", 0.0))),
		"tags": item_settings.get("tags", []).duplicate(true) if item_settings.get("tags", []) is Array else [],
		"rarity": str(item_settings.get("rarity", "common"))
	}
	var previous_state_value: Variant = container.call("export_runtime_state") if container.has_method("export_runtime_state") else {}
	var previous_state: Dictionary = previous_state_value if previous_state_value is Dictionary else {}
	var result_value: Variant = container.call(
		"add_item_data",
		item_stack,
		available,
		{"actor_id": actor_id, "faction_id": faction_id}
	)
	if not result_value is Dictionary:
		return {"ok": false, "accepted": 0, "remainder": amount}
	var result: Dictionary = result_value
	var accepted := clampi(int(result.get("accepted", 0)), 0, available)
	if accepted <= 0:
		return {"ok": false, "accepted": 0, "remainder": amount}
	if not _consume_item(item_id, accepted):
		if not previous_state.is_empty() and container.has_method("import_runtime_state"):
			container.call("import_runtime_state", previous_state)
		return {"ok": false, "accepted": 0, "remainder": amount}
	return {"ok": accepted == amount, "accepted": accepted, "remainder": amount - accepted}


func withdraw_item_from_container(
	container_root: Node,
	item_id: String,
	amount: int,
	actor_id: String = "player",
	faction_id: String = ""
) -> Dictionary:
	if container_root == null or not is_instance_valid(container_root) or amount <= 0:
		return {"ok": false, "accepted": 0, "remainder": maxi(0, amount)}
	var container := ObjectFactoryScript.get_component(container_root, "stores_items")
	if container == null or not container.has_method("get_item_stacks") or not container.has_method("remove_item_data"):
		return {"ok": false, "accepted": 0, "remainder": amount}
	var contents_value: Variant = container.call("get_item_stacks", {"actor_id": actor_id, "faction_id": faction_id})
	if not contents_value is Array:
		return {"ok": false, "accepted": 0, "remainder": amount}
	var available := ItemStackServiceScript.count_items(contents_value, item_id)
	available = mini(available, amount)
	if available <= 0:
		return {"ok": false, "accepted": 0, "remainder": amount}
	var inventory_before := inventory.duplicate(true)
	var remaining := _inventory_add(item_id, available)
	var accepted := available - remaining
	if accepted <= 0:
		return {"ok": false, "accepted": 0, "remainder": amount}
	var remove_value: Variant = container.call(
		"remove_item_data",
		item_id,
		accepted,
		{"actor_id": actor_id, "faction_id": faction_id}
	)
	if not remove_value is Dictionary or not bool(remove_value.get("ok", false)):
		inventory = inventory_before
		inventory_dirty = true
		_update_resource_counts()
		return {"ok": false, "accepted": 0, "remainder": amount}
	return {"ok": accepted == amount, "accepted": accepted, "remainder": amount - accepted}


func place_constructed_object(
	definition: ObjectDefinition,
	position: Vector2,
	blockers: Array = [],
	terrain_id: String = ""
) -> Node2D:
	if definition == null or world_objects == null:
		return null
	var instance := ObjectFactoryScript.instantiate(definition)
	if not instance is Node2D:
		if instance != null:
			instance.free()
		return null
	var placement := ObjectFactoryScript.get_component(instance, "can_be_placed")
	if placement == null or not placement.has_method("can_be_placed"):
		instance.free()
		return null
	if not bool(placement.call("can_be_placed", position, blockers, terrain_id)):
		instance.free()
		return null
	var snapped_value: Variant = placement.call("snap_position", position)
	if not snapped_value is Vector2:
		instance.free()
		return null
	var snapped_position: Vector2 = snapped_value
	var materials := ObjectFactoryScript.get_component(instance, "requires_build_materials")
	if materials != null and materials.has_method("consume_build_materials"):
		if not bool(materials.call("consume_build_materials", self)):
			instance.free()
			return null
	world_objects.add_child(instance)
	(instance as Node2D).global_position = snapped_position
	if ObjectFactoryScript.get_component(instance, "has_build_stages") != null:
		instance.set_meta("object_builder_build_in_progress", true)
		instance.set_meta("object_builder_built", false)
	return instance as Node2D


func get_construction_preview_state(
	definition: ObjectDefinition,
	position: Vector2,
	blockers: Array = [],
	terrain_id: String = ""
) -> Dictionary:
	if definition == null:
		return {"valid": false, "error": "Не передано определение объекта."}
	var preview_object := ObjectFactoryScript.instantiate(definition)
	if preview_object == null:
		return {"valid": false, "error": "Не удалось создать временный объект для preview."}
	var construction := ObjectFactoryScript.get_component(preview_object, "supports_build_preview")
	if construction == null or not construction.has_method("get_preview_state"):
		preview_object.free()
		return {"valid": false, "error": "У объекта не включён предпросмотр строительства."}
	var result_value: Variant = construction.call("get_preview_state", position, blockers, terrain_id)
	preview_object.free()
	return result_value if result_value is Dictionary else {"valid": false, "error": "Preview вернул некорректные данные."}


func generate_objects_from_definition(
	definition: ObjectDefinition,
	bounds: Rect2,
	context: Dictionary = {},
	seed_override: int = -1
) -> Array[Node2D]:
	var spawned: Array[Node2D] = []
	if definition == null or world_objects == null:
		return spawned
	var prototype := ObjectFactoryScript.instantiate(definition)
	if prototype == null:
		return spawned
	var generator := ObjectFactoryScript.get_component(prototype, "has_procedural_layout")
	if generator == null:
		generator = ObjectFactoryScript.get_component(prototype, "has_spawn_conditions")
	if generator == null or not generator.has_method("generate_layout"):
		prototype.free()
		return spawned
	var resolved_seed := seed_override
	if resolved_seed < 0 and generator.has_method("get_world_seed"):
		resolved_seed = int(generator.call("get_world_seed"))
	if resolved_seed < 0:
		resolved_seed = int(config.world.seed)
	var positions_value: Variant = generator.call("generate_layout", bounds, resolved_seed)
	if not positions_value is Array:
		prototype.free()
		return spawned
	var region_id := str(context.get("region", "")).strip_edges().to_lower()
	var biome_id := str(context.get("biome", "")).strip_edges().to_lower()
	var current_count := _count_generated_objects(definition.object_id, region_id)
	for index in range(positions_value.size()):
		var position_value: Variant = positions_value[index]
		if not position_value is Vector2:
			continue
		var spawn_context := context.duplicate(true)
		spawn_context["region_count"] = current_count
		spawn_context["season"] = str(spawn_context.get("season", _get_world_season(_world_time_day)))
		if generator.has_method("can_spawn") and not bool(generator.call("can_spawn", spawn_context)):
			continue
		var instance := ObjectFactoryScript.instantiate(definition)
		if instance == null or not instance is Node2D:
			if instance != null:
				instance.free()
			continue
		world_objects.add_child(instance)
		(instance as Node2D).global_position = position_value
		instance.set_meta("object_builder_generated", true)
		instance.set_meta("object_builder_region_id", region_id)
		instance.set_meta("object_builder_biome_id", biome_id)
		var instance_generator := ObjectFactoryScript.get_component(instance, "supports_world_seed")
		if instance_generator != null and instance_generator.has_method("set_world_seed"):
			instance_generator.call("set_world_seed", resolved_seed + index)
		var variant_value: Variant = generator.call("choose_variant", resolved_seed + index) if generator.has_method("choose_variant") else {}
		if variant_value is Dictionary and not variant_value.is_empty():
			instance.set_meta("object_builder_variant", variant_value.duplicate(true))
		spawned.append(instance as Node2D)
		current_count += 1
	prototype.free()
	return spawned


func _count_generated_objects(object_id: String, region_id: String) -> int:
	var count := 0
	if world_objects == null:
		return count
	var stack: Array[Node] = [world_objects]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			if child is Node:
				stack.append(child)
			if str(child.get_meta("object_definition_id", "")) != object_id:
				continue
			if not bool(child.get_meta("object_builder_generated", false)):
				continue
			if region_id.is_empty() or str(child.get_meta("object_builder_region_id", "")) == region_id:
				count += 1
	return count


func upgrade_constructed_object(object_root: Node) -> Dictionary:
	if object_root == null or not is_instance_valid(object_root):
		return {"ok": false, "error": "Объект строительства не найден."}
	var construction := ObjectFactoryScript.get_component(object_root, "can_be_upgraded")
	if construction == null or not construction.has_method("upgrade"):
		return {"ok": false, "error": "У объекта не включены улучшения."}
	var result_value: Variant = construction.call("upgrade", self)
	return result_value if result_value is Dictionary else {"ok": false, "error": "Механика улучшения вернула некорректный результат."}


func dismantle_constructed_object(object_root: Node) -> Dictionary:
	if object_root == null or not is_instance_valid(object_root):
		return {"ok": false, "error": "Объект строительства не найден."}
	var construction := ObjectFactoryScript.get_component(object_root, "can_be_dismantled")
	if construction == null or not construction.has_method("dismantle"):
		return {"ok": false, "error": "Объект нельзя разобрать."}
	var result_value: Variant = construction.call("dismantle")
	if not result_value is Dictionary:
		return {"ok": false, "error": "Механика разбора вернула некорректный результат."}
	var result: Dictionary = result_value
	if not bool(result.get("ok", false)):
		return result
	var refund: Variant = result.get("refund", {})
	if refund is Dictionary:
		for item_id in refund:
			add_item(str(item_id), int(refund[item_id]))
	object_root.queue_free()
	return result


func _update_construction_mechanics(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	for component in _get_world_components("has_build_stages"):
		var root := ObjectFactoryScript.get_object_root(component)
		if root == null or not is_instance_valid(root) or not bool(root.get_meta("object_builder_build_in_progress", false)):
			continue
		if not component.has_method("advance_build_progress"):
			continue
		var result_value: Variant = component.call("advance_build_progress", delta)
		if not result_value is Dictionary:
			continue
		var result: Dictionary = result_value
		if bool(result.get("completed", false)):
			root.set_meta("object_builder_build_in_progress", false)
			root.set_meta("object_builder_built", true)


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
	if weapon_id == "bow":
		_fire_arrow(config.weapons.get("bow", {}))
		return
	if weapon_id == "arrows":
		# Ammunition cannot trigger an attack; select the bow.
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
	var attack_origin: Vector2 = player.get_attack_position()
	var aim_origin: Vector2 = player.get_aim_position()
	var aim_vector: Vector2 = get_global_mouse_position() - aim_origin
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
	if player.has_method("play_attack_animation"):
		var animation_id := weapon_id
		if weapon_id == "sword":
			animation_id = "sword_thrust" if mode == "thrust" else "sword_slash"
		player.play_attack_animation(
			weapon_id,
			aim_direction,
			maxf(0.24, float(attack.get("cooldown", 0.4)) * 0.9),
			animation_id
		)
	var agility := float(config.player.get("agility", 10.0))
	var skill_scale := clampf(1.0 + (agility - 10.0) * float(config.combat.effect_width_skill_scale), 0.65, 1.65)
	var attack_arc := clampf(float(attack.get("arc_degrees", config.combat.slash_arc_degrees)) + (agility - 10.0) * float(config.combat.arc_skill_bonus), 60.0, 175.0)
	var effect_width := float(attack.get("effect_width", 14.0)) * skill_scale
	_show_attack_effect(aim_direction, float(attack.get("reach", 70.0)), mode, attack_arc, effect_width)

	var hit_count := 0
	for target in resources.duplicate():
		if not is_instance_valid(target) or target.destroying:
			continue
		var target_position: Vector2 = target.get_attack_target_position(attack_origin)
		var offset: Vector2 = target_position - attack_origin
		var distance: float = offset.length()
		var reach := float(attack.get("reach", 70.0))
		var is_hit := false
		if mode == "slash" or mode == "swing":
			is_hit = CombatSystemScript.point_in_arc(
				attack_origin,
				target_position,
				aim_angle,
				reach + target.hit_radius,
				attack_arc
			)
		else:
			var start: Vector2 = attack_origin + aim_direction * 12.0
			var finish: Vector2 = attack_origin + aim_direction * reach
			var hit_width := float(attack.get("width", 22.0)) * skill_scale
			is_hit = (
				distance <= reach + target.hit_radius
				and CombatSystemScript.distance_to_segment(target_position, start, finish)
					<= hit_width + target.hit_radius * 0.35
			)
		if is_hit:
			var material := "wood" if target.resource_type == "tree" else "stone"
			if target.resource_type == "stump" or not CombatSystemScript.can_damage_resource(weapon_id, material):
				continue
			_damage_target(target, attack, target_position)
			hit_count += 1
	hit_count += _apply_harvesting_hits(
		weapon_id,
		attack_origin,
		aim_direction,
		attack_arc,
		attack,
		_get_world_season(_world_time_day)
	)
	hit_count += _apply_component_damage_hits(
		weapon_id,
		attack_origin,
		aim_direction,
		attack_arc,
		attack,
		mode,
		skill_scale
	)
	if hit_count == 0:
		_log("Удар: %s" % weapon_id)

func _apply_harvesting_hits(
	weapon_id: String,
	attack_origin: Vector2,
	aim_direction: Vector2,
	arc_degrees: float,
	attack: Dictionary,
	season: String
) -> int:
	var candidates := _get_world_components("can_be_harvested")
	candidates.append_array(_get_world_components("can_be_mined"))
	var visited_roots: Dictionary = {}
	var completed_count := 0
	var reach := maxf(0.0, float(attack.get("reach", 70.0)))
	var hit_angle := aim_direction.angle()
	var work_step := maxf(0.05, float(attack.get("cooldown", 0.4)))
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var root := ObjectFactoryScript.get_object_root(candidate)
		if root == null or root == player or not is_instance_valid(root) or root.is_queued_for_deletion():
			continue
		var root_id := root.get_instance_id()
		if visited_roots.has(root_id):
			continue
		visited_roots[root_id] = true
		var harvesting := ObjectFactoryScript.get_component(root, "can_be_harvested")
		if harvesting == null:
			harvesting = ObjectFactoryScript.get_component(root, "can_be_mined")
		if harvesting == null or not harvesting.has_method("advance_harvest"):
			continue
		var target_position := _get_object_attack_hit_position(root, attack_origin)
		if not CombatSystemScript.point_in_arc(
			attack_origin,
			target_position,
			hit_angle,
			reach + 16.0,
			arc_degrees
		):
			continue
		var result_value: Variant = harvesting.call(
			"advance_harvest",
			work_step,
			weapon_id,
			season
		)
		if not result_value is Dictionary:
			continue
		var result: Dictionary = result_value
		if not bool(result.get("ok", false)):
			continue
		_trigger_object_mechanic(root, "plays_damage_sound", "play_event", ["damage"])
		_trigger_object_mechanic(root, "emits_particles", "emit_particles")
		if not bool(result.get("completed", false)):
			continue
		_trigger_object_mechanic(root, "plays_destroy_sound", "play_event", ["destroy"])
		var yielded: Variant = result.get("resources", {})
		if yielded is Dictionary:
			for raw_item_id in yielded:
				var item_id := str(raw_item_id).strip_edges()
				var amount := maxi(0, int(yielded[raw_item_id]))
				if not item_id.is_empty() and amount > 0:
					_deliver_mechanic_output(item_id, amount, root)
			if harvesting.has_method("start_regrowth"):
				harvesting.call("start_regrowth")
			_log("Добыча завершена: %s · качество %s." % [
				str(root.name),
				str(result.get("quality", "normal"))
			])
			completed_count += 1
	return completed_count


func _trigger_object_mechanic(
	object_root: Node,
	component_id: String,
	method_name: String,
	arguments: Array = []
) -> bool:
	if object_root == null or not is_instance_valid(object_root):
		return false
	var component := ObjectFactoryScript.get_component(object_root, component_id)
	if component == null or not component.has_method(method_name):
		return false
	if method_name == "play_event" and str(component.get_setting("stream_path", "")).strip_edges().is_empty():
		return false
	var result: Variant = component.callv(method_name, arguments)
	return bool(result) if typeof(result) == TYPE_BOOL else true


func _show_attack_effect(direction: Vector2, reach: float, mode: String, arc_degrees: float, effect_width: float) -> void:
	if player == null:
		return
	var attack_anchor := player.get_node_or_null("AttackPivot") as Node2D
	if attack_anchor == null:
		attack_anchor = player
	var visual_reach := maxf(22.0, reach * float(config.combat.effect_reach_scale))
	var base_color := Color("#cceaff") if mode == "thrust" else (Color("#e8b96f") if mode == "swing" else Color("#e9edbd"))

	# Parent the fading trail to the movable player anchor so it travels with the character.
	var effect_root := Node2D.new()
	effect_root.name = "AttackTrail"
	effect_root.position = Vector2.ZERO
	effect_root.rotation = direction.angle()
	# Player is scaled in the main scene; compensate so configured reach stays in world pixels.
	var anchor_scale := attack_anchor.global_scale
	var safe_scale_x := anchor_scale.x if absf(anchor_scale.x) > 0.001 else 1.0
	var safe_scale_y := anchor_scale.y if absf(anchor_scale.y) > 0.001 else 1.0
	effect_root.scale = Vector2(1.0 / safe_scale_x, 1.0 / safe_scale_y)
	effect_root.z_index = 5
	attack_anchor.add_child(effect_root)

	for layer_index in range(3):
		var effect := Line2D.new()
		effect.width = effect_width * [2.5, 1.55, 0.72][layer_index]
		effect.default_color = Color(base_color.r, base_color.g, base_color.b, [0.10, 0.22, 0.72][layer_index])
		effect.antialiased = true
		effect.begin_cap_mode = Line2D.LINE_CAP_ROUND
		effect.end_cap_mode = Line2D.LINE_CAP_ROUND
		if mode == "slash" or mode == "swing":
			var points := PackedVector2Array()
			for step in range(13):
				var angle := deg_to_rad(-arc_degrees * 0.5 + arc_degrees * float(step) / 12.0)
				points.append(Vector2.from_angle(angle) * (visual_reach - 6.0))
			effect.points = points
		else:
			effect.points = PackedVector2Array([Vector2.RIGHT * 12.0, Vector2.RIGHT * visual_reach])
		effect_root.add_child(effect)

	var tween := create_tween()
	tween.tween_property(effect_root, "modulate:a", 0.0, 0.175)
	tween.tween_callback(effect_root.queue_free)


func _fire_arrow(weapon: Dictionary) -> void:
	if weapon.is_empty() or float(attack_cooldowns.get("bow", 0.0)) > 0.0:
		return
	if arrow_count <= 0:
		attack_cooldowns["bow"] = 0.4
		_log("Стрелы закончились.")
		return
	var aim_vector: Vector2 = get_global_mouse_position() - player.get_aim_position()
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
	if player.has_method("play_attack_animation"):
		player.play_attack_animation("bow", direction, maxf(0.24, float(weapon.get("cooldown", 0.5)) * 0.9))
	var arrow := ArrowProjectileScript.new() as Node2D
	arrow.name = "ArrowProjectile"
	arrow.rotation = direction.angle()
	arrow.global_position = player.get_hand_position(direction) + direction * 8.0
	arrow.z_as_relative = false
	arrow.z_index = clampi(floori(arrow.global_position.y) + WORLD_Z_SORT_OFFSET + 2, -4096, 4096)
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
		arrow.z_as_relative = false
		arrow.z_index = clampi(floori(arrow.global_position.y) + WORLD_Z_SORT_OFFSET + 2, -4096, 4096)
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
	arrow.z_as_relative = false
	arrow.z_index = clampi(floori(arrow.global_position.y) + WORLD_Z_SORT_OFFSET + 2, -4096, 4096)
	embedded_arrows.append(arrow)
	while embedded_arrows.size() > 100:
		var oldest: Node2D = embedded_arrows.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

func _damage_target(target: ResourceNode, attack: Dictionary, hit_position: Vector2) -> void:
	if not is_instance_valid(target) or target.destroying:
		return
	var material := "wood" if target.resource_type == "tree" else "stone"
	var damage_type := str(attack.get("damage_type", "crushing"))
	var amount := CombatSystemScript.calculate_damage(attack, material, float(config.player.strength), config)
	if amount <= 0.0:
		return
	var destroyed := target.apply_damage(amount, damage_type)
	_spawn_damage_number(hit_position + Vector2(0, -28), amount, damage_type)
	var type_info: Dictionary = DAMAGE_LABELS.get(damage_type, {"name": damage_type, "color": Color.WHITE})
	_log("%s: -%.0f HP (%s)." % [str(target.resource_type).capitalize(), amount, str(type_info["name"])])
	_camera_shake()
	if destroyed:
		target.begin_destroy()
		_log("%s разрушено." % str(target.resource_type).capitalize())



## Applies the same melee hit geometry to any Object Builder object that has
## Health + Damageable. Legacy ResourceNode scenes keep their dedicated path above.
func _apply_component_damage_hits(
	weapon_id: String,
	attack_origin: Vector2,
	aim_direction: Vector2,
	arc_degrees: float,
	attack: Dictionary,
	mode: String,
	skill_scale: float
) -> int:
	var hit_count := 0
	var visited_roots: Dictionary = {}
	var reach := maxf(0.0, float(attack.get("reach", 70.0)))
	var hit_angle := aim_direction.angle()
	for damageable in _get_world_components("damageable"):
		if damageable == null or not is_instance_valid(damageable) or not damageable.has_method("receive_damage"):
			continue
		var target_root := ObjectFactoryScript.get_object_root(damageable)
		if (
			target_root == null
			or target_root == player
			or not is_instance_valid(target_root)
			or target_root.is_queued_for_deletion()
			or target_root is ResourceNode
		):
			continue
		var root_id := target_root.get_instance_id()
		if visited_roots.has(root_id):
			continue
		visited_roots[root_id] = true

		var health := ObjectFactoryScript.get_component(target_root, "health")
		if health == null or not health.has_method("is_alive") or not bool(health.call("is_alive")):
			continue
		var material := _get_object_damage_material(target_root)
		var required_tool := str(damageable.get_setting("required_tool_id", "")).strip_edges().to_lower()
		if required_tool.is_empty():
			# Backward compatibility for objects created before mechanics owned these fields.
			required_tool = str(ObjectFactoryScript.get_custom_property(
				target_root,
				"required_tool_id",
				ObjectFactoryScript.get_custom_property(target_root, "required_tool", "")
			)).strip_edges().to_lower()
		if required_tool.is_empty():
			var tool_mechanic := ObjectFactoryScript.get_component(target_root, "requires_tool")
			if tool_mechanic != null:
				required_tool = str(tool_mechanic.get_setting("required_tool_id", "")).strip_edges().to_lower()
		if required_tool.is_empty():
			var mining_mechanic := ObjectFactoryScript.get_component(target_root, "can_be_mined")
			if mining_mechanic != null:
				required_tool = str(mining_mechanic.get_setting("required_tool_id", "")).strip_edges().to_lower()
		if required_tool.is_empty():
			if material == "wood" and weapon_id != "axe":
				continue
			if material == "stone" and weapon_id != "pickaxe":
				continue
		else:
			var tool_matches := required_tool == "any"
			for required_tool_value in required_tool.split(",", false):
				if str(required_tool_value).strip_edges().to_lower() == weapon_id:
					tool_matches = true
					break
			if not tool_matches:
				continue

		var target_position := _get_object_attack_hit_position(target_root, attack_origin)
		var hit_radius := _get_object_hit_radius(target_root)
		var offset: Vector2 = target_position - attack_origin
		var distance := offset.length()
		var is_hit := false
		if mode == "slash" or mode == "swing":
			is_hit = CombatSystemScript.point_in_arc(
				attack_origin,
				target_position,
				hit_angle,
				reach + hit_radius,
				arc_degrees
			)
		else:
			var start: Vector2 = attack_origin + aim_direction * 12.0
			var finish: Vector2 = attack_origin + aim_direction * reach
			var hit_width := float(attack.get("width", 22.0)) * skill_scale
			is_hit = (
				distance <= reach + hit_radius
				and CombatSystemScript.distance_to_segment(target_position, start, finish)
					<= hit_width + hit_radius * 0.35
			)
		if not is_hit:
			continue

		var damage_attack := attack.duplicate(true)
		# Generic material responses do not use the legacy ResourceNode weapon gate.
		damage_attack.erase("weapon_id")
		var damage_type := str(attack.get("damage_type", "crushing"))
		var amount := CombatSystemScript.calculate_damage(
			damage_attack,
			material,
			float(config.player.strength),
			config
		)
		if amount <= 0.0:
			continue

		# Run the short impact sway before applying damage. If this hit is lethal,
		# DestructibleComponent replaces this tween with the full fall animation.
		_play_object_hit_reaction(target_root, material)
		var applied_damage := float(damageable.call("receive_damage", amount, player))
		if applied_damage <= 0.0:
			continue

		_spawn_damage_number(target_position + Vector2(0.0, -28.0), applied_damage, damage_type)
		_trigger_object_mechanic(target_root, "plays_damage_sound", "play_event", ["damage"])
		if not _trigger_object_mechanic(target_root, "emits_particles", "emit_particles_at", [target_position]):
			_spawn_object_hit_particles(target_root, target_position, material)
		_camera_shake()
		var type_info: Dictionary = DAMAGE_LABELS.get(damage_type, {"name": damage_type, "color": Color.WHITE})
		_log("%s: -%.0f HP (%s)." % [
			str(target_root.name),
			applied_damage,
			str(type_info["name"])
		])
		if not bool(health.call("is_alive")):
			_handle_object_destroyed(target_root, target_position)
		hit_count += 1
	return hit_count


func _get_object_damage_material(target_root: Node) -> String:
	var damageable := ObjectFactoryScript.get_component(target_root, "damageable")
	var material_value: Variant = damageable.get_setting("material_type", "") if damageable != null else ""
	if str(material_value).strip_edges().is_empty():
		material_value = ObjectFactoryScript.get_custom_property(target_root, "material_type", "")
	var material := str(material_value).strip_edges().to_lower()
	if material in ["wood", "stone", "flesh", "metal", "plant", "nature", "glass", "ice"]:
		return material
	var tags: Variant = target_root.get_meta("object_builder_tags", target_root.get_meta("object_tags", []))
	if tags is Array or tags is PackedStringArray:
		for tag_value in tags:
			var tag := str(tag_value).to_lower()
			if tag in ["tree", "wood", "wooden", "timber"]:
				return "wood"
			if tag in ["rock", "stone", "ore", "mineral"]:
				return "stone"
	return "flesh"


func _get_object_hit_position(target_root: Node) -> Vector2:
	if target_root is Node2D:
		return (target_root as Node2D).global_position
	return Vector2.ZERO


## Finds the nearest point on any visible sprite belonging to an Object Builder object.
## This makes tall trees and large rocks hittable by their artwork instead of their root pivot.
func _get_object_attack_hit_position(target_root: Node, attacker_world_position: Vector2) -> Vector2:
	if not target_root is Node2D:
		return Vector2.ZERO
	var root := target_root as Node2D
	var best_position := root.global_position
	var best_distance := attacker_world_position.distance_to(best_position)
	var candidates: Array[Node] = []
	if target_root is CanvasItem and target_root.has_method("get_rect"):
		candidates.append(target_root)
	candidates.append_array(target_root.find_children("*", "Sprite2D", true, false))
	candidates.append_array(target_root.find_children("*", "AnimatedSprite2D", true, false))
	for candidate in candidates:
		if not candidate is Node2D or not candidate is CanvasItem:
			continue
		var visual := candidate as CanvasItem
		if not visual.is_visible_in_tree() or not visual.has_method("get_rect"):
			continue
		var rect_value: Variant = visual.call("get_rect")
		if not rect_value is Rect2:
			continue
		var bounds: Rect2 = rect_value
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			continue
		var visual_node := candidate as Node2D
		var local_attacker := visual_node.to_local(attacker_world_position)
		var local_target := bounds.get_center()
		if not bounds.has_point(local_attacker):
			local_target = Vector2(
				clampf(local_attacker.x, bounds.position.x, bounds.end.x),
				clampf(local_attacker.y, bounds.position.y, bounds.end.y)
			)
		var world_target := visual_node.to_global(local_target)
		var distance := attacker_world_position.distance_to(world_target)
		if distance < best_distance:
			best_distance = distance
			best_position = world_target
	return best_position


func _get_object_hit_radius(target_root: Node) -> float:
	var damageable := ObjectFactoryScript.get_component(target_root, "damageable")
	var radius_value: Variant = damageable.get_setting("hit_radius", 0.0) if damageable != null else 0.0
	if typeof(radius_value) == TYPE_INT or typeof(radius_value) == TYPE_FLOAT:
		if float(radius_value) > 0.0:
			return clampf(float(radius_value), 4.0, 512.0)
	# Keep old custom properties readable while older saved objects are migrated.
	radius_value = ObjectFactoryScript.get_custom_property(target_root, "hit_radius", 0.0)
	if typeof(radius_value) == TYPE_INT or typeof(radius_value) == TYPE_FLOAT:
		if float(radius_value) > 0.0:
			return clampf(float(radius_value), 4.0, 512.0)
	return 18.0


func _play_object_hit_reaction(target_root: Node, material: String) -> void:
	if target_root == null or not is_instance_valid(target_root):
		return
	var fall_component := ObjectFactoryScript.get_component(target_root, "falls_when_destroyed")
	if fall_component != null and fall_component.has_method("play_hit_reaction"):
		if bool(fall_component.call("play_hit_reaction", material)):
			return
	if not target_root is Node2D:
		return
	var node := target_root as Node2D
	var base_rotation := float(node.get_meta("object_builder_hit_base_rotation", node.rotation))
	node.set_meta("object_builder_hit_base_rotation", base_rotation)
	var previous_tween: Variant = node.get_meta("object_builder_hit_tween", null)
	if previous_tween is Tween and (previous_tween as Tween).is_running():
		(previous_tween as Tween).kill()
	var strength := deg_to_rad(3.6) if material == "wood" else (deg_to_rad(1.5) if material == "stone" else deg_to_rad(2.0))
	var direction := -1.0 if randf() < 0.5 else 1.0
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "rotation", base_rotation + strength * direction, 0.055)
	tween.tween_property(node, "rotation", base_rotation - strength * direction * 0.42, 0.10)
	tween.tween_property(node, "rotation", base_rotation, 0.17)
	node.set_meta("object_builder_hit_tween", tween)


func _spawn_object_hit_particles(target_root: Node, world_position: Vector2, material: String) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var effects_root: Node = get_tree().current_scene
	if effects_root == null:
		effects_root = target_root.get_parent()
	if effects_root == null:
		return
	var color := Color("#9d754c") if material == "wood" else (
		Color("#89939b") if material == "stone" else Color("#d8d2c4")
	)
	var image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var particles := CPUParticles2D.new()
	particles.name = "ObjectHitParticles"
	particles.amount = 14 if material == "wood" else 10
	particles.lifetime = 0.34
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 28.0
	particles.initial_velocity_max = 92.0
	particles.gravity = Vector2(0.0, 190.0)
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.5
	particles.color = color
	particles.texture = ImageTexture.create_from_image(image)
	particles.z_as_relative = false
	particles.z_index = 4
	effects_root.add_child(particles)
	particles.global_position = world_position
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _handle_object_destroyed(target_root: Node, origin: Vector2) -> void:
	if target_root.has_meta("object_builder_destruction_processed"):
		return
	target_root.set_meta("object_builder_destruction_processed", true)
	_trigger_object_mechanic(target_root, "plays_destroy_sound", "play_event", ["destroy"])
	var regrowth_component := ObjectFactoryScript.get_component(target_root, "can_regrow")
	if regrowth_component != null and regrowth_component.has_method("start_regrowth"):
		regrowth_component.call("start_regrowth")

	var loot_component := ObjectFactoryScript.get_component(target_root, "drops_loot_on_destroy")
	var delivered_loot := false
	if loot_component != null and loot_component.has_method("roll_loot"):
		var loot_value: Variant = loot_component.call("roll_loot", rng)
		if loot_value is Array:
			for loot_entry in loot_value:
				if not loot_entry is Dictionary:
					continue
				var item_id := str(loot_entry.get("item_id", "")).strip_edges()
				var amount := maxi(0, int(loot_entry.get("amount", 0)))
				if not item_id.is_empty() and amount > 0:
					_deliver_mechanic_output(item_id, amount, target_root)
					delivered_loot = true

	if not delivered_loot:
		var item_id := str(ObjectFactoryScript.get_custom_property(target_root, "drop_item_id", "")).strip_edges()
		var amount := maxi(0, int(ObjectFactoryScript.get_custom_property(target_root, "drop_amount", 0)))
		if not item_id.is_empty() and amount > 0:
			_deliver_mechanic_output(item_id, amount, target_root)

	var debris_component := ObjectFactoryScript.get_component(target_root, "spawns_debris")
	if debris_component != null and debris_component.has_method("spawn_debris"):
		var debris_parent := world_objects if world_objects != null else target_root.get_parent()
		if debris_parent != null:
			debris_component.call("spawn_debris", debris_parent, origin)



func _spawn_damage_number(world_position: Vector2, amount: float, damage_type: String) -> void:
	var label := Label.new()
	label.text = "-%d" % roundi(amount)
	label.position = world_position
	label.z_as_relative = false
	label.z_index = clampi((player.z_index if player != null else WORLD_Z_SORT_OFFSET) + 128, -4096, 4096)
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

func _on_resource_broken(item_id: String, drop_position: Vector2, amount: int, resource: ResourceNode) -> void:
	resources.erase(resource)
	item_id = item_id.strip_edges()
	var definition := ItemCatalogServiceScript.get_definition(item_id, {"definitions": config.item_definitions})
	if item_id.is_empty() or definition == null:
		_log("У ресурса '%s' указан неизвестный item_id: %s." % [resource.name if is_instance_valid(resource) else "?", item_id])
		return
	for index in range(maxi(1, amount)):
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var speed := rng.randf_range(float(config.drops.scatter_speed_min), float(config.drops.scatter_speed_max))
		var drop := ResourceDropScript.new() as ResourceDrop
		drop.name = "Drop_%s_%03d" % [item_id, drops.size() + 1]
		drop.configure(item_id, 1, direction * speed, config.drops, definition)
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
	var ground_position: Vector2 = player.get_ground_position()
	for drop in drops.duplicate():
		if not is_instance_valid(drop):
			drops.erase(drop)
			continue
		var distance: float = drop.global_position.distance_to(ground_position)
		if drop.is_protected_from_player():
			drop.clear_magnet_target()
			continue
		var drop_magnet_radius: float = drop.get_magnet_radius(magnet_radius)
		if distance <= drop_magnet_radius:
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



## Object Builder pickup receiver. The legacy inventory remains the single source of truth.
func receive_pickup(item_id: String, amount: int, source: Node) -> int:
	var requested := maxi(0, amount)
	if item_id.strip_edges().is_empty() or requested <= 0:
		return 0
	var remaining := _inventory_add(item_id, requested)
	var accepted := clampi(requested - remaining, 0, requested)
	if accepted > 0:
		var label := str(config.items.get(item_id, {}).get("label", item_id))
		_log("Подобрано: %s ×%d." % [label, accepted])
	return accepted


func _update_component_pickups() -> void:
	if player == null:
		return
	var actor_position := _get_actor_world_position(player)
	for component in _get_world_components("pickup"):
		var pickup := component as PickupComponent
		if pickup == null or not pickup.can_be_picked_up or pickup.get_remaining_quantity() <= 0:
			continue
		var source := ObjectFactoryScript.get_object_root(pickup)
		if source == null or source == pickup or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		var target_position := _get_component_world_position(pickup, source)
		if actor_position.distance_to(target_position) <= pickup.pickup_radius:
			pickup.try_pickup(self)

	# New item mechanics use their own stack state, but feed the existing player
	# inventory so there is still exactly one source of truth for carried items.
	for item_component in _get_world_components("is_pickup_item"):
		if not item_component.has_method("is_pickup_allowed") or not item_component.has_method("get_count"):
			continue
		if not bool(item_component.call("is_pickup_allowed")):
			continue
		var source := ObjectFactoryScript.get_object_root(item_component)
		if source == null or source == item_component or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		# Legacy PickupComponent remains authoritative for objects that explicitly use it.
		if ObjectFactoryScript.get_component(source, "pickup") != null:
			continue
		var pickup_radius := maxf(0.0, float(item_component.get_setting("pickup_radius", 48.0)))
		if actor_position.distance_to(_get_component_world_position(item_component, source)) > pickup_radius:
			continue
		var item_id := str(source.get_meta(
			"object_builder_item_id",
			ObjectFactoryScript.get_custom_property(source, "item_id", source.get_meta("object_definition_id", ""))
		)).strip_edges()
		var available := maxi(0, int(item_component.call("get_count")))
		if item_id.is_empty() or available <= 0:
			continue
		var accepted := receive_pickup(item_id, available, source)
		if accepted <= 0:
			continue
		if accepted >= available and item_component.has_method("mark_picked_up"):
			item_component.call("mark_picked_up")
		if item_component.has_method("remove_from_stack"):
			item_component.call("remove_from_stack", accepted)
		if int(item_component.call("get_count")) <= 0:
			source.queue_free()


func _update_animal_mechanics(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	var candidates: Array[ObjectComponent] = []
	for mechanic_id in [
		"can_be_tamed",
		"can_be_fed",
		"can_breed",
		"can_produce_resources",
		"has_habitat",
		"has_happiness",
		"has_daily_routine",
		"can_be_mounted",
		"can_migrate",
		"can_be_petted"
	]:
		candidates.append_array(_get_world_components(mechanic_id))
	var visited_roots: Dictionary = {}
	for component in candidates:
		if component == null or not is_instance_valid(component):
			continue
		var root := ObjectFactoryScript.get_object_root(component)
		if root == null or not is_instance_valid(root) or root.is_queued_for_deletion():
			continue
		var root_id := root.get_instance_id()
		if visited_roots.has(root_id):
			continue
		visited_roots[root_id] = true
		var animal_driver := ObjectFactoryScript.get_component(root, "can_be_fed")
		if animal_driver == null:
			animal_driver = component
		if animal_driver.has_method("advance_time"):
			animal_driver.call("advance_time", delta)
		if ObjectFactoryScript.get_component(root, "can_produce_resources") != null:
			if animal_driver.has_method("advance_resource_production"):
				animal_driver.call("advance_resource_production", delta)


func _update_world_clock(delta: float) -> void:
	var minutes_per_second := maxf(0.0, float(config.world.get("game_minutes_per_real_second", 1.0)))
	if is_finite(delta) and delta > 0.0 and minutes_per_second > 0.0:
		_world_time_hour += delta * minutes_per_second / 60.0
		while _world_time_hour >= 24.0:
			_world_time_hour -= 24.0
			_world_time_day += 1
	var hour_bucket := floori(_world_time_hour)
	if _world_time_day == _last_dispatched_world_day and hour_bucket == _last_dispatched_world_hour:
		return
	_last_dispatched_world_day = _world_time_day
	_last_dispatched_world_hour = hour_bucket
	_dispatch_world_time()


func _dispatch_world_time() -> void:
	var season := _get_world_season(_world_time_day)
	var weather := str(config.world.get("default_weather", "clear")).strip_edges().to_lower()
	var time_components: Array[ObjectComponent] = []
	for mechanic_id in ["has_day_night_schedule", "changes_by_season", "supports_event_schedule", "reacts_to_weather"]:
		time_components.append_array(_get_world_components(mechanic_id))
	var visited_time_roots: Dictionary = {}
	for component in time_components:
		var root := ObjectFactoryScript.get_object_root(component)
		if root == null or not is_instance_valid(root):
			continue
		var root_id := root.get_instance_id()
		if visited_time_roots.has(root_id):
			continue
		visited_time_roots[root_id] = true
		var phase := "day"
		var time_driver := ObjectFactoryScript.get_component(root, "has_day_night_schedule")
		if time_driver == null:
			time_driver = component
		if time_driver.has_method("get_day_phase"):
			phase = str(time_driver.call("get_day_phase", _world_time_hour))
		if time_driver.has_method("update_world_time"):
			time_driver.call("update_world_time", _world_time_day, _world_time_hour)
		root.set_meta("object_builder_world_day", _world_time_day)
		root.set_meta("object_builder_day_phase", phase)
		root.set_meta("object_builder_season", season)
		if time_driver.has_method("get_season_data"):
			var season_data: Variant = time_driver.call("get_season_data", season)
			if season_data is Dictionary:
				root.set_meta("object_builder_season_data", season_data)
		if time_driver.has_method("get_weather_effect"):
			var weather_effect: Variant = time_driver.call("get_weather_effect", weather)
			if weather_effect is Dictionary:
				root.set_meta("object_builder_weather_effect", weather_effect)

	var animal_components := _get_world_components("has_daily_routine")
	for animal_component in animal_components:
		var animal_root := ObjectFactoryScript.get_object_root(animal_component)
		if animal_root == null or not is_instance_valid(animal_root):
			continue
		if animal_component.has_method("get_routine_action"):
			animal_root.set_meta(
				"object_builder_animal_routine_action",
				animal_component.call("get_routine_action", _world_time_hour)
			)

	for generation_component in _get_world_components("adapts_to_environment"):
		var generation_root := ObjectFactoryScript.get_object_root(generation_component)
		if generation_root == null or not is_instance_valid(generation_root):
			continue
		var generation_phase := str(generation_root.get_meta("object_builder_day_phase", "day"))
		var generation_time := ObjectFactoryScript.get_component(generation_root, "has_day_night_schedule")
		if generation_time != null and generation_time.has_method("get_day_phase"):
			generation_phase = str(generation_time.call("get_day_phase", _world_time_hour))
		if generation_component.has_method("adapt_to_environment"):
			var modifiers: Variant = generation_component.call(
				"adapt_to_environment",
				{"season": season, "day_phase": generation_phase, "weather": weather}
			)
			if modifiers is Dictionary:
				generation_root.set_meta("object_builder_environment_modifiers", modifiers)


func _get_world_season(day: int) -> String:
	var days_per_season := maxi(1, int(config.world.get("days_per_season", 30)))
	var day_of_year := posmod(maxi(1, day) - 1, days_per_season * 4)
	return ["spring", "summer", "autumn", "winter"][int(floor(float(day_of_year) / float(days_per_season)))]


func _bind_world_mechanic_signals() -> void:
	for component in _get_world_components("can_produce_resources"):
		_connect_mechanic_signal(component, "resource_produced", "_on_mechanic_resource_produced")
	for component in _get_world_components("has_periodic_output"):
		_connect_mechanic_signal(component, "periodic_output", "_on_mechanic_resource_produced")
	for component in _get_world_components("supports_screen_shake"):
		_connect_mechanic_signal(component, "screen_shake_requested", "_on_mechanic_screen_shake_requested")


func _connect_mechanic_signal(
	component: ObjectComponent,
	signal_name: String,
	callback_method: String
) -> void:
	if component == null or not is_instance_valid(component) or not component.has_signal(signal_name):
		return
	var callback := Callable(self, callback_method).bind(component)
	if not component.is_connected(signal_name, callback):
		component.connect(signal_name, callback)


func _on_mechanic_resource_produced(
	item_id: String,
	amount: int,
	source_component: ObjectComponent
) -> void:
	if source_component == null or not is_instance_valid(source_component):
		return
	_deliver_mechanic_output(item_id, amount, ObjectFactoryScript.get_object_root(source_component))


func _deliver_mechanic_output(item_id: String, amount: int, source: Node) -> void:
	var normalized_id := item_id.strip_edges()
	var remaining := maxi(0, amount)
	if normalized_id.is_empty() or remaining <= 0:
		return
	var accepted_before := remaining
	remaining = _inventory_add(normalized_id, remaining)
	var accepted := accepted_before - remaining
	if accepted > 0:
		_log("Получено от механики: %s ×%d." % [
			str(config.items.get(normalized_id, {}).get("label", normalized_id)),
			accepted
		])
	if remaining <= 0:
		return
	var definition := config.item_definitions.get(normalized_id) as ItemDefinition
	if definition == null or world_objects == null:
		_log("Не удалось разместить остаток ресурса '%s' в мире." % normalized_id)
		return
	var drop := ResourceDropScript.new() as ResourceDrop
	drop.name = "MechanicDrop_%s_%03d" % [normalized_id, drops.size() + 1]
	drop.configure(normalized_id, remaining, Vector2.ZERO, config.drops, definition)
	world_objects.add_child(drop)
	var spawn_position := Vector2.ZERO
	if source is Node2D:
		spawn_position = (source as Node2D).global_position
	drop.global_position = spawn_position
	drops.append(drop)
	_log("На земле осталось: %s ×%d." % [normalized_id, remaining])


func _on_mechanic_screen_shake_requested(
	intensity: float,
	duration: float,
	_source_component: ObjectComponent
) -> void:
	if not screen_shake_enabled or not is_finite(intensity) or not is_finite(duration):
		return
	if intensity <= 0.0 or duration <= 0.0:
		return
	_camera_shake_strength_override = maxf(_camera_shake_strength_override, intensity)
	camera_shake_timer = maxf(camera_shake_timer, duration)


func _try_interact_with_nearest() -> void:
	if player == null:
		return
	var actor_position := _get_actor_world_position(player)
	var nearest: InteractableComponent
	var nearest_distance := INF
	for component in _get_world_components("interactable"):
		var interactable := component as InteractableComponent
		if interactable == null or not interactable.is_interaction_ready():
			continue
		var source := ObjectFactoryScript.get_object_root(interactable)
		if source == null or source == interactable or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		var distance := actor_position.distance_to(_get_component_world_position(interactable, source))
		if distance <= interactable.interaction_radius and distance < nearest_distance:
			nearest = interactable
			nearest_distance = distance
	if nearest == null:
		if _try_interact_with_nearest_animal(actor_position):
			return
		_log("Рядом нет доступных объектов для взаимодействия.")
		return
	if nearest.try_interact(player):
		var source := ObjectFactoryScript.get_object_root(nearest)
		if source != null:
			_trigger_object_mechanic(source, "plays_interaction_sound", "play_event", ["interact"])
			_trigger_object_mechanic(source, "emits_particles", "emit_particles")
			_log("Взаимодействие: %s." % source.name)
	else:
		_log("Не удалось взаимодействовать с объектом.")


func _try_interact_with_nearest_animal(actor_position: Vector2) -> bool:
	var candidates := _get_world_components("can_be_fed")
	candidates.append_array(_get_world_components("can_be_petted"))
	var nearest_root: Node
	var nearest_animal: ObjectComponent
	var nearest_distance := 72.0
	var visited: Dictionary = {}
	for component in candidates:
		if component == null or not is_instance_valid(component):
			continue
		var root := ObjectFactoryScript.get_object_root(component)
		if root == null or not is_instance_valid(root) or root.is_queued_for_deletion():
			continue
		var root_id := root.get_instance_id()
		if visited.has(root_id):
			continue
		visited[root_id] = true
		var animal_driver := ObjectFactoryScript.get_component(root, "can_be_fed")
		if animal_driver == null:
			animal_driver = ObjectFactoryScript.get_component(root, "can_be_petted")
		if animal_driver == null:
			continue
		var distance := actor_position.distance_to(_get_component_world_position(animal_driver, root))
		if distance <= nearest_distance:
			nearest_root = root
			nearest_animal = animal_driver
			nearest_distance = distance
	if nearest_root == null or nearest_animal == null:
		return false

	var selected_item := _get_selected_item_id()
	var feeding_component := ObjectFactoryScript.get_component(nearest_root, "can_be_fed")
	if feeding_component != null and not selected_item.is_empty():
		var accepted_foods := str(feeding_component.get_setting("accepted_foods_csv", "")).to_lower().split(",", false)
		if accepted_foods.has(selected_item.to_lower()) and _get_item_count(selected_item) > 0:
			var inventory_before := inventory.duplicate(true)
			if _consume_item(selected_item, 1):
				if bool(nearest_animal.call("feed", selected_item)):
					_trigger_object_mechanic(nearest_root, "plays_interaction_sound", "play_event", ["feed"])
					_log("Животное накормлено: %s." % nearest_root.name)
					return true
				inventory = inventory_before
				inventory_dirty = true
				_update_resource_counts()

	var pet_component := ObjectFactoryScript.get_component(nearest_root, "can_be_petted")
	if pet_component != null and pet_component.has_method("pet"):
		if bool(pet_component.call("pet", "player")):
			_trigger_object_mechanic(nearest_root, "plays_interaction_sound", "play_event", ["pet"])
			_log("Вы погладили: %s." % nearest_root.name)
		else:
			_log("Животное пока не готово к повторному контакту.")
		return true
	return false


func _get_world_components(component_id: String) -> Array[ObjectComponent]:
	var result: Array[ObjectComponent] = []
	_collect_world_components(self, component_id.strip_edges().to_lower(), result)
	return result


func _collect_world_components(current: Node, component_id: String, output: Array[ObjectComponent]) -> void:
	if current == null:
		return
	if current.has_meta("object_definition_id"):
		output.append_array(ObjectFactoryScript.get_components(current, component_id))
		_collect_nested_world_components(current, component_id, output)
		return
	if current is ObjectComponent:
		var direct_component := current as ObjectComponent
		if direct_component.component_id.strip_edges().to_lower() == component_id:
			output.append(direct_component)
	for child in current.get_children():
		if child is Node:
			_collect_world_components(child as Node, component_id, output)


func _collect_nested_world_components(current: Node, component_id: String, output: Array[ObjectComponent]) -> void:
	for child in current.get_children():
		if child.has_meta("object_definition_id"):
			_collect_world_components(child, component_id, output)
		else:
			_collect_nested_world_components(child, component_id, output)


func _get_component_world_position(component: ObjectComponent, source: Node) -> Vector2:
	if component != null:
		var target := component.get_parent()
		if target is Node2D:
			return (target as Node2D).global_position
	if source is Node2D:
		return (source as Node2D).global_position
	return Vector2.ZERO


func _get_actor_world_position(actor: Node) -> Vector2:
	if actor != null and actor.has_method("get_ground_position"):
		var value: Variant = actor.call("get_ground_position")
		if typeof(value) == TYPE_VECTOR2:
			return value
	if actor is Node2D:
		return (actor as Node2D).global_position
	return Vector2.ZERO

func _get_magnet_radius() -> float:
	return float(config.player.pickup_base_radius) + float(config.player.magnet) * float(config.player.pickup_magnet_per_level)

func _count_nearby_resources() -> int:
	var total := 0
	if world_objects == null or player == null:
		return total
	for resource in _get_resource_nodes():
		if resource.resource_type != "stump" and resource.global_position.distance_to(player.get_ground_position()) <= 240.0:
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
		var strength := _camera_shake_strength_override if _camera_shake_strength_override >= 0.0 else float(config.camera.shake_strength)
		camera.offset = Vector2(rng.randf_range(-strength, strength), rng.randf_range(-strength, strength))
	else:
		camera.offset = Vector2.ZERO
		_camera_shake_strength_override = -1.0

func _camera_shake() -> void:
	if screen_shake_enabled:
		camera_shake_timer = float(config.camera.shake_duration_ms) / 1000.0

func _update_z_order() -> void:
	if player != null:
		# Sort by the character's foot Y at pixel precision so small vertical
		# movements correctly move the sprite behind/in front of tree canopies.
		player.z_as_relative = false
		player.z_index = clampi(floori(player.get_foot_sort_y()) + WORLD_Z_SORT_OFFSET + 1, -4096, 4096)

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

func _get_generic_world_objects() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if world_objects == null:
		return result
	for category_node in world_objects.get_children():
		if not category_node is Node2D:
			continue
		for object in category_node.get_children():
			if object is Node2D and not object is ResourceNode and not object is ResourceDrop:
				result.append(object as Node2D)
	return result

func _debug_object_contains_point(object: Node, world_position: Vector2) -> bool:
	if object is Node2D and object is CanvasItem and object.has_method("get_rect"):
		var visual := object as CanvasItem
		var visual_node := object as Node2D
		if visual.is_visible_in_tree():
			var visual_rect: Variant = object.call("get_rect")
			if visual_rect is Rect2 and visual_rect.has_point(visual_node.to_local(world_position)):
				return true
	if object is CollisionShape2D:
		var collision := object as CollisionShape2D
		if not collision.disabled and collision.shape != null:
			if collision.shape.get_rect().has_point(collision.to_local(world_position)):
				return true
	for child in object.get_children():
		if _debug_object_contains_point(child, world_position):
			return true
	return false


func _refresh_debug_entries() -> void:
	if ui == null:
		return
	debug_entries.clear()
	if is_instance_valid(player):
		debug_entries.append({
			"id": str(player.get_instance_id()),
			"kind": "player",
			"label": "Игрок",
			"node": player,
			"distance": 0.0
		})
	if world_objects != null:
		for resource in _get_resource_nodes():
			var kind := str(resource.resource_type)
			var label := "Пень" if kind == "stump" else ("Дерево" if kind == "tree" else "Камень")
			var distance: float = resource.global_position.distance_to(player.global_position) if is_instance_valid(player) else 0.0
			debug_entries.append({
				"id": str(resource.get_instance_id()),
				"kind": kind,
				"label": "%s · %s" % [label, resource.name],
				"node": resource,
				"distance": distance
			})
	for object in _get_generic_world_objects():
		var category_label := str(object.get_parent().name).replace("_", " ")
		var object_label := str(object.name).replace("_", " ").capitalize()
		var distance: float = object.global_position.distance_to(player.global_position) if is_instance_valid(player) else 0.0
		if not object.has_meta("debug_original_transform"):
			object.set_meta("debug_original_transform", {
				"position": object.position,
				"scale": object.scale,
				"rotation": object.rotation
			})
		debug_entries.append({
			"id": str(object.get_instance_id()),
			"kind": "world_object",
			"label": "%s · %s" % [category_label, object_label],
			"node": object,
			"distance": distance
		})
	for drop in drops:
		if is_instance_valid(drop):
			var item_kind := str(drop.category)
			var item_label := str(config.items.get(str(drop.item_id), {}).get("label", drop.item_id))
			var distance: float = drop.global_position.distance_to(player.global_position) if is_instance_valid(player) else 0.0
			debug_entries.append({
				"id": str(drop.get_instance_id()),
				"kind": item_kind,
				"label": "%s · %s ×%d" % [item_label, _item_category_label(item_kind), int(drop.amount)],
				"node": drop,
				"distance": distance
			})
	var inventory_selection_invalidated := false
	if debug_selected_inventory_slot >= 0 and _find_debug_entry().is_empty():
		debug_selected_inventory_slot = -1
		inventory_selection_invalidated = true
	var ui_entries: Array[Dictionary] = []
	var selected_found := false
	for entry in debug_entries:
		ui_entries.append({
			"id": entry["id"],
			"kind": entry["kind"],
			"label": entry["label"],
			"distance": float(entry.get("distance", 0.0))
		})
		if str(entry["id"]) == debug_selected_id:
			selected_found = true
	if debug_selected_inventory_slot < 0 and not selected_found and not debug_selected_id.is_empty():
		debug_selected_id = ""
		_update_debug_selection_highlight()
	ui.set_debug_objects(ui_entries, debug_selected_id if debug_selected_inventory_slot < 0 else "")
	ui.set_debug_inventory_items(inventory, backpack_slots, debug_selected_inventory_slot, config.items)
	if inventory_selection_invalidated:
		_update_debug_inspector()
func _select_debug_target(world_position: Vector2) -> void:
	var nearest_id := ""
	var nearest_distance := 72.0
	if is_instance_valid(player) and world_position.distance_to(player.global_position) <= 30.0 and world_position.distance_to(player.global_position) < nearest_distance:
		nearest_id = str(player.get_instance_id())
		nearest_distance = world_position.distance_to(player.global_position)
	if world_objects != null:
		for resource in _get_resource_nodes():
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
	for object in _get_generic_world_objects():
		if _debug_object_contains_point(object, world_position):
			var distance: float = object.global_position.distance_to(world_position)
			if nearest_id.is_empty() or distance < nearest_distance:
				nearest_id = str(object.get_instance_id())
				nearest_distance = distance
	if nearest_id.is_empty():
		return
	debug_selected_inventory_slot = -1
	debug_selected_id = nearest_id
	_update_debug_selection_highlight()
	_refresh_debug_entries()
	_update_debug_inspector()

func _on_debug_object_selected(object_id: String) -> void:
	debug_selected_inventory_slot = -1
	debug_selected_id = object_id
	_update_debug_selection_highlight()
	_refresh_debug_entries()
	_update_debug_inspector()

func _on_debug_inventory_item_selected(slot_index: int) -> void:
	if slot_index < 0:
		debug_selected_inventory_slot = -1
		debug_selected_id = ""
		_update_debug_selection_highlight()
		_refresh_debug_entries()
		_update_debug_inspector()
		return
	if slot_index >= inventory.size() or slot_index >= 9 + backpack_slots:
		return
	if str(inventory[slot_index].get("id", "")).is_empty():
		return
	debug_selected_id = ""
	debug_selected_inventory_slot = slot_index
	_update_debug_selection_highlight()
	_refresh_debug_entries()
	_update_debug_inspector()
func _update_debug_selection_highlight() -> void:
	if is_instance_valid(player):
		player.set_debug_selected(debug_selected_id == str(player.get_instance_id()))
	if world_objects != null:
		for resource in _get_resource_nodes():
			resource.set_debug_selected(debug_selected_id == str(resource.get_instance_id()))
	for drop in drops:
		if is_instance_valid(drop):
			drop.set_debug_selected(debug_selected_id == str(drop.get_instance_id()))

func _clear_debug_selection() -> void:
	debug_selected_id = ""
	debug_selected_inventory_slot = -1
	_update_debug_selection_highlight()
	if ui != null:
		ui.set_debug_item_save_enabled(false)
		ui.set_debug_world_actions_enabled(false)
		_clear_debug_inspector_properties()
func _clear_debug_inspector_properties() -> void:
	var empty_properties: Array[Dictionary] = []
	ui.set_debug_properties(empty_properties)

func _find_debug_entry() -> Dictionary:
	if debug_selected_inventory_slot >= 0:
		var slot_index := debug_selected_inventory_slot
		if slot_index >= inventory.size() or slot_index >= 9 + backpack_slots:
			return {}
		var stack: Dictionary = inventory[slot_index]
		var item_id := str(stack.get("id", ""))
		var amount := int(stack.get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			return {}
		var item_data: Dictionary = config.items.get(item_id, {})
		var item_label := str(item_data.get("label", item_id))
		var location := "Быстрый слот %d" % (slot_index + 1) if slot_index < 9 else "Рюкзак · ячейка %d" % (slot_index - 8)
		return {
			"id": "inventory:%d" % slot_index,
			"kind": "inventory_item",
			"label": "%s · %s ×%d" % [location, item_label, amount],
			"node": null,
			"item_id": item_id,
			"amount": amount,
			"slot_index": slot_index
		}
	for entry in debug_entries:
		if str(entry.get("id", "")) == debug_selected_id:
			return entry
	return {}
func _update_debug_inspector() -> void:
	if ui == null:
		return
	var entry := _find_debug_entry()
	if entry.is_empty():
		ui.set_debug_item_save_enabled(false)
		ui.set_debug_world_actions_enabled(false)
		_clear_debug_inspector_properties()
		return
	var kind := str(entry.get("kind", ""))
	var node = entry.get("node")
	var item_id := str(entry.get("item_id", ""))
	if is_instance_valid(node) and node is ResourceDrop:
		item_id = str(node.item_id)
	var can_save_item := false
	if kind == "inventory_item" or (is_instance_valid(node) and node is ResourceDrop):
		var item_catalog := config.item_catalog_by_id.get(item_id) as ItemCatalog
		can_save_item = item_catalog != null and not item_catalog.resource_path.is_empty()
	ui.set_debug_item_save_enabled(can_save_item)
	ui.set_debug_world_actions_enabled(kind != "inventory_item" and is_instance_valid(node))
	if kind == "player" and is_instance_valid(node):
		ui.set_debug_target("Игрок", node.current_health, float(config.player.max_health))
	elif (kind == "tree" or kind == "rock" or kind == "stump") and is_instance_valid(node):
		ui.set_debug_target(str(entry.get("label", kind)), node.health, node.max_health)
	elif kind == "inventory_item":
		ui.set_debug_target(str(entry.get("label", "Предмет из инвентаря")))
	elif is_instance_valid(node) and node is ResourceDrop:
		var item_data: Dictionary = config.items.get(item_id, {})
		ui.set_debug_target("%s ×%d" % [str(item_data.get("label", item_id)), node.amount])
	else:
		ui.set_debug_target(str(entry.get("label", kind)))
	ui.set_debug_properties(_build_debug_properties(entry))
func _debug_property(path: String, label: String, value: float, minimum: float = -100000.0, maximum: float = 100000.0, step: float = 0.1) -> Dictionary:
	return {"path": path, "label": label, "value": value, "min": minimum, "max": maximum, "step": step}


func _item_category_label(category: String) -> String:
	match category:
		"tools":
			return "Инструменты"
		"weapons":
			return "Оружие"
		"food":
			return "Еда"
		"materials":
			return "Материалы"
		"ammunition":
			return "Боеприпасы"
	return category


func _item_property_label(property_key: String) -> String:
	var labels := {
		"damage": "Урон / сила",
		"damage_type": "Тип урона",
		"attack_type": "Тип атаки",
		"stamina_cost": "Расход выносливости",
		"efficiency": "Эффективность",
		"cooldown": "Перезарядка / задержка",
		"reach": "Дальность",
		"projectile_speed": "Скорость снаряда",
		"projectile_range": "Дальность снаряда",
		"arc_degrees": "Угол удара",
		"width": "Ширина удара",
		"effect_width": "Ширина эффекта",
		"max_health": "Максимальное здоровье",
		"heal": "Восстановление здоровья",
		"restore_health": "Восстановление здоровья",
		"restore_stamina": "Восстановление выносливости"
	}
	return str(labels.get(property_key, property_key.capitalize()))


func _append_item_definition_debug_properties(result: Array[Dictionary], definition: ItemDefinition) -> void:
	result.append({"path": "item.description", "label": "Описание", "value": definition.description, "readonly": true})
	result.append({"path": "item.category", "label": "Категория", "value": _item_category_label(definition.category), "readonly": true})
	if definition.category in ["tools", "weapons"]:
		result.append({"path": "item.stack_limit", "label": "Хранение", "value": "Отдельный объект · без стопки", "readonly": true})
	else:
		var stack_property := _debug_property("item.stack_limit", "Максимум в стопке", definition.stack_limit, 1.0, 9999.0, 1.0)
		stack_property["save_default"] = true
		result.append(stack_property)
	for property_key in definition.properties:
		var property_value: Variant = definition.properties[property_key]
		var property_label := _item_property_label(str(property_key))
		if property_value is int or property_value is float:
			var data := _debug_property("item.properties." + str(property_key), property_label, float(property_value), -5000.0, 5000.0, 0.1)
			if definition.category == "food":
				data["save_default"] = true
			else:
				data["readonly"] = true
			result.append(data)
		else:
			result.append({"path": "item.properties." + str(property_key), "label": property_label, "value": str(property_value), "readonly": true})
	_append_debug_item_combat_properties(result, definition.combat_stats, "item.combat")


func _append_debug_item_combat_properties(result: Array[Dictionary], stats: Dictionary, prefix: String) -> void:
	var keys: Array = stats.keys()
	keys.sort()
	for key_value in keys:
		var key := str(key_value)
		var value: Variant = stats[key_value]
		var property_path := prefix + "." + key
		if value is Dictionary:
			result.append({"path": property_path, "label": _item_property_label(key), "value": "", "readonly": true})
			_append_debug_item_combat_properties(result, value, property_path)
		elif key == "damage_type":
			var damage_types := ["cutting", "piercing", "crushing"]
			var data := {
				"path": property_path,
				"label": _item_property_label(key),
				"value": maxi(0, damage_types.find(str(value))),
				"options": damage_types,
				"save_default": true
			}
			result.append(data)
		elif value is int or value is float:
			var minimum := 0.0
			var maximum := 5000.0
			var step := 1.0
			if key == "cooldown":
				minimum = 0.01
				maximum = 10.0
				step = 0.01
			elif key in ["arc_degrees"]:
				maximum = 360.0
				step = 1.0
			elif key in ["projectile_speed", "projectile_range"]:
				maximum = 5000.0
				step = 10.0
			else:
				maximum = 2000.0
				step = 0.1 if value is float else 1.0
			var data := _debug_property(property_path, _item_property_label(key), float(value), minimum, maximum, step)
			data["save_default"] = true
			result.append(data)
		else:
			result.append({"path": property_path, "label": _item_property_label(key), "value": str(value), "readonly": true})


func _apply_item_definition_value(item_id: String, path: String, value: float) -> void:
	var definition := config.item_definitions.get(item_id) as ItemDefinition
	if definition == null:
		return
	if path == "item.stack_limit":
		definition.stack_limit = maxi(1, roundi(value))
	elif path.begins_with("item.combat."):
		var parts := path.trim_prefix("item.combat.").split(".")
		var stored_value: Variant = value
		if parts.size() > 0 and parts[parts.size() - 1] == "damage_type":
			var damage_types := ["cutting", "piercing", "crushing"]
			stored_value = damage_types[clampi(roundi(value), 0, damage_types.size() - 1)]
		_set_nested_item_dictionary(definition.combat_stats, parts, stored_value)
		config.weapons[item_id] = definition.combat_stats.duplicate(true)
	elif path.begins_with("item.properties."):
		var parts := path.trim_prefix("item.properties.").split(".")
		_set_nested_item_dictionary(definition.properties, parts, value)
	else:
		return
	config.items[item_id] = ItemCatalogServiceScript.rebuild_item_data(definition)
	for drop in drops:
		if is_instance_valid(drop) and str(drop.item_id) == item_id:
			drop.set_item_definition(item_id, definition, drop.amount)
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
		result.append(_debug_property("transform.scale_x", "Масштаб X (%)", node.scale.x * 100.0, 10.0, 500.0, 5.0))
		result.append(_debug_property("transform.scale_y", "Масштаб Y (%)", node.scale.y * 100.0, 10.0, 500.0, 5.0))
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
		if node.resource_type == "tree" or node.resource_type == "stump":
			result.append(_debug_property("resource.stump_height", "Высота процедурного пня", node.stump_height, 4.0, 64.0, 1.0))
			result.append(_debug_property("resource.stump_width", "Ширина процедурного пня", node.stump_width, 6.0, 48.0, 1.0))
		result.append(_debug_property("resource.resistance_cutting", "Сопротивление: режущий", node.damage_resistances.get("cutting", 1.0), 0.0, 5.0, 0.05))
		result.append(_debug_property("resource.resistance_piercing", "Сопротивление: колющий", node.damage_resistances.get("piercing", 1.0), 0.0, 5.0, 0.05))
		result.append(_debug_property("resource.resistance_crushing", "Сопротивление: дробящий", node.damage_resistances.get("crushing", 1.0), 0.0, 5.0, 0.05))
		result.append(_debug_property("transform.x", "Координата X", node.global_position.x, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.y", "Координата Y", node.global_position.y, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.scale_x", "Масштаб X (%)", node.scale.x * 100.0, 10.0, 500.0, 5.0))
		result.append(_debug_property("transform.scale_y", "Масштаб Y (%)", node.scale.y * 100.0, 10.0, 500.0, 5.0))
		result.append(_debug_property("transform.rotation", "Вращение", rad_to_deg(node.rotation), -360.0, 360.0, 1.0))
	elif is_instance_valid(node) and node is ResourceDrop:
		if node.stack_limit > 1:
			result.append(_debug_property("drop.amount", "Количество в стопке", node.amount, 1.0, float(node.stack_limit), 1.0))
		result.append(_debug_property("drop.velocity_x", "Скорость X", node.velocity.x, -2000.0, 2000.0, 5.0))
		result.append(_debug_property("drop.velocity_y", "Скорость Y", node.velocity.y, -2000.0, 2000.0, 5.0))
		result.append(_debug_property("drop.gravity", "Гравитация прыжка", node.gravity, 0.0, 3000.0, 10.0))
		result.append(_debug_property("drop.friction", "Затухание движения", node.friction, 0.0, 3000.0, 10.0))
		result.append(_debug_property("drop.bounce_factor", "Сила отскока", node.bounce_factor, 0.0, 1.5, 0.01))
		var item_ids: Array = config.item_definitions.keys()
		item_ids.sort()
		result.append({
			"path": "drop.item_id",
			"label": "Тип предмета",
			"value": maxi(0, item_ids.find(str(node.item_id))),
			"options": item_ids
		})
		result.append(_debug_property("drop.pickup_radius", "Радиус подбора", node.pickup_radius, 1.0, 200.0, 1.0))
		result.append(_debug_property("transform.x", "Координата X", node.global_position.x, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.y", "Координата Y", node.global_position.y, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.scale_x", "Масштаб X (%)", node.scale.x * 100.0, 10.0, 500.0, 5.0))
		result.append(_debug_property("transform.scale_y", "Масштаб Y (%)", node.scale.y * 100.0, 10.0, 500.0, 5.0))
		var definition := config.item_definitions.get(str(node.item_id)) as ItemDefinition
		if definition != null:
			_append_item_definition_debug_properties(result, definition)
	elif is_instance_valid(node) and node is Node2D:
		result.append({"path": "object.name", "label": "Имя объекта", "value": str(node.name), "readonly": true})
		result.append({"path": "object.type", "label": "Тип узла", "value": node.get_class(), "readonly": true})
		result.append(_debug_property("transform.x", "Координата X", node.global_position.x, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.y", "Координата Y", node.global_position.y, -5000.0, 5000.0, 1.0))
		result.append(_debug_property("transform.scale_x", "Масштаб X (%)", node.scale.x * 100.0, 10.0, 500.0, 5.0))
		result.append(_debug_property("transform.scale_y", "Масштаб Y (%)", node.scale.y * 100.0, 10.0, 500.0, 5.0))
		result.append(_debug_property("transform.rotation", "Вращение", rad_to_deg(node.rotation), -360.0, 360.0, 1.0))
		if node is CanvasItem:
			result.append(_debug_property("transform.z_index", "Z-слой", node.z_index, -4096.0, 4096.0, 1.0))
	elif kind == "inventory_item":
		var item_id := str(entry.get("item_id", ""))
		var definition := config.item_definitions.get(item_id) as ItemDefinition
		var max_stack := maxi(1, int(config.items.get(item_id, {}).get("max_stack", 1)))
		result.append(_debug_property("inventory.amount", "Количество в слоте", int(entry.get("amount", 1)), 1.0, float(max_stack), 1.0))
		if definition != null:
			_append_item_definition_debug_properties(result, definition)
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
				scale_x.x = value / 100.0
				node.scale = scale_x
			"transform.scale_y":
				var scale_y: Vector2 = node.scale
				scale_y.y = value / 100.0
				node.scale = scale_y
			"transform.rotation":
				node.rotation = deg_to_rad(value)
			"transform.z_index":
				if node is CanvasItem:
					node.z_index = roundi(value)
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
			"resource.stump_height":
				node.stump_height = value
			"resource.stump_width":
				node.stump_width = value
			"resource.resistance_cutting":
				node.damage_resistances["cutting"] = value
			"resource.resistance_piercing":
				node.damage_resistances["piercing"] = value
			"resource.resistance_crushing":
				node.damage_resistances["crushing"] = value
		node.queue_redraw()
	elif kind == "inventory_item":
		var item_id := str(entry.get("item_id", ""))
		if path == "inventory.amount":
			var slot_index := int(entry.get("slot_index", -1))
			if slot_index >= 0 and slot_index < inventory.size():
				var max_stack := maxi(1, int(config.items.get(item_id, {}).get("max_stack", 1)))
				inventory[slot_index]["amount"] = clampi(roundi(value), 1, max_stack)
		elif path.begins_with("item."):
			_apply_item_definition_value(item_id, path, value)
	elif is_instance_valid(node) and node is ResourceDrop:
		if path.begins_with("item."):
			_apply_item_definition_value(str(node.item_id), path, value)
		else:
			match path:
				"drop.amount":
					node.amount = clampi(roundi(value), 1, node.stack_limit)
				"drop.velocity_x":
					var drop_velocity_x: Vector2 = node.velocity
					drop_velocity_x.x = value
					node.velocity = drop_velocity_x
				"drop.velocity_y":
					var drop_velocity_y: Vector2 = node.velocity
					drop_velocity_y.y = value
					node.velocity = drop_velocity_y
				"drop.item_id":
					var item_ids: Array = config.item_definitions.keys()
					item_ids.sort()
					var next_index := clampi(roundi(value), 0, maxi(0, item_ids.size() - 1))
					if not item_ids.is_empty():
						var next_item_id := str(item_ids[next_index])
						var next_definition := config.item_definitions.get(next_item_id) as ItemDefinition
						node.set_item_definition(next_item_id, next_definition)
						_refresh_debug_entries()
				"drop.gravity":
					node.gravity = value
				"drop.friction":
					node.friction = value
				"drop.bounce_factor":
					node.bounce_factor = value
				"drop.pickup_radius":
					node.pickup_radius = value
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
			ui.set_debug_selection_mode_enabled(true)
			player.set_debug_selected(true)
			debug_selected_inventory_slot = -1
			debug_selected_id = str(player.get_instance_id())
			_refresh_debug_entries()
			_update_debug_inspector()
			ui.set_debug_cheats(player.debug_infinite_stamina, player.debug_invulnerable)
	else:
		if ui.current_panel == "debug":
			ui.close_panels()
		_clear_debug_selection()
	ui.set_debug_mode_enabled(enabled)

func _on_debug_selection_mode_changed(enabled: bool) -> void:
	debug_object_selection_enabled = enabled


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
		node.swing_strength = float(config.resources.swing_strength)
		node.destruction_duration = float(config.resources.destruction_duration)
		node.fall_angle_degrees = float(config.resources.fall_angle_degrees)
		node.stump_height = 16.0
		node.stump_width = 15.0
		node.damage_resistances = {
			"cutting": float(config.resources.resistance_cutting),
			"piercing": float(config.resources.resistance_piercing),
			"crushing": float(config.resources.resistance_crushing)
		}
		node.scale = Vector2.ONE
		node.rotation = 0.0
		node.modulate = Color.WHITE
		node.destroying = false
		var collision := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			collision.set_deferred("disabled", false)
	elif is_instance_valid(node) and node is ResourceDrop:
		node.configure(node.default_item_id, node.default_amount, node.default_velocity, config.drops, node.default_definition)
		node.gravity = float(config.drops.gravity)
		node.friction = float(config.drops.horizontal_friction)
		node.bounce_factor = float(config.drops.bounce_factor)
		node.pickup_radius = float(config.drops.pickup_distance)
	elif is_instance_valid(node) and node is Node2D and node.has_meta("debug_original_transform"):
		var original: Dictionary = node.get_meta("debug_original_transform")
		node.position = original.get("position", node.position)
		node.scale = original.get("scale", node.scale)
		node.rotation = float(original.get("rotation", node.rotation))
	_refresh_debug_entries()
	_update_debug_inspector()
	_log("Параметры выбранного объекта сброшены.")

func _log(message: String) -> void:
	print("[game] " + message)
	if ui != null:
		ui.add_log(message)
