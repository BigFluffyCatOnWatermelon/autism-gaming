@tool
extends RefCounted
class_name ObjectLibraryService

const LIBRARY_ROOT := "res://data/object_library"
# Stable ASCII paths are used for every new resource. Display names and
# translated category labels must never become filesystem identifiers.
const OBJECTS_PATH := LIBRARY_ROOT + "/objects"
const SCENES_PATH := LIBRARY_ROOT + "/scenes"
const TEMPLATES_PATH := LIBRARY_ROOT + "/templates"
# Read paths created by the short-lived localized-path migration. On the next
# successful save each definition and generated scene is moved to its stable
# ID-based path; old data is never ignored.
const LEGACY_OBJECTS_PATH := LIBRARY_ROOT + "/Объекты"
const LEGACY_SCENES_PATH := LIBRARY_ROOT + "/Сцены"
const LEGACY_TEMPLATES_PATH := LIBRARY_ROOT + "/Шаблоны"
const ObjectBuilderReferenceScript = preload("res://scripts/object_system/object_builder_reference.gd")
const ItemCatalog = preload("res://scripts/item_catalog_service.gd")


static func ensure_directories() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OBJECTS_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENES_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMPLATES_PATH))


static func load_definitions() -> Array[ObjectDefinition]:
	var definitions: Array[ObjectDefinition] = []
	_scan_directory(OBJECTS_PATH, definitions, false)
	_scan_directory(LEGACY_OBJECTS_PATH, definitions, false)
	definitions.sort_custom(func(a: ObjectDefinition, b: ObjectDefinition) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)
	return definitions


## Returns every on-disk definition, including duplicate object IDs. The Web
## Object Builder uses this only to detect files copied manually in Godot's
## FileSystem dock; normal library consumers should use load_definitions().
static func load_all_definition_files() -> Array[ObjectDefinition]:
	var definitions: Array[ObjectDefinition] = []
	_scan_directory_all(OBJECTS_PATH, definitions, false)
	_scan_directory_all(LEGACY_OBJECTS_PATH, definitions, false)
	return definitions


static func load_templates() -> Array[ObjectDefinition]:
	var templates: Array[ObjectDefinition] = []
	_scan_directory(TEMPLATES_PATH, templates, true)
	_scan_directory(LEGACY_TEMPLATES_PATH, templates, true)
	templates.sort_custom(func(a: ObjectDefinition, b: ObjectDefinition) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)
	return templates


