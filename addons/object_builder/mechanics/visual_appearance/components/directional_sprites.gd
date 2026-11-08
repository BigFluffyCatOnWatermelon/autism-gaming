@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"directions_json": "{}", "initial_direction": "down"})


func _apply_bound_target() -> bool:
    var sprite := find_sprite()
    if sprite == null:
        return fail("Для направленных спрайтов нужен Sprite2D в целевой ветке.")
    var directions: Variant = JSON.parse_string(str(get_option("directions_json", "{}")))
    if not directions is Dictionary or directions.is_empty():
        return true
    return set_direction(sprite, str(get_option("initial_direction", "down")))


func set_direction(sprite: Sprite2D, direction: String) -> bool:
    if not is_instance_valid(sprite):
        return fail("Не передан действительный Sprite2D.")
    var parsed: Variant = JSON.parse_string(str(get_option("directions_json", "{}")))
    if not parsed is Dictionary:
        return fail("Карта направлений содержит некорректный JSON.")
    var key := direction.strip_edges().to_lower()
    if not parsed.has(key):
        return fail("Для направления '%s' не задан спрайт." % key)
    var path := str(parsed[key]).strip_edges()
    if path.is_empty() or not ResourceLoader.exists(path):
        return fail("Текстура направления не найдена: %s" % path)
    var texture := load(path) as Texture2D
    if texture == null:
        return fail("Ресурс направления не является Texture2D.")
    sprite.texture = texture
    set_option("initial_direction", key)
    action_completed.emit(key)
    return true
