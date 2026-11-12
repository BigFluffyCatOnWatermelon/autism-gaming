@tool
extends RefCounted
class_name WebObjectBuilderSceneDraftService

const ObjectBuilderReferenceScript = preload("res://scripts/object_system/object_builder_reference.gd")
const ObjectWorldSortScript = preload("res://scripts/object_system/object_world_sort.gd")
## Creates and copies PackedScene drafts without depending on EditorInterface.


static func apply_object_identity(scene_root: Node, definition: ObjectDefinition) -> void:
	if scene_root == null or definition == null:
		return
	var stable_name := definition.display_name.strip_edges().validate_node_name()
	if not stable_name.is_empty():
		scene_root.name = stable_name

	# Metadata is useful while the editor session is open, but the dedicated
	# reference child is the durable link: its exported properties are packed
	# into the .tscn file and remain available after closing/reopening the scene.
	var definition_path := ObjectLibraryService.get_definition_path_for_definition(definition)
	var builder_uri := "objectbuilder://object/" + definition.object_id.uri_encode()
	scene_root.set_meta("object_definition_id", definition.object_id)
	scene_root.set_meta("object_builder_id", definition.object_id)
	scene_root.set_meta("object_builder_uri", builder_uri)
	scene_root.set_meta("object_builder_name", definition.display_name)
	scene_root.set_meta("object_category", definition.category)
	scene_root.set_meta("object_builder_resource_path", definition_path)
	scene_root.set_meta("object_builder_relations", definition.relations.duplicate(true))

	var reference_node: Node
	for child in scene_root.get_children():
		if child is Node and child.get_script() == ObjectBuilderReferenceScript:
			reference_node = child
			break
	if reference_node == null:
		reference_node = Node.new()
		reference_node.set_script(ObjectBuilderReferenceScript)
		scene_root.add_child(reference_node)
	reference_node.name = "Идентификатор объекта"
	reference_node.owner = scene_root
	if reference_node.has_method("configure"):
		reference_node.call(
			"configure",
			definition.object_id,
			definition.display_name,
			definition.category,
			definition_path
		)


static func create_scene(definition: ObjectDefinition) -> Dictionary:
	if definition == null:
		return _failure("Определение объекта не создано.")
	ObjectLibraryService.ensure_unique_display_name(definition)
	var created_object: Object = ClassDB.instantiate(definition.root_type)
	if not created_object is Node:
		return _failure("Не удалось создать корневой узел типа " + definition.root_type)

	var scene_root := created_object as Node
	apply_object_identity(scene_root, definition)

	var visuals := Node2D.new()
	visuals.name = "Визуальные элементы"
	scene_root.add_child(visuals)
	visuals.owner = scene_root

	var property_data := ObjectPropertyData.new()
	property_data.name = "Свойства объекта"
	scene_root.add_child(property_data)
	property_data.owner = scene_root
	property_data.configure(definition.custom_properties)
	_sync_managed_nodes(scene_root, definition)

	return _pack_and_save(scene_root, definition)


static func clone_template_scene(
	template_definition: ObjectDefinition,
	target_definition: ObjectDefinition
) -> Dictionary:
	if template_definition == null or target_definition == null:
		return _failure("Не удалось определить шаблон или целевой объект.")

	var source_scene: PackedScene = template_definition.scene
	if not template_definition.scene_path.is_empty() and FileAccess.file_exists(template_definition.scene_path):
		var loaded_scene := ResourceLoader.load(
			template_definition.scene_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		)
		if loaded_scene is PackedScene:
			source_scene = loaded_scene as PackedScene
	if source_scene == null:
		return _failure("У шаблона нет сохранённой сцены для копирования.")

	var scene_root := source_scene.instantiate()
	if scene_root == null:
		return _failure("Не удалось создать экземпляр сцены шаблона.")
	ObjectLibraryService.ensure_unique_display_name(target_definition)
	apply_object_identity(scene_root, target_definition)

	var property_data := _find_property_data(scene_root)
	if property_data == null:
		property_data = ObjectPropertyData.new()
		scene_root.add_child(property_data)
	property_data.name = "Свойства объекта"
	property_data.configure(target_definition.custom_properties, {}, true)
	property_data.owner = scene_root
	_sync_managed_nodes(scene_root, target_definition)

	return _pack_and_save(scene_root, target_definition)


