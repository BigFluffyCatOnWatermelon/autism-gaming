@tool
extends "res://addons/web_object_builder/mechanics/animation/components/animation_action_component.gd"

func _on_configured() -> void:
    _load_options({"animation_name": "attack"})


func play_attack() -> bool:
    if _animation_player == null or not is_instance_valid(_animation_player):
        return _fail("Сначала привяжите AnimationPlayer через bind_animation_player().")
    if not _animation_player.has_animation(StringName(str(get_option("animation_name", "attack")))):
        return _fail("Анимация не найдена: %s" % str(get_option("animation_name", "attack")))

    return _play_animation(str(get_option("animation_name", "attack")))
