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

	var pickup_component := ObjectComponentCatalog.create_definition("pickup")
	_expect(pickup_component != null, "built-in pickup component is available for schema metadata")
	if pickup_component != null:
		var pickup_item_descriptor: Dictionary = {}
		for descriptor in pickup_component.get_setting_definitions():
			if str(descriptor.get("key", "")) == "item_id":
				pickup_item_descriptor = descriptor
				break
		_expect(not pickup_item_descriptor.is_empty(), "pickup item setting is present")
		if not pickup_item_descriptor.is_empty():
			_expect(str(pickup_item_descriptor.get("display_name", "")) == "Предмет", "pickup item has a user-facing label instead of an internal ID label")
			_expect(str(pickup_item_descriptor.get("group_id", "")) == "предмет", "group ID is derived consistently from its visible name")
			_expect(int(pickup_item_descriptor.get("order", -1)) == 0, "field order defaults to source declaration order")
			_expect(int(pickup_item_descriptor.get("group_order", -1)) == 0, "group order defaults to first appearance")
			_expect(str(pickup_item_descriptor.get("level", "")) == "Basic", "legacy settings default to Basic")
			_expect(str(pickup_item_descriptor.get("visibility", "")) == "always", "settings default to always visible")
			_expect(str(pickup_item_descriptor.get("editor", "")) == "catalog_reference", "pickup item is explicitly a catalogue reference")
			_expect(str(pickup_item_descriptor.get("reference_type", "")) == "item", "pickup catalogue reference declares its item type")
			_expect(bool(pickup_item_descriptor.get("required", false)), "required metadata remains available")
			_expect(str(pickup_item_descriptor.get("default_value", "missing")) == "", "normalization does not alter the stored default")
			var raw_pickup_item_descriptor: Dictionary = {}
			for descriptor in pickup_component.setting_definitions:
				if str(descriptor.get("key", "")) == "item_id":
					raw_pickup_item_descriptor = descriptor
					break
			_expect(not raw_pickup_item_descriptor.has("group_id"), "normalization does not mutate the source descriptor")

	var pickup_capability := ObjectCapabilityCatalog.get_definition_reference("is_pickup_item")
	_expect(pickup_capability != null, "built-in pickup capability remains registered")
	if pickup_capability != null:
		var pickup_schema_item: Dictionary = {}
		for descriptor in pickup_capability.settings_schema:
			if str(descriptor.get("setting_key", "")) == "item_id":
				pickup_schema_item = descriptor
				break
		_expect(not pickup_schema_item.is_empty(), "pickup item setting resolves through its capability")
		if not pickup_schema_item.is_empty():
			_expect(bool(pickup_schema_item.get("required", false)), "required is inherited from the canonical component descriptor")
			_expect(str(pickup_schema_item.get("value_type", "")) == "String", "capability presentation keeps the canonical value type")
			_expect(str(pickup_schema_item.get("default_value", "missing")) == "", "capability presentation keeps the canonical default")
			_expect(not pickup_schema_item.has("_forbidden_overlay_keys"), "valid presentation metadata has no forbidden override marker")

	var forbidden_overlay := CapabilityDefinitionScript.new()
	forbidden_overlay.capability_id = "smoke_forbidden_setting_override"
	forbidden_overlay.display_name = "Проверка запрещённого переопределения"
	forbidden_overlay.description = "Не должна менять канонический default компонента."
	forbidden_overlay.category_id = "stats"
	forbidden_overlay.category_name = "Характеристики"
	forbidden_overlay.kind_id = "attributes"
	forbidden_overlay.execution_scope = "runtime"
	forbidden_overlay.implementation_type = "component"
	forbidden_overlay.readiness_status = "ready"
	forbidden_overlay.component_ids = PackedStringArray(["health"])
	forbidden_overlay.settings_schema = [
		{"setting_key": "max_health", "default_value": 55.0}
	]
	var forbidden_overlay_errors := ObjectCapabilityCatalog.register_definitions(
		[forbidden_overlay],
		"schema_contract_smoke"
	)
	var default_override_rejected := false
	for error_message in forbidden_overlay_errors:
		if str(error_message).contains("default_value"):
			default_override_rejected = true
			break
	_expect(default_override_rejected, "capability overlay cannot replace a component default")

	var invalid_editor_descriptor := pickup_item_descriptor.duplicate(true)
	invalid_editor_descriptor["editor"] = "made_up_editor"
	var invalid_editor_errors := ObjectComponentCatalog._validate_setting_metadata(
		invalid_editor_descriptor,
		"item_id",
		"pickup"
	)
	var invalid_editor_rejected := false
	for error_message in invalid_editor_errors:
		if str(error_message).contains("неизвестный editor"):
			invalid_editor_rejected = true
			break
	_expect(invalid_editor_rejected, "unknown setting editors are rejected by component metadata validation")

	var incomplete_enum_descriptor := pickup_item_descriptor.duplicate(true)
	incomplete_enum_descriptor["editor"] = "enum"
	incomplete_enum_descriptor["options"] = []
	var incomplete_enum_errors := ObjectComponentCatalog._validate_setting_metadata(
		incomplete_enum_descriptor,
		"item_id",
		"pickup"
	)
	var incomplete_enum_rejected := false
	for error_message in incomplete_enum_errors:
		if str(error_message).contains("должна содержать options"):
			incomplete_enum_rejected = true
			break
	_expect(incomplete_enum_rejected, "enum settings require explicit labelled options")

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