static func find_definition_path(
	object_id: String,
	is_template: bool = false,
	preferred_path: String = ""
) -> String:
	var clean_id := object_id.strip_edges()
	if clean_id.is_empty():
		return ""
	if (
		is_managed_definition_path(preferred_path)
		and FileAccess.file_exists(preferred_path)
	):
		var preferred := ResourceLoader.load(
			preferred_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ObjectDefinition
		if preferred != null and preferred.object_id == clean_id:
			return preferred_path

	var roots := PackedStringArray()
	if is_template:
		roots.append(TEMPLATES_PATH)
		roots.append(LEGACY_TEMPLATES_PATH)
	else:
		roots.append(OBJECTS_PATH)
		roots.append(LEGACY_OBJECTS_PATH)
	for root_path in roots:
		var found_path := _find_definition_path_recursive(root_path, clean_id)
		if not found_path.is_empty():
			return found_path
	return ""


static func _find_definition_path_recursive(directory_path: String, object_id: String) -> String:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return ""
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() != "tres":
			continue
		var candidate_path := directory_path.path_join(file_name)
		var candidate := ResourceLoader.load(
			candidate_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ObjectDefinition
		if candidate != null and candidate.object_id == object_id:
			return candidate_path
	for child_directory in directory.get_directories():
		var found_path := _find_definition_path_recursive(
			directory_path.path_join(child_directory), object_id
		)
		if not found_path.is_empty():
			return found_path
	return ""


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
			ResourceLoader.CACHE_MODE_IGNORE
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

	_validate_gameplay_table_references(all_bindings, errors)

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

	var used_relation_ids: Dictionary = {}
	for relation_value in definition.relations:
		if not relation_value is Dictionary:
			errors.append("В списке связей есть запись неверного типа.")
			continue
		var relation: Dictionary = relation_value
		var relation_id := str(relation.get("relation_id", "")).strip_edges()
		var target_id := str(relation.get("target_object_id", "")).strip_edges()
		if relation_id.is_empty():
			errors.append("У каждой связи должен быть постоянный ID.")
		elif used_relation_ids.has(relation_id):
			errors.append("Повторяется ID связи: " + relation_id)
		else:
			used_relation_ids[relation_id] = true
		if target_id.is_empty():
			errors.append("У связи '%s' не указан целевой объект." % relation_id)
		elif target_id == definition.object_id:
			errors.append("Объект не может ссылаться сам на себя.")
		if int(relation.get("quantity", 1)) < 1:
			errors.append("Количество в связи '%s' должно быть не меньше 1." % relation_id)

	return errors


## New external gameplay tables are strict: a broken .tres reference or an
## unknown item ID blocks saving. Legacy JSON remains on its compatibility path.
static func _validate_gameplay_table_references(
	bindings: Array[ObjectComponentBinding],
	errors: PackedStringArray
) -> void:
	var expected_tables := {
		"yields_resources": {"path_key": "resource_table_path", "type": "yield"},
		"drops_loot_on_destroy": {"path_key": "loot_table_path", "type": "loot"},
		"supports_item_crafting": {"path_key": "recipes_table_path", "type": "recipe"},
		"can_produce_resources": {"path_key": "production_table_path", "type": "production"},
		"has_periodic_output": {"path_key": "production_table_path", "type": "production"}
	}
	for binding in bindings:
		if binding == null or not binding.enabled or binding.component_definition == null:
			continue
		var component := binding.component_definition
		if not component.enabled:
			continue
		var component_id := component.component_id.strip_edges().to_lower()
		if not expected_tables.has(component_id):
			continue
		var table_config: Dictionary = expected_tables[component_id]
		var path_key := str(table_config.path_key)
		var resource_path := str(component.get_setting(path_key, "")).strip_edges()
		if resource_path.is_empty():
			continue
		var context := "Компонент «%s», привязка «%s»" % [component_id, binding.binding_id]
		if not ResourceLoader.exists(resource_path):
			errors.append("%s: таблица не найдена: %s" % [context, resource_path])
			continue
		var table := ResourceLoader.load(resource_path) as GameplayTableDefinition
		if table == null:
			errors.append("%s: ресурс не является GameplayTableDefinition: %s" % [context, resource_path])
			continue
		var expected_type := str(table_config.type)
		if table.table_type != expected_type:
			errors.append("%s: ожидалась таблица типа «%s», получен «%s»." % [context, expected_type, table.table_type])
			continue
		var referenced_ids: Array[String] = []
		for entry_index in range(table.entries.size()):
			var entry: Variant = table.entries[entry_index]
			if not entry is Dictionary:
				errors.append("%s: запись %d должна быть словарём." % [context, entry_index + 1])
				continue
			match expected_type:
				"yield", "loot":
					var item_id := str(entry.get("item_id", entry.get("id", ""))).strip_edges()
					if item_id.is_empty():
						errors.append("%s: в записи %d отсутствует item_id." % [context, entry_index + 1])
					else:
						referenced_ids.append(item_id)
					var chance := float(entry.get("chance", 1.0))
					var minimum := int(entry.get("min", entry.get("minimum", entry.get("amount", 1))))
					var maximum := int(entry.get("max", entry.get("maximum", entry.get("amount", minimum))))
					if chance < 0.0 or chance > 1.0 or minimum < 0 or maximum < minimum:
						errors.append("%s: некорректные chance/min/max в записи %d." % [context, entry_index + 1])
				"production":
					var item_id := str(entry.get("item_id", entry.get("id", ""))).strip_edges()
					if item_id.is_empty():
						errors.append("%s: в записи %d отсутствует item_id." % [context, entry_index + 1])
					else:
						referenced_ids.append(item_id)
					if int(entry.get("amount_per_cycle", entry.get("amount", 1))) <= 0:
						errors.append("%s: количество production в записи %d должно быть больше нуля." % [context, entry_index + 1])
				"recipe":
					var recipe_id := str(entry.get("recipe_id", entry.get("id", ""))).strip_edges()
					if recipe_id.is_empty():
						errors.append("%s: у рецепта %d отсутствует recipe_id." % [context, entry_index + 1])
					var ingredients: Variant = entry.get("ingredients", {})
					if not ingredients is Dictionary or ingredients.is_empty():
						errors.append("%s: у рецепта %d отсутствуют ингредиенты." % [context, entry_index + 1])
					else:
						for raw_item_id in ingredients.keys():
							var ingredient_id := str(raw_item_id).strip_edges()
							if ingredient_id.is_empty():
								errors.append("%s: у рецепта %d найден пустой ID ингредиента." % [context, entry_index + 1])
							else:
								referenced_ids.append(ingredient_id)
							if int(ingredients[raw_item_id]) <= 0:
								errors.append("%s: количество ингредиента «%s» в рецепте %d должно быть больше нуля." % [context, ingredient_id, entry_index + 1])
					var output: Variant = entry.get("output", {})
					if not output is Dictionary:
						errors.append("%s: у рецепта %d некорректный output." % [context, entry_index + 1])
					else:
						var output_id := str(output.get("item_id", "")).strip_edges()
						if output_id.is_empty():
							errors.append("%s: у рецепта %d отсутствует item_id результата." % [context, entry_index + 1])
						else:
							referenced_ids.append(output_id)
						if int(output.get("amount", 1)) <= 0:
							errors.append("%s: количество результата рецепта %d должно быть больше нуля." % [context, entry_index + 1])
		var validation := ItemCatalog.validate_item_ids(referenced_ids)
		for missing_id in validation.get("missing", []):
			errors.append("%s: item_id «%s» отсутствует в каталоге предметов (%s)." % [context, str(missing_id), resource_path])


static func save_definition(definition: ObjectDefinition) -> Error:
	if definition == null:
		return ERR_INVALID_PARAMETER
	definition.is_template = false
	ensure_unique_display_name(definition)
	_prepare_definition_for_save(definition)
	return _save_resource(definition, get_definition_path_for_definition(definition))


static func save_template(definition: ObjectDefinition) -> Error:
	if definition == null:
		return ERR_INVALID_PARAMETER
	definition.is_template = true
	ensure_unique_display_name(definition)
	_prepare_definition_for_save(definition)
	return _save_resource(definition, get_definition_path_for_definition(definition))


static func get_definition_path_for_definition(definition: ObjectDefinition) -> String:
	if definition == null:
		return ""
	var root_path := TEMPLATES_PATH if definition.is_template else OBJECTS_PATH
	var category_path := _category_folder_part(definition.category)
	var file_name := _stable_object_file_part(definition.display_name)
	return root_path.path_join(category_path).path_join(file_name + ".tres")


static func get_scene_path_for_definition(definition: ObjectDefinition) -> String:
	if definition == null:
		return ""
	var collection_name := "templates" if definition.is_template else "objects"
	var category_path := _category_folder_part(definition.category)
	var file_name := _stable_object_file_part(definition.display_name)
	return SCENES_PATH.path_join(collection_name).path_join(category_path).path_join(file_name + ".tscn")


static func get_scene_path(object_id: String) -> String:
	var clean_id := object_id.strip_edges()
	for definition in load_definitions() + load_templates():
		if definition.object_id != clean_id:
			continue
		if not definition.scene_path.is_empty() and FileAccess.file_exists(definition.scene_path):
			return definition.scene_path
		return get_scene_path_for_definition(definition)
	# Compatibility with old ID-named scenes in either storage layout.
	for legacy_path in [
		LEGACY_SCENES_PATH.path_join(_safe_file_part(clean_id) + ".tscn"),
		SCENES_PATH.path_join(_safe_file_part(clean_id) + ".tscn")
	]:
		if FileAccess.file_exists(legacy_path):
			return legacy_path
	return SCENES_PATH.path_join("objects").path_join("other").path_join(_stable_object_file_part(clean_id) + ".tscn")


static func ensure_unique_display_name(definition: ObjectDefinition) -> String:
	if definition == null:
		return ""
	var base_name := definition.display_name.strip_edges()
	if base_name.is_empty():
		base_name = "Новый объект"
	var candidate := base_name
	var suffix := 2
	while _has_name_or_path_conflict(definition, candidate):
		candidate = "%s (%d)" % [base_name, suffix]
		suffix += 1
		if suffix > 10000:
			break
	definition.display_name = candidate
	return candidate


static func _has_name_or_path_conflict(definition: ObjectDefinition, candidate_name: String) -> bool:
	var existing_definitions := load_templates() if definition.is_template else load_definitions()
	for existing in existing_definitions:
		if existing == null or existing.object_id == definition.object_id:
			continue
		if existing.display_name.strip_edges().to_lower() == candidate_name.to_lower():
			return true
	var candidate := definition.duplicate(false) as ObjectDefinition
	candidate.display_name = candidate_name
	var resource_path := get_definition_path_for_definition(candidate)
	if FileAccess.file_exists(resource_path):
		var existing_resource := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ObjectDefinition
		if existing_resource == null or existing_resource.object_id != definition.object_id:
			return true
	var scene_path := get_scene_path_for_definition(candidate)
	if FileAccess.file_exists(scene_path):
		var packed := ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if packed == null:
			return true
		var scene_object_id := get_packed_scene_object_id(packed)
		if not scene_object_id.is_empty():
			if scene_object_id != definition.object_id:
				return true
		elif scene_path != definition.scene_path:
			# A legacy scene without the new reference marker can only be treated
			# as the same object's file when it is already its recorded scene path.
			return true
	return false


## Resolves the durable Object Builder identity from an actual scene root.
## This works for both the live scene currently edited by Godot and PackedScene instances.
static func get_scene_root_object_id(scene_root: Node) -> String:
	if scene_root == null or not is_instance_valid(scene_root):
		return ""
	var object_id := str(
		scene_root.get_meta(
			"object_builder_id",
			scene_root.get_meta("object_definition_id", "")
		)
	).strip_edges()
	if not object_id.is_empty():
		return object_id
	# apply_object_identity() stores the reference as a direct child of the
	# object scene root. Never search recursively here: a level scene can contain
	# nested object instances, and their IDs must not identify the level itself.
	for candidate in scene_root.get_children():
		if candidate is Node and candidate.get_script() == ObjectBuilderReferenceScript:
			object_id = str(candidate.get("object_id")).strip_edges()
			if not object_id.is_empty():
				return object_id
	return ""


## Finds a unique Object Builder scene root inside a larger edited level.
## Returns null when more than one instance shares the requested ID, because
## per-instance overrides must never be guessed.
static func find_scene_root_in_tree(scene_root: Node, object_id: String) -> Node:
	if scene_root == null or object_id.strip_edges().is_empty():
		return null
	if get_scene_root_object_id(scene_root) == object_id:
		return scene_root
	var match_root: Node
	for candidate in scene_root.find_children("*", "", true, false):
		if get_scene_root_object_id(candidate) != object_id:
			continue
		if match_root != null:
			return null
		match_root = candidate
	return match_root


static func get_packed_scene_object_id(packed_scene: PackedScene) -> String:
	if packed_scene == null:
		return ""
	var instance := packed_scene.instantiate()
	if instance == null:
		return ""
	var object_id := get_scene_root_object_id(instance)
	instance.free()
	return object_id


static func is_managed_scene_path(path: String) -> bool:
	return (
		path.begins_with(SCENES_PATH + "/")
		or path.begins_with(LEGACY_SCENES_PATH + "/")
	)


static func remove_scene_if_unreferenced(scene_path: String, object_id: String) -> bool:
	if scene_path.strip_edges().is_empty() or not is_managed_scene_path(scene_path):
		return false
	for definition in load_definitions() + load_templates():
		if definition == null or definition.object_id == object_id:
			continue
		if definition.scene_path == scene_path:
			return false
	if not FileAccess.file_exists(scene_path):
		return true
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path))
	return error == OK


