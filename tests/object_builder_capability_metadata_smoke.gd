extends SceneTree

const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const CapabilityDefinitionScript = preload("res://scripts/object_system/object_capability_definition.gd")
const CapabilitySelectionScript = preload("res://scripts/object_system/object_capability_selection.gd")
const BackendScript = preload("res://addons/web_object_builder/services/object_builder_backend.gd")
const GameplayTables = preload("res://scripts/object_system/object_gameplay_table_service.gd")

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

	var incompatible_editor_descriptor := pickup_item_descriptor.duplicate(true)
	incompatible_editor_descriptor["editor"] = "number"
	var incompatible_editor_errors := ObjectComponentCatalog._validate_setting_metadata(
		incompatible_editor_descriptor,
		"item_id",
		"pickup"
	)
	var incompatible_editor_rejected := false
	for error_message in incompatible_editor_errors:
		if str(error_message).contains("несовместим с типом"):
			incompatible_editor_rejected = true
			break
	_expect(incompatible_editor_rejected, "editor type must match the setting value type")

	var invalid_default_range_descriptor := pickup_item_descriptor.duplicate(true)
	invalid_default_range_descriptor["value_type"] = "Float"
	invalid_default_range_descriptor["editor"] = "number"
	invalid_default_range_descriptor["default_value"] = 2.0
	invalid_default_range_descriptor["has_range"] = true
	invalid_default_range_descriptor["minimum"] = 0.0
	invalid_default_range_descriptor["maximum"] = 1.0
	var invalid_default_range_errors := ObjectComponentCatalog._validate_setting_metadata(
		invalid_default_range_descriptor,
		"item_id",
		"pickup"
	)
	var invalid_default_range_rejected := false
	for error_message in invalid_default_range_errors:
		if str(error_message).contains("выходит за заданный диапазон"):
			invalid_default_range_rejected = true
			break
	_expect(invalid_default_range_rejected, "numeric default must stay inside its declared range")

	_expect(
		ComponentDefinitionScript._default_editor_for_setting("String", "prompt_text") == "text",
		"plain human-readable string settings use a text editor"
	)
	_expect(
		ComponentDefinitionScript._default_editor_for_setting("String", "required_tool_id") == "unspecified",
		"identifier strings are not exposed as unrestricted text inputs"
	)
	_expect(
		ComponentDefinitionScript._default_editor_for_setting("String", "loot_table_json") == "unspecified",
		"structured JSON strings are not exposed as textareas"
	)

	var color_component := ComponentDefinitionScript.new()
	color_component.component_id = "smoke_color"
	color_component.setting_definitions = [{
		"key": "tint",
		"display_name": "Оттенок",
		"value_type": "Color",
		"default_value": Color.WHITE,
		"group_name": "Внешний вид"
	}]
	_expect(color_component.set_setting("tint", Color(0.25, 0.5, 0.75, 1.0)), "Color setting values are accepted by component definitions")
	_expect(color_component.get_setting("tint") == Color(0.25, 0.5, 0.75, 1.0), "Color setting values round-trip inside the component definition")
	_expect(color_component._variant_type_for_setting("Color") == TYPE_COLOR, "Color settings expose the correct Godot Variant type")

	var backend := BackendScript.new()
	var item_reference_options := backend._get_setting_reference_options("item")
	_expect(not item_reference_options.is_empty(), "typed item references are populated from the project item catalog")
	var valid_reference_option := false
	for option in item_reference_options:
		if not str(option.get("value", "")).is_empty() and not str(option.get("label", "")).is_empty():
			valid_reference_option = true
			break
	_expect(valid_reference_option, "item reference options include stable IDs and human-readable labels")
	var tool_reference_options := backend._get_setting_reference_options("tool")
	_expect(not tool_reference_options.is_empty(), "tool references are filtered from the tools item category")

	var loot_component := ObjectComponentCatalog.create_definition("drops_loot_on_destroy")
	_expect(loot_component != null, "destruction loot component is registered")
	var loot_descriptor: Dictionary = {}
	if loot_component != null:
		for descriptor in loot_component.get_setting_definitions():
			if str(descriptor.get("key", "")) == "loot_table_json":
				loot_descriptor = descriptor
				break
	_expect(not loot_descriptor.is_empty(), "legacy loot table descriptor is present")
	if not loot_descriptor.is_empty():
		_expect(str(loot_descriptor.get("editor", "")) == "structured_list", "legacy loot table uses a structured visual editor")
		_expect(str(loot_descriptor.get("level", "")) == "Expert", "legacy loot table editor stays in Expert settings")
		var loot_editor_config: Dictionary = loot_descriptor.get("editor_config", {})
		_expect(str(loot_editor_config.get("structure_type", "")) == "loot_table", "loot editor declares its structured data type")
		_expect(str(loot_editor_config.get("reference_type", "")) == "item", "loot editor references the item catalog")
		var loot_metadata_errors := ObjectComponentCatalog._validate_setting_metadata(
			loot_descriptor,
			"loot_table_json",
			"drops_loot_on_destroy"
		)
		_expect(loot_metadata_errors.is_empty(), "structured loot editor metadata passes schema validation")

	var backend_capabilities := backend._get_capabilities()
	var backend_loot_descriptor: Dictionary = {}
	for capability_data in backend_capabilities.get("items", []):
		for descriptor in capability_data.get("settingsSchema", []):
			if str(descriptor.get("setting_key", "")) == "loot_table_json":
				backend_loot_descriptor = descriptor
				break
		if not backend_loot_descriptor.is_empty():
			break
	_expect(not backend_loot_descriptor.is_empty(), "merged destruction capability exposes its loot setting to Web")
	if not backend_loot_descriptor.is_empty():
		var backend_loot_config: Dictionary = backend_loot_descriptor.get("editor_config", {})
		var backend_loot_options: Array = backend_loot_config.get("reference_options", [])
		_expect(not backend_loot_options.is_empty(), "Web loot editor receives item catalog options from backend")

	var crafting_component := ObjectComponentCatalog.create_definition("supports_item_crafting")
	_expect(crafting_component != null, "inventory crafting component is registered")
	var recipe_descriptor: Dictionary = {}
	if crafting_component != null:
		for descriptor in crafting_component.get_setting_definitions():
			if str(descriptor.get("key", "")) == "recipes_json":
				recipe_descriptor = descriptor
				break
	_expect(not recipe_descriptor.is_empty(), "legacy recipe table descriptor is present")
	if not recipe_descriptor.is_empty():
		_expect(str(recipe_descriptor.get("editor", "")) == "structured_object", "legacy recipe table uses a specialized structured object editor")
		_expect(str(recipe_descriptor.get("level", "")) == "Expert", "legacy recipe fallback stays in Expert settings")
		var recipe_editor_config: Dictionary = recipe_descriptor.get("editor_config", {})
		_expect(str(recipe_editor_config.get("structure_type", "")) == "recipe_table", "recipe editor declares its structured data type")
		_expect(str(recipe_editor_config.get("reference_type", "")) == "item", "recipe editor references the item catalog")
		var recipe_metadata_errors := ObjectComponentCatalog._validate_setting_metadata(
			recipe_descriptor,
			"recipes_json",
			"supports_item_crafting"
		)
		_expect(recipe_metadata_errors.is_empty(), "structured recipe editor metadata passes schema validation")

	var backend_recipe_descriptor: Dictionary = {}
	for capability_data in backend_capabilities.get("items", []):
		for descriptor in capability_data.get("settingsSchema", []):
			if str(descriptor.get("setting_key", "")) == "recipes_json":
				backend_recipe_descriptor = descriptor
				break
		if not backend_recipe_descriptor.is_empty():
			break
	_expect(not backend_recipe_descriptor.is_empty(), "merged crafting capability exposes its recipe setting to Web")
	if not backend_recipe_descriptor.is_empty():
		var backend_recipe_config: Dictionary = backend_recipe_descriptor.get("editor_config", {})
		var backend_recipe_options: Array = backend_recipe_config.get("reference_options", [])
		_expect(not backend_recipe_options.is_empty(), "Web recipe editor receives item catalog options from backend")

	var animals_production_component := ObjectComponentCatalog.create_definition("can_produce_resources")
	_expect(animals_production_component != null, "animal production component is registered")
	var production_descriptor: Dictionary = {}
	if animals_production_component != null:
		for descriptor in animals_production_component.get_setting_definitions():
			if str(descriptor.get("key", "")) == "production_table_json":
				production_descriptor = descriptor
				break
	_expect(not production_descriptor.is_empty(), "legacy production table descriptor is present for animals")
	if not production_descriptor.is_empty():
		_expect(str(production_descriptor.get("editor", "")) == "structured_list", "production outputs use the StructuredList editor")
		_expect(str(production_descriptor.get("level", "")) == "Expert", "production fallback table stays in Expert settings")
		var production_editor_config: Dictionary = production_descriptor.get("editor_config", {})
		_expect(str(production_editor_config.get("structure_type", "")) == "production_table", "production editor declares its structured data type")
		_expect(str(production_editor_config.get("reference_type", "")) == "item", "production editor references the item catalog")
		var production_metadata_errors := ObjectComponentCatalog._validate_setting_metadata(
			production_descriptor,
			"production_table_json",
			"can_produce_resources"
		)
		_expect(production_metadata_errors.is_empty(), "structured production editor metadata passes schema validation")

	var world_output_component := ObjectComponentCatalog.create_definition("has_periodic_output")
	_expect(world_output_component != null, "world time periodic output component is registered")
	var world_output_descriptor: Dictionary = {}
	if world_output_component != null:
		for descriptor in world_output_component.get_setting_definitions():
			if str(descriptor.get("key", "")) == "production_table_json":
				world_output_descriptor = descriptor
				break
	_expect(not world_output_descriptor.is_empty(), "legacy production table descriptor is present for world time")
	if not world_output_descriptor.is_empty():
		var world_production_config: Dictionary = world_output_descriptor.get("editor_config", {})
		_expect(str(world_production_config.get("structure_type", "")) == "production_table", "world time shares the production table editor schema")
		var world_production_errors := ObjectComponentCatalog._validate_setting_metadata(
			world_output_descriptor,
			"production_table_json",
			"has_periodic_output"
		)
		_expect(world_production_errors.is_empty(), "world time production editor metadata passes schema validation")

	var normalized_production := GameplayTables.normalize_production_table([
		{"item_id":"milk","amount_per_cycle":2},
		{"item_id":"egg","amount":3}
	])
	_expect(normalized_production.size() == 2, "production table normalizer supports multiple item outputs")
	_expect(int(normalized_production[0].get("amount_per_cycle", 0)) == 2, "production table keeps amount_per_cycle")
	_expect(str(normalized_production[1].get("item_id", "")) == "egg" and int(normalized_production[1].get("amount_per_cycle", 0)) == 3, "production normalizer accepts the legacy amount alias")
	var runtime_legacy_table := JSON.stringify([{"item_id":"milk","amount_per_cycle":2},{"item_id":"egg","amount_per_cycle":3}])
	var legacy_production := GameplayTables.load_production_table("", "milk", 1, runtime_legacy_table)
	_expect(legacy_production.size() == 2, "runtime loader prefers multi-output legacy table over single-output fallback")
	var legacy_production := GameplayTables.load_production_table(
		"",
		"milk",
		1,
		JSON.stringify([{"item_id":"milk","amount_per_cycle":2},{"item_id":"egg","amount_per_cycle":3}])
	)
	_expect(legacy_production.size() == 2, "runtime loader prefers the multi-output legacy table over the single-output fallback")

	var backend_production_descriptor: Dictionary = {}
	for capability_data in backend_capabilities.get("items", []):
		for descriptor in capability_data.get("settingsSchema", []):
			if str(descriptor.get("setting_key", "")) == "production_table_json":
				backend_production_descriptor = descriptor
				break
		if not backend_production_descriptor.is_empty():
			break
	_expect(not backend_production_descriptor.is_empty(), "backend exposes structured production table settings to Web")
	if not backend_production_descriptor.is_empty():
		var backend_production_config: Dictionary = backend_production_descriptor.get("editor_config", {})
		var backend_production_options: Array = backend_production_config.get("reference_options", [])
		_expect(not backend_production_options.is_empty(), "Web production editor receives item catalog options from backend")

	var animal_routine_component := ObjectComponentCatalog.create_definition("has_daily_routine")
	_expect(animal_routine_component != null, "animal daily routine component is registered")
	var routine_descriptor: Dictionary = {}
	if animal_routine_component != null:
		for descriptor in animal_routine_component.get_setting_definitions():
			if str(descriptor.get("key", "")) == "schedule_json":
				routine_descriptor = descriptor
				break
	_expect(not routine_descriptor.is_empty(), "daily routine schedule descriptor is present")
	if not routine_descriptor.is_empty():
		_expect(str(routine_descriptor.get("editor", "")) == "structured_list", "daily routine uses a visual StructuredList editor")
		_expect(str(routine_descriptor.get("level", "")) == "Expert", "daily routine table stays in Expert settings")
		var routine_config: Dictionary = routine_descriptor.get("editor_config", {})
		_expect(str(routine_config.get("structure_type", "")) == "daily_routine", "daily routine declares its data shape")
		var routine_errors := ObjectComponentCatalog._validate_setting_metadata(routine_descriptor, "schedule_json", "has_daily_routine")
		_expect(routine_errors.is_empty(), "daily routine editor metadata passes validation")

	var day_phase_component := ObjectComponentCatalog.create_definition("has_day_night_schedule")
	_expect(day_phase_component != null, "day/night schedule component is registered")
	var day_phase_descriptor: Dictionary = {}
	if day_phase_component != null:
		for descriptor in day_phase_component.get_setting_definitions():
			if str(descriptor.get("key", "")) == "schedule_json":
				day_phase_descriptor = descriptor
				break
	_expect(not day_phase_descriptor.is_empty(), "day/night schedule descriptor is present")
	if not day_phase_descriptor.is_empty():
		var day_phase_config: Dictionary = day_phase_descriptor.get("editor_config", {})
		_expect(str(day_phase_config.get("structure_type", "")) == "day_phase_schedule", "day/night schedule declares its data shape")
		var day_phase_errors := ObjectComponentCatalog._validate_setting_metadata(day_phase_descriptor, "schedule_json", "has_day_night_schedule")
		_expect(day_phase_errors.is_empty(), "day/night editor metadata passes validation")

	var midnight_schedule := GameplayTables.normalize_schedule([
		{"start":18,"end":6,"phase":"night","custom_flag":true}
	])
	_expect(midnight_schedule.size() == 1, "schedule normalizer accepts midnight-crossing intervals")
	_expect(float(midnight_schedule[0].get("start", -1)) == 18.0 and float(midnight_schedule[0].get("end", -1)) == 6.0, "schedule normalizer keeps interval boundaries")
	_expect(bool(midnight_schedule[0].get("custom_flag", false)), "schedule normalizer preserves custom event fields")

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
