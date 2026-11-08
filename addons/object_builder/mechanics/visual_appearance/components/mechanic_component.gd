@tool
extends ObjectComponent

signal state_changed(key: String, new_value: Variant)
signal action_completed(result: Variant)
signal action_failed(reason: String)

var _runtime_options: Dictionary = {}
var _bound_target: Node


func bind_target(target: Node) -> bool:
    if target == null or not is_instance_valid(target):
        return fail("Не передан действительный целевой узел внешнего вида.")
    _bound_target = target
    return _apply_bound_target()


func get_bound_target() -> Node:
    return _bound_target if is_instance_valid(_bound_target) else null


func _apply_bound_target() -> bool:
    return true


func find_sprite(root: Node = null) -> Sprite2D:
    var search_root := root if root != null else get_bound_target()
    if search_root == null or not is_instance_valid(search_root):
        return null
    if search_root is Sprite2D:
        return search_root as Sprite2D
    for child in search_root.get_children():
        if child is Node:
            var found := find_sprite(child as Node)
            if found != null:
                return found
    return null


func find_canvas_item(root: Node = null) -> CanvasItem:
    var search_root := root if root != null else get_bound_target()
    if search_root == null or not is_instance_valid(search_root):
        return null
    if search_root is CanvasItem:
        return search_root as CanvasItem
    for child in search_root.get_children():
        if child is Node:
            var found := find_canvas_item(child as Node)
            if found != null:
                return found
    return null


func _load_options(defaults: Dictionary) -> void:
    _runtime_options.clear()
    for key in defaults:
        _runtime_options[key] = get_setting(str(key), defaults[key])


func configure_mechanic(values: Dictionary) -> bool:
    for key in values:
        var name := str(key)
        if not _runtime_options.has(name):
            action_failed.emit("Неизвестная настройка: %s" % name)
            return false
        if typeof(values[key]) != typeof(_runtime_options[name]):
            action_failed.emit("Неверный тип настройки: %s" % name)
            return false

    for key in values:
        _runtime_options[str(key)] = values[key]
        state_changed.emit(str(key), values[key])
    if get_bound_target() != null and not _apply_bound_target():
        return false
    action_completed.emit(export_runtime_state())
    return true


func get_option(key: String, fallback: Variant = null) -> Variant:
    return _runtime_options.get(key, fallback)


func set_option(key: String, value: Variant) -> bool:
    if not _runtime_options.has(key):
        action_failed.emit("Неизвестная настройка: %s" % key)
        return false
    if typeof(value) != typeof(_runtime_options[key]):
        action_failed.emit("Неверный тип настройки: %s" % key)
        return false
    _runtime_options[key] = value
    state_changed.emit(key, value)
    return true


func export_runtime_state() -> Dictionary:
    return _runtime_options.duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
    return configure_mechanic(state)


func fail(reason: String) -> bool:
    action_failed.emit(reason)
    return false
