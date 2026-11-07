extends SceneTree

const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const DefinitionScript = preload("res://scripts/object_system/object_capability_definition.gd")
const SelectionScript = preload("res://scripts/object_system/object_capability_selection.gd")
const SelectionSessionScript = preload("res://addons/object_builder/controllers/capability_selection_session.gd")
const BatchPlannerScript = preload("res://addons/object_builder/services/capability_batch_planner.gd")

const VISUAL_ID := "smoke_batch_visual"
const DATA_ID := "smoke_batch_data"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)

	_test_selection_session()
	_test_editor_only_capability()
	_test_dependency_resolution_and_settings()
	_test_atomic_conflict_rejection()

	if failures.is_empty():
		print("Object Builder capability batch planner tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error("Object Builder capability batch planner: " + failure)
	quit(1)


func _test_selection_session() -> void:
	var session = SelectionSessionScript.new()
	_expect(session.is_empty(), "selection session starts empty")
	_expect(session.select(" CAN_RECEIVE_DAMAGE "), "selection normalizes IDs")
	_expect(session.select("can_attack"), "multiple capabilities can be selected")
	_expect(not session.select("can_attack"), "duplicate selection is ignored")
	_expect(session.get_count() == 2, "selection count reports unique IDs")
	_expect(
		session.get_selected_ids() == PackedStringArray(["can_receive_damage", "can_attack"]),
		"selection order is stable and independent from catalog filtering"
	)
	_expect(session.toggle("can_receive_damage") == false, "toggling a selected capability removes it")
	_expect(not session.contains("can_receive_damage"), "removed capability is no longer selected")
	_expect(session.deselect("can_attack"), "individual selection can be removed")
	_expect(session.is_empty(), "session becomes empty after removing the last selection")
	session.select("can_attack")
	session.clear()
	_expect(session.is_empty(), "selection can be cleared")


func _test_editor_only_capability() -> void:
	var visual := DefinitionScript.new()
	visual.capability_id = VISUAL_ID
	visual.display_name = "Тестовая визуальная возможность"
	visual.description = "Редакторская визуальная настройка без игрового компонента."
	visual.category_id = "visual"
	visual.category_name = "Внешний вид"
	visual.runtime_status = "Planned"
	visual.readiness_status = "ready"
	visual.kind_id = "presentation"
	visual.execution_scope = "editor_only"
	visual.implementation_type = "scene_resource"
	visual.icon_resource_path = "res://addons/object_builder/assets/capabilities/visual.svg"
	visual.synonyms = PackedStringArray(["внешний вид", "картинка"])
	visual.example_queries = PackedStringArray(["изменить внешний вид объекта"])
	visual.relations.append({
		"type": "related",
		"target_id": DATA_ID,
		"explanation": "Обе возможности настраивают данные объекта."
	})

	var data := DefinitionScript.new()
	data.capability_id = DATA_ID
	data.display_name = "Тестовые данные"
	data.description = "Данные без отдельного runtime-поведения."
	data.category_id = "general"
	data.category_name = "Основное"
	data.runtime_status = "Planned"
	data.readiness_status = "ready"
	data.kind_id = "data"
	data.execution_scope = "data_only"
	data.implementation_type = "declarative_data"
	data.relations.append({
		"type": "conflicts",
		"target_id": VISUAL_ID,
		"explanation": "Эта проверка моделирует реальную несовместимость двух возможностей."
	})

	var relation_dependent := DefinitionScript.new()
	relation_dependent.capability_id = "smoke_relation_dependent"
	relation_dependent.display_name = "Возможность с декларативной зависимостью"
	relation_dependent.description = "Проверяет отношение requires без legacy dependency ID."
	relation_dependent.category_id = "general"
	relation_dependent.category_name = "Основное"
	relation_dependent.runtime_status = "Planned"
	relation_dependent.readiness_status = "ready"
	relation_dependent.kind_id = "data"
	relation_dependent.execution_scope = "data_only"
	relation_dependent.implementation_type = "declarative_data"
	relation_dependent.relations.append({
		"type": "requires",
		"target_id": "has_health",
		"explanation": "Этой возможности нужны данные здоровья."
	})

	var registration_errors := ObjectCapabilityCatalog.register_definitions(
		[visual, data, relation_dependent],
		"smoke_capability_batch"
	)
	_expect(registration_errors.is_empty(), "editor-only and data-only capabilities register without runtime components")
	if not registration_errors.is_empty():
		return

	var registered_visual := ObjectCapabilityCatalog.get_definition_reference(VISUAL_ID)
	_expect(registered_visual != null and registered_visual.is_ready(), "editor-only capability is ready despite legacy Planned runtime status")
	_expect(
		registered_visual != null and registered_visual.execution_scope == "editor_only",
		"editor-only execution scope is preserved"
	)
	_expect(
		registered_visual != null and registered_visual.relations.size() == 1,
		"typed relationship metadata survives registration"
	)

	var empty_current: Array[ObjectCapabilitySelection] = []
	var plan := BatchPlannerScript.build_addition_plan(empty_current, PackedStringArray([VISUAL_ID]))
	_expect(bool(plan.get("ok", false)), "ready editor-only capability can be added without runtime component")
	_expect(plan.get("user_selected_ids", PackedStringArray()) == PackedStringArray([VISUAL_ID]), "batch plan identifies the user's selection")
	_expect(plan.get("auto_required_ids", PackedStringArray()).is_empty(), "editor-only capability adds no fake runtime dependency")
	var app_plan: Dictionary = plan.get("application_plan", {})
	var added_components: Array = app_plan.get("added_components", [])
	_expect(
		bool(app_plan.get("ok", false)) and added_components.is_empty(),
		"editor-only application plan contains no runtime component"
	)

	var relation_dependency_plan := BatchPlannerScript.build_addition_plan(
		[],
		PackedStringArray(["smoke_relation_dependent"])
	)
	_expect(
		bool(relation_dependency_plan.get("ok", false)),
		"typed requires relation participates in dependency planning"
	)
	_expect(
		relation_dependency_plan.get("auto_required_ids", PackedStringArray()) == PackedStringArray(["has_health"]),
		"typed requires relation adds the target capability automatically"
	)


func _test_dependency_resolution_and_settings() -> void:
	var empty_current: Array[ObjectCapabilitySelection] = []
	var dependency_plan := BatchPlannerScript.build_addition_plan(
		empty_current,
		PackedStringArray(["can_receive_damage"])
	)
	_expect(bool(dependency_plan.get("ok", false)), "batch planner accepts a ready damageable capability")
	_expect(
		dependency_plan.get("user_selected_ids", PackedStringArray()) == PackedStringArray(["can_receive_damage"]),
		"dependent capability remains marked as user-selected"
	)
	_expect(
		dependency_plan.get("auto_required_ids", PackedStringArray()) == PackedStringArray(["has_health"]),
		"required Health capability is reported as an automatic dependency"
	)

	var selections_value: Variant = dependency_plan.get("selections", [])
	var resolved_health := _find_selection(selections_value, "has_health")
	_expect(resolved_health != null and resolved_health.enabled, "required Health selection is enabled in the proposed batch")
	_expect(resolved_health != null and resolved_health.automatically_added, "automatic dependency provenance is retained")

	var manual_health := ObjectCapabilityCatalog.create_selection("has_health")
	manual_health.set_component_setting("health", "max_health", 240.0)
	var existing: Array[ObjectCapabilitySelection] = [manual_health]
	var with_existing_health := BatchPlannerScript.build_addition_plan(
		existing,
		PackedStringArray(["can_receive_damage"])
	)
	_expect(bool(with_existing_health.get("ok", false)), "batch can reuse an existing manually configured dependency")
	_expect(
		with_existing_health.get("auto_required_ids", PackedStringArray()).is_empty(),
		"existing dependency is not reported as a new automatic addition"
	)
	var next_health := _find_selection(with_existing_health.get("selections", []), "has_health")
	_expect(
		next_health != null and is_equal_approx(
			float(next_health.get_component_settings("health").get("max_health", 0.0)),
			240.0
		),
		"existing component settings survive batch planning"
	)
	_expect(
		is_equal_approx(
			float(manual_health.get_component_settings("health").get("max_health", 0.0)),
			240.0
		),
		"planning does not mutate the caller's current selection"
	)

	manual_health.enabled = false
	var reenabled_manual := BatchPlannerScript.build_addition_plan(
		[manual_health],
		PackedStringArray(["can_receive_damage"])
	)
	var preserved_manual := _find_selection(reenabled_manual.get("selections", []), "has_health")
	_expect(bool(reenabled_manual.get("ok", false)), "batch re-enables an existing disabled dependency")
	_expect(
		preserved_manual != null and preserved_manual.enabled and not preserved_manual.automatically_added,
		"re-enabled manual dependency keeps its original ownership"
	)
	_expect(
		reenabled_manual.get("auto_required_ids", PackedStringArray()).is_empty(),
		"manually owned dependency is not misreported as a new automatic dependency"
	)


func _test_atomic_conflict_rejection() -> void:
	var conflict_plan := BatchPlannerScript.build_addition_plan(
		[],
		PackedStringArray([VISUAL_ID, DATA_ID])
	)
	_expect(not bool(conflict_plan.get("ok", false)), "conflicting multi-selection is rejected before application")
	var failed_selections: Array = conflict_plan.get("selections", [])
	var conflict_errors: PackedStringArray = conflict_plan.get("errors", PackedStringArray())
	_expect(
		failed_selections.is_empty(),
		"failed batch plan exposes no partially applied selection set"
	)
	_expect(not conflict_errors.is_empty(), "failed batch explains the conflict")


func _find_selection(values: Variant, capability_id: String) -> ObjectCapabilitySelection:
	if not values is Array:
		return null
	for value in values:
		if value is ObjectCapabilitySelection and value.capability_id == capability_id:
			return value as ObjectCapabilitySelection
	return null


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
