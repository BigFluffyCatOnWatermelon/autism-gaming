@tool
extends RefCounted
## Centralizes safe sizing and placement of Object Builder popup windows.


static func calculate_safe_window_size(
	usable_size: Vector2i,
	preferred_size: Vector2i
) -> Vector2i:
	if usable_size.x <= 0 or usable_size.y <= 0:
		return preferred_size
	var maximum_size := calculate_maximum_window_size(usable_size)
	return Vector2i(mini(preferred_size.x, maximum_size.x), mini(preferred_size.y, maximum_size.y))


static func calculate_maximum_window_size(usable_size: Vector2i) -> Vector2i:
	if usable_size.x <= 0 or usable_size.y <= 0:
		return Vector2i.ZERO
	return Vector2i(
		mini(usable_size.x, maxi(240, int(floor(float(usable_size.x) * 0.90)))),
		mini(usable_size.y, maxi(180, int(floor(float(usable_size.y) * 0.84))))
	)


static func popup_window_safely(
	window: Window,
	preferred_size: Vector2i,
	fallback_ratio: float = 0.82
) -> void:
	if window == null or not is_instance_valid(window):
		return
	var screen_index := DisplayServer.window_get_current_screen()
	var usable_size := DisplayServer.screen_get_usable_rect(screen_index).size
	if usable_size.x <= 0 or usable_size.y <= 0:
		window.popup_centered_clamped(preferred_size, fallback_ratio)
		return
	window.max_size = calculate_maximum_window_size(usable_size)
	var requested_size := calculate_safe_window_size(usable_size, preferred_size)
	window.size = requested_size
	window.popup_centered_clamped(requested_size, fallback_ratio)
