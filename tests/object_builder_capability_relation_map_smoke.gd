extends SceneTree

const MapViewScript = preload("res://addons/object_builder/ui/capability_relation_map_view.gd")
const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)

	var host_control := Control.new()
	root.add_child(host_control)
	var map = MapViewScript.new()
	map.open_full(host_control, "can_attack")

	_expect(int(map.call("get_domain_count")) == 9, "overview groups mechanics into nine semantic domains")
	_expect(int(map.call("get_mechanic_count")) >= 200, "semantic map retains the complete capability catalogue")
	_expect(int(map.call("get_edge_count")) >= 60, "all curated capability relations are collected")
	_expect(int(map.call("get_explained_edge_count")) == int(map.call("get_edge_count")), "every relation retains an explanation or receives a clear fallback")
	_expect(int(map.call("get_node_count")) == 9, "overview renders only the nine domain nodes instead of 200 mechanic cards")
	_expect(str(map.call("get_domain_id_for_category", "audio_effects")) == "presentation", "technical categories map into the intended semantic domain")
	_expect(map.call("get_domain_position", 0) == map.call("get_domain_position", 0), "domain layout is deterministic")

	map.call("open_domain", "combat")
	var domain_mechanics := int(map.call("get_domain_mechanic_count", "combat"))
	_expect(domain_mechanics > 0 and domain_mechanics < 200, "combat domain contains only its own mechanics")
	_expect(int(map.call("get_visible_mechanic_count")) == domain_mechanics, "domain view initially exposes all mechanics in its domain")
	_expect(int(map.call("get_node_count")) == domain_mechanics, "domain view creates mechanic nodes only after drilling into a domain")

	map.call("filter_full_map", "атака")
	var search_count := int(map.call("get_visible_mechanic_count"))
	_expect(search_count > 0 and search_count < domain_mechanics, "domain search narrows mechanics using localized catalogue metadata")
	map.call("filter_full_map", "")
	_expect(int(map.call("get_visible_mechanic_count")) == domain_mechanics, "clearing search restores the domain")
	map.call("set_full_category_filter", "combat")
	var category_count := int(map.call("get_visible_mechanic_count"))
	_expect(category_count > 0 and category_count <= domain_mechanics, "category sub-group filter narrows the selected domain")
	map.call("set_full_category_filter", "")

	map.call("open_local_focus", "can_attack")
	_expect(int(map.call("get_node_count")) >= 2, "local focus renders the selected mechanic and its direct neighbors")
	_expect(int(map.call("get_connection_count")) > 0, "local focus draws typed relations around the selected mechanic")
	_expect(int(map.call("get_relation_type_count")) == 6, "all six relation kinds remain distinguishable")

	var installed_ids: Array[String] = ["plays_attack_sound", "plays_attack_animation"]
	map.call("open_installed", host_control, installed_ids)
	_expect(int(map.call("get_installed_capability_count")) == 2, "installed map receives only the enabled capability IDs")
	_expect(int(map.call("get_visible_mechanic_count")) == 2, "installed map shows every enabled mechanic")
	_expect(int(map.call("get_node_count")) == 2, "installed map creates no nodes for disabled catalogue mechanics")
	_expect(int(map.call("get_installed_edge_count")) >= 1, "installed map derives relations only between installed mechanics")
	_expect(int(map.call("get_connection_count")) >= 1, "installed map draws the relations between its enabled mechanics")
	_expect(bool(map.call("has_installed_capability", "plays_attack_sound")), "installed map keeps a stable ID lookup for enabled nodes")
	_expect(not bool(map.call("has_installed_capability", "can_be_picked_up")), "installed map excludes mechanics absent from the object")
	map.call("filter_full_map", "plays_attack_sound")
	_expect(int(map.call("get_visible_mechanic_count")) == 1, "installed map search filters only its enabled nodes")
	map.call("filter_full_map", "")
	map.call("set_full_relation_filter", "recommends")
	_expect(int(map.call("get_connection_count")) >= 1, "installed map relation filter preserves matching typed edges")
	map.call("set_full_relation_filter", "")
	map.call("open_domain", "combat")
	map.call("_show_dependencies")
	_expect(int(map.call("get_visible_mechanic_count")) > 0, "dependency mode keeps the selected domain navigable")
	map.call("_show_overview")
	map.call("_show_dependencies")
	_expect(int(map.call("get_node_count")) == 9, "global dependency overview aggregates mandatory links across all domains")

	host_control.queue_free()
	if failures.is_empty():
		print("Object Builder semantic capability map tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("Object Builder semantic capability map: " + failure)
	quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