static func _prepare_definition_for_save(definition: ObjectDefinition) -> void:
	if definition == null:
		return
	definition.resource_name = definition.display_name.strip_edges()
	definition.schema_version = ObjectDefinition.CURRENT_SCHEMA_VERSION
	for binding in definition.component_bindings:
		if binding != null:
			binding.ensure_binding_id()


static func _save_resource(definition: ObjectDefinition, target_path: String) -> Error:
	if definition == null or target_path.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var errors := validate_definition(definition)
	if not errors.is_empty():
		for message in errors:
			push_error("Object Builder: " + message)
		return ERR_INVALID_DATA

	var previous_path := definition.resource_path
	if FileAccess.file_exists(target_path):
		var existing_resource := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ObjectDefinition
		if existing_resource == null or existing_resource.object_id != definition.object_id:
			return ERR_ALREADY_EXISTS
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_path.get_base_dir())
	)
	if directory_error != OK:
		push_error(
			"Object Builder: не удалось создать каталог для %s (код %d)."
			% [target_path, directory_error]
		)
		return directory_error
	var absolute_target := ProjectSettings.globalize_path(target_path)
	var backup_path := absolute_target + ".bak"
	var had_previous_target := FileAccess.file_exists(target_path)
	if had_previous_target:
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		var backup_error := DirAccess.copy_absolute(absolute_target, backup_path)
		if backup_error != OK:
			return backup_error

	var save_error := ResourceSaver.save(definition, target_path)
	if save_error != OK:
		if had_previous_target and FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(backup_path, absolute_target)
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		push_error("Object Builder: не удалось сохранить " + target_path + " (код %d)." % save_error)
		return save_error
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	if is_managed_definition_path(previous_path) and previous_path != target_path and FileAccess.file_exists(previous_path):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(previous_path))
		if remove_error != OK:
			push_warning("Object Builder: новая запись сохранена, но старый файл остался: " + previous_path)
	return OK


