@tool
extends RefCounted
class_name CapabilityCatalogController
## Owns catalog filtering, multi-selection state and batch plan presentation.

const SelectionSessionScript = preload("res://addons/object_builder/controllers/capability_selection_session.gd")
const BatchPlannerScript = preload("res://addons/object_builder/services/capability_batch_planner.gd")
const PresetRegistryScript = preload("res://addons/object_builder/services/capability_preset_registry.gd")
const PresetStoreScript = preload("res://addons/object_builder/services/capability_preset_store.gd")

var _selection_session: RefCounted = SelectionSessionScript.new()
var _focused_capability_id := ""
var _active_preset_id := ""
var _preset_store: RefCounted = PresetStoreScript.new()


func set_selected(capability_id: String, selected: bool) -> void:
	_focused_capability_id = capability_id.strip_edges().to_lower()
	if selected:
		_selection_session.call("select", capability_id)
	else:
		_selection_session.call("deselect", capability_id)


func set_focused_capability(capability_id: String) -> void:
	_focused_capability_id = capability_id.strip_edges().to_lower()


func get_focused_capability_id() -> String:
	return _focused_capability_id


func is_selected(capability_id: String) -> bool:
	return bool(_selection_session.call("contains", capability_id))


func clear_selection() -> void:
	_selection_session.call("clear")
	_focused_capability_id = ""


func get_selected_ids() -> PackedStringArray:
	return _selection_session.call("get_selected_ids")


func get_selected_count() -> int:
	return int(_selection_session.call("get_count"))


func set_active_preset(preset_id: String) -> void:
	var normalized_id := preset_id.strip_edges().to_lower()
	var preset := _get_preset_definition(normalized_id)
	_active_preset_id = normalized_id if not preset.is_empty() else ""


func get_active_preset_id() -> String:
	return _active_preset_id


func get_preset_definition(preset_id: String) -> Dictionary:
	return _get_preset_definition(preset_id.strip_edges().to_lower())


func build_unique_custom_preset_id(display_name: String) -> String:
	var normalized_name := display_name.strip_edges().to_lower().replace("ё", "е")
	var transliteration := {
		"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e",
		"ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l",
		"м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s",
		"т": "t", "у": "u", "ф": "f", "х": "h", "ц": "ts", "ч": "ch",
		"ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "", "э": "e",
		"ю": "yu", "я": "ya"
	}
	var slug := ""
	for index in range(normalized_name.length()):
		var character := normalized_name.substr(index, 1)
		if transliteration.has(character):
			slug += str(transliteration[character])
		elif "abcdefghijklmnopqrstuvwxyz0123456789_-".contains(character):
			slug += character
		elif not slug.ends_with("_"):
			slug += "_"
	while slug.begins_with("_"):
		slug = slug.substr(1)
	while slug.ends_with("_"):
		slug = slug.left(slug.length() - 1)
	if slug.is_empty():
		slug = "preset"
	var base_id := "user_" + slug.left(43)
	var used_ids: Dictionary = {}
	for preset in _get_all_presets():
		used_ids[str(preset.get("id", ""))] = true
	var candidate := base_id
	var suffix := 2
	while used_ids.has(candidate):
		var suffix_text := "_" + str(suffix)
		candidate = base_id.left(48 - suffix_text.length()) + suffix_text
		suffix += 1
	return candidate


func build_preset_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for preset in _get_all_presets():
		var capability_ids: Array = preset.get("capability_ids", [])
		var ready_count := 0
		var installed_count := 0
		var selected_count := 0
		for capability_id_value in capability_ids:
			var capability_id := str(capability_id_value)
			var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
			if definition != null and definition.is_ready():
				ready_count += 1
			if is_selected(capability_id):
				selected_count += 1
		result.append({
			"id": str(preset.get("id", "")),
			"display_name": str(preset.get("display_name", "")),
			"description": str(preset.get("description", "")),
			"icon": str(preset.get("icon", "shapes")),
			"total_count": capability_ids.size(),
			"ready_count": ready_count,
			"selected_count": selected_count,
			"is_custom": bool(preset.get("is_custom", false))
		})
	return result


