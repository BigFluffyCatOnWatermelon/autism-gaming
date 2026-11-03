@tool
extends EditorPlugin

const PLACEABLE_SCRIPT: Script = preload("res://scripts/placeable_art.gd")
const MENU_ITEM := "Cozy Village & Farm: обновить сцены объектов"
const ASSET_ROOTS := [
	{
		"source": "res://Assets/CozyVillageFarm/02_Nature",
		"destination": "res://scenes/environment/Nature",
	},
	{
		"source": "res://Assets/CozyVillageFarm/03_Buildings",
		"destination": "res://scenes/environment/Buildings",
	},
	{
		"source": "res://Assets/CozyVillageFarm/04_Props",
		"destination": "res://scenes/environment/Props",
	},
	{
		"source": "res://Assets/CozyVillageFarm/05_Interiors/Furniture",
		"destination": "res://scenes/environment/Interiors/Furniture",
	},
]

var _generation_done := false
var _generated_count := 0

func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, _refresh_placeable_scenes)
	var filesystem := EditorInterface.get_resource_filesystem()
	if not filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		filesystem.filesystem_changed.connect(_on_filesystem_changed)
	call_deferred("_generate_placeable_scenes")

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		filesystem.filesystem_changed.disconnect(_on_filesystem_changed)

func _on_filesystem_changed() -> void:
	if not _generation_done:
		call_deferred("_generate_placeable_scenes")

func _refresh_placeable_scenes() -> void:
	_generation_done = false
	_generate_placeable_scenes()

func _generate_placeable_scenes() -> void:
	if _generation_done:
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	# The initial project scan must finish before imported textures are loaded.
	# filesystem_changed will call this method again after that scan.
	if filesystem.is_scanning():
		return

	_generation_done = true
	_generated_count = 0
	for mapping in ASSET_ROOTS:
		_scan_assets(str(mapping.source), str(mapping.destination))
	if _generated_count > 0:
		filesystem.scan()
	print("Cozy Village & Farm: создано сцен объектов: ", _generated_count)

func _scan_assets(source_path: String, destination_path: String) -> void:
	var directory := DirAccess.open(source_path)
	if directory == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_path))
	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var child_source := source_path.path_join(entry)
		var child_destination := destination_path.path_join(entry)
		if directory.current_is_dir():
			_scan_assets(child_source, child_destination)
		elif entry.get_extension().to_lower() == "png" and _is_static_placeable(entry):
			_create_placeable_scene(child_source, child_destination)
	directory.list_dir_end()

func _is_static_placeable(file_name: String) -> bool:
	var lower := file_name.to_lower()
	if lower.begins_with("_"):
		return false
	if "_anim_" in lower or lower.ends_with("_2f.png"):
		return false
	if "_sheet" in lower or "_stages_" in lower or "_all_" in lower:
		return false
	if "autotile" in lower:
		return false
	return true

func _create_placeable_scene(texture_path: String, output_directory: String) -> void:
	var output_path := output_directory.path_join(texture_path.get_file().get_basename() + ".tscn")
	if FileAccess.file_exists(output_path):
		return

	var texture := ResourceLoader.load(texture_path) as Texture2D
	if texture == null:
		push_warning("Не удалось загрузить спрайт: " + texture_path)
		return

	var sprite := Sprite2D.new()
	sprite.name = texture_path.get_file().get_basename().replace(" ", "_")
	sprite.texture = texture
	sprite.set_script(PLACEABLE_SCRIPT)
	sprite.centered = true
	var packed := PackedScene.new()
	var pack_error := packed.pack(sprite)
	if pack_error != OK:
		push_warning("Не удалось собрать сцену: " + texture_path)
		sprite.free()
		return

	var save_error := ResourceSaver.save(packed, output_path)
	sprite.free()
	if save_error == OK:
		_generated_count += 1
	else:
		push_warning("Не удалось сохранить сцену: " + output_path)
