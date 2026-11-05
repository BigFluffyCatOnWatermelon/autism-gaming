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
	return errors


static func save_definition(definition: ObjectDefinition) -> Error:
	definition.is_template = false
	var target_path := OBJECTS_PATH.path_join(_safe_file_part(definition.object_id) + ".tres")
	return _save_resource(definition, target_path)


static func save_template(definition: ObjectDefinition) -> Error:
	definition.is_template = true
	var target_path := TEMPLATES_PATH.path_join(_safe_file_part(definition.object_id) + ".tres")
	return _save_resource(definition, target_path)


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
