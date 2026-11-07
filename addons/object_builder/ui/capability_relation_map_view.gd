@tool
extends RefCounted
class_name CapabilityRelationMapView
## Opens a local, interactive map around one focused capability.

signal focus_requested(capability_id: String)

var _window: Window
var _graph: GraphEdit
var _focus_button_count := 0
var _full_nodes_by_id: Dictionary = {}
var _full_search_text_by_id: Dictionary = {}
var _full_search_input: LineEdit

const RELATION_TYPE_IDS := {
	"requires": 1,
	"conflicts": 2,
	"recommends": 3,
	"extends": 4,
	"alternative": 5,
	"related": 6
}


func open(
	host_control: Control,
	focused_definition: ObjectCapabilityDefinition,
	entries: Array[Dictionary]
) -> void:
	if host_control == null or focused_definition == null:
		return
	_close_window()
	_window = Window.new()
	_window.title = "Карта связей · " + focused_definition.display_name
	_window.min_size = Vector2i(620, 420)
	_window.size = Vector2i(820, 620)
	_window.transient = true
	_window.exclusive = false
	_window.close_requested.connect(_close_window)
	host_control.add_child(_window)

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
	_graph.minimap_enabled = true
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
		var relation_type_id := _get_relation_type_id(relation_type)
		_graph.add_valid_connection_type(0, relation_type_id)
		_graph.add_valid_connection_type(relation_type_id, 0)
		var graph_node := _create_graph_node(
			node_name,
			definition.display_name,
			relation_caption + " · " + direction,
			definition.is_ready(),
			definition.capability_id,
			relation_type_id
		)
		var angle := TAU * float(index) / float(maxi(1, count)) - PI * 0.5
		var radius := 260.0 if count <= 8 else 320.0
		graph_node.position_offset = Vector2(330, 250) + Vector2(cos(angle), sin(angle)) * radius
		_graph.add_child(graph_node)
		if bool(entry.get("is_reverse", false)):
			_graph.connect_node(node_name, 0, "FocusedCapability", 0)
		else:
			_graph.connect_node("FocusedCapability", 0, node_name, 0)

	_window.popup_centered()


func open_full(host_control: Control, focused_capability_id: String = "") -> void:
	if host_control == null:
		return
	_close_window()
	_window = Window.new()
	_window.title = "Полная карта механик · 200 возможностей"
	_window.min_size = Vector2i(720, 520)
	_window.size = Vector2i(1040, 760)
	_window.transient = true
	_window.exclusive = false
	_window.close_requested.connect(_close_window)
	host_control.add_child(_window)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 6)
	_window.add_child(layout)

	var hint := Label.new()
	hint.text = "Все 200 механик сгруппированы по категориям. Линии показывают связи; поиск оставляет на карте только совпавшие узлы. Карточки в разработке можно изучать и открывать."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)

	_full_search_input = LineEdit.new()
	_full_search_input.placeholder_text = "Найти механику на карте по названию, категории, синониму или описанию…"
	_full_search_input.text_changed.connect(filter_full_map)
	layout.add_child(_full_search_input)

	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.show_grid = true
	_graph.show_zoom_buttons = true
	_graph.minimap_enabled = true
	_graph.minimap_size = Vector2(180, 120)
	_graph.zoom = 0.55
	_graph.type_names = {
		1: "Обязательная зависимость",
		2: "Конфликт",
		3: "Рекомендуется",
		4: "Расширяет",
		5: "Альтернатива",
		6: "Тематическая связь"
	}
	for relation_type_id in RELATION_TYPE_IDS.values():
		_graph.add_valid_connection_type(int(relation_type_id), int(relation_type_id))
	layout.add_child(_graph)

	_full_nodes_by_id.clear()
	_full_search_text_by_id.clear()
	_focus_button_count = 0
	var capability_ids := ObjectCapabilityCatalog.get_capability_ids("", false)
	var category_indices: Dictionary = {}
	var category_counts: Dictionary = {}
	var node_names_by_id: Dictionary = {}
	var definitions_by_id: Dictionary = {}

	for index in range(capability_ids.size()):
		var capability_id := str(capability_ids[index])
		var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		if definition == null:
			continue
		definitions_by_id[capability_id] = definition
		if not category_indices.has(definition.category_id):
			category_indices[definition.category_id] = category_indices.size()
		var category_index := int(category_indices[definition.category_id])
		var category_item_index := int(category_counts.get(definition.category_id, 0))
		category_counts[definition.category_id] = category_item_index + 1
		var category_column := category_index % 4
		var category_row := int(category_index / 4)
		var item_column := category_item_index % 2
		var item_row := int(category_item_index / 2)
		var node_name := "FullCapability_" + str(index)
		node_names_by_id[capability_id] = node_name
		var readiness := "Готово" if definition.is_ready() else "В разработке"
		var subtitle := definition.category_name + " · " + readiness
		var graph_node := _create_full_graph_node(node_name, definition)
		graph_node.custom_minimum_size = Vector2(215, 190)
		graph_node.position_offset = Vector2(
			category_column * 520 + item_column * 245,
			category_row * 1100 + item_row * 210
		)
		_graph.add_child(graph_node)
		_full_nodes_by_id[capability_id] = graph_node
		_full_search_text_by_id[capability_id] = (
			definition.display_name + " " + definition.description + " "
			+ definition.category_name + " " + " ".join(definition.keywords) + " "
			+ " ".join(definition.synonyms) + " " + " ".join(definition.example_queries)
		).to_lower().replace("ё", "е")

	var connected_pairs: Dictionary = {}
	for capability_id in definitions_by_id:
		var definition := definitions_by_id[capability_id] as ObjectCapabilityDefinition
		for edge in _get_relation_edges(definition):
			var target_id := str(edge.get("target_id", ""))
			if not node_names_by_id.has(target_id):
				continue
			var relation_type := str(edge.get("type", "related"))
			var relation_type_id := _get_relation_type_id(relation_type)
			var pair_key := str(capability_id) + ">" + target_id + ":" + relation_type
			if connected_pairs.has(pair_key):
				continue
			connected_pairs[pair_key] = true
			_graph.connect_node(
				str(node_names_by_id[capability_id]),
				relation_type_id - 1,
				str(node_names_by_id[target_id]),
				relation_type_id - 1
			)

	if not focused_capability_id.is_empty() and _full_nodes_by_id.has(focused_capability_id):
		var focused_node := _full_nodes_by_id[focused_capability_id] as GraphNode
		focused_node.title += " · ФОКУС"
	_window.popup_centered()


