extends SceneTree

const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const CapabilityDefinitionScript = preload("res://scripts/object_system/object_capability_definition.gd")
const CapabilitySelectionScript = preload("res://scripts/object_system/object_capability_selection.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)

	var registry_errors := ObjectCapabilityCatalog.validate_registry()
	for error_message in registry_errors:
		failures.append("catalog validation: " + error_message)

	var visual := ObjectCapabilityCatalog.get_definition_reference("has_sprite")
	_expect(visual != null, "visual capability exists in the shared catalogue")
	if visual != null:
		_expect(visual.kind_id == "presentation", "visual category maps to presentation kind")
		_expect(visual.get_effective_readiness_status() == "planned", "planned visual capability keeps its own readiness")
		_expect(not visual.is_ready(), "planned visual capability cannot be enabled")
		_expect(visual.component_ids.has("has_sprite"), "visual mechanic resolves to its registered component definition")
		_expect(visual.icon_resource_path.is_empty(), "unfinished icon resource remains optional")
		_expect(visual.illustration_resource_path.is_empty(), "unfinished illustration resource remains optional")
		var has_typed_relation := false
		for relation in visual.relations:
			if str(relation.get("type", "")) == "recommends" and str(relation.get("target_id", "")) == "plays_idle_animation":
				has_typed_relation = true
		_expect(has_typed_relation, "visual mechanic inherits its curated typed relationship metadata")
		_expect(visual.compatibility_rules.is_empty(), "compatibility rules are represented independently")

	var health := ObjectCapabilityCatalog.get_definition_reference("has_health")
	_expect(health != null, "implemented Health capability remains registered")
	if health != null:
		_expect(health.is_ready(), "implemented runtime capability is ready")
		_expect(health.get_effective_readiness_status() == "ready", "legacy runtime status maps to ready")
		_expect(health.kind_id == "attributes", "health uses the attributes kind")
		_expect(health.execution_scope == "runtime", "component-backed capability is classified as runtime")
		_expect(health.implementation_type == "component", "component-backed capability reports its implementation type")

	var editor_only := CapabilityDefinitionScript.new()
	editor_only.capability_id = "smoke_editor_only_visual"
	editor_only.display_name = "Тестовая визуальная настройка"
	editor_only.description = "Editor-only возможность без runtime-компонента."
	editor_only.category_id = "visual"
	editor_only.category_name = "Внешний вид"
	editor_only.runtime_status = "Planned"
	editor_only.readiness_status = "ready"
	editor_only.execution_scope = "editor_only"
	editor_only.kind_id = "presentation"
	editor_only.implementation_type = "scene_resource"
	_expect(editor_only.is_ready(), "editor-only capability can be ready without a runtime component")
	_expect(editor_only.component_ids.is_empty(), "editor-only test capability needs no component")
	_expect(
		editor_only.get_effective_readiness_status() == "ready",
		"explicit readiness metadata takes precedence over the legacy runtime flag"
	)

	var planned_selection := CapabilitySelectionScript.new()
	planned_selection.capability_id = "has_sprite"
	var planned_errors := ObjectCapabilityService.validate_selections([planned_selection])
	_expect(not planned_errors.is_empty(), "planned visual capability cannot be enabled before its editor implementation exists")

	if failures.is_empty():
		print("Object Builder capability metadata tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error("Object Builder capability metadata: " + failure)
	quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
