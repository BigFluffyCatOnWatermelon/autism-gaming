@tool
extends RefCounted
class_name CapabilityCatalogController
## Owns catalog filtering, multi-selection state and batch plan presentation.

const SelectionSessionScript = preload("res://addons/object_builder/controllers/capability_selection_session.gd")
const BatchPlannerScript = preload("res://addons/object_builder/services/capability_batch_planner.gd")

var _selection_session: RefCounted = SelectionSessionScript.new()


func set_selected(capability_id: String, selected: bool) -> void:
	if selected:
		_selection_session.call("select", capability_id)
	else:
		_selection_session.call("deselect", capability_id)


func is_selected(capability_id: String) -> bool:
	return bool(_selection_session.call("contains", capability_id))


func clear_selection() -> void:
	_selection_session.call("clear")


func get_selected_ids() -> PackedStringArray:
	return _selection_session.call("get_selected_ids")


func get_selected_count() -> int:
	return int(_selection_session.call("get_count"))


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
			"can_configure": is_enabled and is_ready
		})
	return result


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
