@tool
extends ObjectComponent
class_name ContainerMechanicComponent

const ITEM_STACKS = preload("res://scripts/object_system/object_item_stack_service.gd")

signal contents_changed(contents: Array[Dictionary])
signal lock_changed(locked: bool)
signal access_denied(actor_id: String, reason: String)
signal action_failed(reason: String)

static var _shared_storage_states: Dictionary = {}


func get_option(key: String, fallback: Variant = null) -> Variant:
	return get_setting(key, fallback)


func get_contents(actor_id: String = "", faction_id: String = "") -> Array[Dictionary]:
	if not can_access(actor_id, faction_id):
		access_denied.emit(actor_id, "Нет доступа к содержимому контейнера.")
		return []
	return ITEM_STACKS.normalize_items(_get_state().get("items", []))


## Common storage read API; access checks are supplied separately by the container.
func get_item_stacks(options: Dictionary = {}) -> Array[Dictionary]:
	return get_contents(str(options.get("actor_id", "")), str(options.get("faction_id", "")))


func get_item_count(item_id: String) -> int:
	return ITEM_STACKS.count_items(_get_state().get("items", []), item_id)


func get_total_weight() -> float:
	return ITEM_STACKS.total_weight(_get_state().get("items", []))


func can_access(actor_id: String = "", faction_id: String = "") -> bool:
	var state := _get_state()
	if bool(state.get("locked", false)):
		return false
	if not _has_mechanic("has_container_permissions"):
		return true
	if bool(_option("has_container_permissions", "public_access", true)):
		return true
	var owner_id := str(_option("has_container_permissions", "owner_id", "")).strip_edges()
	if not owner_id.is_empty() and actor_id == owner_id:
		return true
	return _split_csv(str(_option("has_container_permissions", "allowed_factions_csv", ""))).has(faction_id.strip_edges().to_lower())


func add_item(item_id: String, amount: int = 1, max_stack: int = 1, weight: float = 0.0, tags: Array = [], actor_id: String = "", faction_id: String = "") -> Dictionary:
	return add_item_data({
		"item_id": item_id,
		"amount": amount,
		"max_stack": max_stack,
		"weight": weight,
		"tags": tags
	}, -1, {"actor_id": actor_id, "faction_id": faction_id})


## Shared storage contract used by inventory, containers and transfer adapters.
## Access and container capacity remain local rules; stack operations are shared.
func add_item_data(
	item_data: Dictionary,
	amount_override: int = -1,
	options: Dictionary = {}
) -> Dictionary:
	var actor_id := str(options.get("actor_id", ""))
	var faction_id := str(options.get("faction_id", ""))
	if not _has_mechanic("stores_items"):
		return _failed_result("Контейнер не поддерживает хранение предметов.")
	if not can_access(actor_id, faction_id):
		return _failed_result("Контейнер закрыт или недоступен.")
	var stack := ITEM_STACKS.normalize_item(item_data)
	if stack.is_empty():
		return _failed_result("Некорректная запись предмета.")
	if amount_override >= 0:
		stack["amount"] = amount_override
	var item_id := str(stack.get("item_id", "")).strip_edges()
	var amount := int(stack.get("amount", 0))
	var weight := float(stack.get("weight", 0.0))
	if item_id.is_empty() or amount <= 0 or not is_finite(weight) or weight < 0.0:
		return _failed_result("Некорректные данные предмета.")
	var state := _get_state()
	var items: Array = state.get("items", [])
	var amount_allowed := amount
	var max_weight := float(state.get("max_weight", _option("has_container_capacity", "max_weight", 0.0)))
	if _has_mechanic("has_container_capacity") and max_weight > 0.0 and weight > 0.0:
		amount_allowed = mini(amount, int(floor(maxf(0.0, max_weight - ITEM_STACKS.total_weight(items)) / weight)))
	var capacity_remainder := amount - amount_allowed
	stack["amount"] = amount_allowed
	var slot_capacity := maxi(1, int(state.get("max_slots", _option("has_container_capacity", "max_slots", 24))))
	var add_result := ITEM_STACKS.add_stack(items, stack, slot_capacity, false)
	state["items"] = add_result.get("items", items)
	_save_state(state)
	var accepted_total := int(add_result.get("accepted", 0))
	var remainder := capacity_remainder + int(add_result.get("remainder", amount_allowed))
	return {"ok": remainder == 0, "accepted": accepted_total, "remainder": remainder}


