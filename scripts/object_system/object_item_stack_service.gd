@tool
extends RefCounted
class_name ObjectItemStackService

## Shared dictionary contract for item stacks stored by inventories and containers.
## Required fields: item_id, amount, weight, tags. max_stack is optional in legacy data.
## rarity/bound receive common defaults; quality and custom fields are preserved.


static func normalize_item(value: Variant, default_max_stack: int = 0) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	var item_id := str(source.get("item_id", "")).strip_edges()
	var amount := int(source.get("amount", 0))
	var weight := float(source.get("weight", 0.0))
	if item_id.is_empty() or amount <= 0 or not is_finite(weight) or weight < 0.0:
		return {}
	var tags_value: Variant = source.get("tags", [])
	var tags: Array = tags_value.duplicate(true) if tags_value is Array else []
	var result: Dictionary = source.duplicate(true)
	result["item_id"] = item_id
	result["amount"] = amount
	# Older stored stacks may not contain max_stack. Keep that omission so an
	# incoming item's current stack limit remains the fallback, as before migration.
	if source.has("max_stack") or default_max_stack > 0:
		result["max_stack"] = maxi(1, int(source.get("max_stack", default_max_stack)))
	result["weight"] = weight
	result["tags"] = tags
	result["rarity"] = str(source.get("rarity", "common"))
	result["bound"] = bool(source.get("bound", false))
	return result