func save_custom_preset(preset: Dictionary) -> Dictionary:
	return _preset_store.call("save_preset", preset)


func duplicate_custom_preset(source_id: String, new_id: String, new_name: String) -> Dictionary:
	return _preset_store.call("duplicate_preset", source_id, new_id, new_name)


func delete_custom_preset(preset_id: String) -> Dictionary:
	if _active_preset_id == preset_id:
		_active_preset_id = ""
	return _preset_store.call("delete_preset", preset_id)


func get_custom_presets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for preset in _preset_store.call("load_presets"):
		var copy: Dictionary = preset.duplicate(true)
		copy["is_custom"] = true
		result.append(copy)
	return result


func _get_all_presets() -> Array[Dictionary]:
	var result := PresetRegistryScript.get_presets()
	for preset in get_custom_presets():
		result.append(preset)
	return result


func _get_preset_definition(preset_id: String) -> Dictionary:
	for preset in get_custom_presets():
		if str(preset.get("id", "")) == preset_id:
			return preset
	return PresetRegistryScript.get_preset(preset_id)


func build_active_preset_details(
	current_selections: Array[ObjectCapabilitySelection]
) -> Dictionary:
	if _active_preset_id.is_empty():
		return {}
	var preset := _get_preset_definition(_active_preset_id)
	if preset.is_empty():
		return {}

	var simulated := _copy_plan_selections(current_selections)
	var installed_ids: Dictionary = {}
	for selection in current_selections:
		if selection != null and selection.enabled:
			installed_ids[selection.capability_id.strip_edges().to_lower()] = true

	for selected_id in get_selected_ids():
		if selected_id.is_empty():
			continue
		var selected_plan := ObjectCapabilityService.plan_selection_change(simulated, selected_id, true)
		if bool(selected_plan.get("ok", false)):
			simulated = _copy_plan_selections(selected_plan.get("selections", []))

	var entries: Array[Dictionary] = []
	var available_count := 0
	var selected_count := 0
	var installed_count := 0
	for capability_id_value in preset.get("capability_ids", []):
		var capability_id := str(capability_id_value).strip_edges().to_lower()
		var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		if definition == null:
			entries.append({
				"capability_id": capability_id,
				"display_name": capability_id,
				"available": false,
				"blocked_reason": "Возможность отсутствует в каталоге."
			})
			continue

		var is_enabled := installed_ids.has(capability_id)
		var is_selected_in_catalog := is_selected(capability_id)
		var can_select := false
		var blocked_reason := ""
		var dependency_names := PackedStringArray()

		if not definition.is_ready():
			blocked_reason = "Возможность ещё разрабатывается."
		elif is_enabled:
			installed_count += 1
			blocked_reason = "Уже установлена."
		elif is_selected_in_catalog:
			can_select = true
			selected_count += 1
		else:
			var plan := ObjectCapabilityService.plan_selection_change(simulated, capability_id, true)
			if bool(plan.get("ok", false)):
				can_select = true
				available_count += 1
				var added_ids: PackedStringArray = plan.get("added_capability_ids", PackedStringArray())
				for added_id in added_ids:
					if added_id == capability_id:
						continue
					var dependency := ObjectCapabilityCatalog.get_definition_reference(added_id)
					if dependency != null and not dependency_names.has(dependency.display_name):
						dependency_names.append(dependency.display_name)
				simulated = _copy_plan_selections(plan.get("selections", []))
			else:
				var errors: PackedStringArray = plan.get("errors", PackedStringArray())
				blocked_reason = "; ".join(errors)

		entries.append({
			"capability_id": capability_id,
			"definition": definition,
			"display_name": definition.display_name,
			"description": definition.description,
			"ready": definition.is_ready(),
			"installed": is_enabled,
			"selected": is_selected_in_catalog,
			"can_select": can_select,
			"blocked_reason": blocked_reason,
			"automatic_dependencies": dependency_names
		})

	return {
		"id": _active_preset_id,
		"display_name": str(preset.get("display_name", "")),
		"description": str(preset.get("description", "")),
		"is_custom": bool(preset.get("is_custom", false)),
		"capability_ids": (preset.get("capability_ids", []) as Array).duplicate(),
		"entries": entries,
		"available_count": available_count,
		"installed_count": installed_count,
		"selected_count": selected_count
	}


