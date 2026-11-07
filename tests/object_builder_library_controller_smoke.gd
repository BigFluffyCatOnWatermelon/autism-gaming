extends SceneTree

const ControllerScript = preload("res://addons/object_builder/controllers/library_controller.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller = ControllerScript.new()
	var oak = DefinitionScript.new()
	oak.object_id = "tree_oak"
	oak.display_name = "Дуб"
	oak.description = "Большое дерево"
	oak.category = "Nature"
	oak.tags = PackedStringArray(["tree", "wood", "forest"])
	oak.object_type = "resource"

	var pine = DefinitionScript.new()
	pine.object_id = "tree_pine"
	pine.display_name = "Сосна"
	pine.description = "Хвойное дерево"
	pine.category = "Nature"
	pine.tags = PackedStringArray(["tree", "wood"])
	pine.object_type = "resource"

	var stone = DefinitionScript.new()
	stone.object_id = "stone_granite"
	stone.display_name = "Гранит"
	stone.description = "Твёрдый камень"
	stone.category = "Nature"
	stone.tags = PackedStringArray(["stone", "mineral"])
	stone.object_type = "resource"

	var weapon = DefinitionScript.new()
	weapon.object_id = "weapon_sword"
	weapon.display_name = "Меч"
	weapon.description = "Оружие ближнего боя"
	weapon.category = "Equipment"
	weapon.tags = PackedStringArray(["weapon", "steel"])
	weapon.object_type = "equipment"

	var damageable_selection := ObjectCapabilitySelection.new()
	damageable_selection.capability_id = "can_receive_damage"
	oak.capabilities.append(damageable_selection)

	var definitions: Array[ObjectDefinition] = [stone, weapon, pine, oak]
	var no_templates: Array[ObjectDefinition] = []
	controller.call("set_library_data", definitions, no_templates)
	_expect(int(controller.call("get_definition_count")) == 4, "library data is loaded")
	_expect((controller.get("definitions") as Array).size() == 4, "definitions are owned by the controller")
	_expect(controller.call("find_definition", "tree_oak") == oak, "object ID index resolves a definition")
	_expect(controller.call("find_definition", "missing") == null, "unknown IDs return null")

	var categories: Array[Dictionary] = controller.call("get_category_options", "Nature")
	var found_equipment := false
	for category in categories:
		if category.get("id") == "Equipment" and category.get("label") == "Экипировка":
			found_equipment = true
	_expect(found_equipment, "known category names are translated")
	var tags: Array[Dictionary] = controller.call("get_tag_options", "")
	_expect(tags.size() == 7, "tag options are unique")

	var entries: Array[Dictionary] = controller.call("build_visible_entries", "", "", "", "all")
	_expect(entries.size() == 4, "all mode returns every library definition")
	_expect(entries[0].get("definition") == stone and entries[1].get("definition") == oak, "library entries are sorted by display name")
	_expect(controller.call("get_visible_definition", 0) == stone and controller.call("get_visible_definition", 1) == oak, "visible item index resolves to its definition")
	_expect(str(entries[0].get("title")).begins_with("Гранит"), "library entry titles preserve the display name")
	_expect(str(entries[0].get("tooltip")).contains("Твёрдый камень"), "library entry tooltip includes description")
	_expect(entries[0].get("category_label") == "Природа", "library entries expose localized category labels")

	entries = controller.call("build_visible_entries", "дерево", "", "", "all")
	_expect(entries.size() == 2, "search uses cached case-normalized text")
	entries = controller.call("build_visible_entries", "", "Equipment", "", "all")
	_expect(entries.size() == 1 and entries[0].get("definition") == weapon, "category filter is applied")
	entries = controller.call("build_visible_entries", "", "", "stone", "all")
	_expect(entries.size() == 1 and entries[0].get("definition") == stone, "tag filter is applied")
	entries = controller.call("build_visible_entries", "можно повредить", "", "", "all")
	_expect(entries.size() == 1 and entries[0].get("definition") == oak, "search includes enabled capability names and descriptions")
	var detail_data: Dictionary = controller.call("build_detail_data", oak)
	_expect(detail_data.get("category") == "Природа", "details translate known category IDs to user-facing labels")
	_expect(str(detail_data.get("capabilities_text", "")).contains("Можно повредить"), "details include enabled capability display names")
	_expect(str(detail_data.get("dependencies_text", "")).contains("Есть здоровье"), "details explain required capability dependencies")

	controller.call("toggle_favorite", "tree_oak")
	controller.call("toggle_favorite", "weapon_sword")
	_expect(bool(controller.call("is_favorite", "tree_oak")), "favorite state is stored")
	entries = controller.call("build_visible_entries", "", "", "", "favorites")
	_expect(entries.size() == 2, "favorites mode only shows favorite definitions")
	_expect(str(entries[0].get("title")).begins_with("★ "), "favorite entries receive the star prefix")
	controller.call("toggle_favorite", "tree_oak")
	_expect(not bool(controller.call("is_favorite", "tree_oak")), "favorite can be removed")

	controller.call("record_recent", "tree_pine")
	controller.call("record_recent", "tree_oak")
	controller.call("record_recent", "tree_pine")
	var recent: PackedStringArray = controller.call("get_recent_ids")
	_expect(recent == PackedStringArray(["tree_pine", "tree_oak"]), "recent list moves repeated entries to the front")
	entries = controller.call("build_visible_entries", "", "", "", "recent")
	_expect(entries.size() == 2 and entries[0].get("definition") == pine, "recent mode preserves visit order")
	controller.call("record_recent", "missing")
	entries = controller.call("build_visible_entries", "", "", "", "recent")
	_expect(entries.size() == 2, "missing recent IDs are skipped")

	var collection_id := str(controller.call("create_collection", "Лесные ресурсы"))
	_expect(not collection_id.is_empty(), "custom collection receives a stable ID")
	_expect(controller.call("add_to_collection", collection_id, "tree_oak"), "object can be added to a custom collection")
	_expect(not controller.call("add_to_collection", collection_id, "tree_oak"), "duplicate collection membership is rejected")
	entries = controller.call("build_visible_entries", "", "", "", "collection:" + collection_id)
	_expect(entries.size() == 1 and entries[0].get("definition") == oak, "collection navigation shows only its saved objects")
	var collection_options: Array[Dictionary] = controller.call("get_collection_options")
	_expect(collection_options.size() == 1 and collection_options[0].get("label") == "Лесные ресурсы", "custom collections expose user-facing navigation labels")
	_expect(controller.call("remove_from_collection", collection_id, "tree_oak"), "object can be removed from a custom collection")
	_expect(controller.call("get_collection_object_ids", collection_id).is_empty(), "removed object no longer belongs to the collection")
	_expect(controller.call("rename_collection", collection_id, "Лес"), "custom collection can be renamed")
	controller.call("set_local_state", [], [], controller.call("get_collections_state"))
	_expect(controller.call("get_collection_options")[0].get("label") == "Лес", "custom collections survive local-state serialization")
	_expect(controller.call("add_to_collection", collection_id, "tree_oak"), "collection can be repopulated before deleting a library entry")
	controller.call("remove_local_entry", "tree_oak")
	_expect(controller.call("get_collection_object_ids", collection_id).is_empty(), "deleting a library entry removes it from every custom collection")
	_expect(controller.call("delete_collection", collection_id), "custom collection can be deleted")
	_expect(controller.call("get_collection_options").is_empty(), "deleted collection is removed from navigation")

	controller.call("set_local_state", ["tree_oak", "weapon_sword", "tree_oak"], ["tree_pine", "tree_oak"])
	_expect(controller.call("is_favorite", "tree_oak"), "local favorites can be restored")
	_expect(controller.call("get_favorites") == PackedStringArray(["tree_oak", "weapon_sword"]), "array metadata is normalized and deduplicated")
	_expect(controller.call("get_recent_ids") == PackedStringArray(["tree_pine", "tree_oak"]), "recent metadata is restored")

	var template = DefinitionScript.new()
	template.object_id = "template_crate"
	template.display_name = "Ящик"
	template.is_template = true
	var templates: Array[ObjectDefinition] = [template]
	controller.call("set_library_data", definitions, templates)
	_expect(int(controller.call("get_template_count")) == 1, "templates are stored separately from objects")
	_expect(controller.call("get_template", 0) == template, "template index returns its definition")
	_expect(controller.call("get_template", -1) == null, "invalid template indices return null")
	_expect(controller.call("get_template_names") == ["Ящик"], "template names are exposed for the UI")
	var template_source_options: Array[Dictionary] = controller.call("get_creation_source_options", true)
	_expect(template_source_options.size() == 1 and template_source_options[0].get("id") == "template_crate", "creation wizard receives stable template source IDs")
	_expect(template_source_options[0].get("label") == "Ящик", "creation wizard receives template display names")
	var object_source_options: Array[Dictionary] = controller.call("get_creation_source_options", false)
	_expect(object_source_options.size() == definitions.size(), "creation wizard receives all saved object sources")
	var oak_source: Dictionary = {}
	for source_option in object_source_options:
		if source_option.get("id") == "tree_oak":
			oak_source = source_option
	_expect(oak_source.get("category") == "Nature", "creation sources include source category")
	_expect(oak_source.get("description") == "Большое дерево", "creation sources include source description")
	_expect(oak_source.get("tags") == PackedStringArray(["tree", "wood", "forest"]), "creation sources include source tags")
	entries = controller.call("build_visible_entries", "", "", "", "templates")
	_expect(entries.size() == 1 and entries[0].get("definition") == template, "template mode exposes starter templates as library cards")
	_expect(controller.call("get_visible_definition", 0) == template, "template card selection resolves to its template definition")
	controller.call("toggle_favorite", "template_crate")
	entries = controller.call("build_visible_entries", "", "", "", "favorites")
	var favorite_template_found := false
	for favorite_entry in entries:
		if favorite_entry.get("definition") == template:
			favorite_template_found = true
	_expect(entries.size() == 3 and favorite_template_found, "favorites mode also includes favorited templates")

	await process_frame
	if failures.is_empty():
		print("Object Builder library controller tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
