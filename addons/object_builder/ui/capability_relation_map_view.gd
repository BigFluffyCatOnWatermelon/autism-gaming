@tool
extends RefCounted
class_name CapabilityRelationMapView
## Opens a local, interactive map around one focused capability.

signal focus_requested(capability_id: String)

var _window: Window
var _graph: GraphEdit
var _focus_button_count := 0


func open(
	owner: Control,
	focused_definition: ObjectCapabilityDefinition,
	entries: Array[Dictionary]
) -> void:
	if owner == null or focused_definition == null:
		return
	_close_window()
	_window = Window.new()
	_window.title = "Карта связей · " + focused_definition.display_name
	_window.min_size = Vector2i(620, 420)
	_window.size = Vector2i(820, 620)
	_window.transient = true
	_window.exclusive = false
	_window.close_requested.connect(_close_window)
	owner.add_child(_window)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 6)
	_window.add_child(layout)

	var hint := Label.new()
	hint.text = "Центральная карточка — выбранная механика. Нажми на узел, чтобы перейти к ней в каталоге. Линии показывают тип связи."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)

	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.show_grid = true
	_graph.show_zoom_buttons = true
	_graph.show_minimap = true
	_graph.minimap_size = Vector2(150, 100)
	_graph.add_valid_connection_type(0, 0)
	layout.add_child(_graph)

	_focus_button_count = 0
	var center_node := _create_graph_node(
		"FocusedCapability",
		focused_definition.display_name,
		"Выбранная механика",
		true,
		""
	)
	center_node.position_offset = Vector2(330, 250)
	_graph.add_child(center_node)

	var valid_entries: Array[Dictionary] = []
	for entry in entries:
		var definition := entry.get("definition") as ObjectCapabilityDefinition
		if definition == null or definition.capability_id == focused_definition.capability_id:
			continue
		valid_entries.append(entry)

	var count := valid_entries.size()
	for index in range(count):
		var entry := valid_entries[index]
		var definition := entry.get("definition") as ObjectCapabilityDefinition
		var relation_type := str(entry.get("relation_type", "related"))
		var relation_caption := _relation_caption(relation_type)
		var direction := "Входящая связь" if bool(entry.get("is_reverse", false)) else "Исходящая связь"
		var node_name := "Capability_" + str(index)
		var graph_node := _create_graph_node(
			node_name,
			definition.display_name,
			relation_caption + " · " + direction,
			definition.is_ready(),
			definition.capability_id
		)
		var angle := TAU * float(index) / float(maxi(1, count)) - PI * 0.5
		var radius := 260.0 if count <= 8 else 320.0
		graph_node.position_offset = Vector2(330, 250) + Vector2(cos(angle), sin(angle)) * radius
		_graph.add_child(graph_node)
		_graph.connect_node("FocusedCapability", 0, node_name, 0)

	_window.popup_centered()


func get_node_count() -> int:
	return _graph.get_child_count() if _graph != null else 0


func get_connection_count() -> int:
	return _graph.get_connection_list().size() if _graph != null else 0


func get_focus_button_count() -> int:
	return _focus_button_count


func _create_graph_node(
	node_name: String,
	title_text: String,
	subtitle: String,
	is_ready: bool,
	capability_id: String
) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = node_name
	graph_node.title = title_text
	graph_node.custom_minimum_size = Vector2(190, 92)
	graph_node.resizable = false
	graph_node.set_slot(0, true, 0, Color(0.62, 0.75, 0.95), true, 0, Color(0.62, 0.75, 0.95))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	graph_node.add_child(content)

	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 10)
	subtitle_label.modulate = Color(0.68, 0.75, 0.84)
	content.add_child(subtitle_label)

	if not capability_id.is_empty():
		var action := Button.new()
		action.text = "Перейти к механике" if is_ready else "Изучить (в разработке)"
		action.disabled = false
		action.pressed.connect(_on_focus_pressed.bind(capability_id))
		content.add_child(action)
		_focus_button_count += 1
	else:
		var center_label := Label.new()
		center_label.text = "Текущий фокус каталога"
		center_label.add_theme_font_size_override("font_size", 10)
		content.add_child(center_label)
	return graph_node


func _on_focus_pressed(capability_id: String) -> void:
	focus_requested.emit(capability_id)
	_close_window()


func _close_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null
	_graph = null


func _relation_caption(relation_type: String) -> String:
	match relation_type:
		"requires":
			return "Требует"
		"conflicts":
			return "Конфликт"
		"recommends":
			return "Рекомендуется"
		"extends":
			return "Расширяет"
		"alternative":
			return "Альтернатива"
		"profile":
			return "Подходит профилю"
		_:
			return "Связано"