func select_all_available_from_active_preset(
	current_selections: Array[ObjectCapabilitySelection]
) -> int:
	var details := build_active_preset_details(current_selections)
	var added_count := 0
	for entry in details.get("entries", []):
		if not bool(entry.get("can_select", false)):
			continue
		if _selection_session.call("select", str(entry.get("capability_id", ""))):
			added_count += 1
	return added_count


func build_entries(
	capability_ids: PackedStringArray,
	current_selections: Array[ObjectCapabilitySelection],
	query: String = ""
) -> Array[Dictionary]:
	var normalized_query := query.strip_edges().to_lower()
	var selections_by_id: Dictionary = {}
	for selection in current_selections:
		if selection == null:
			continue
		selections_by_id[selection.capability_id.strip_edges().to_lower()] = selection

	var relationship_highlights := _build_relationship_highlights()
	var related_capability_ids := _build_related_capability_id_set()
	var result: Array[Dictionary] = []
	for capability_id in capability_ids:
		var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		if definition == null:
			continue
		if not _matches_query(definition, normalized_query):
			continue

		var selection := selections_by_id.get(capability_id) as ObjectCapabilitySelection
		var is_enabled := selection != null and selection.enabled
		var is_ready := definition.is_ready()
		result.append({
			"definition": definition,
			"installed": selection != null,
			"enabled": is_enabled,
			"selected_in_catalog": is_selected(capability_id),
			"automatically_added": selection != null and selection.automatically_added,
			"can_toggle": is_ready and not (selection != null and selection.automatically_added),
			"can_configure": is_enabled and is_ready,
			"has_relations": related_capability_ids.has(capability_id),
			"relation_highlight": relationship_highlights.get(capability_id, {})
		})
	return result


func _build_related_capability_id_set() -> Dictionary:
	var related_ids: Dictionary = {}
	for capability_id in ObjectCapabilityCatalog.get_capability_ids("", false):
		var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		if definition == null:
			continue
		var relations := _get_declared_relations(definition)
		if relations.is_empty():
			continue
		related_ids[capability_id] = true
		for relation in relations:
			var target_id := str(relation.get("target_id", ""))
			if not target_id.is_empty():
				related_ids[target_id] = true
	return related_ids


func build_related_entries() -> Array[Dictionary]:
	var result_by_id: Dictionary = {}
	if _focused_capability_id.is_empty():
		return []
	var focused_definition := ObjectCapabilityCatalog.get_definition_reference(_focused_capability_id)
	if focused_definition == null:
		return []

	for relation in _get_declared_relations(focused_definition):
		_append_related_entry(
			result_by_id,
			str(relation.get("target_id", "")),
			str(relation.get("type", "related")),
			str(relation.get("explanation", "")),
			false
		)

	for other_id in ObjectCapabilityCatalog.get_capability_ids("", false):
		if other_id == _focused_capability_id:
			continue
		var other_definition := ObjectCapabilityCatalog.get_definition_reference(other_id)
		if other_definition == null:
			continue
		for relation in _get_declared_relations(other_definition):
			if str(relation.get("target_id", "")) != _focused_capability_id:
				continue
			var explanation := str(relation.get("explanation", ""))
			if explanation.is_empty():
				explanation = "Эта возможность связана с выбранной механикой."
			_append_related_entry(
				result_by_id,
				other_id,
				str(relation.get("type", "related")),
				explanation,
				true
			)

	var result: Array[Dictionary] = []
	for entry in result_by_id.values():
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order := {
			"requires": 0,
			"conflicts": 1,
			"recommends": 2,
			"extends": 3,
			"alternative": 4,
			"related": 5
		}
		var order_a := int(order.get(str(a.get("relation_type", "related")), 5))
		var order_b := int(order.get(str(b.get("relation_type", "related")), 5))
		if order_a == order_b:
			var def_a := a.get("definition") as ObjectCapabilityDefinition
			var def_b := b.get("definition") as ObjectCapabilityDefinition
			if def_a == null or def_b == null:
				return str(a.get("capability_id", "")) < str(b.get("capability_id", ""))
			return def_a.display_name.naturalnocasecmp_to(def_b.display_name) < 0
		return order_a < order_b
	)
	return result


