@tool
extends "res://addons/web_object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"palette_json": "{}"})


func apply_to(sprite: Sprite2D) -> bool:
    if not is_instance_valid(sprite) or sprite.texture == null:
        return fail("Для смены палитры нужен Sprite2D с текстурой.")
    var parsed: Variant = JSON.parse_string(str(get_option("palette_json", "{}")))
    if not parsed is Dictionary:
        return fail("Палитра должна быть JSON-словарём вида {\"#старый\":\"#новый\"}.")
    if parsed.is_empty():
        return fail("Палитра не содержит замен цветов.")
    var image := sprite.texture.get_image()
    if image == null or image.is_empty():
        return fail("Не удалось получить пиксели исходной текстуры.")
    var replacements: Dictionary = {}
    for source_hex in parsed:
        var source_text := str(source_hex)
        var target_text := str(parsed[source_hex])
        if not source_text.is_valid_html_color() or not target_text.is_valid_html_color():
            return fail("В палитре обнаружен неверный HTML-цвет.")
        replacements[source_text.trim_prefix("#").to_lower()] = target_text
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var old_color := image.get_pixel(x, y)
            var key := old_color.to_html(false).to_lower()
            if replacements.has(key):
                var new_color := Color.from_string(replacements[key], old_color)
                new_color.a = old_color.a
                image.set_pixel(x, y, new_color)
    sprite.texture = ImageTexture.create_from_image(image)
    action_completed.emit(sprite)
    return true