static func import_scene(source_path: String, target_definition: ObjectDefinition) -> Dictionary:
	var clean_source_path := source_path.strip_edges()
	if clean_source_path.is_empty() or target_definition == null:
		return _failure("Не выбран файл сцены или не подготовлено определение объекта.")
	if clean_source_path.get_extension().to_lower() not in ["tscn", "scn"]:
		return _failure("Поддерживаются только сцены .tscn и .scn: " + clean_source_path)
	if not ResourceLoader.exists(clean_source_path):
		return _failure("Файл сцены не найден или недоступен Godot: " + clean_source_path)

	var loaded_resource := ResourceLoader.load(
		clean_source_path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	if loaded_resource == null:
		var failure_message := "Godot не смог загрузить сцену или один из её ресурсов: " + clean_source_path
		var missing_dependencies := _get_missing_dependency_paths(clean_source_path)
		if not missing_dependencies.is_empty():
			failure_message += "\nНе найдены ресурсы: " + ", ".join(missing_dependencies)
		return _failure(failure_message)
	if not loaded_resource is PackedScene:
		return _failure("Выбранный файл не является PackedScene: " + clean_source_path)

	var source_scene := loaded_resource as PackedScene
	var imported_root := source_scene.instantiate()
	if imported_root == null:
		return _failure("Не удалось создать временную копию сцены: " + clean_source_path)
	if not imported_root is Node2D:
		var unsupported_root_type := imported_root.get_class()
		imported_root.free()
		return _failure(
			"Для игрового 2D-объекта нужен корень Node2D или его наследник. "
			+ "В выбранной сцене корень %s: %s" % [unsupported_root_type, clean_source_path]
		)
	if imported_root.name.is_empty():
		imported_root.name = "Object"
	target_definition.root_type = imported_root.get_class()
	imported_root.set_meta("object_definition_id", target_definition.object_id)
	imported_root.set_meta("object_category", target_definition.category)

	var property_node := _find_property_node(imported_root)
	if property_node != null and not property_node is ObjectPropertyData:
		imported_root.free()
		return _failure(
			"В импортируемой сцене имя «Свойства объекта» уже занято другим типом узла: "
			+ clean_source_path
		)
	var property_data := property_node as ObjectPropertyData
	var is_new_property_data := property_data == null
	if is_new_property_data:
		property_data = ObjectPropertyData.new()
		imported_root.add_child(property_data)
	elif target_definition.custom_properties.is_empty():
		for existing_property in property_data.property_definitions:
			if existing_property != null:
				target_definition.custom_properties.append(
					existing_property.duplicate(true) as ObjectPropertyDefinition
				)
	property_data.name = "Свойства объекта"
	if is_new_property_data or not target_definition.custom_properties.is_empty():
		property_data.configure(target_definition.custom_properties, {}, true)
	property_data.owner = imported_root
	_sync_managed_nodes(imported_root, target_definition)

	var import_report := _build_import_report(imported_root)
	var save_result := _pack_and_save(imported_root, target_definition)
	if not bool(save_result.get("ok", false)):
		return save_result
	save_result["import_report"] = import_report
	return save_result


static func clone_object_scene(
	source_definition: ObjectDefinition,
	target_definition: ObjectDefinition
) -> Dictionary:
	if source_definition == null or target_definition == null:
		return _failure("Не выбран исходный или целевой объект.")
	var has_scene := source_definition.scene != null or (
		not source_definition.scene_path.is_empty()
		and ResourceLoader.exists(source_definition.scene_path)
	)
	if has_scene:
		return clone_template_scene(source_definition, target_definition)
	return create_scene(target_definition)

static func _pack_and_save(scene_root: Node, definition: ObjectDefinition) -> Dictionary:
	if scene_root == null or definition == null:
		if scene_root != null:
			scene_root.free()
		return _failure("Не удалось подготовить сцену для сохранения.")

	apply_object_identity(scene_root, definition)
	_set_owner_recursive(scene_root, scene_root)
	var packed_scene := PackedScene.new()
	packed_scene.resource_name = definition.display_name
	var pack_error := packed_scene.pack(scene_root)
	scene_root.free()
	if pack_error != OK:
		return _failure("Не удалось собрать PackedScene. Код ошибки: %d" % pack_error)

	var target_path := ObjectLibraryService.get_scene_path_for_definition(definition)
	if target_path.strip_edges().is_empty():
		return _failure("Не удалось определить путь сохранения сцены объекта.")
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_path.get_base_dir())
	)
	if directory_error != OK:
		return _failure(
			"Не удалось создать каталог сцены %s (код ошибки: %d)."
			% [target_path.get_base_dir(), directory_error]
		)
	if FileAccess.file_exists(target_path):
		var existing := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
		if existing == null:
			return _failure("Файл сцены с таким названием уже существует и не читается: " + target_path)
		var existing_id := ObjectLibraryService.get_packed_scene_object_id(existing)
		if existing_id != definition.object_id:
			return _failure("Файл сцены уже занят другим объектом: " + target_path)
	var save_error := ResourceSaver.save(packed_scene, target_path)
	if save_error != OK:
		return _failure(
			"Не удалось сохранить сцену %s (код ошибки: %d)."
			% [target_path, save_error]
		)

	definition.scene = packed_scene
	definition.scene_path = target_path
	return {
		"ok": true,
		"scene": packed_scene,
		"scene_path": target_path,
		"message": ""
	}