func build_recommended_entries(
	current_selections: Array[ObjectCapabilitySelection],
	query: String = "",
	max_results: int = 8,
	profile_id: String = "",
	object_category: String = "",
	object_tags: PackedStringArray = PackedStringArray()
) -> Array[Dictionary]:
	var context_ids: Dictionary = {}
	var already_present: Dictionary = {}
	var simulated: Array[ObjectCapabilitySelection] = []
	for selection in current_selections:
		if selection == null:
			continue
		var copy := selection.duplicate(true) as ObjectCapabilitySelection
		simulated.append(copy)
		var capability_id := copy.capability_id.strip_edges().to_lower()
		if copy.enabled:
			context_ids[capability_id] = true
			already_present[capability_id] = true

	for capability_id in get_selected_ids():
		var normalized_id := capability_id.strip_edges().to_lower()
		if normalized_id.is_empty():
			continue
		context_ids[normalized_id] = true
		already_present[normalized_id] = true
		var step_plan := ObjectCapabilityService.plan_selection_change(simulated, normalized_id, true)
		if not bool(step_plan.get("ok", false)):
			continue
		simulated = _copy_plan_selections(step_plan.get("selections", []))

	if not _focused_capability_id.is_empty():
		context_ids[_focused_capability_id] = true

	var candidates: Dictionary = {}
	for source_id in context_ids:
		var source_definition := ObjectCapabilityCatalog.get_definition_reference(str(source_id))
		if source_definition == null:
			continue
		for relation in _get_declared_relations(source_definition):
			var target_id := str(relation.get("target_id", "")).strip_edges().to_lower()
			var relation_type := str(relation.get("type", "related")).strip_edges().to_lower()
			_add_recommendation_candidate(
				candidates,
				target_id,
				source_definition,
				relation_type,
				str(relation.get("explanation", "")),
				false,
				already_present
			)

	for candidate_id in ObjectCapabilityCatalog.get_capability_ids("", false):
		if context_ids.has(candidate_id) or already_present.has(candidate_id):
			continue
		var candidate_definition := ObjectCapabilityCatalog.get_definition_reference(candidate_id)
		if candidate_definition == null:
			continue
		for relation in _get_declared_relations(candidate_definition):
			var target_id := str(relation.get("target_id", "")).strip_edges().to_lower()
			if not context_ids.has(target_id):
				continue
			var target_definition := ObjectCapabilityCatalog.get_definition_reference(target_id)
			if target_definition == null:
				continue
			_add_recommendation_candidate(
				candidates,
				candidate_id,
				target_definition,
				str(relation.get("type", "related")),
				str(relation.get("explanation", "")),
				true,
				already_present
			)

	var normalized_profile_id := profile_id.strip_edges().to_lower()
	var recommendation_profiles: Array[ObjectCreationProfileDefinition] = []
	var explicit_profile: ObjectCreationProfileDefinition = (
		ObjectCreationProfileRegistry.get_definition(normalized_profile_id)
		if not normalized_profile_id.is_empty()
		else null
	)
	if explicit_profile != null and not explicit_profile.suggested_capability_ids.is_empty():
		recommendation_profiles.append(explicit_profile)
	elif explicit_profile == null or normalized_profile_id.is_empty() or normalized_profile_id == "other":
		var normalized_object_category := object_category.strip_edges().to_lower()
		if not normalized_object_category.is_empty():
			for category_profile_id in ObjectCreationProfileRegistry.get_profile_ids():
				var category_profile := ObjectCreationProfileRegistry.get_definition(category_profile_id)
				if category_profile == null or category_profile.suggested_capability_ids.is_empty():
					continue
				if category_profile.suggested_category.strip_edges().to_lower() != normalized_object_category:
					continue
				recommendation_profiles.append(category_profile)

	for profile in recommendation_profiles:
		for suggested_id in profile.suggested_capability_ids:
			_add_profile_recommendation_candidate(
				candidates,
				str(suggested_id),
				profile,
				already_present
			)

	var normalized_query := query.strip_edges().to_lower()
	var normalized_category := object_category.strip_edges().to_lower()
	var normalized_tags := PackedStringArray()
	for tag in object_tags:
		var clean_tag := tag.strip_edges().to_lower()
		if not clean_tag.is_empty() and not normalized_tags.has(clean_tag):
			normalized_tags.append(clean_tag)
	var result: Array[Dictionary] = []
	for candidate_id in candidates:
		var candidate_definition := ObjectCapabilityCatalog.get_definition_reference(str(candidate_id))
		if candidate_definition == null or not candidate_definition.is_ready():
			continue
		if already_present.has(candidate_id) or is_selected(str(candidate_id)):
			continue

		var candidate_data: Dictionary = candidates[candidate_id]
		var plan := ObjectCapabilityService.plan_selection_change(simulated, str(candidate_id), true)
		if not bool(plan.get("ok", false)):
			continue

		var score := int(candidate_data.get("score", 0))
		var matched_tags := PackedStringArray()
		if not normalized_query.is_empty() and _matches_query(candidate_definition, normalized_query):
			score += 18
		for tag in normalized_tags:
			if _matches_query(candidate_definition, tag):
				score += 6
				matched_tags.append(tag)
		if not normalized_category.is_empty() and candidate_definition.category_id.to_lower() == normalized_category:
			score += 4
		var added_ids: PackedStringArray = plan.get("added_capability_ids", PackedStringArray())
		var automatic_names := PackedStringArray()
		for added_id in added_ids:
			if added_id == candidate_id:
				continue
			var dependency := ObjectCapabilityCatalog.get_definition_reference(added_id)
			if dependency != null:
				automatic_names.append(dependency.display_name)

		var explanation := str(candidate_data.get("explanation", ""))
		if not normalized_query.is_empty() and _matches_query(candidate_definition, normalized_query):
			explanation += " Подходит под твой поисковый запрос."
		if not matched_tags.is_empty():
			explanation += " Совпадают метки объекта: " + ", ".join(matched_tags) + "."
		if not automatic_names.is_empty():
			explanation += " Вместе потребуется: " + ", ".join(automatic_names) + "."
		result.append({
			"capability_id": str(candidate_id),
			"definition": candidate_definition,
			"score": score,
			"relation_type": str(candidate_data.get("relation_type", "related")),
			"explanation": explanation,
			"source_names": candidate_data.get("source_names", PackedStringArray()),
			"automatic_dependencies": automatic_names,
			"ready": true
		})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("score", 0))
		var score_b := int(b.get("score", 0))
		if score_a == score_b:
			var definition_a := a.get("definition") as ObjectCapabilityDefinition
			var definition_b := b.get("definition") as ObjectCapabilityDefinition
			if definition_a == null or definition_b == null:
				return str(a.get("capability_id", "")) < str(b.get("capability_id", ""))
			return definition_a.display_name.naturalnocasecmp_to(definition_b.display_name) < 0
		return score_a > score_b
	)
	if result.size() > maxi(1, max_results):
		result.resize(maxi(1, max_results))
	return result


