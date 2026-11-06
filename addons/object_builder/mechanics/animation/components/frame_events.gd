@tool
extends "res://addons/object_builder/mechanics/animation/component.gd"

signal frame_event(animation_name: String, frame_index: int)

var _animated_sprite: AnimatedSprite2D
var _allowed_frames: Dictionary = {}


func _on_configured() -> void:
    _load_options({"frames_csv": ""})
    _parse_frame_filter()


func configure_mechanic(values: Dictionary) -> bool:
    if values.has("frames_csv") and not _is_valid_frame_filter(str(values["frames_csv"])):
        return _fail("Фильтр кадров должен содержать неотрицательные целые числа через запятую.")
    if not super.configure_mechanic(values):
        return false
    return _parse_frame_filter()


func bind_animated_sprite(sprite: AnimatedSprite2D) -> bool:
    if sprite == null or not is_instance_valid(sprite):
        return _fail("Не передан действующий AnimatedSprite2D.")
    var callback := Callable(self, "_on_frame_changed")
    if _animated_sprite != null and is_instance_valid(_animated_sprite) and _animated_sprite.frame_changed.is_connected(callback):
        _animated_sprite.frame_changed.disconnect(callback)
    _animated_sprite = sprite
    if not _animated_sprite.frame_changed.is_connected(callback):
        _animated_sprite.frame_changed.connect(callback)
    return true


func _is_valid_frame_filter(raw_value: String) -> bool:
    var raw := raw_value.strip_edges()
    if raw.is_empty():
        return true
    for token in raw.split(",", false):
        var clean := token.strip_edges()
        if not clean.is_valid_int() or int(clean) < 0:
            return false
    return true


func _parse_frame_filter() -> bool:
    _allowed_frames.clear()
    var raw := str(get_option("frames_csv", "")).strip_edges()
    if raw.is_empty():
        return true
    for token in raw.split(",", false):
        _allowed_frames[int(token.strip_edges())] = true
    return true


func _on_frame_changed() -> void:
    if _animated_sprite == null or not is_instance_valid(_animated_sprite):
        return
    var frame_index := _animated_sprite.frame
    if not _allowed_frames.is_empty() and not _allowed_frames.has(frame_index):
        return
    frame_event.emit(String(_animated_sprite.animation), frame_index)


func emit_current_frame_event() -> bool:
    if _animated_sprite == null or not is_instance_valid(_animated_sprite):
        return _fail("Сначала привяжите AnimatedSprite2D через bind_animated_sprite().")
    _on_frame_changed()
    action_completed.emit(_animated_sprite.frame)
    return true
