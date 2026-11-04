extends Node

func _enter_tree() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_bind_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("dodge", KEY_SPACE)
	_bind_key("interact", KEY_E)
	_bind_key("parry", KEY_F)
	_bind_key("heal", KEY_Q)
	_bind_key("lock_target", KEY_TAB)
	_bind_key("pause", KEY_ESCAPE)
	_bind_mouse("light_attack", MOUSE_BUTTON_LEFT)
	_bind_mouse("heavy_attack", MOUSE_BUTTON_MIDDLE)
	_bind_mouse("block", MOUSE_BUTTON_RIGHT)
	_bind_key("light_attack", KEY_J)
	_bind_key("heavy_attack", KEY_K)
	_bind_key("block", KEY_L)
	_bind_key("switch_weapon", KEY_V)
	_bind_pad("dodge", JOY_BUTTON_B)
	_bind_pad("light_attack", JOY_BUTTON_X)
	_bind_pad("heavy_attack", JOY_BUTTON_Y)
	_bind_pad("block", JOY_BUTTON_LEFT_SHOULDER)
	_bind_pad("sprint", JOY_BUTTON_RIGHT_SHOULDER)
	_bind_pad("interact", JOY_BUTTON_A)
	_bind_pad("pause", JOY_BUTTON_START)

func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)

func _bind_key(action: StringName, key: int) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _bind_mouse(action: StringName, button: int) -> void:
	_ensure_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _bind_pad(action: StringName, button: int) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _bind_axis(action: StringName, axis: int, direction: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