func _add_recommendation_candidate(
	candidates: Dictionary,
	candidate_id: String,
	source_definition: ObjectCapabilityDefinition,
	relation_type: String,
	explanation: String,
	is_reverse: bool,
	already_present: Dictionary
) -> void:
	var normalized_id := candidate_id.strip_edges().to_lower()
	if normalized_id.is_empty() or already_present.has(normalized_id):
		return
	if relation_type == "conflicts":
		return
	var candidate_definition := ObjectCapabilityCatalog.get_definition_reference(normalized_id)
	if candidate_definition == null or not candidate_definition.is_ready():
		return
	var relation_score := _recommendation_relation_score(relation_type)
	if relation_score <= 0:
		return

	var source_name := source_definition.display_name
	var reason := explanation.strip_edges()
	if reason.is_empty():
		reason = "Подходит в сочетании с возможностью «%s»." % source_name
	else:
		reason = "Вместе с «%s»: %s" % [source_name, reason]
	if is_reverse:
		reason = "«%s» дополняет выбранное поведение: %s" % [candidate_definition.display_name, reason]

	if not candidates.has(normalized_id):
		candidates[normalized_id] = {
			"score": relation_score,
			"relation_type": relation_type,
			"explanation": reason,
			"source_names": PackedStringArray([source_name])
		}
		return

	var existing: Dictionary = candidates[normalized_id]
	var existing_score := int(existing.get("score", 0))
	if relation_score > existing_score:
		existing["score"] = relation_score
		existing["relation_type"] = relation_type
		existing["explanation"] = reason
	else:
		existing["score"] = existing_score + 4
	var source_names: PackedStringArray = existing.get("source_names", PackedStringArray())
	if not source_names.has(source_name):
		source_names.append(source_name)
		existing["source_names"] = source_names
		if relation_score <= existing_score:
			existing["explanation"] = str(existing.get("explanation", "")) + " Также связано с «%s»." % source_name
	candidates[normalized_id] = existing