## Reconcile only Object Builder-owned presentation/collision nodes in an existing draft.
## User-authored scene children are left untouched.
static func sync_scene(definition: ObjectDefinition) -> Dictionary:
	if definition == null:
		return _failure("Определение объекта не создано.")
	ObjectLibraryService.ensure_unique_display_name(definition)
	if definition.scene_path.strip_edges().is_empty() or not ResourceLoader.exists(definition.scene_path):
		# A previous version may have stored the PackedScene directly in the
		# ObjectDefinition. Recover that scene before falling back to an empty
		# generated scene; never discard a recoverable user-authored hierarchy.
		if definition.scene != null:
			var recovered_root := definition.scene.instantiate()
			if recovered_root == null:
				return _failure("В ObjectDefinition есть PackedScene, но создать её экземпляр не удалось.")
			var recovered_property_node := _find_property_node(recovered_root)
			if recovered_property_node != null and not recovered_property_node is ObjectPropertyData:
				recovered_root.free()
				return _failure("В восстановленной сцене имя «Свойства объекта» занято узлом другого типа.")
			var recovered_property_data := recovered_property_node as ObjectPropertyData
			if recovered_property_data == null:
				recovered_property_data = ObjectPropertyData.new()
				recovered_root.add_child(recovered_property_data)
			recovered_property_data.name = "Свойства объекта"
			recovered_property_data.configure(definition.custom_properties, {}, true)
			recovered_property_data.owner = recovered_root
			_sync_managed_nodes(recovered_root, definition)
			return _pack_and_save(recovered_root, definition)
		return create_scene(definition)
	var loaded := ResourceLoader.load(
		definition.scene_path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	) as PackedScene
	if loaded == null:
		return _failure("Не удалось открыть сохранённую сцену объекта: " + definition.scene_path)
	var scene_root := loaded.instantiate()
	if scene_root == null:
		return _failure("Не удалось создать временный экземпляр сохранённой сцены.")
	var property_node := _find_property_node(scene_root)
	if property_node != null and not property_node is ObjectPropertyData:
		scene_root.free()
		return _failure("Имя «Свойства объекта» занято узлом другого типа. Сцена не изменена.")
	var property_data := property_node as ObjectPropertyData
	if property_data == null:
		property_data = ObjectPropertyData.new()
		scene_root.add_child(property_data)
	property_data.name = "Свойства объекта"
	property_data.configure(definition.custom_properties, {}, true)
	property_data.owner = scene_root
	_sync_managed_nodes(scene_root, definition)
	return _pack_and_replace(scene_root, definition)


