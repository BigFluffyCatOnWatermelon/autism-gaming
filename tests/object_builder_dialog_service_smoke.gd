extends SceneTree

const DialogService = preload("res://addons/object_builder/services/dialog_service.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		DialogService.calculate_safe_window_size(Vector2i(1920, 1080), Vector2i(820, 620)) == Vector2i(820, 620),
		"preferred dialog size is preserved when it fits the screen"
	)
	_expect(
		DialogService.calculate_safe_window_size(Vector2i(800, 600), Vector2i(820, 620)) == Vector2i(720, 504),
		"large dialogs are reduced to the available screen area"
	)
	_expect(
		DialogService.calculate_safe_window_size(Vector2i(160, 120), Vector2i(820, 620)) == Vector2i(160, 120),
		"very small screens are never exceeded by the computed dialog size"
	)
	_expect(
		DialogService.calculate_safe_window_size(Vector2i.ZERO, Vector2i(820, 620)) == Vector2i(820, 620),
		"unknown screen size preserves the requested size for fallback centering"
	)
	_expect(
		DialogService.calculate_maximum_window_size(Vector2i(800, 600)) == Vector2i(720, 504),
		"maximum dimensions follow one shared screen margin policy"
	)
	DialogService.popup_window_safely(null, Vector2i(400, 300))
	_expect(true, "popup service tolerates a missing optional window")
	await process_frame
	if failures.is_empty():
		print("Object Builder dialog service tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