func remove_item(item_id: String, amount: int = 1, actor_id: String = "", faction_id: String = "") -> bool:
	return bool(remove_item_data(item_id, amount, {"actor_id": actor_id, "faction_id": faction_id}).get("ok", false))


## Common removal API. Container access and looting permissions remain local rules.
func remove_item_data(item_id: String, amount: int = 1, options: Dictionary = {}) -> Dictionary:
	if not _has_mechanic("can_be_looted") or not bool(_option("can_be_looted", "loot_enabled", true)):
		return _failed_result("Содержимое контейнера нельзя обыскивать или изымать.")
	var actor_id := str(options.get("actor_id", ""))
	var faction_id := str(options.get("faction_id", ""))
	if not can_access(actor_id, faction_id):
		return _failed_result("Нет доступа к контейнеру.")
	if amount <= 0:
		return _failed_result("Количество для изъятия должно быть положительным.")
	var state := _get_state()
	var items: Array = state.get("items", [])
	var remove_result := ITEM_STACKS.remove_stack(items, item_id, amount, false, false)
	if not bool(remove_result.get("ok", false)):
		return _failed_result("В контейнере недостаточно предметов: " + item_id)
	state["items"] = remove_result.get("items", items)
	_save_state(state)
	return {
		"ok": true,
		"removed": int(remove_result.get("removed", amount)),
		"remainder": 0,
		"items": remove_result.get("removed_items", [])
	}


func loot(actor_id: String = "", faction_id: String = "") -> Array[Dictionary]:
	if not _has_mechanic("can_be_looted") or not bool(_option("can_be_looted", "loot_enabled", true)):
		_fail("Контейнер нельзя обыскать.")
		return []
	return get_contents(actor_id, faction_id)


func lock(key_id: String = "") -> bool:
	if not _has_mechanic("can_be_locked"):
		return _fail("Контейнер нельзя запереть.")
	var state := _get_state()
	if bool(state.get("locked", false)):
		return _fail("Контейнер уже заперт.")
	var required_key := str(_option("can_be_locked", "lock_key_id", "")).strip_edges()
	if not required_key.is_empty() and key_id != required_key:
		return _fail("Неверный ключ для запирания.")
	state["locked"] = true
	_save_state(state)
	lock_changed.emit(true)
	return true


func unlock(key_id: String = "") -> bool:
	var combined_unlock_enabled := (
		_has_mechanic("can_be_locked")
		and bool(_option("can_be_locked", "unlock_enabled", false))
	)
	# Keep accepting old explicit component bindings while capability selections
	# migrate can_be_unlocked into the shared lock component.
	var legacy_unlock_enabled := _has_mechanic("can_be_unlocked")
	if not combined_unlock_enabled and not legacy_unlock_enabled:
		return _fail("Контейнер нельзя отпереть.")
	var state := _get_state()
	if not bool(state.get("locked", false)):
		return _fail("Контейнер уже открыт.")
	var requires_key := bool(_option(
		"can_be_locked",
		"unlock_requires_key",
		_option("can_be_unlocked", "requires_key", false)
	))
	var required_key := str(_option(
		"can_be_locked",
		"unlock_key_id",
		_option("can_be_unlocked", "unlock_key_id", "")
	))
	if requires_key and (required_key.is_empty() or key_id != required_key):
		return _fail("Для отпирания нужен подходящий ключ.")
	state["locked"] = false
	_save_state(state)
	lock_changed.emit(false)
	return true


func is_locked() -> bool:
	return bool(_get_state().get("locked", false))


func sort_contents(mode: String = "") -> bool:
	if not _has_mechanic("supports_auto_sort"):
		return _fail("Автосортировка контейнера не включена.")
	var sort_mode := mode.strip_edges().to_lower()
	if sort_mode.is_empty():
		sort_mode = str(_option("supports_auto_sort", "default_sort", "name")).to_lower()
	if not ["name", "weight", "amount"].has(sort_mode):
		return _fail("Неизвестный режим сортировки: " + sort_mode)
	var state := _get_state()
	state["items"] = ITEM_STACKS.sort_items(state.get("items", []), sort_mode, false)
	_save_state(state)
	return true