static func _sync_managed_nodes(scene_root: Node, definition: ObjectDefinition) -> void:
	if scene_root == null or definition == null:
		return
	apply_object_identity(scene_root, definition)
	var visuals := _find_managed_node(scene_root, "object_builder_visuals") as Node2D
	if visuals == null:
		# Adopt containers created by earlier Object Builder versions.
		visuals = scene_root.get_node_or_null("Визуальные элементы") as Node2D
		if visuals == null:
			visuals = scene_root.get_node_or_null("ObjectBuilderVisuals") as Node2D
		if visuals == null:
			visuals = scene_root.get_node_or_null("Visuals") as Node2D
		if visuals == null:
			visuals = Node2D.new()
			scene_root.add_child(visuals)
	visuals.name = "Визуальные элементы"
	visuals.set_meta("object_builder_visuals", true)
	visuals.owner = scene_root
	var sprite := _find_managed_node(scene_root, "object_builder_sprite") as Sprite2D
	if sprite == null:
		# The legacy generated sprite had no ownership metadata; adopt only its reserved path.
		sprite = visuals.get_node_or_null("Основной спрайт") as Sprite2D
		if sprite == null:
			sprite = visuals.get_node_or_null("ObjectSprite") as Sprite2D
		if sprite == null:
			sprite = Sprite2D.new()
			visuals.add_child(sprite)
	sprite.name = "Основной спрайт"
	sprite.set_meta("object_builder_sprite", true)
	sprite.owner = scene_root
	sprite.texture = definition.preview_texture
	sprite.visible = definition.preview_texture != null
	sprite.centered = true
	sprite.position = definition.preview_sprite_offset
	sprite.scale = definition.preview_sprite_scale
	sprite.rotation_degrees = definition.preview_sprite_rotation_degrees
	sprite.z_index = definition.preview_sprite_z_index
	scene_root.set_meta("object_builder_size", definition.object_size)
	_sync_world_sort_controller(scene_root)
	visuals.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Additional sprite layers are managed children of the visual container.
	# Reconcile only nodes marked by this service; hand-authored scene nodes survive.
	var desired_layer_ids: Dictionary = {}
	for layer_index in range(definition.sprite_layers.size()):
		var layer_data: Dictionary = definition.sprite_layers[layer_index]
		var layer_id := str(layer_data.get("id", "sprite_%d" % layer_index)).strip_edges()
		if layer_id.is_empty():
			layer_id = "sprite_%d" % layer_index
		desired_layer_ids[layer_id] = true
		var layer_node: Sprite2D
		for candidate in visuals.find_children("*", "Sprite2D", true, false):
			if candidate.owner != scene_root:
				continue
			if str(candidate.get_meta("object_builder_sprite_layer_id", "")) == layer_id:
				layer_node = candidate as Sprite2D
				break
		if layer_node == null:
			layer_node = Sprite2D.new()
			layer_node.name = ("Спрайт — " + str(layer_data.get("name", "Дополнительный спрайт"))).validate_node_name()
			layer_node.set_meta("object_builder_sprite_layer", true)
			layer_node.set_meta("object_builder_sprite_layer_id", layer_id)
			visuals.add_child(layer_node)
		layer_node.name = ("Спрайт — " + str(layer_data.get("name", "Дополнительный спрайт"))).validate_node_name()
		layer_node.owner = scene_root
		layer_node.texture = layer_data.get("texture") as Texture2D
		layer_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var position_value: Variant = layer_data.get("position", Vector2.ZERO)
		var scale_value: Variant = layer_data.get("scale", Vector2.ONE)
		layer_node.position = position_value if position_value is Vector2 else Vector2.ZERO
		layer_node.scale = scale_value if scale_value is Vector2 else Vector2.ONE
		layer_node.rotation_degrees = float(layer_data.get("rotation", 0.0))
		layer_node.z_index = clampi(int(layer_data.get("z_index", 0)), -4096, 4096)
		var embedded_relation_id := str(layer_data.get("embedded_relation_id", ""))
		if not embedded_relation_id.is_empty():
			layer_node.set_meta("object_builder_embedded_remains", true)
			layer_node.set_meta("object_builder_embedded_remains_relation_id", embedded_relation_id)
			layer_node.set_meta("object_builder_embedded_remains_object_id", str(layer_data.get("embedded_object_id", "")))
		else:
			layer_node.remove_meta("object_builder_embedded_remains")
			layer_node.remove_meta("object_builder_embedded_remains_relation_id")
			layer_node.remove_meta("object_builder_embedded_remains_object_id")
		# Editor visibility is separate from runtime visibility for embedded remains.
		layer_node.visible = (
			bool(layer_data.get("visible", true))
			and bool(layer_data.get("runtime_visible", true))
			and layer_node.texture != null
		)
		layer_node.centered = true

	for candidate in visuals.find_children("*", "Sprite2D", true, false):
		if candidate.owner != scene_root:
			continue
		if not bool(candidate.get_meta("object_builder_sprite_layer", false)):
			continue
		var old_layer_id := str(candidate.get_meta("object_builder_sprite_layer_id", ""))
		if not desired_layer_ids.has(old_layer_id):
			candidate.free()

	# AnimatedSprite2D is generated from the configured rows of the optional sheet.
	var animated_sprite := _find_managed_node(scene_root, "object_builder_animated_sprite") as AnimatedSprite2D
	var has_animation_data := (
		definition.sprite_sheet_texture != null
		and not definition.sprite_animations.is_empty()
	)
	if has_animation_data:
		if animated_sprite == null:
			animated_sprite = AnimatedSprite2D.new()
			animated_sprite.name = "Анимация спрайта"
			animated_sprite.set_meta("object_builder_animated_sprite", true)
			visuals.add_child(animated_sprite)
		animated_sprite.owner = scene_root
		var sprite_frames := SpriteFrames.new()
		sprite_frames.clear_all()
		var first_animation := ""
		for animation_data in definition.sprite_animations:
			var animation_name := str(animation_data.get("name", "idle")).strip_edges()
			if animation_name.is_empty():
				continue
			if sprite_frames.has_animation(animation_name) and animation_name != "default":
				continue
			if not sprite_frames.has_animation(animation_name):
				sprite_frames.add_animation(animation_name)
			var rows := clampi(int(animation_data.get("rows", 1)), 1, 256)
			var columns := clampi(int(animation_data.get("columns", 1)), 1, 256)
			var row := clampi(int(animation_data.get("row", 0)), 0, rows - 1)
			var start_column := clampi(int(animation_data.get("start_column", 0)), 0, columns - 1)
			var frame_count := clampi(
				int(animation_data.get("frame_count", columns - start_column)),
				1,
				columns - start_column
			)
			var margin_x := clampi(int(animation_data.get("margin_x", 0)), 0, definition.sprite_sheet_texture.get_width() / 2)
			var margin_y := clampi(int(animation_data.get("margin_y", 0)), 0, definition.sprite_sheet_texture.get_height() / 2)
			var separation_x := clampi(int(animation_data.get("separation_x", 0)), 0, definition.sprite_sheet_texture.get_width())
			var separation_y := clampi(int(animation_data.get("separation_y", 0)), 0, definition.sprite_sheet_texture.get_height())
			var available_width := definition.sprite_sheet_texture.get_width() - margin_x * 2 - separation_x * (columns - 1)
			var available_height := definition.sprite_sheet_texture.get_height() - margin_y * 2 - separation_y * (rows - 1)
			if available_width <= 0 or available_height <= 0:
				continue
			var frame_size := Vector2(
				float(available_width) / float(columns),
				float(available_height) / float(rows)
			)
			if frame_size.x < 1.0 or frame_size.y < 1.0:
				continue
			sprite_frames.set_animation_speed(animation_name, clampf(float(animation_data.get("fps", 8.0)), 0.1, 60.0))
			var loop_mode := SpriteFrames.LOOP_LINEAR if bool(animation_data.get("loop", true)) else SpriteFrames.LOOP_NONE
			sprite_frames.set_animation_loop_mode(animation_name, loop_mode)
			for frame_index in range(frame_count):
				var atlas_texture := AtlasTexture.new()
				atlas_texture.atlas = definition.sprite_sheet_texture
				atlas_texture.region = Rect2(
					Vector2(
						float(margin_x) + float(start_column + frame_index) * (frame_size.x + float(separation_x)),
						float(margin_y) + float(row) * (frame_size.y + float(separation_y))
					),
					frame_size
				)
				sprite_frames.add_frame(animation_name, atlas_texture)
			if sprite_frames.get_frame_count(animation_name) > 0 and first_animation.is_empty():
				first_animation = animation_name
		if not first_animation.is_empty():
			animated_sprite.sprite_frames = sprite_frames
			animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			animated_sprite.animation = first_animation
			animated_sprite.position = definition.preview_sprite_offset
			animated_sprite.scale = definition.preview_sprite_scale
			animated_sprite.z_index = definition.preview_sprite_z_index
			animated_sprite.visible = true
			animated_sprite.play()
			sprite.visible = false
		else:
			animated_sprite.free()
			sprite.visible = definition.preview_texture != null
	else:
		if animated_sprite != null:
			animated_sprite.free()
		sprite.visible = definition.preview_texture != null

	# Reconcile only Builder-owned nodes. A single unmarked CollisionShape2D
	# is adopted as the visual/collision editor's profile; ambiguous user physics
	# setups are left untouched.
	var previous_host := _find_managed_node(scene_root, "object_builder_collision_host")
	if previous_host == null:
		# Earlier integration builds used this legacy metadata key.
		previous_host = _find_managed_node(scene_root, "object_builder_managed_collision")
	var previous_shape := _find_managed_node(scene_root, "object_builder_collision_shape")
	if previous_shape == null:
		var unmarked_shapes: Array[CollisionShape2D] = []
		for candidate in scene_root.find_children("*", "CollisionShape2D", true, false):
			if candidate is not CollisionShape2D or candidate.owner != scene_root:
				continue
			var candidate_shape := candidate as CollisionShape2D
			var candidate_resource := candidate_shape.shape
			if (
				not bool(candidate_shape.get_meta("object_builder_collision_shape", false))
				and candidate_shape.get_parent() is CollisionObject2D
				and (
					candidate_resource is RectangleShape2D
					or candidate_resource is CircleShape2D
					or candidate_resource is CapsuleShape2D
				)
			):
				unmarked_shapes.append(candidate_shape)
		if unmarked_shapes.size() == 1:
			previous_shape = unmarked_shapes[0]

	var previous_collision_host: CollisionObject2D
	if previous_shape != null:
		previous_collision_host = previous_shape.get_parent() as CollisionObject2D
		previous_shape.free()
	if previous_host != null and previous_host != previous_collision_host:
		previous_host.free()

	# Schema 10 used a generic 1/1 profile, but the player scans obstacle layer 2.
	# Upgrade before the enabled check so saving an object with collision disabled
	# cannot mark the old profile as migrated prematurely.
	if definition.schema_version < 11 and definition.collision_layer == 1 and definition.collision_mask == 1:
		definition.collision_layer = 2
	if not definition.collision_enabled:
		if (
			previous_host != null
			and previous_host == previous_collision_host
			and previous_host != scene_root
			and is_instance_valid(previous_host)
		):
			previous_host.free()
		return

	var collision_host: CollisionObject2D
	var previous_host_matches_mode := (
		previous_collision_host != null
		and is_instance_valid(previous_collision_host)
		and (
			(definition.collision_mode == "area" and previous_collision_host is Area2D)
			or (definition.collision_mode == "solid" and previous_collision_host is PhysicsBody2D)
		)
	)
	if previous_host_matches_mode:
		collision_host = previous_collision_host
	elif definition.collision_mode == "area" and scene_root is Area2D:
		collision_host = scene_root as Area2D
	elif definition.collision_mode == "solid" and scene_root is PhysicsBody2D:
		collision_host = scene_root as PhysicsBody2D
	else:
		if (
			previous_host != null
			and previous_host == previous_collision_host
			and previous_host != scene_root
			and is_instance_valid(previous_host)
		):
			previous_host.free()
		if definition.collision_mode == "area":
			collision_host = Area2D.new()
		else:
			collision_host = StaticBody2D.new()
		collision_host.name = "Коллизия"
		collision_host.set_meta("object_builder_collision_host", true)
		scene_root.add_child(collision_host)
		collision_host.owner = scene_root

	collision_host.collision_layer = maxi(0, definition.collision_layer)
	collision_host.collision_mask = maxi(0, definition.collision_mask)
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "Форма коллизии"
	collision_shape.set_meta("object_builder_collision_shape", true)
	# ObjectDefinition stores the shape offset in object-root coordinates.
	# Convert it back to the collision host's local coordinates so a host moved
	# or rotated in Godot is not counted twice on the next Web Builder save.
	var host_transform := _node_2d_transform_relative_to_root(
		collision_host,
		scene_root
	)
	collision_shape.position = host_transform.affine_inverse() * definition.collision_offset
	var shape: Shape2D
	match definition.collision_shape:
		"circle":
			var circle := CircleShape2D.new()
			circle.radius = clampf(definition.collision_radius, 1.0, 8192.0)
			shape = circle
		"capsule":
			var capsule := CapsuleShape2D.new()
			capsule.radius = clampf(definition.collision_radius, 1.0, 4096.0)
			capsule.height = maxf(
				capsule.radius * 2.0,
				clampf(definition.collision_height, capsule.radius * 2.0, 8192.0)
			)
			shape = capsule
		_:
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(
				clampf(definition.collision_size.x, 1.0, 8192.0),
				clampf(definition.collision_size.y, 1.0, 8192.0)
			)
			shape = rectangle
	collision_shape.shape = shape
	collision_shape.z_index = 1
	collision_shape.set_meta("object_builder_collision_z_index", 1)
	collision_host.add_child(collision_shape)
	collision_shape.owner = scene_root


