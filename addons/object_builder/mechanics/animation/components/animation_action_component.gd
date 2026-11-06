@tool
extends "res://addons/object_builder/mechanics/animation/component.gd"

var _animation_player: AnimationPlayer


func bind_animation_player(player: AnimationPlayer) -> bool:
    if player == null or not is_instance_valid(player):
        return _fail("Не передан действующий AnimationPlayer.")
    _animation_player = player
    return true


func _play_animation(animation_name: String, blend_seconds: float = -1.0) -> bool:
    if _animation_player == null or not is_instance_valid(_animation_player):
        return _fail("Сначала привяжите AnimationPlayer через bind_animation_player().")
    var clean_name := animation_name.strip_edges()
    if clean_name.is_empty():
        return _fail("Имя анимации не задано.")
    if not _animation_player.has_animation(StringName(clean_name)):
        return _fail("Анимация не найдена: %s" % clean_name)
    if blend_seconds < -1.0 or blend_seconds > 10.0:
        return _fail("Время смешивания должно быть от -1 до 10 секунд.")
    _animation_player.play(StringName(clean_name), blend_seconds)
    action_completed.emit(clean_name)
    return true
