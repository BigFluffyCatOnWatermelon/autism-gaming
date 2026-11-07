@tool
extends RefCounted
class_name CapabilityBatchPlanner
## Builds an atomic, dependency-complete plan for a multi-selection catalog session.
## This service never mutates the caller's current selections or ObjectDefinition.

static func build_addition_plan(
	current_selections: Array[ObjectCapabilitySelection],
	selected_ids: PackedStringArray,
	scene_root: Node = null
) -> Dictionary:
	var unique_selected_ids := _unique_normalized_ids(selected_ids)
	if unique_selected_ids.is_empty():
		return _failed_plan(PackedStringArray(["Выбери хотя бы одну возможность."]))

	var initial_enabled: Dictionary = {}
	var next_selections: Array[ObjectCapabilitySelection] = []
	for current in current_selections:
		if current == null:
			continue
		var copied := current.duplicate(true) as ObjectCapabilitySelection
		next_selections.append(copied)
		if copied.enabled:
			initial_enabled[copied.capability_id.strip_edges().to_lower()] = true

	# Reuse the existing dependency/conflict planner against a private copy.
	# Nothing reaches the real object until the caller accepts the final plan.
	for capability_id in unique_selected_ids:
		var step_plan := ObjectCapabilityService.plan_selection_change(
			next_selections,
			capability_id,
			true
		)
		if not bool(step_plan.get("ok", false)):
			return _failed_plan(_to_packed_errors(step_plan.get("errors", PackedStringArray())))

		var planned_values: Variant = step_plan.get("selections", [])
		if not planned_values is Array:
			return _failed_plan(PackedStringArray(["Планировщик вернул набор возможностей в неизвестном формате."]))
		next_selections.clear()
		for value in planned_values:
			if value is ObjectCapabilitySelection:
				next_selections.append(value as ObjectCapabilitySelection)
			else:
				return _failed_plan(PackedStringArray(["В итоговом плане обнаружена некорректная запись возможности."]))

	var application_plan := ObjectCapabilityService.build_application_plan(
		current_selections,
		next_selections,
		scene_root
	)
	if not bool(application_plan.get("ok", false)):
		return _failed_plan(_to_packed_errors(application_plan.get("errors", PackedStringArray())))

	var selected_by_user := PackedStringArray()
	var already_present := PackedStringArray()
	for capability_id in unique_selected_ids:
		if initial_enabled.has(capability_id):
			already_present.append(capability_id)
		else:
			selected_by_user.append(capability_id)

	var auto_required := PackedStringArray()
	var auto_required_already_present := PackedStringArray()
	for selection in next_selections:
		if selection == null or not selection.enabled or not selection.automatically_added:
			continue
		var capability_id := selection.capability_id.strip_edges().to_lower()
		if unique_selected_ids.has(capability_id):
			continue
		if initial_enabled.has(capability_id):
			auto_required_already_present.append(capability_id)
		else:
			auto_required.append(capability_id)

	return {
		"ok": true,
		"changed": bool(application_plan.get("changed", false)),
		"selections": next_selections,
		"user_selected_ids": selected_by_user,
		"auto_required_ids": auto_required,
		"auto_required_already_present_ids": auto_required_already_present,
		"already_present_ids": already_present,
		"application_plan": application_plan,
		"errors": PackedStringArray()
	}


static func _unique_normalized_ids(values: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for value in values:
		var normalized_id := value.strip_edges().to_lower()
		if normalized_id.is_empty() or result.has(normalized_id):
			continue
		result.append(normalized_id)
	return result


static func _to_packed_errors(value: Variant) -> PackedStringArray:
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		var packed_errors: PackedStringArray = value
		return packed_errors.duplicate()
	var result := PackedStringArray()
	if value is Array:
		for item in value:
			result.append(str(item))
	elif value != null:
		result.append(str(value))
	return result


static func _failed_plan(errors: PackedStringArray) -> Dictionary:
	return {
		"ok": false,
		"changed": false,
		"selections": [],
		"user_selected_ids": PackedStringArray(),
		"auto_required_ids": PackedStringArray(),
		"auto_required_already_present_ids": PackedStringArray(),
		"already_present_ids": PackedStringArray(),
		"application_plan": {
			"ok": false,
			"changed": false,
			"errors": errors.duplicate()
		},
		"errors": errors
	}