static func _node_2d_transform_relative_to_root(
	node: Node2D,
	scene_root: Node
) -> Transform2D:
	if node == null:
		return Transform2D.IDENTITY
	var chain: Array[Node2D] = []
	var current: Node = node
	while current != null and current != scene_root:
		if current is Node2D:
			chain.push_front(current as Node2D)
		current = current.get_parent()
	if current != scene_root:
		return node.transform
	var relative_transform := Transform2D.IDENTITY
	for transform_node in chain:
		relative_transform = relative_transform * transform_node.transform
	return relative_transform


static func _sync_world_sort_controller(scene_root: Node) -> void:
	if scene_root == null or not (scene_root is Node2D):
		return
	var controller := _find_managed_node(scene_root, "object_builder_world_sort_controller")
	if controller == null:
		controller = Node.new()
		controller.name = "Автосортировка по Y"
		controller.set_script(ObjectWorldSortScript)
		controller.set_meta("object_builder_world_sort_controller", true)
		scene_root.add_child(controller)
	controller.owner = scene_root
	if controller.has_method("update_sort_order"):
		controller.call("update_sort_order")


static func _find_property_node(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var property_data := _find_property_data(scene_root)
	if property_data != null:
		return property_data
	var localized := scene_root.find_child("Свойства объекта", true, false)
	if localized != null:
		return localized
	return scene_root.find_child("ObjectProperties", true, false)


static func _find_property_data(scene_root: Node) -> ObjectPropertyData:
	if scene_root == null:
		return null
	if scene_root is ObjectPropertyData:
		return scene_root as ObjectPropertyData
	for child in scene_root.get_children():
		if child is Node:
			var found := _find_property_data(child as Node)
			if found != null:
				return found
	return null


static func _find_managed_node(scene_root: Node, metadata_key: String) -> Node:
	if scene_root == null:
		return null
	for candidate in scene_root.find_children("*", "", true, false):
		if candidate.owner != scene_root:
			continue
		if candidate.has_meta(metadata_key) and bool(candidate.get_meta(metadata_key)):
			return candidate
	return null


static func _pack_and_replace(scene_root: Node, definition: ObjectDefinition) -> Dictionary:
	if scene_root == null or definition == null:
		if scene_root != null:
			scene_root.free()
		return _failure("Не удалось подготовить сцену для обновления.")
	apply_object_identity(scene_root, definition)
	_set_owner_recursive(scene_root, scene_root)
	var packed_scene := PackedScene.new()
	packed_scene.resource_name = definition.display_name
	var pack_error := packed_scene.pack(scene_root)
	scene_root.free()
	if pack_error != OK:
		return _failure("Не удалось собрать обновлённую сцену. Код ошибки: %d" % pack_error)
	var previous_path := definition.scene_path
	var target_path := ObjectLibraryService.get_scene_path_for_definition(definition)
	if target_path.strip_edges().is_empty():
		return _failure("Не удалось определить путь обновления сцены объекта.")
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_path.get_base_dir())
	)
	if directory_error != OK:
		return _failure(
			"Не удалось создать каталог сцены %s (код ошибки: %d)."
			% [target_path.get_base_dir(), directory_error]
		)
	if FileAccess.file_exists(target_path) and target_path != previous_path:
		var existing := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
		if existing == null:
			return _failure("Целевой файл сцены занят и не читается: " + target_path)
		var existing_id := ObjectLibraryService.get_packed_scene_object_id(existing)
		if existing_id != definition.object_id:
			return _failure("Целевой файл сцены уже принадлежит другому объекту: " + target_path)

	var absolute_target := ProjectSettings.globalize_path(target_path)
	var backup_path := OS.get_cache_dir().path_join(
		"object_builder_%s_%d.tscn" % [definition.object_id, Time.get_ticks_usec()]
	)
	var had_previous_scene := FileAccess.file_exists(target_path)
	if had_previous_scene:
		var backup_error := DirAccess.copy_absolute(absolute_target, backup_path)
		if backup_error != OK:
			return _failure("Не удалось создать резервную копию сцены. Исходник не изменён (код %d)." % backup_error)

	var save_error := ResourceSaver.save(packed_scene, target_path)
	if save_error != OK:
		if had_previous_scene:
			var restore_error := DirAccess.copy_absolute(backup_path, absolute_target)
			DirAccess.remove_absolute(backup_path)
			if restore_error != OK:
				return _failure(
					"Не удалось обновить сцену (код %d), и резервная копия не восстановилась (код %d): %s"
					% [save_error, restore_error, backup_path]
				)
		elif FileAccess.file_exists(target_path):
			DirAccess.remove_absolute(absolute_target)
		return _failure(
			"Не удалось обновить сцену %s. Предыдущая версия восстановлена. Код ошибки: %d."
			% [target_path, save_error]
		)

	if had_previous_scene and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	definition.scene = packed_scene
	definition.scene_path = target_path
	if not previous_path.is_empty() and previous_path != target_path:
		ObjectLibraryService.remove_scene_if_unreferenced(previous_path, definition.object_id)
	return {"ok": true, "scene": packed_scene, "scene_path": target_path, "message": ""}