func _add_profile_recommendation_candidate(
	candidates: Dictionary,
	capability_id: String,
	profile: ObjectCreationProfileDefinition,
	already_present: Dictionary
) -> void:
	var normalized_id := capability_id.strip_edges().to_lower()
	if normalized_id.is_empty() or already_present.has(normalized_id) or is_selected(normalized_id):
		return
	var definition := ObjectCapabilityCatalog.get_definition_reference(normalized_id)
	if definition == null or not definition.is_ready():
		return

	var profile_score := 68
	var explanation := "Подходит профилю «%s»: %s" % [
		profile.display_name,
		profile.description.strip_edges()
	]
	if explanation.ends_with(": "):
		explanation = "Подходит профилю «%s»." % profile.display_name

	if not candidates.has(normalized_id):
		candidates[normalized_id] = {
			"score": profile_score,
			"relation_type": "profile",
			"explanation": explanation,
			"source_names": PackedStringArray([profile.display_name])
		}
		return

	var existing: Dictionary = candidates[normalized_id]
	var existing_score := int(existing.get("score", 0))
	if profile_score > existing_score:
		existing["score"] = profile_score
		existing["relation_type"] = "profile"
		existing["explanation"] = explanation
	else:
		existing["score"] = existing_score + 3
	var source_names: PackedStringArray = existing.get("source_names", PackedStringArray())
	if not source_names.has(profile.display_name):
		source_names.append(profile.display_name)
		existing["source_names"] = source_names
		existing["explanation"] = str(existing.get("explanation", "")) + " Также подходит профилю «%s»." % profile.display_name
	candidates[normalized_id] = existing


func _recommendation_relation_score(relation_type: String) -> int:
	match relation_type:
		"profile":
			return 68
		"requires":
			return 120
		"recommends":
			return 90
		"extends":
			return 72
		"alternative":
			return 35
		"related":
			return 24
		_:
			return 0


func _copy_plan_selections(values: Variant) -> Array[ObjectCapabilitySelection]:
	var result: Array[ObjectCapabilitySelection] = []
	if not values is Array:
		return result
	for value in values:
		if value is ObjectCapabilitySelection:
			result.append((value as ObjectCapabilitySelection).duplicate(true) as ObjectCapabilitySelection)
	return result


