@tool
extends RefCounted
class_name ObjectLibraryService

const LIBRARY_ROOT := "res://data/object_library"
const OBJECTS_PATH := LIBRARY_ROOT + "/objects"
const SCENES_PATH := LIBRARY_ROOT + "/scenes"
const TEMPLATES_PATH := LIBRARY_ROOT + "/templates"


static func ensure_directories() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OBJECTS_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENES_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMPLATES_PATH))


static func load_definitions() -> Array[ObjectDefinition]:
	var definitions: Array[ObjectDefinition] = []
	_scan_directory(OBJECTS_PATH, definitions, false)
	definitions.sort_custom(func(a: ObjectDefinition, b: ObjectDefinition) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)
	return definitions


static func load_templates() -> Array[ObjectDefinition]:
	var templates: Array[ObjectDefinition] = []
	_scan_directory(TEMPLATES_PATH, templates, true)
	templates.sort_custom(func(a: ObjectDefinition, b: ObjectDefinition) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)
	return templates


static func load_definition(object_id: String) -> ObjectDefinition:
	for definition in load_definitions():
		if definition.object_id == object_id:
			return definition
	return null


static func validate_definition(definition: ObjectDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("Определение объекта не создано.")
		return errors
	if definition.schema_version > ObjectDefinition.CURRENT_SCHEMA_VERSION:
		errors.append("Версия данных новее поддерживаемой этим Object Builder.")
	if definition.object_id.strip_edges().is_empty():
		errors.append("У объекта должен быть постоянный ID.")
	if definition.display_name.strip_edges().is_empty():
		errors.append("Укажи название объекта.")
	if definition.category.strip_edges().is_empty():
		errors.append("Укажи категорию объекта.")
	if definition.object_type.strip_edges().is_empty():
		errors.append("Укажи тип объекта.")

	var used_property_ids: Dictionary = {}
	for property_definition in definition.custom_properties:
		if property_definition == null:
			errors.append("В списке свойств есть пустая запись.")
			continue
		var property_id := property_definition.property_id.strip_edges()
		if property_id.is_empty():
			errors.append("У пользовательского свойства должен быть ID.")
		elif used_property_ids.has(property_id):
			errors.append("Повторяется ID свойства: " + property_id)
		else:
			used_property_ids[property_id] = true
		if property_definition.has_range:
			if property_definition.value_type != "Integer" and property_definition.value_type != "Float":
				errors.append("Диапазон поддерживается только для Integer и Float: " + property_id)
			elif property_definition.minimum > property_definition.maximum:
				errors.append("Минимум больше максимума у свойства: " + property_id)
			elif property_definition.value_type == "Integer" and (
					not is_equal_approx(property_definition.minimum, roundf(property_definition.minimum))
					or not is_equal_approx(property_definition.maximum, roundf(property_definition.maximum))
			):
				errors.append("Границы Integer должны быть целыми числами: " + property_id)
			else:
				var numeric_default := float(property_definition.default_value)
				if numeric_default < property_definition.minimum or numeric_default > property_definition.maximum:
					errors.append("Значение по умолчанию вне диапазона у свойства: " + property_id)

	var used_component_ids: Dictionary = {}
	for component_definition in definition.components:
		if component_definition == null:
			errors.append("В списке legacy-компонентов есть пустая запись.")
			continue
		var component_id := component_definition.component_id.strip_edges().to_lower()
		if component_id.is_empty():
			errors.append("У компонента должен быть постоянный ID.")
		elif used_component_ids.has(component_id):
			errors.append("Повторяется ID legacy-компонента: " + component_id)
		else:
			used_component_ids[component_id] = true
		if component_definition.component_script == null and not ObjectComponentCatalog.has_component(component_id):
			errors.append("У компонента '%s' нет скрипта и такого ID нет в каталоге." % component_id)

	var used_binding_ids: Dictionary = {}
	var validation_scene: Node = null
	var validation_packed_scene: PackedScene = null
	if not definition.scene_path.strip_edges().is_empty() and ResourceLoader.exists(definition.scene_path):
		validation_packed_scene = ResourceLoader.load(
			definition.scene_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		) as PackedScene
	if validation_packed_scene == null:
		validation_packed_scene = definition.scene
	if validation_packed_scene != null:
		validation_scene = validation_packed_scene.instantiate()
		if validation_scene == null:
			errors.append("Не удалось открыть сцену объекта для проверки привязок компонентов.")
	if validation_scene == null and ClassDB.class_exists(definition.root_type):
		var temporary_root: Object = ClassDB.instantiate(definition.root_type)
		if temporary_root is Node:
			validation_scene = temporary_root as Node

	# Apply only to this disposable validation instance so bindings may target generated nodes.
	var structure_plan := ObjectSceneStructureService.apply_structure(definition, validation_scene)
	if not bool(structure_plan.get("ok", false)):
		var structure_errors: PackedStringArray = structure_plan.get("errors", PackedStringArray())
		for structure_error in structure_errors:
			errors.append(structure_error)

	var capability_errors := ObjectCapabilityService.validate_selections(
		definition.capabilities,
		validation_scene
	)
	for capability_error in capability_errors:
		errors.append(capability_error)

	for binding in definition.component_bindings:
		if binding == null:
			errors.append("В списке привязок компонентов есть пустая запись.")
			continue
		var binding_id := binding.binding_id.strip_edges()
		if binding_id.is_empty():
			errors.append("У привязки компонента должен быть постоянный ID.")
		elif used_binding_ids.has(binding_id):
			errors.append("Повторяется ID привязки компонента: " + binding_id)
		else:
			used_binding_ids[binding_id] = true

		var component_definition := binding.component_definition
		if component_definition == null:
			errors.append("У привязки '%s' не выбрано поведение." % binding_id)
			continue
		var component_id := component_definition.component_id.strip_edges().to_lower()
		if component_id.is_empty():
			errors.append("У привязки '%s' не указан ID компонента." % binding_id)
		elif component_definition.component_script == null and not ObjectComponentCatalog.has_component(component_id):
			errors.append("У компонента '%s' нет скрипта и такого ID нет в каталоге." % component_id)

		var target_path := str(binding.target_node_path)
		if target_path.is_empty() or target_path == ".":
			continue
		if validation_scene == null:
			errors.append(
				"Привязка '%s' указывает на '%s', но у объекта нет сцены с таким узлом."
				% [binding_id, target_path]
			)
		elif validation_scene.get_node_or_null(binding.target_node_path) == null:
			errors.append(
				"Для привязки '%s' не найден узел '%s'."
				% [binding_id, target_path]
			)

	var all_bindings: Array[ObjectComponentBinding] = []
	for legacy_definition in definition.components:
		if legacy_definition == null or not legacy_definition.enabled:
			continue
		var legacy_binding := ObjectComponentBinding.new()
		legacy_binding.component_definition = legacy_definition
		legacy_binding.binding_id = "legacy:" + legacy_definition.component_id.strip_edges().to_lower()
		legacy_binding.target_node_path = NodePath(".")
		all_bindings.append(legacy_binding)
	for binding in definition.component_bindings:
		all_bindings.append(binding)
	for generated_binding in ObjectCapabilityService.build_component_bindings(definition.capabilities):
		if generated_binding == null:
			continue
		var generated_id := generated_binding.binding_id
		if used_binding_ids.has(generated_id):
			errors.append("ID привязки повторяется между возможностью и ручной настройкой: " + generated_id)
		else:
			used_binding_ids[generated_id] = true
		all_bindings.append(generated_binding)

	# Resolve against the actual draft scene. If no scene exists yet, create a temporary
	# root of the declared class so root-level supported_node_types are still checked.
	if validation_scene == null and ClassDB.class_exists(definition.root_type):
		var temporary_root: Object = ClassDB.instantiate(definition.root_type)
		if temporary_root is Node:
			validation_scene = temporary_root as Node

	if validation_scene != null:
		var binding_plan := ObjectComponentCatalog.resolve_bindings(all_bindings, validation_scene)
		if not bool(binding_plan.get("ok", false)):
			var binding_errors: PackedStringArray = binding_plan.get("errors", PackedStringArray())
			for binding_error in binding_errors:
				errors.append(binding_error)
		validation_scene.free()
	elif not all_bindings.is_empty():
		errors.append("Не удалось создать корневой узел для проверки компонентов.")

	return errors


static func save_definition(definition: ObjectDefinition) -> Error:
	definition.is_template = false
	_prepare_definition_for_save(definition)
	var target_path := OBJECTS_PATH.path_join(_safe_file_part(definition.object_id) + ".tres")
	return _save_resource(definition, target_path)


static func save_template(definition: ObjectDefinition) -> Error:
	definition.is_template = true
	_prepare_definition_for_save(definition)
	var target_path := TEMPLATES_PATH.path_join(_safe_file_part(definition.object_id) + ".tres")
	return _save_resource(definition, target_path)


static func _prepare_definition_for_save(definition: ObjectDefinition) -> void:
	if definition == null:
		return
	definition.schema_version = ObjectDefinition.CURRENT_SCHEMA_VERSION
	for binding in definition.component_bindings:
		if binding != null:
			binding.ensure_binding_id()


static func get_scene_path(object_id: String) -> String:
	return SCENES_PATH.path_join(_safe_file_part(object_id) + ".tscn")


static func _save_resource(definition: ObjectDefinition, target_path: String) -> Error:
	var errors := validate_definition(definition)
	if not errors.is_empty():
		for message in errors:
			push_error("Object Builder: " + message)
		return ERR_INVALID_DATA

	ensure_directories()
	var absolute_target := ProjectSettings.globalize_path(target_path)
	if FileAccess.file_exists(target_path):
		var backup_path := absolute_target + ".bak"
		if FileAccess.file_exists(target_path + ".bak"):
			DirAccess.remove_absolute(backup_path)
		var backup_error := DirAccess.copy_absolute(absolute_target, backup_path)
		if backup_error != OK:
			push_warning("Object Builder: не удалось создать резервную копию " + target_path)

	var save_error := ResourceSaver.save(definition, target_path)
	if save_error != OK:
		push_error("Object Builder: не удалось сохранить " + target_path + " (код %d)." % save_error)
	return save_error


static func _scan_directory(
	directory_path: String,
	output: Array[ObjectDefinition],
	templates_only: bool
) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() != "tres":
			continue
		var resource_path := directory_path.path_join(file_name)
		var resource := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if resource is ObjectDefinition:
			var definition := resource as ObjectDefinition
			if definition.is_template == templates_only:
				output.append(definition)
	for child_directory in directory.get_directories():
		_scan_directory(directory_path.path_join(child_directory), output, templates_only)


static func _safe_file_part(value: String) -> String:
	var result := value.strip_edges().validate_filename().replace(".", "_")
	if result.is_empty():
		return "object"
	return result
