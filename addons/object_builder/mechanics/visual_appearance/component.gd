@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"texture_path": ""})


func apply_to(sprite: Sprite2D, path_override: String = "") -> bool:
    if not is_instance_valid(sprite):
        return fail("Не передан действительный Sprite2D.")
    var path := path_override.strip_edges()
    if path.is_empty():
        path = str(get_option("texture_path", "")).strip_edges()
    if path.is_empty() or not ResourceLoader.exists(path):
        return fail("Файл текстуры не найден: %s" % path)
    var texture := load(path) as Texture2D
    if texture == null:
        return fail("Ресурс не является Texture2D: %s" % path)
    sprite.texture = texture
    action_completed.emit(sprite)
    return true