static func _build_import_report(scene_root: Node) -> Dictionary:
	var visual_parts: Array[String] = []
	var advanced_nodes: Array[String] = []
	var total_nodes := _collect_import_report(scene_root, "", visual_parts, advanced_nodes)
	return {
		"visual_part_count": visual_parts.size(),
		"visual_part_paths": visual_parts,
		"advanced_node_count": advanced_nodes.size(),
		"advanced_node_paths": advanced_nodes,
		"total_node_count": total_nodes
	}


static func _collect_import_report(
	parent: Node,
	parent_path: String,
	visual_parts: Array[String],
	advanced_nodes: Array[String]
) -> int:
	var total_nodes := 0
	for child in parent.get_children():
		var child_path := child.name if parent_path.is_empty() else parent_path.path_join(child.name)
		total_nodes += 1
		if child is Sprite2D or child is AnimatedSprite2D or child is Polygon2D or child is Line2D:
			visual_parts.append(child_path + " (" + child.get_class() + ")")
		else:
			advanced_nodes.append(child_path + " (" + child.get_class() + ")")
		total_nodes += _collect_import_report(child, child_path, visual_parts, advanced_nodes)
	return total_nodes

static func _get_missing_dependency_paths(scene_path: String) -> PackedStringArray:
	var missing := PackedStringArray()
	for dependency in ResourceLoader.get_dependencies(scene_path):
		var dependency_path := str(dependency).get_slice("::", 0)
		if dependency_path.is_empty() or ResourceLoader.exists(dependency_path):
			continue
		if not missing.has(dependency_path):
			missing.append(dependency_path)
	return missing

static func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"scene": null,
		"scene_path": "",
		"message": message
	}
