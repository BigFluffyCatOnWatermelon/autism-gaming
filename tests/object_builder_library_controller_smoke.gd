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

	entries = controller.call("build_visible_entries", "дерево", "", "", "all")
	_expect(entries.size() == 2, "search uses cached case-normalized text")
	entries = controller.call("build_visible_entries", "", "Equipment", "", "all")
	_expect(entries.size() == 1 and entries[0].get("definition") == weapon, "category filter is applied")
	entries = controller.call("build_visible_entries", "", "", "stone", "all")
	_expect(entries.size() == 1 and entries[0].get("definition") == stone, "tag filter is applied")

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
