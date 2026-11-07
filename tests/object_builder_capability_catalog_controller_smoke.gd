extends SceneTree

const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")
const DefinitionScript = preload("res://scripts/object_system/object_capability_definition.gd")
const ControllerScript = preload("res://addons/object_builder/controllers/capability_catalog_controller.gd")

const VISUAL_ID := "smoke_catalog_controller_visual"
const DATA_ID := "smoke_catalog_controller_data"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)

	var visual := DefinitionScript.new()
	visual.capability_id = VISUAL_ID
	visual.display_name = "Цветовой оттенок"
	visual.description = "Меняет оттенок изображения объекта."
	visual.category_id = "visual"
	visual.category_name = "Внешний вид"
	visual.runtime_status = "Planned"
	visual.readiness_status = "ready"
	visual.kind_id = "presentation"
	visual.execution_scope = "editor_only"
	visual.implementation_type = "scene_resource"
	visual.synonyms = PackedStringArray(["покрасить", "изменить цвет"])
	visual.example_queries = PackedStringArray(["сделать объект красным", "ломать дерево топором"])

	var data := DefinitionScript.new()
	data.capability_id = DATA_ID
	data.display_name = "Пользовательские данные"
	data.description = "Хранит дополнительные значения объекта."
	data.category_id = "general"
	data.category_name = "Основное"
	data.runtime_status = "Planned"
	data.readiness_status = "ready"
	data.kind_id = "data"
	data.execution_scope = "data_only"
	data.implementation_type = "declarative_data"
	data.synonyms = PackedStringArray(["свойства", "характеристики"])

	var registration_errors := ObjectCapabilityCatalog.register_definitions(
		[visual, data],
		"smoke_catalog_controller"
	)
	_expect(registration_errors.is_empty(), "test capabilities register")
	if not registration_errors.is_empty():
		_finish()
		return

	var controller = ControllerScript.new()
	controller.call("set_selected", VISUAL_ID, true)
	controller.call("set_selected", DATA_ID, true)
	_expect(int(controller.call("get_selected_count")) == 2, "controller tracks selections across categories")

	var visual_ids := PackedStringArray([VISUAL_ID])
	var no_current_selections: Array[ObjectCapabilitySelection] = []
	var visual_entries: Array[Dictionary] = controller.call(
		"build_entries",
		visual_ids,
		no_current_selections,
		"сделать объект красным"
	)
	_expect(visual_entries.size() == 1, "natural-language example query finds the visual capability")
	_expect(
		bool(visual_entries[0].get("selected_in_catalog", false)),
		"selection is preserved when the result set is filtered"
	)
	var visual_definition := visual_entries[0].get("definition") as ObjectCapabilityDefinition
	_expect(
		visual_definition != null and visual_definition.execution_scope == "editor_only",
		"visual card retains its non-runtime execution scope"
	)

	var data_ids := PackedStringArray([DATA_ID])
	var data_entries: Array[Dictionary] = controller.call(
		"build_entries",
		data_ids,
		no_current_selections,
		"свойства"
	)
	_expect(data_entries.size() == 1, "synonym search finds data-only capabilities")
	_expect(
		bool(data_entries[0].get("selected_in_catalog", false)),
		"selection remains after changing the result category"
	)

	var phrase_entries: Array[Dictionary] = controller.call(
		"build_entries",
		visual_ids,
		no_current_selections,
		"чтобы дерево ломалось от топора"
	)
	_expect(
		phrase_entries.size() == 1,
		"search matches natural-language phrases with common Russian word endings"
	)

	var all_ids := ObjectCapabilityCatalog.get_capability_ids("", false)
	_expect(
		int(controller.call("count_ready", all_ids)) >= 2,
		"ready counter includes editor-only and data-only capabilities"
	)

	var empty_current: Array[ObjectCapabilitySelection] = []
	controller.call("clear_selection")
	controller.call("set_selected", "can_receive_damage", true)
	var batch_plan: Dictionary = controller.call("build_addition_plan", empty_current)
	_expect(bool(batch_plan.get("ok", false)), "controller forwards selection into the batch planner")
	var summary: PackedStringArray = controller.call("build_batch_summary", batch_plan)
	_expect(not summary.is_empty(), "controller creates a human-readable batch summary")
	var summary_text := "\n".join(summary)
	_expect(summary_text.contains("Можно повредить"), "batch summary names the user-selected capability")
	_expect(summary_text.contains("Есть здоровье"), "batch summary explains the required Health dependency")

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("Object Builder capability catalog controller tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("Object Builder capability catalog controller: " + failure)
	quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
