extends SceneTree

const SceneDraftService = preload("res://addons/web_object_builder/services/scene_draft_service.gd")
const DefinitionScript = preload("res://scripts/object_system/object_definition.gd")
const WorldSortScript = preload("res://scripts/object_system/object_world_sort.gd")
const DestructibleComponentScript = preload("res://scripts/object_system/components/destructible_component.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Collision/sorting/rendering test: create definition")
	var definition := DefinitionScript.new() as ObjectDefinition
	definition.object_id = "test_collision_sort_rendering"
	definition.display_name = "Collision Sort Test"
	definition.schema_version = 10
	definition.object_size = Vector2(40.0, 60.0)
	definition.collision_enabled = true
	definition.collision_mode = "solid"
	definition.collision_shape = "rectangle"
	definition.collision_size = Vector2(28.0, 18.0)
	# Schema 10 defaulted to layer/mask 1/1. The player uses mask 2.
	definition.collision_layer = 1
	definition.collision_mask = 1

	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	definition.preview_texture = texture
	definition.sprite_layers.append({
		"id": "front_decoration",
		"name": "Front decoration",
		"texture": texture,
		"position": Vector2.ZERO,
		"scale": Vector2.ONE,
		"rotation": 0.0,
		"z_index": 7,
		"visible": true
	})
	definition.sprite_layers.append({
		"id": "embedded_stump",
		"name": "Tree — Stump",
		"texture": texture,
		"position": Vector2(2.0, 4.0),
		"scale": Vector2.ONE,
		"rotation": 0.0,
		"z_index": 8,
		"visible": true,
		"runtime_visible": false,
		"embedded_relation_id": "relation_stump",
		"embedded_object_id": "test_stump",
		"embedded_source_name": "Stump"
	})

	print("Collision/sorting/rendering test: create scene nodes")
	var root := Node2D.new()
	root.position = Vector2(3.0, 20.0)
	print("Collision/sorting/rendering test: synchronize managed nodes")
	SceneDraftService._sync_managed_nodes(root, definition)
	print("Collision/sorting/rendering test: managed nodes synchronized")

	var collision_host := root.get_node_or_null("Коллизия") as StaticBody2D
	_expect(collision_host != null, "solid collision host is created for a Node2D object")
	if collision_host != null:
		_expect(collision_host.collision_layer == 2, "legacy 1/1 collision defaults migrate to obstacle layer 2")
		_expect(collision_host.collision_mask == 1, "solid object collision mask includes the player layer")
		var collision_shape := collision_host.get_node_or_null("Форма коллизии") as CollisionShape2D
		_expect(collision_shape != null, "collision host has a CollisionShape2D")
		_expect(
			collision_shape != null and collision_shape.shape is RectangleShape2D,
			"configured rectangle collision shape is created"
		)
		_expect(
			collision_shape != null and collision_shape.z_index == 1,
			"managed collision shape is drawn at Z-index 1 above object sprites"
		)

	var visuals := root.get_node_or_null("Визуальные элементы") as Node2D
	_expect(visuals != null, "managed visual container is created")
	if visuals != null:
		_expect(
			visuals.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"visual container explicitly uses nearest texture filtering"
		)
		var main_sprite := visuals.get_node_or_null("Основной спрайт") as Sprite2D
		_expect(main_sprite != null, "primary sprite is created")
		_expect(
			main_sprite != null and main_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"primary sprite explicitly uses nearest texture filtering"
		)
		var additional_sprite: Sprite2D
		for candidate in visuals.find_children("*", "Sprite2D", true, false):
			if str(candidate.get_meta("object_builder_sprite_layer_id", "")) == "front_decoration":
				additional_sprite = candidate as Sprite2D
				break
		_expect(additional_sprite != null, "configured additional sprite layer is created")
		if additional_sprite != null:
			_expect(additional_sprite.z_index == 7, "additional sprite layer preserves its Z-index")
			_expect(
				additional_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
				"additional sprite layer explicitly uses nearest texture filtering"
			)
		var embedded_stump: Sprite2D
		for candidate in visuals.find_children("*", "Sprite2D", true, false):
			if str(candidate.get_meta("object_builder_sprite_layer_id", "")) == "embedded_stump":
				embedded_stump = candidate as Sprite2D
				break
		_expect(embedded_stump != null, "embedded remain is generated as an editable Sprite2D layer")
		if embedded_stump != null:
			_expect(not embedded_stump.visible, "embedded remain starts hidden in the generated game scene")
			_expect(
				bool(embedded_stump.get_meta("object_builder_embedded_remains", false)),
				"embedded remain keeps its destruction marker"
			)

		root.set_meta("object_definition_id", definition.object_id)
		# The remains relation is owned by the destruction mechanic; it must
		# work without requiring the separate legacy leaves_remains component.
		var destructible_component := DestructibleComponentScript.new() as ObjectComponent
		destructible_component.component_id = "destructible"
		destructible_component.configure_context(root, "test-destructible", NodePath("."))
		destructible_component.configure({})
		root.add_child(destructible_component)
		_expect(
			bool(destructible_component.call("destroy")),
			"destruction event activates an embedded remain layer"
		)
		if embedded_stump != null and main_sprite != null:
			_expect(embedded_stump.visible, "embedded remain becomes visible when the object is destroyed")
			_expect(not main_sprite.visible, "the original managed tree sprite is hidden when remains appear")
		_expect(root.visible, "parent object remains alive and visible so its stump can render")
		_expect(
			bool(destructible_component.call("repair")),
			"repair restores the original object after embedded remains were shown"
		)
		if embedded_stump != null and main_sprite != null:
			_expect(not embedded_stump.visible, "repair hides the embedded remain again")
			_expect(main_sprite.visible, "repair restores the original object sprite")

	var sort_controller := root.get_node_or_null("Автосортировка по Y")
	_expect(sort_controller != null, "automatic world Y-sort controller is attached to the object")
	if sort_controller != null:
		_expect(
			sort_controller.get_script() == WorldSortScript,
			"automatic sorting controller uses the shared project sorting script"
		)
		if sort_controller.has_method("update_sort_order"):
			sort_controller.call("update_sort_order")
		_expect(root.z_as_relative == false, "world object uses absolute Z sorting like the player")
		_expect(root.z_index == 2099, "world object is sorted by its bottom/foot Y coordinate")
		root.position.y = 100.0
		sort_controller.call("update_sort_order")
		_expect(root.z_index == 2179, "world object Z order updates when its Y position changes")

	var global_filter := int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter", -1
	))
	_expect(global_filter == 0, "project-wide CanvasItem texture filter defaults to nearest")
	_expect(str(ProjectSettings.get_setting("layer_names/2d_physics/layer_1", "")) == "Игрок", "physics layer 1 is named Player in project settings")
	_expect(str(ProjectSettings.get_setting("layer_names/2d_physics/layer_2", "")) == "Препятствия", "physics layer 2 is named Obstacles in project settings")

	print("Collision/sorting/rendering test: cleanup")
	root.free()

	var disabled_legacy := DefinitionScript.new() as ObjectDefinition
	disabled_legacy.object_id = "test_legacy_disabled_collision"
	disabled_legacy.display_name = "Legacy Disabled Collision"
	disabled_legacy.schema_version = 10
	disabled_legacy.collision_enabled = false
	disabled_legacy.collision_layer = 1
	disabled_legacy.collision_mask = 1
	var disabled_root := Node2D.new()
	SceneDraftService._sync_managed_nodes(disabled_root, disabled_legacy)
	_expect(disabled_legacy.collision_layer == 2, "disabled schema 10 collision profile is migrated before schema upgrade")
	_expect(disabled_root.get_node_or_null("Коллизия") == null, "disabled legacy collision does not create a physics body")
	disabled_legacy.collision_enabled = true
	SceneDraftService._sync_managed_nodes(disabled_root, disabled_legacy)
	var migrated_host := disabled_root.get_node_or_null("Коллизия") as StaticBody2D
	_expect(migrated_host != null and migrated_host.collision_layer == 2, "enabling migrated legacy collision uses obstacle layer 2")
	disabled_root.free()

	if failures.is_empty():
		print("Web Object Builder collision, sorting and rendering smoke tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("WEB_OBJECT_BUILDER_COLLISION_TESTS: " + failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
