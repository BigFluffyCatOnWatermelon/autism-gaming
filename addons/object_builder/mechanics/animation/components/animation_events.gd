@tool
extends "res://addons/object_builder/mechanics/animation/components/animation_action_component.gd"

signal animation_event(event_name: String, animation_name: String)

var _emit_started := true
var _emit_finished := true


func _on_configured() -> void:
    _load_options({"emit_started": true, "emit_finished": true})
    _sync_event_flags()


func bind_animation_player(player: AnimationPlayer) -> bool:
    var started := Callable(self, "_on_animation_started")
    var finished := Callable(self, "_on_animation_finished")
    if _animation_player != null and is_instance_valid(_animation_player):
        if _animation_player.animation_started.is_connected(started):
            _animation_player.animation_started.disconnect(started)
        if _animation_player.animation_finished.is_connected(finished):
            _animation_player.animation_finished.disconnect(finished)
    if not super.bind_animation_player(player):
        return false
    started = Callable(self, "_on_animation_started")
    finished = Callable(self, "_on_animation_finished")
    if not _animation_player.animation_started.is_connected(started):
        _animation_player.animation_started.connect(started)
    if not _animation_player.animation_finished.is_connected(finished):
        _animation_player.animation_finished.connect(finished)
    return true


func configure_mechanic(values: Dictionary) -> bool:
    if not super.configure_mechanic(values):
        return false
    _sync_event_flags()
    return true


func _sync_event_flags() -> void:
    _emit_started = bool(get_option("emit_started", true))
    _emit_finished = bool(get_option("emit_finished", true))


func _on_animation_started(animation_name: StringName) -> void:
    if _emit_started:
        animation_event.emit("started", String(animation_name))


func _on_animation_finished(animation_name: StringName) -> void:
    if _emit_finished:
        animation_event.emit("finished", String(animation_name))


func emit_marker(marker_name: String) -> bool:
    var clean_name := marker_name.strip_edges()
    if clean_name.is_empty():
        return _fail("Имя маркера не может быть пустым.")
    var current_name := ""
    if _animation_player != null and is_instance_valid(_animation_player):
        current_name = String(_animation_player.current_animation)
    animation_event.emit(clean_name, current_name)
    action_completed.emit(clean_name)
    return true