func _append_related_entry(
	result_by_id: Dictionary,
	capability_id: String,
	relation_type: String,
	explanation: String,
	is_reverse: bool
) -> void:
	var normalized_id := capability_id.strip_edges().to_lower()
	if normalized_id.is_empty() or normalized_id == _focused_capability_id:
		return
	var definition := ObjectCapabilityCatalog.get_definition_reference(normalized_id)
	if definition == null:
		return
	if result_by_id.has(normalized_id):
		return
	result_by_id[normalized_id] = {
		"capability_id": normalized_id,
		"definition": definition,
		"relation_type": relation_type,
		"explanation": explanation,
		"is_reverse": is_reverse,
		"ready": definition.is_ready()
	}


func count_ready(capability_ids: PackedStringArray) -> int:
	var count := 0
	for capability_id in capability_ids:
		var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		if definition != null and definition.is_ready():
			count += 1
	return count


func build_addition_plan(
	current_selections: Array[ObjectCapabilitySelection],
	scene_root: Node = null
) -> Dictionary:
	return BatchPlannerScript.build_addition_plan(
		current_selections,
		get_selected_ids(),
		scene_root
	)


func get_plan_selections(plan: Dictionary) -> Array[ObjectCapabilitySelection]:
	var result: Array[ObjectCapabilitySelection] = []
	var values: Variant = plan.get("selections", [])
	if not values is Array:
		return result
	for value in values:
		if value is ObjectCapabilitySelection:
			result.append((value as ObjectCapabilitySelection).duplicate(true) as ObjectCapabilitySelection)
	return result


