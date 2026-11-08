@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"

var _shadow: Sprite2D


func _on_configured() -> void:
    _load_options({"shadow_offset": Vector2(0.0, 8.0), "shadow_opacity": 0.35, "shadow_scale": Vector2(1.0, 0.55)})
    set_option("shadow_opacity", clampf(float(get_option("shadow_opacity", 0.35)), 0.0, 1.0))


func _apply_bound_target() -> bool:
    var source := find_sprite()
    if source == null or source.texture == null:
        return fail("Для визуальной тени нужен Sprite2D с текстурой в целевой ветке.")
    if is_instance_valid(_shadow):
        return update_shadow(source, _shadow)
    _shadow = create_shadow(source)
    return _shadow != null


func _exit_tree() -> void:
    if is_instance_valid(_shadow):
        _shadow.queue_free()
    _shadow = null


func create_shadow(source: Sprite2D) -> Sprite2D:
    if not is_instance_valid(source) or source.texture == null:
        fail("Для создания тени нужен Sprite2D с текстурой.")
        return null
    var shadow := Sprite2D.new()
    shadow.name = "%s_Shadow" % source.name
    shadow.texture = source.texture
    shadow.region_enabled = source.region_enabled
    shadow.region_rect = source.region_rect
    shadow.hframes = source.hframes
    shadow.vframes = source.vframes
    shadow.frame = source.frame
    shadow.centered = source.centered
    shadow.offset = source.offset
    # Keep the shadow under the source so it follows movement/rotation/scale
    # without a per-frame synchronisation loop.
    shadow.position = get_option("shadow_offset", Vector2(0.0, 8.0))
    shadow.scale = get_option("shadow_scale", Vector2(1.0, 0.55))
    shadow.z_as_relative = true
    shadow.z_index = -1
    shadow.modulate = Color(0.0, 0.0, 0.0, float(get_option("shadow_opacity", 0.35)))
    source.add_child(shadow)
    action_completed.emit(shadow)
    return shadow


func update_shadow(source: Sprite2D, shadow: Sprite2D) -> bool:
    if not is_instance_valid(source) or not is_instance_valid(shadow):
        return fail("Исходный спрайт или тень больше не существуют.")
    shadow.texture = source.texture
    shadow.region_enabled = source.region_enabled
    shadow.region_rect = source.region_rect
    shadow.hframes = source.hframes
    shadow.vframes = source.vframes
    shadow.frame = source.frame
    shadow.centered = source.centered
    shadow.offset = source.offset
    shadow.modulate = Color(0.0, 0.0, 0.0, float(get_option("shadow_opacity", 0.35)))
    shadow.position = get_option("shadow_offset", Vector2(0.0, 8.0))
    shadow.scale = get_option("shadow_scale", Vector2(1.0, 0.55))
    shadow.z_as_relative = true
    shadow.z_index = -1
    return true