func link_container(target: Object) -> bool:
	if not _has_mechanic("has_shared_storage") or not bool(_option("has_shared_storage", "allow_links", false)):
		return _fail("Связи между контейнерами отключены.")
	if target == null or not target.has_method("_has_mechanic") or not bool(target.call("_has_mechanic", "has_shared_storage")):
		return _fail("Целевой объект не поддерживает общее хранилище.")
	if not bool(target.call("_option", "has_shared_storage", "allow_links", false)):
		return _fail("У целевого контейнера выключено связывание.")
	var target_root: Node = target.call("get_object_root")
	var own_root := get_object_root()
	if target_root == null or own_root == null or target_root == own_root:
		return _fail("Нельзя связать контейнер с самим собой.")
	var own_group := str(own_root.get_meta("object_builder_container_shared_group", ""))
	var target_group := str(target_root.get_meta("object_builder_container_shared_group", ""))
	if not own_group.is_empty() or not target_group.is_empty():
		if own_group == target_group and not own_group.is_empty():
			return true
		return _fail("Сначала отключите контейнер от прежней группы.")
	var own_config_group := str(_option("has_shared_storage", "shared_group_id", "")).strip_edges()
	var target_config_group := str(target.call("_option", "has_shared_storage", "shared_group_id", "")).strip_edges()
	if not own_config_group.is_empty() and own_config_group == target_config_group:
		return true
	var own_owner := str(_option("has_container_permissions", "owner_id", ""))
	var target_owner := str(target.call("_option", "has_container_permissions", "owner_id", ""))
	var own_factions := str(_option("has_container_permissions", "allowed_factions_csv", ""))
	var target_factions := str(target.call("_option", "has_container_permissions", "allowed_factions_csv", ""))
	var own_public := bool(_option("has_container_permissions", "public_access", true))
	var target_public := bool(target.call("_option", "has_container_permissions", "public_access", true))
	if own_owner != target_owner or own_factions != target_factions or own_public != target_public:
		return _fail("Перед связыванием настройте одинаковые права доступа у обоих контейнеров.")
	var own_state := _get_state()
	var target_state: Dictionary = target.call("_get_state")
	var merged_items: Array = target_state.get("items", []).duplicate(true)
	for item in own_state.get("items", []):
		merged_items.append(item.duplicate(true))
	var own_capacity := maxi(1, int(_option("has_container_capacity", "max_slots", 24)))
	var target_capacity := maxi(1, int(target.call("_option", "has_container_capacity", "max_slots", 24)))
	var shared_capacity := mini(own_capacity, target_capacity)
	if merged_items.size() > shared_capacity:
		return _fail("Содержимое не помещается в общую вместимость контейнеров.")
	var own_max_weight := float(_option("has_container_capacity", "max_weight", 0.0))
	var target_max_weight := float(target.call("_option", "has_container_capacity", "max_weight", 0.0))
	var shared_max_weight := own_max_weight
	if shared_max_weight <= 0.0 or (target_max_weight > 0.0 and target_max_weight < shared_max_weight):
		shared_max_weight = target_max_weight
	var merged_weight := 0.0
	for item in merged_items:
		merged_weight += float(item.get("weight", 0.0)) * float(item.get("amount", 0))
	if shared_max_weight > 0.0 and merged_weight > shared_max_weight:
		return _fail("Содержимое превышает общий весовой лимит контейнеров.")
	var group_id := own_config_group if not own_config_group.is_empty() else target_config_group
	if group_id.is_empty():
		group_id = "container_group_" + str(Time.get_ticks_usec()) + "_" + str(randi())
	var merged_state := {
		"items": merged_items,
		"locked": bool(own_state.get("locked", false)) or bool(target_state.get("locked", false)),
		"max_slots": shared_capacity,
		"max_weight": shared_max_weight
	}
	_shared_storage_states[group_id] = merged_state.duplicate(true)
	target_root.remove_meta("object_builder_container_force_local")
	own_root.remove_meta("object_builder_container_force_local")
	target_root.set_meta("object_builder_container_shared_group", group_id)
	own_root.set_meta("object_builder_container_shared_group", group_id)
	return true

func unlink_container() -> bool:
	var root := get_object_root()
	if root == null:
		return false
	var group_id := str(root.get_meta("object_builder_container_shared_group", ""))
	if group_id.is_empty():
		group_id = str(_option("has_shared_storage", "shared_group_id", "")).strip_edges()
	if group_id.is_empty():
		return false
	var local_state := _get_state()
	root.remove_meta("object_builder_container_shared_group")
	root.set_meta("object_builder_container_force_local", true)
	root.set_meta("object_builder_container_state", local_state)
	return true