static func is_managed_definition_path(path: String) -> bool:
	return (
		path.begins_with(OBJECTS_PATH + "/")
		or path.begins_with(TEMPLATES_PATH + "/")
		or path.begins_with(LEGACY_OBJECTS_PATH + "/")
		or path.begins_with(LEGACY_TEMPLATES_PATH + "/")
	)


static func _scan_directory_all(
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
		var resource := ResourceLoader.load(
			resource_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ObjectDefinition
		if resource == null:
			continue
		resource.is_template = templates_only
		output.append(resource)
	for child_directory in directory.get_directories():
		_scan_directory_all(
			directory_path.path_join(child_directory), output, templates_only
		)


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
		var resource := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			push_warning("Object Builder: не удалось загрузить запись библиотеки: " + resource_path)
			continue
		if not resource is ObjectDefinition:
			push_warning("Object Builder: файл библиотеки не является ObjectDefinition: " + resource_path)
			continue

		# The folder is the source of truth. Older or manually edited resources may
		# contain a stale is_template flag; it must never make a saved object vanish.
		var definition := resource as ObjectDefinition
		var duplicate_id := false
		for existing_definition in output:
			if existing_definition != null and existing_definition.object_id == definition.object_id:
				duplicate_id = true
				break
		if duplicate_id:
			continue
		definition.is_template = templates_only
		output.append(definition)
	for child_directory in directory.get_directories():
		_scan_directory(directory_path.path_join(child_directory), output, templates_only)


static func _category_folder_part(value: String) -> String:
	# Built-in category IDs are already stable ASCII identifiers. Custom or
	# localized category labels are grouped separately; the object ID keeps
	# filenames unique inside that folder.
	const CATEGORY_IDS := [
		"Nature", "Buildings", "Items", "Equipment", "Furniture", "Characters",
		"Animals", "Interactive", "Effects", "Transport", "Decorations", "Other",
		"Environment", "Resources", "Weapons", "Tools", "NPC"
	]
	var category_id := value.strip_edges()
	if CATEGORY_IDS.has(category_id):
		return category_id.to_snake_case()
	return "custom"


static func _stable_object_file_part(value: String) -> String:
	var raw := value.strip_edges().to_lower()
	if raw.is_empty():
		raw = "object"

	# Preserve readable filenames without putting localized characters into
	# res:// paths. Russian names are transliterated deterministically:
	# "Сосна" -> "sosna", "Древесина" -> "drevesina".
	const CYRILLIC_TO_ASCII := {
		"а": "a", "б": "b", "в": "v", "г": "g", "д": "d",
		"е": "e", "ё": "yo", "ж": "zh", "з": "z", "и": "i",
		"й": "y", "к": "k", "л": "l", "м": "m", "н": "n",
		"о": "o", "п": "p", "р": "r", "с": "s", "т": "t",
		"у": "u", "ф": "f", "х": "kh", "ц": "ts", "ч": "ch",
		"ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "",
		"э": "e", "ю": "yu", "я": "ya"
	}
	var transliterated := ""
	for character in raw:
		if CYRILLIC_TO_ASCII.has(character):
			transliterated += str(CYRILLIC_TO_ASCII[character])
		else:
			transliterated += character

	var pattern := RegEx.new()
	pattern.compile("[^a-z0-9_-]+")
	var safe := pattern.sub(transliterated, "_", true).trim_prefix("_").trim_suffix("_")
	while safe.contains("__"):
		safe = safe.replace("__", "_")
	if safe.is_empty():
		safe = "object"
	return safe


static func _safe_file_part(value: String) -> String:
	var result := value.strip_edges().validate_filename()
	if result.is_empty():
		return "object"
	return result
