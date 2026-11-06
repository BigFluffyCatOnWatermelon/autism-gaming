@tool
extends RefCounted
class_name MechanicModuleLoader

## Loads self-contained mechanic packages and registers their definitions in the shared catalogues.
## Module code is trusted GDScript shipped with the project; this loader is not a sandbox.

const MODULE_API_VERSION := 1
const DEFAULT_MODULES_DIRECTORY := "res://addons/object_builder/mechanics"

static var _registered_modules: Dictionary = {}
static var _scanned_directories: Dictionary = {}


static func register_modules_in_directory(
	directory_path: String = DEFAULT_MODULES_DIRECTORY
) -> PackedStringArray:
	var errors := PackedStringArray()
	if _scanned_directories.has(directory_path):
		return errors
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return errors

	var module_directories := PackedStringArray()
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if directory.current_is_dir() and not entry_name.begins_with(".") and not entry_name.begins_with("_"):
			var candidate_path := directory_path.path_join(entry_name)
			if FileAccess.file_exists(candidate_path.path_join("module.cfg")):
				module_directories.append(candidate_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
	module_directories.sort()

	for module_directory in module_directories:
		errors.append_array(register_module(module_directory))
	_scanned_directories[directory_path] = true
	return errors


static func register_module(module_directory: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized_path := module_directory.strip_edges().trim_suffix("/")
	if normalized_path.is_empty():
		return PackedStringArray(["Не указан путь к папке модуля."])

	var manifest_path := normalized_path.path_join("module.cfg")
	if not FileAccess.file_exists(manifest_path):
		return PackedStringArray(["В папке модуля отсутствует module.cfg: " + normalized_path])

	var config := ConfigFile.new()
	var load_error := config.load(manifest_path)
	if load_error != OK:
		return PackedStringArray([
			"Не удалось прочитать module.cfg (%s): %s" % [str(load_error), manifest_path]
		])

	var module_id := str(config.get_value("mechanic", "id", "")).strip_edges().to_lower()
	var module_version := int(config.get_value("mechanic", "version", 0))
	var api_version := int(config.get_value("mechanic", "api_version", 0))
	var entrypoint := str(config.get_value("mechanic", "entrypoint", "")).strip_edges()

	if not _is_valid_id(module_id):
		errors.append("В module.cfg указан некорректный ID модуля: " + module_id)
	if module_version < 1:
		errors.append("Версия модуля должна быть не меньше 1: " + module_id)
	if api_version != MODULE_API_VERSION:
		errors.append(
			"Модуль '%s' использует API %d; текущая версия API: %d."
			% [module_id, api_version, MODULE_API_VERSION]
		)
	if not _is_safe_relative_path(entrypoint):
		errors.append("У модуля '%s' некорректный относительный entrypoint." % module_id)
	if not errors.is_empty():
		return errors

	if _registered_modules.has(module_id):
		if str(_registered_modules[module_id]) == normalized_path:
			return PackedStringArray()
		return PackedStringArray(["Модуль с ID '%s' уже загружен из другой папки." % module_id])

	var source_id := "mechanic_module:" + module_id
	var script_path := normalized_path.path_join(entrypoint)
	if not ResourceLoader.exists(script_path):
		return PackedStringArray(["Не найден entrypoint модуля: " + script_path])

	var module_script := ResourceLoader.load(script_path) as Script
	if module_script == null:
		return PackedStringArray(["Не удалось загрузить GDScript модуля: " + script_path])

	var module_instance: Object = module_script.new()
	if not module_instance is RefCounted:
		return PackedStringArray(["Entry point модуля должен наследовать RefCounted: " + script_path])
	if not module_instance.has_method("build_component_definitions"):
		return PackedStringArray(["Entry point не реализует build_component_definitions(): " + script_path])
	if not module_instance.has_method("build_capability_definitions"):
		return PackedStringArray(["Entry point не реализует build_capability_definitions(): " + script_path])

	var component_value: Variant = module_instance.call("build_component_definitions")
	var capability_value: Variant = module_instance.call("build_capability_definitions")
	if not component_value is Array:
		return PackedStringArray(["build_component_definitions() должен возвращать Array."])
	if not capability_value is Array:
		return PackedStringArray(["build_capability_definitions() должен возвращать Array."])

	var component_definitions: Array = component_value
	var capability_definitions: Array = capability_value
	var expected_component_ids := _read_id_array(
		config.get_value("mechanic", "component_ids", null),
		"component_ids",
		errors
	)
	var expected_capability_ids := _read_id_array(
		config.get_value("mechanic", "capability_ids", null),
		"capability_ids",
		errors
	)
	if component_definitions.is_empty():
		errors.append("Модуль должен объявлять хотя бы один runtime-компонент.")
	if capability_definitions.is_empty():
		errors.append("Модуль должен объявлять хотя бы одну пользовательскую возможность.")

	var actual_component_ids := _extract_definition_ids(
		component_definitions,
		"component_id",
		ObjectComponentDefinition,
		"компонента",
		errors
	)
	var actual_capability_ids := _extract_definition_ids(
		capability_definitions,
		"capability_id",
		ObjectCapabilityDefinition,
		"возможности",
		errors
	)
	if not _same_ids(expected_component_ids, actual_component_ids):
		errors.append("component_ids в module.cfg не совпадает с ID определений компонентов.")
	if not _same_ids(expected_capability_ids, actual_capability_ids):
		errors.append("capability_ids в module.cfg не совпадает с ID определений возможностей.")
	if not errors.is_empty():
		return errors

	var component_errors := ObjectComponentCatalog.register_definitions(
		component_definitions,
		source_id
	)
	if not component_errors.is_empty():
		errors.append_array(component_errors)
		return errors

	var capability_errors := ObjectCapabilityCatalog.register_definitions(
		capability_definitions,
		source_id
	)
	if not capability_errors.is_empty():
		errors.append_array(capability_errors)
		var rollback_errors := ObjectComponentCatalog.unregister_source(source_id)
		if not rollback_errors.is_empty():
			errors.append_array(rollback_errors)
			errors.append("Не удалось полностью откатить регистрацию компонентов модуля '%s'." % module_id)
		return errors

	_registered_modules[module_id] = normalized_path
	return errors


static func unregister_module(module_id: String) -> PackedStringArray:
	var normalized_id := module_id.strip_edges().to_lower()
	if not _registered_modules.has(normalized_id):
		return PackedStringArray(["Модуль не зарегистрирован: " + normalized_id])

	var source_id := "mechanic_module:" + normalized_id
	var component_ids := PackedStringArray()
	for component_id in ObjectComponentCatalog.get_component_ids():
		if ObjectComponentCatalog.get_source_id(component_id) == source_id:
			component_ids.append(component_id)

	# Check dependants before mutating either catalogue, so unload is all-or-nothing.
	for capability_id in ObjectCapabilityCatalog.get_capability_ids("", false):
		if ObjectCapabilityCatalog.get_source_id(capability_id) == source_id:
			continue
		var capability := ObjectCapabilityCatalog.get_definition(capability_id)
		if capability == null:
			continue
		for component_id in capability.component_ids:
			if component_ids.has(str(component_id).strip_edges().to_lower()):
				return PackedStringArray([
					"Нельзя отключить модуль '%s': возможность '%s' использует его компонент '%s'."
					% [normalized_id, capability_id, component_id]
				])

	var capability_errors := ObjectCapabilityCatalog.unregister_source(source_id)
	if not capability_errors.is_empty():
		return capability_errors
	var component_errors := ObjectComponentCatalog.unregister_source(source_id)
	if not component_errors.is_empty():
		return component_errors

	_registered_modules.erase(normalized_id)
	return PackedStringArray()


static func get_loaded_module_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for module_id in _registered_modules:
		result.append(str(module_id))
	result.sort()
	return result


static func _read_id_array(
	value: Variant,
	field_name: String,
	errors: PackedStringArray
) -> PackedStringArray:
	var result := PackedStringArray()
	if value is PackedStringArray:
		for item in value:
			result.append(str(item).strip_edges().to_lower())
	elif value is Array:
		for item in value:
			if typeof(item) != TYPE_STRING:
				errors.append("Поле %s в module.cfg должно содержать только строки." % field_name)
			else:
				result.append(str(item).strip_edges().to_lower())
	else:
		errors.append("Поле %s в module.cfg должно быть массивом ID." % field_name)
		return result

	var seen: Dictionary = {}
	for item in result:
		if not _is_valid_id(item):
			errors.append("Некорректный ID '%s' в поле %s." % [item, field_name])
		if seen.has(item):
			errors.append("Повторяющийся ID '%s' в поле %s." % [item, field_name])
		seen[item] = true
	return result


static func _extract_definition_ids(
	definitions: Array,
	property_name: String,
	expected_type: Variant,
	label: String,
	errors: PackedStringArray
) -> PackedStringArray:
	var result := PackedStringArray()
	var seen: Dictionary = {}
	for value in definitions:
		if not is_instance_of(value, expected_type):
			errors.append("Модуль содержит элемент неверного типа вместо определения %s." % label)
			continue
		var definition_id := str(value.get(property_name)).strip_edges().to_lower()
		if not _is_valid_id(definition_id):
			errors.append("Определение %s содержит некорректный ID: %s." % [label, definition_id])
		if seen.has(definition_id):
			errors.append("В модуле повторяется ID: " + definition_id)
		seen[definition_id] = true
		result.append(definition_id)
	return result


static func _same_ids(first: PackedStringArray, second: PackedStringArray) -> bool:
	var left := first.duplicate()
	var right := second.duplicate()
	left.sort()
	right.sort()
	return left == right


static func _is_safe_relative_path(value: String) -> bool:
	var path := value.strip_edges()
	return (
		not path.is_empty()
		and not path.begins_with("/")
		and not path.contains("..")
		and not path.begins_with("res://")
		and not path.begins_with("user://")
	)


static func _is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return value[0] != "_" and value[value.length() - 1] != "_"