func filter_full_map(query: String) -> void:
	var normalized_query := query.strip_edges().to_lower().replace("ё", "е")
	for capability_id in _full_nodes_by_id:
		var graph_node := _full_nodes_by_id[capability_id] as GraphNode
		var searchable := str(_full_search_text_by_id.get(capability_id, ""))
		graph_node.visible = normalized_query.is_empty() or searchable.contains(normalized_query)


func get_relation_type_count() -> int:
	return _graph.type_names.size() if _graph != null else 0


func get_visible_node_count() -> int:
	var count := 0
	for graph_node_value in _full_nodes_by_id.values():
		var graph_node := graph_node_value as GraphNode
		if graph_node != null and graph_node.visible:
			count += 1
	return count





func get_node_count() -> int:
	return _graph.get_child_count() if _graph != null else 0


func get_connection_count() -> int:
	return _graph.get_connection_list().size() if _graph != null else 0


func has_connection(from_node: String, to_node: String) -> bool:
	return _graph.is_node_connected(from_node, 0, to_node, 0) if _graph != null else false


func get_focus_button_count() -> int:
	return _focus_button_count


func _create_graph_node(
	node_name: String,
	title_text: String,
	subtitle: String,
	is_ready: bool,
	capability_id: String,
	port_type: int = 0
) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = node_name
	graph_node.title = title_text
	graph_node.custom_minimum_size = Vector2(190, 92)
	graph_node.resizable = false

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	graph_node.add_child(content)
	var port_color := _get_relation_type_color(port_type)
	graph_node.set_slot(0, true, port_type, port_color, true, port_type, port_color)

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


func _create_full_graph_node(node_name: String, definition: ObjectCapabilityDefinition) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = node_name
	graph_node.title = definition.display_name
	graph_node.custom_minimum_size = Vector2(215, 190)
	graph_node.resizable = false
	for relation_type in RELATION_TYPE_IDS:
		var row := HBoxContainer.new()
		var relation_label := Label.new()
		relation_label.text = _relation_caption(str(relation_type))
		relation_label.add_theme_font_size_override("font_size", 9)
		relation_label.modulate = _get_relation_type_color(int(RELATION_TYPE_IDS[relation_type]))
		row.add_child(relation_label)
		graph_node.add_child(row)
		var slot_index := graph_node.get_child_count() - 1
		var type_id := int(RELATION_TYPE_IDS[relation_type])
		var color := _get_relation_type_color(type_id)
		graph_node.set_slot(slot_index, true, type_id, color, true, type_id, color)

	var action := Button.new()
	action.text = "Открыть карточку"
	action.tooltip_text = definition.description
	action.pressed.connect(_on_focus_pressed.bind(definition.capability_id))
	graph_node.add_child(action)
	_focus_button_count += 1
	return graph_node


func _get_relation_edges(definition: ObjectCapabilityDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if definition == null:
		return result
	for required_id in definition.required_capability_ids:
		result.append({"target_id": str(required_id).strip_edges().to_lower(), "type": "requires"})
	for conflict_id in definition.incompatible_capability_ids:
		result.append({"target_id": str(conflict_id).strip_edges().to_lower(), "type": "conflicts"})
	for relation in definition.relations:
		result.append({
			"target_id": str(relation.get("target_id", "")).strip_edges().to_lower(),
			"type": str(relation.get("type", "related")).strip_edges().to_lower()
		})
	return result


func _get_relation_type_id(relation_type: String) -> int:
	return int(RELATION_TYPE_IDS.get(relation_type, RELATION_TYPE_IDS["related"]))


func _get_relation_type_color(type_id: int) -> Color:
	match type_id:
		1:
			return Color(0.55, 0.75, 1.0)
		2:
			return Color(1.0, 0.48, 0.45)
		3:
			return Color(0.48, 0.84, 0.62)
		4:
			return Color(0.76, 0.62, 0.94)
		5:
			return Color(0.48, 0.8, 0.84)
		_:
			return Color(0.85, 0.78, 0.52)


func _on_focus_pressed(capability_id: String) -> void:
	focus_requested.emit(capability_id)
	_close_window()


func _close_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null
	_graph = null
	_full_nodes_by_id.clear()
	_full_search_text_by_id.clear()
	_full_search_input = null


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