static func normalize_items(values: Variant, preserve_empty_slots: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not values is Array:
		return result
	for value in values:
		if value is Dictionary and (value as Dictionary).is_empty():
			if preserve_empty_slots:
				result.append({})
			continue
		var normalized := normalize_item(value)
		if normalized.is_empty():
			if preserve_empty_slots:
				result.append({})
			continue
		result.append(normalized)
	return result


static func count_items(items: Array, item_id: String) -> int:
	var total := 0
	var normalized_id := item_id.strip_edges()
	if normalized_id.is_empty():
		return total
	for value in items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		if str(item.get("item_id", "")).strip_edges() == normalized_id:
			total += maxi(0, int(item.get("amount", 0)))
	return total


static func has_room_for_item(items: Array, item_id: String) -> bool:
	var normalized_id := item_id.strip_edges()
	if normalized_id.is_empty():
		return false
	for value in items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		if item.is_empty():
			return true
		if str(item.get("item_id", "")) == normalized_id:
			if int(item.get("amount", 0)) < maxi(1, int(item.get("max_stack", 1))):
				return true
	return false


static func total_weight(items: Array) -> float:
	var total := 0.0
	for value in items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		if item.is_empty():
			continue
		var amount := maxi(0, int(item.get("amount", 0)))
		var weight := maxf(0.0, float(item.get("weight", 0.0)))
		total += weight * float(amount)
	return total


static func can_stack_together(existing: Dictionary, incoming: Dictionary) -> bool:
	if existing.is_empty() or incoming.is_empty():
		return false
	if str(existing.get("item_id", "")) != str(incoming.get("item_id", "")):
		return false
	if not is_equal_approx(float(existing.get("weight", 0.0)), float(incoming.get("weight", 0.0))):
		return false
	# Do not merge items whose per-instance metadata differs. Amount and stack
	# limit describe storage, not the identity of the item inside the stack.
	var metadata_keys: Dictionary = {}
	for key in existing:
		if str(key) not in ["amount", "max_stack"]:
			metadata_keys[str(key)] = true
	for key in incoming:
		if str(key) not in ["amount", "max_stack"]:
			metadata_keys[str(key)] = true
	for key in metadata_keys:
		if existing.get(str(key), null) != incoming.get(str(key), null):
			return false
	return true


## Adds a stack to either fixed inventory slots or a compact container list.
## The only storage-specific choice is preserve_empty_slots; stack merging and
## remainder accounting are identical for both callers.
static func add_stack(
	slots: Array,
	incoming_value: Dictionary,
	slot_capacity: int,
	preserve_empty_slots: bool
) -> Dictionary:
	var incoming := normalize_item(incoming_value, 1)
	if incoming.is_empty():
		return {"ok": false, "items": slots.duplicate(true), "accepted": 0, "remainder": 0}
	var capacity := maxi(0, slot_capacity)
	var working := normalize_items(slots, preserve_empty_slots)
	if preserve_empty_slots:
		while working.size() < capacity:
			working.append({})
	var remaining := int(incoming.get("amount", 0))
	var accepted_total := 0
	var stack_limit := maxi(1, int(incoming.get("max_stack", 1)))
	if stack_limit > 1:
		for index in range(working.size()):
			if remaining <= 0:
				break
			var current: Dictionary = working[index]
			if not can_stack_together(current, incoming):
				continue
			var current_limit := maxi(1, int(current.get("max_stack", stack_limit)))
			var accepted := mini(remaining, maxi(0, current_limit - int(current.get("amount", 0))))
			if accepted <= 0:
				continue
			current["amount"] = int(current.get("amount", 0)) + accepted
			working[index] = current
			remaining -= accepted
			accepted_total += accepted
	while remaining > 0:
		var target_index := -1
		if preserve_empty_slots:
			for index in range(working.size()):
				if working[index].is_empty():
					target_index = index
					break
		else:
			if working.size() < capacity:
				target_index = working.size()
		if target_index < 0:
			break
		var accepted_new := mini(remaining, stack_limit)
		var new_stack := incoming.duplicate(true)
		new_stack["amount"] = accepted_new
		if preserve_empty_slots:
			working[target_index] = new_stack
		else:
			working.append(new_stack)
		remaining -= accepted_new
		accepted_total += accepted_new
	return {
		"ok": remaining == 0,
		"items": working,
		"accepted": accepted_total,
		"remainder": remaining
	}


## Removes matching quantities while preserving per-stack metadata in removed_items.
## On partial failure callers can discard the returned list and leave saved state intact.
static func remove_stack(
	slots: Array,
	item_id: String,
	amount: int,
	skip_bound: bool,
	preserve_empty_slots: bool
) -> Dictionary:
	var working := normalize_items(slots, preserve_empty_slots)
	var removed_items: Array[Dictionary] = []
	var remaining := amount
	if amount <= 0 or item_id.strip_edges().is_empty():
		return {"ok": false, "items": working, "removed_items": removed_items, "removed": 0, "remainder": maxi(0, amount)}
	var index := 0
	while index < working.size() and remaining > 0:
		var item: Dictionary = working[index]
		if item.is_empty() or str(item.get("item_id", "")) != item_id:
			index += 1
			continue
		if skip_bound and bool(item.get("bound", false)):
			index += 1
			continue
		var removed_amount := mini(remaining, maxi(0, int(item.get("amount", 0))))
		if removed_amount <= 0:
			index += 1
			continue
		var removed_item := item.duplicate(true)
		removed_item["amount"] = removed_amount
		removed_items.append(removed_item)
		item["amount"] = int(item.get("amount", 0)) - removed_amount
		remaining -= removed_amount
		if int(item["amount"]) <= 0:
			if preserve_empty_slots:
				working[index] = {}
				index += 1
			else:
				working.remove_at(index)
		else:
			working[index] = item
			index += 1
	return {
		"ok": remaining == 0,
		"items": working,
		"removed_items": removed_items,
		"removed": amount - remaining,
		"remainder": remaining
	}


static func sort_items(items: Array, mode: String, preserve_empty_slots: bool) -> Array[Dictionary]:
	var working := normalize_items(items, preserve_empty_slots)
	var occupied: Array[Dictionary] = []
	for item in working:
		if not item.is_empty():
			occupied.append(item)
	var normalized_mode := mode.strip_edges().to_lower()
	occupied.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_before(a, b, normalized_mode)
	)
	if preserve_empty_slots:
		while occupied.size() < working.size():
			occupied.append({})
	return occupied


static func _sort_before(a: Dictionary, b: Dictionary, mode: String) -> bool:
	match mode:
		"weight":
			return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0))
		"amount":
			return int(a.get("amount", 0)) > int(b.get("amount", 0))
		"rarity":
			return str(a.get("rarity", "")).naturalnocasecmp_to(str(b.get("rarity", ""))) < 0
		"type":
			return str(a.get("type", "")).naturalnocasecmp_to(str(b.get("type", ""))) < 0
		_:
			return str(a.get("item_id", "")).naturalnocasecmp_to(str(b.get("item_id", ""))) < 0