func build_batch_summary(plan: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var user_selected: PackedStringArray = plan.get("user_selected_ids", PackedStringArray())
	var auto_required: PackedStringArray = plan.get("auto_required_ids", PackedStringArray())
	var auto_existing: PackedStringArray = plan.get("auto_required_already_present_ids", PackedStringArray())
	var already_present: PackedStringArray = plan.get("already_present_ids", PackedStringArray())
	if not user_selected.is_empty():
		lines.append("Выбрано тобой: " + _get_display_names(user_selected) + ".")
	if not auto_required.is_empty():
		lines.append("Добавятся автоматически как зависимости: " + _get_display_names(auto_required) + ".")
	if not auto_existing.is_empty():
		lines.append("Уже есть необходимые зависимости: " + _get_display_names(auto_existing) + ".")
	if not already_present.is_empty():
		lines.append("Уже установлено: " + _get_display_names(already_present) + ".")

	var application_plan: Dictionary = plan.get("application_plan", {})
	var summary_value: Variant = application_plan.get("summary_lines", PackedStringArray())
	if summary_value is PackedStringArray:
		var packed_lines: PackedStringArray = summary_value
		lines.append_array(packed_lines)
	elif summary_value is Array:
		for line in summary_value:
			lines.append(str(line))
	return lines


func _build_relationship_highlights() -> Dictionary:
	var highlights: Dictionary = {}
	if _focused_capability_id.is_empty():
		return highlights
	var focused_definition := ObjectCapabilityCatalog.get_definition_reference(_focused_capability_id)
	if focused_definition == null:
		return highlights

	for relation in _get_declared_relations(focused_definition):
		var target_id := str(relation.get("target_id", ""))
		if target_id.is_empty() or target_id == _focused_capability_id:
			continue
		_store_relationship_highlight(
			highlights,
			target_id,
			str(relation.get("type", "related")),
			str(relation.get("explanation", "")),
			false
		)

	for other_id in ObjectCapabilityCatalog.get_capability_ids("", false):
		if other_id == _focused_capability_id:
			continue
		var other_definition := ObjectCapabilityCatalog.get_definition_reference(other_id)
		if other_definition == null:
			continue
		for relation in _get_declared_relations(other_definition):
			if str(relation.get("target_id", "")) != _focused_capability_id:
				continue
			var relation_type := str(relation.get("type", "related"))
			var explanation := str(relation.get("explanation", ""))
			if explanation.is_empty():
				explanation = "Эта возможность связана с выбранной механикой."
			_store_relationship_highlight(
				highlights,
				other_id,
				relation_type,
				explanation,
				true
			)
	return highlights


func _get_declared_relations(definition: ObjectCapabilityDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if definition == null:
		return result
	for required_id in definition.required_capability_ids:
		result.append({
			"type": "requires",
			"target_id": str(required_id).strip_edges().to_lower(),
			"explanation": "Обязательная зависимость: нужна для работы выбранной возможности."
		})
	for conflict_id in definition.incompatible_capability_ids:
		result.append({
			"type": "conflicts",
			"target_id": str(conflict_id).strip_edges().to_lower(),
			"explanation": "Эти две возможности нельзя использовать вместе."
		})
	for relation in definition.relations:
		var relation_type := str(relation.get("type", "related")).strip_edges().to_lower()
		var target_id := str(relation.get("target_id", "")).strip_edges().to_lower()
		if target_id.is_empty():
			continue
		var duplicate := false
		for existing in result:
			if str(existing.get("type", "")) == relation_type and str(existing.get("target_id", "")) == target_id:
				duplicate = true
				break
		if not duplicate:
			result.append({
				"type": relation_type,
				"target_id": target_id,
				"explanation": str(relation.get("explanation", "")).strip_edges()
			})
	return result


func _store_relationship_highlight(
	highlights: Dictionary,
	capability_id: String,
	relation_type: String,
	explanation: String,
	is_reverse: bool
) -> void:
	if highlights.has(capability_id):
		return
	highlights[capability_id] = {
		"type": relation_type,
		"explanation": explanation,
		"is_reverse": is_reverse
	}


func _get_display_names(capability_ids: PackedStringArray) -> String:
	var names := PackedStringArray()
	for capability_id in capability_ids:
		var definition := ObjectCapabilityCatalog.get_definition(capability_id)
		names.append(definition.display_name if definition != null else capability_id)
	return ", ".join(names)


func _matches_query(definition: ObjectCapabilityDefinition, query: String) -> bool:
	if query.is_empty():
		return true
	var searchable := (
		definition.display_name + " " + definition.description + " "
		+ " ".join(definition.keywords) + " "
		+ " ".join(definition.synonyms) + " "
		+ " ".join(definition.example_queries) + " "
		+ definition.category_name + " " + definition.kind_id
	).to_lower().replace("ё", "е")
	if searchable.contains(query):
		return true

	# Match all meaningful words independently, allowing common Russian endings
	# to differ between the user's phrase and indexed examples.
	var query_tokens := _tokenize(query)
	var searchable_tokens := _tokenize(searchable)
	if query_tokens.is_empty():
		return true
	for query_token in query_tokens:
		var found := false
		for searchable_token in searchable_tokens:
			if _tokens_share_stem(query_token, searchable_token):
				found = true
				break
		if not found:
			return false
	return true


func _tokenize(value: String) -> PackedStringArray:
	var normalized := value.to_lower().replace("ё", "е")
	for punctuation in [",", ".", "!", "?", ":", ";", "(", ")", "[", "]", "-", "_", "\n", "\t"]:
		normalized = normalized.replace(punctuation, " ")
	var tokens := PackedStringArray()
	for raw_token in normalized.split(" ", false):
		var token := raw_token.strip_edges()
		if token.length() < 2 or _is_search_stop_word(token):
			continue
		if not tokens.has(token):
			tokens.append(token)
	return tokens


func _tokens_share_stem(first: String, second: String) -> bool:
	if first == second:
		return true
	var shared_length := mini(4, mini(first.length(), second.length()))
	if shared_length < 4:
		return false
	return first.left(shared_length) == second.left(shared_length)


func _is_search_stop_word(token: String) -> bool:
	return token in [
		"чтобы", "что", "как", "для", "при", "после", "перед", "если",
		"это", "этот", "эта", "эти", "объект", "объекта", "мог", "могла",
		"могло", "можно", "должен", "должна", "должно", "иметь", "имеет",
		"сделать", "сделай", "надо", "нужно", "от", "из", "в", "на", "с", "и"
	]