func can_persist() -> bool:
	return _has_mechanic("has_container_persistence") and bool(_option("has_container_persistence", "persistent", true))


func export_runtime_state() -> Dictionary:
	return _get_state().duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
	if not state.get("items", []) is Array or not state.get("locked", false) is bool:
		return _fail("Состояние контейнера имеет неверный формат.")
	var raw_items: Array = state.get("items", [])
	var normalized_items := ITEM_STACKS.normalize_items(raw_items)
	if normalized_items.size() != raw_items.size():
		return _fail("Состояние контейнера содержит некорректный предмет.")
	var normalized := {
		"items": normalized_items,
		"locked": bool(state.get("locked", false)),
		"max_slots": int(state.get("max_slots", _option("has_container_capacity", "max_slots", 24))),
		"max_weight": float(state.get("max_weight", _option("has_container_capacity", "max_weight", 0.0)))
	}
	_save_state(normalized)
	return true


func _get_state() -> Dictionary:
	var root := get_object_root()
	if root == null:
		return {"items": [], "locked": false}
	var group_id := str(root.get_meta("object_builder_container_shared_group", ""))
	if group_id.is_empty() and not bool(root.get_meta("object_builder_container_force_local", false)) and _has_mechanic("has_shared_storage"):
		group_id = str(_option("has_shared_storage", "shared_group_id", "")).strip_edges()
	if not group_id.is_empty():
		if not _shared_storage_states.has(group_id):
			_shared_storage_states[group_id] = _load_local_state(root)
		var shared_state: Dictionary = (_shared_storage_states[group_id] as Dictionary).duplicate(true)
		shared_state["items"] = ITEM_STACKS.normalize_items(shared_state.get("items", []))
		return shared_state
	if root.has_meta("object_builder_container_state"):
		var stored: Variant = root.get_meta("object_builder_container_state")
		if stored is Dictionary:
			var restored: Dictionary = stored.duplicate(true)
			restored["items"] = ITEM_STACKS.normalize_items(stored.get("items", []))
			return restored
	return _load_local_state(root)


func _load_local_state(root: Node) -> Dictionary:
	var parsed: Variant = JSON.parse_string(str(_option("stores_items", "initial_contents_json", "[]")))
	var items := ITEM_STACKS.normalize_items(parsed)
	var capacity_enabled := _has_mechanic("has_container_capacity")
	var lock_enabled := _has_mechanic("can_be_locked")
	return {
		"items": items,
		"locked": bool(_option("can_be_locked", "initially_locked", false)) if lock_enabled else false,
		"max_slots": maxi(1, int(_option("has_container_capacity", "max_slots", 24))) if capacity_enabled else 24,
		"max_weight": maxf(0.0, float(_option("has_container_capacity", "max_weight", 0.0))) if capacity_enabled else 0.0
	}


func _save_state(state: Dictionary) -> void:
	var root := get_object_root()
	if root == null:
		return
	var copied := state.duplicate(true)
	copied["items"] = ITEM_STACKS.normalize_items(copied.get("items", []))
	var group_id := str(root.get_meta("object_builder_container_shared_group", ""))
	if group_id.is_empty() and not bool(root.get_meta("object_builder_container_force_local", false)) and _has_mechanic("has_shared_storage"):
		group_id = str(_option("has_shared_storage", "shared_group_id", "")).strip_edges()
	if not group_id.is_empty():
		_shared_storage_states[group_id] = copied
	else:
		root.set_meta("object_builder_container_state", copied)
	contents_changed.emit(copied.get("items", []).duplicate(true))


func _has_mechanic(mechanic_id: String) -> bool:
	var root := get_object_root()
	if root == null:
		return false
	var component := ObjectFactory.get_component(root, mechanic_id)
	if component == null:
		return false
	var enabled_value: Variant = component.get_setting("enabled", null)
	return bool(enabled_value) if enabled_value != null else true


func _option(mechanic_id: String, key: String, fallback: Variant = null) -> Variant:
	var root := get_object_root()
	if root == null:
		return fallback
	var component := ObjectFactory.get_component(root, mechanic_id)
	return component.get_setting(key, fallback) if component != null else fallback


func _split_csv(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	for raw in value.split(",", false):
		var item := raw.strip_edges().to_lower()
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result


func _failed_result(reason: String) -> Dictionary:
	_fail(reason)
	return {"ok": false, "error": reason}


func _fail(reason: String) -> bool:
	action_failed.emit(reason)
	return false
