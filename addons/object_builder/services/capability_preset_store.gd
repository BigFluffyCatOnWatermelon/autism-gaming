@tool
extends RefCounted
class_name CapabilityPresetStore
## Persistent user presets. Built-in presets remain owned by CapabilityPresetRegistry.

const BUILTIN_REGISTRY_SCRIPT = preload("res://addons/object_builder/services/capability_preset_registry.gd")
const STORE_DIRECTORY := "user://object_builder"
const STORE_PATH := "user://object_builder/custom_capability_presets.json"
const SCHEMA_VERSION := 1
const MAX_PRESETS := 100
const MAX_NAME_LENGTH := 64
const MAX_DESCRIPTION_LENGTH := 240
const MAX_CAPABILITIES := 200

var storage_path := STORE_PATH


func load_presets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(storage_path):
		return result
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		push_warning("Object Builder: не удалось открыть пользовательские наборы: " + storage_path)
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("Object Builder: файл пользовательских наборов повреждён; исходный файл сохранён.")
		return result
	if int(parsed.get("schema_version", -1)) != SCHEMA_VERSION:
		push_warning("Object Builder: неизвестная версия файла пользовательских наборов.")
		return result
	var presets: Variant = parsed.get("presets", [])
	if not presets is Array:
		push_warning("Object Builder: список пользовательских наборов имеет неверный формат.")
		return result
	for value in presets:
		if not value is Dictionary:
			continue
		var preset: Dictionary = value
		var errors := validate_preset(preset, result)
		if errors.is_empty():
			result.append(_normalize_preset(preset))
	return result


func save_preset(preset: Dictionary) -> Dictionary:
	var existing := load_presets()
	var errors := validate_preset(preset, existing)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var normalized := _normalize_preset(preset)
	var replaced := false
	for index in range(existing.size()):
		if str(existing[index].get("id", "")) == str(normalized.get("id", "")):
			existing[index] = normalized
			replaced = true
			break
	if not replaced:
		if existing.size() >= MAX_PRESETS:
			return {"ok": false, "errors": PackedStringArray(["Достигнут лимит пользовательских наборов (%d)." % MAX_PRESETS])}
		existing.append(normalized)
	var write_result := _write_presets(existing)
	write_result["preset"] = normalized
	return write_result


func delete_preset(preset_id: String) -> Dictionary:
	var normalized_id := preset_id.strip_edges().to_lower()
	var existing := load_presets()
	var next: Array[Dictionary] = []
	var found := false
	for preset in existing:
		if str(preset.get("id", "")) == normalized_id:
			found = true
		else:
			next.append(preset)
	if not found:
		return {"ok": false, "errors": PackedStringArray(["Пользовательский набор не найден."])}
	return _write_presets(next)


func duplicate_preset(source_id: String, new_id: String, new_name: String) -> Dictionary:
	var source: Dictionary = {}
	for preset in load_presets():
		if str(preset.get("id", "")) == source_id.strip_edges().to_lower():
			source = preset
			break
	if source.is_empty():
		for preset in BUILTIN_REGISTRY_SCRIPT.get_presets():
			if str(preset.get("id", "")) == source_id.strip_edges().to_lower():
				source = preset
				break
	if source.is_empty():
		return {"ok": false, "errors": PackedStringArray(["Исходный набор не найден."])}
	var copy := source.duplicate(true)
	copy["id"] = new_id
	copy["display_name"] = new_name
	return save_preset(copy)


func validate_preset(preset: Dictionary, existing: Array[Dictionary] = []) -> PackedStringArray:
	var errors := PackedStringArray()
	var preset_id := str(preset.get("id", "")).strip_edges().to_lower()
	var id_regex := RegEx.new()
	id_regex.compile("^[a-z0-9][a-z0-9_-]{1,47}$")
	if id_regex.search(preset_id) == null:
		errors.append("ID набора: 2–48 символов, только латиница, цифры, дефис и подчёркивание.")
	for builtin in BUILTIN_REGISTRY_SCRIPT.get_presets():
		if str(builtin.get("id", "")) == preset_id:
			errors.append("Нельзя перезаписать встроенный набор.")
			break
	for item in existing:
		if str(item.get("id", "")) == preset_id:
			continue
		if str(item.get("id", "")) == preset_id:
			errors.append("Набор с таким ID уже существует.")
			break
	var display_name := str(preset.get("display_name", "")).strip_edges()
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH:
		errors.append("Название должно содержать от 1 до %d символов." % MAX_NAME_LENGTH)
	var description := str(preset.get("description", "")).strip_edges()
	if description.length() > MAX_DESCRIPTION_LENGTH:
		errors.append("Описание не должно превышать %d символов." % MAX_DESCRIPTION_LENGTH)
	var values: Variant = preset.get("capability_ids", [])
	if not values is Array:
		errors.append("Состав набора должен быть списком возможностей.")
		return errors
	if values.is_empty() or values.size() > MAX_CAPABILITIES:
		errors.append("Набор должен содержать от 1 до %d возможностей." % MAX_CAPABILITIES)
	var seen: Dictionary = {}
	for value in values:
		var capability_id := str(value).strip_edges().to_lower()
		if capability_id.is_empty() or seen.has(capability_id):
			errors.append("Список возможностей содержит пустой или повторяющийся ID.")
			continue
		seen[capability_id] = true
		var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		if definition == null:
			errors.append("Возможность '%s' отсутствует в каталоге." % capability_id)
		elif not definition.is_ready():
			errors.append("Возможность '%s' ещё не готова." % capability_id)
	return errors


func _normalize_preset(preset: Dictionary) -> Dictionary:
	var ids := PackedStringArray()
	for value in preset.get("capability_ids", []):
		var capability_id := str(value).strip_edges().to_lower()
		if not capability_id.is_empty() and not ids.has(capability_id):
			ids.append(capability_id)
	return {
		"id": str(preset.get("id", "")).strip_edges().to_lower(),
		"display_name": str(preset.get("display_name", "")).strip_edges(),
		"description": str(preset.get("description", "")).strip_edges(),
		"icon": str(preset.get("icon", "shapes")).strip_edges(),
		"capability_ids": Array(ids)
	}


func _write_presets(presets: Array[Dictionary]) -> Dictionary:
	var directory := storage_path.get_base_dir()
	var absolute_directory := ProjectSettings.globalize_path(directory)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if make_dir_error != OK:
		return {"ok": false, "errors": PackedStringArray(["Не удалось создать папку пользовательских наборов."])}
	var temporary_path := storage_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": PackedStringArray(["Не удалось записать временный файл пользовательских наборов."])}
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"presets": presets
	}, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(storage_path):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path))
		if remove_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
			return {"ok": false, "errors": PackedStringArray(["Не удалось заменить файл пользовательских наборов."])}
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(storage_path)
	)
	if rename_error != OK:
		return {"ok": false, "errors": PackedStringArray(["Не удалось завершить сохранение пользовательских наборов."])}
	return {"ok": true, "errors": PackedStringArray()}
