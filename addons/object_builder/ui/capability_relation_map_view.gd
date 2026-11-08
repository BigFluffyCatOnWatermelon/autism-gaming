@tool
extends RefCounted
class_name CapabilityRelationMapView
## A three-level, semantic map for exploring the capability catalogue.
## The map is read-only: navigation changes catalogue focus but never enables a capability.

signal focus_requested(capability_id: String)

const RELATION_TYPE_ORDER := ["requires", "conflicts", "recommends", "extends", "alternative", "related"]
const RELATION_TYPE_IDS := {
	"requires": 1,
	"conflicts": 2,
	"recommends": 3,
	"extends": 4,
	"alternative": 5,
	"related": 6
}
const RELATION_TYPE_NAMES := {
	"requires": "Обязательная зависимость",
	"conflicts": "Конфликт",
	"recommends": "Рекомендуется",
	"extends": "Расширяет",
	"alternative": "Альтернатива",
	"related": "Тематическая связь"
}
const RELATION_TYPE_COLORS := {
	"requires": Color(0.42, 0.72, 1.0),
	"conflicts": Color(1.0, 0.40, 0.38),
	"recommends": Color(0.36, 0.82, 0.57),
	"extends": Color(0.72, 0.57, 0.94),
	"alternative": Color(0.35, 0.76, 0.82),
	"related": Color(0.68, 0.70, 0.76)
}

class CapabilityMapData:
	const DOMAINS := [
		{"id": "core", "name": "Основы объекта", "subtitle": "Идентичность, свойства и базовые состояния", "icon": "◆", "categories": ["general"]},
		{"id": "presentation", "name": "Внешний вид", "subtitle": "Графика, анимация, звук и эффекты", "icon": "✦", "categories": ["visual", "animation", "audio_effects"]},
		{"id": "motion", "name": "Движение и физика", "subtitle": "Перемещение, столкновения и физические силы", "icon": "↗", "categories": ["movement", "physics"]},
		{"id": "behavior", "name": "Поведение и AI", "subtitle": "Реакции, решения, животные и автономность", "icon": "◉", "categories": ["ai", "animals"]},
		{"id": "interaction", "name": "Взаимодействие", "subtitle": "Действия игрока и реакции объектов", "icon": "⌖", "categories": ["interaction"]},
		{"id": "combat", "name": "Бой и выживание", "subtitle": "Атака, здоровье, защита и состояния", "icon": "⚔", "categories": ["combat", "defense", "stats"]},
		{"id": "items", "name": "Предметы и хранение", "subtitle": "Подбор, экипировка, инвентарь и контейнеры", "icon": "▣", "categories": ["items", "inventory", "containers"]},
		{"id": "resources", "name": "Разрушение и добыча", "subtitle": "Прочность, сбор ресурсов и выпадение предметов", "icon": "⛏", "categories": ["destruction", "harvesting"]},
		{"id": "world", "name": "Мир и строительство", "subtitle": "Постройки, время, события и генерация", "icon": "⌂", "categories": ["construction", "world_time", "world_generation"]}
	]

	static func get_domain_for_category(category_id: String) -> Dictionary:
		for domain in DOMAINS:
			if (domain["categories"] as Array).has(category_id):
				return domain
		return {"id": "other", "name": "Другие механики", "subtitle": "Дополнительные категории", "icon": "◇", "categories": [category_id]}

	static func get_group_for_category(category_id: String) -> String:
		var groups := {
			"general": "Идентичность и базовые свойства",
			"visual": "Графика и отображение",
			"animation": "Анимация и события кадров",
			"audio_effects": "Звуки и визуальные эффекты",
			"movement": "Передвижение и управление",
			"physics": "Физика и столкновения",
			"ai": "Логика и принятие решений",
			"animals": "Животные и потребности",
			"interaction": "Взаимодействие с миром",
			"combat": "Атака и нанесение урона",
			"defense": "Защита и сопротивления",
			"stats": "Здоровье и характеристики",
			"items": "Предметы и экипировка",
			"inventory": "Инвентарь и быстрый доступ",
			"containers": "Хранение и контейнеры",
			"destruction": "Прочность и разрушение",
			"harvesting": "Добыча и сбор",
			"construction": "Размещение и строительство",
			"world_time": "Время и мировые события",
			"world_generation": "Биомы и генерация"
		}
		return str(groups.get(category_id, "Другие механики"))

	static func build_catalog() -> Dictionary:
		var domains_by_id: Dictionary = {}
		var definitions_by_id: Dictionary = {}
		var category_names: Dictionary = {}
		var category_counts: Dictionary = {}
		for domain in DOMAINS:
			var copy: Dictionary = domain.duplicate(true)
			copy["mechanics"] = []
			copy["ready_count"] = 0
			copy["category_count"] = 0
			copy["groups"] = {}
			domains_by_id[str(copy["id"])] = copy
		for capability_id in ObjectCapabilityCatalog.get_capability_ids("", false):
			var definition := ObjectCapabilityCatalog.get_definition_reference(capability_id)
			if definition == null:
				continue
			definitions_by_id[capability_id] = definition
			category_names[definition.category_id] = definition.category_name
			category_counts[definition.category_id] = int(category_counts.get(definition.category_id, 0)) + 1
			var domain_info := get_domain_for_category(definition.category_id)
			var domain_id := str(domain_info["id"])
			if not domains_by_id.has(domain_id):
				var extra: Dictionary = domain_info.duplicate(true)
				extra["mechanics"] = []
				extra["ready_count"] = 0
				extra["category_count"] = 0
				extra["groups"] = {}
				domains_by_id[domain_id] = extra
			var domain: Dictionary = domains_by_id[domain_id]
			(domain["mechanics"] as Array).append(capability_id)
			if definition.is_ready():
				domain["ready_count"] = int(domain["ready_count"]) + 1
			var group_id := definition.category_id
			if not (domain["groups"] as Dictionary).has(group_id):
				(domain["groups"] as Dictionary)[group_id] = {
					"id": group_id,
					"name": get_group_for_category(group_id),
					"category_name": definition.category_name,
					"mechanics": []
				}
			((domain["groups"] as Dictionary)[group_id]["mechanics"] as Array).append(capability_id)
		for domain_id in domains_by_id:
			var domain: Dictionary = domains_by_id[domain_id]
			var groups: Array = (domain["groups"] as Dictionary).values()
			groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0
			)
			domain["groups"] = groups
			domain["category_count"] = groups.size()
			(domain["mechanics"] as Array).sort()
			domains_by_id[domain_id] = domain
		return {
			"domains": domains_by_id,
			"definitions": definitions_by_id,
			"category_names": category_names,
			"category_counts": category_counts
		}

	static func build_edges(definitions: Dictionary) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var seen: Dictionary = {}
		for capability_id in definitions:
			var definition := definitions[capability_id] as ObjectCapabilityDefinition
			if definition == null:
				continue
			for required_id in definition.required_capability_ids:
				_append_edge(result, seen, str(capability_id), str(required_id), "requires",
					"Обязательная зависимость: без неё эта возможность не сможет работать.")
			for conflict_id in definition.incompatible_capability_ids:
				_append_edge(result, seen, str(capability_id), str(conflict_id), "conflicts",
					"Эти возможности несовместимы и не должны использоваться вместе.")
			for relation in definition.relations:
				var relation_type := str(relation.get("type", "related")).strip_edges().to_lower()
				var target_id := str(relation.get("target_id", "")).strip_edges().to_lower()
				var explanation := str(relation.get("explanation", "")).strip_edges()
				if explanation.is_empty():
					explanation = _default_explanation(relation_type)
				_append_edge(result, seen, str(capability_id), target_id, relation_type, explanation)
		return result

	static func _append_edge(
		result: Array[Dictionary],
		seen: Dictionary,
		source_id: String,
		target_id: String,
		relation_type: String,
		explanation: String
	) -> void:
		if source_id.is_empty() or target_id.is_empty() or source_id == target_id:
			return
		if not CapabilityRelationMapView.RELATION_TYPE_IDS.has(relation_type):
			relation_type = "related"
		var key := source_id + ">" + target_id + ":" + relation_type
		if seen.has(key):
			return
		seen[key] = true
		result.append({
			"source_id": source_id,
			"target_id": target_id,
			"type": relation_type,
			"explanation": explanation
		})

	static func _default_explanation(relation_type: String) -> String:
		match relation_type:
			"requires": return "Обязательная зависимость для работы возможности."
			"conflicts": return "Эти возможности нельзя использовать одновременно."
			"recommends": return "Эта возможность хорошо дополняет выбранную."
			"extends": return "Расширяет или дополняет базовое поведение."
			"alternative": return "Альтернативный способ реализовать похожую задачу."
			_: return "Тематически связанная возможность."

	static func get_neighbors(capability_id: String, edges: Array[Dictionary]) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var seen: Dictionary = {}
		for edge in edges:
			var source_id := str(edge["source_id"])
			var target_id := str(edge["target_id"])
			var is_reverse := source_id != capability_id and target_id == capability_id
			if source_id != capability_id and not is_reverse:
				continue
			var neighbor_id := source_id if is_reverse else target_id
			var relation_key := neighbor_id + ":" + str(edge["type"]) + ":" + str(is_reverse)
			if seen.has(relation_key):
				continue
			seen[relation_key] = true
			var copied: Dictionary = edge.duplicate(true)
			copied["capability_id"] = neighbor_id
			copied["is_reverse"] = is_reverse
			result.append(copied)
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_type := CapabilityRelationMapView.RELATION_TYPE_ORDER.find(str(a["type"]))
			var b_type := CapabilityRelationMapView.RELATION_TYPE_ORDER.find(str(b["type"]))
			if a_type != b_type:
				return a_type < b_type
			var a_def := ObjectCapabilityCatalog.get_definition_reference(str(a["capability_id"]))
			var b_def := ObjectCapabilityCatalog.get_definition_reference(str(b["capability_id"]))
			if a_def == null or b_def == null:
				return str(a["capability_id"]) < str(b["capability_id"])
			return a_def.display_name.naturalnocasecmp_to(b_def.display_name) < 0
		)
		if result.size() > 12:
			result.resize(12)
		return result


class CapabilityMapLayout:
	static func domain_position(index: int) -> Vector2:
		const COLUMNS := 3
		const COLUMN_SPACING := 440.0
		const ROW_SPACING := 285.0
		return Vector2(float(index % COLUMNS) * COLUMN_SPACING, float(int(index / COLUMNS)) * ROW_SPACING)

	static func mechanic_position(index: int, group_index: int) -> Vector2:
		const GROUP_SPACING := 560.0
		const NODE_SPACING := 168.0
		const COLUMNS := 3
		return Vector2(
			float(group_index) * GROUP_SPACING + float(index % COLUMNS) * 205.0,
			float(int(index / COLUMNS)) * NODE_SPACING
		)

	static func local_position(index: int, count: int) -> Vector2:
		if index == 0:
			return Vector2(360, 250)
		var angle := TAU * float(index - 1) / float(maxi(1, count - 1)) - PI * 0.5
		var radius := 310.0 if count <= 8 else 390.0
		return Vector2(360, 250) + Vector2(cos(angle), sin(angle)) * radius


var _window: Window
var _layout: VBoxContainer
var _toolbar: HBoxContainer
var _graph: GraphEdit
var _hint: Label
var _search_input: LineEdit
var _category_filter: OptionButton
var _relation_filter: OptionButton
var _status_filter: OptionButton
var _breadcrumb: Label
var _focus_button_count := 0
var _catalog: Dictionary = {}
var _domains: Dictionary = {}
var _definitions: Dictionary = {}
var _edges: Array[Dictionary] = []
var _domain_edges: Array[Dictionary] = []
var _node_names_by_id: Dictionary = {}
var _nodes_by_id: Dictionary = {}
var _domain_node_names: Dictionary = {}
var _current_mode := "overview"
var _current_domain_id := ""
var _focused_capability_id := ""
var _search_query := ""
var _selected_category_id := ""
var _selected_relation_type := ""
var _selected_status := "all"


func open(host_control: Control, focused_definition: ObjectCapabilityDefinition, entries: Array[Dictionary]) -> void:
	if host_control == null or focused_definition == null:
		return
	_open_window(host_control, "Карта связей · " + focused_definition.display_name)
	_catalog = CapabilityMapData.build_catalog()
	_domains = _catalog["domains"]
	_definitions = _catalog["definitions"]
	_edges = CapabilityMapData.build_edges(_definitions)
	var neighbors: Array[Dictionary] = []
	for entry in entries:
		var definition := entry.get("definition") as ObjectCapabilityDefinition
		if definition == null:
			continue
		var copy: Dictionary = entry.duplicate(true)
		copy["capability_id"] = definition.capability_id
		copy["type"] = str(entry.get("relation_type", "related"))
		copy["is_reverse"] = bool(entry.get("is_reverse", false))
		copy["explanation"] = str(entry.get("explanation", ""))
		neighbors.append(copy)
	_build_local_graph(focused_definition.capability_id, neighbors, focused_definition)


func open_full(host_control: Control, focused_capability_id: String = "") -> void:
	if host_control == null:
		return
	_open_window(host_control, "Карта механик · умный каталог")
	_catalog = CapabilityMapData.build_catalog()
	_domains = _catalog["domains"]
	_definitions = _catalog["definitions"]
	_edges = CapabilityMapData.build_edges(_definitions)
	_domain_edges = _build_domain_edges()
	_focused_capability_id = focused_capability_id
	_current_mode = "overview"
	_current_domain_id = ""
	_search_query = ""
	_selected_category_id = ""
	_selected_relation_type = ""
	_selected_status = "all"
	_rebuild_view()


func _open_window(host_control: Control, title_text: String) -> void:
	_close_window()
	_window = Window.new()
	_window.title = title_text
	_window.min_size = Vector2i(900, 620)
	_window.size = Vector2i(1240, 850)
	_window.transient = true
	_window.exclusive = false
	_window.close_requested.connect(_close_window)
	host_control.add_child(_window)
	_layout = VBoxContainer.new()
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.add_theme_constant_override("separation", 7)
	_window.add_child(_layout)
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 5)
	_layout.add_child(_toolbar)
	_breadcrumb = Label.new()
	_breadcrumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_breadcrumb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toolbar.add_child(_breadcrumb)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	_layout.add_child(_hint)
	_window.popup_centered()


func _rebuild_view() -> void:
	if _layout == null:
		return
	_focus_button_count = 0
	for child in _toolbar.get_children():
		child.queue_free()
	for child in _layout.get_children():
		if child != _toolbar:
			child.queue_free()
	_graph = null
	_search_input = null
	_category_filter = null
	_relation_filter = null
	_status_filter = null
	_breadcrumb = Label.new()
	_breadcrumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_breadcrumb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toolbar.add_child(_breadcrumb)
	_add_toolbar_button("Обзор", _show_overview, _current_mode == "overview")
	if _current_mode != "overview":
		_add_toolbar_button("Назад", _go_back)
	_add_toolbar_button("Связи", _show_local_focus, _current_mode == "local")
	_add_toolbar_button("Зависимости", _show_dependencies, _current_mode == "dependencies")
	_add_toolbar_button("Область", _show_current_domain, _current_mode == "domain")
	_add_toolbar_button("Закрыть", _close_window)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	_layout.add_child(_hint)
	match _current_mode:
		"overview":
			_breadcrumb.text = "Карта механик  /  Обзор"
			_hint.text = "Сначала выбери тематическую область. Здесь показаны только крупные направления и связи между ними — без перегружающих линий от каждой отдельной механики."
			_build_overview()
		"domain":
			var domain: Dictionary = _domains.get(_current_domain_id, {})
			_breadcrumb.text = "Карта механик  /  " + str(domain.get("name", "Область"))
			_hint.text = "Механики сгруппированы по смысловым подгруппам. Выбери «Связи», чтобы исследовать соседние механики, или открой карточку в каталоге."
			_build_domain_toolbar()
			_build_domain_graph()
		"local":
			var definition := _definitions.get(_focused_capability_id) as ObjectCapabilityDefinition
			_breadcrumb.text = "Карта механик  /  Связи  /  " + (definition.display_name if definition != null else _focused_capability_id)
			_hint.text = "В центре — выбранная механика. Вокруг — до 12 наиболее значимых прямых входящих и исходящих связей, включая другие тематические области. Наведи курсор на узел, чтобы прочитать объяснение."
			_build_local_from_catalog()
		"dependencies":
			_hint.text = "Показаны только обязательные зависимости и конфликты. Рекомендации и тематические связи не выдаются за обязательные требования."
			if _current_domain_id.is_empty():
				_breadcrumb.text = "Карта механик  /  Зависимости между областями"
				_build_overview()
			else:
				var dependency_domain: Dictionary = _domains.get(_current_domain_id, {})
				_breadcrumb.text = "Карта механик  /  Зависимости  /  " + str(dependency_domain.get("name", "Область"))
				_selected_relation_type = ""
				_build_domain_toolbar()
				_build_domain_graph()


func _add_toolbar_button(caption: String, callback: Callable, active: bool = false) -> void:
	var button := Button.new()
	button.text = caption
	button.toggle_mode = active
	button.button_pressed = active
	button.pressed.connect(callback)
	_toolbar.add_child(button)


func _build_overview() -> void:
	_graph = _create_graph()
	_layout.add_child(_graph)
	var domain_ids: Array = _domains.keys()
	domain_ids.sort_custom(func(a: String, b: String) -> bool:
		var a_order := _domain_order(a)
		var b_order := _domain_order(b)
		return a_order < b_order
	)
	_domain_node_names.clear()
	for index in range(domain_ids.size()):
		var domain_id := str(domain_ids[index])
		var domain: Dictionary = _domains[domain_id]
		var node_name := "Domain_" + domain_id
		_domain_node_names[domain_id] = node_name
		var graph_node := GraphNode.new()
		graph_node.name = node_name
		graph_node.title = str(domain.get("icon", "◇")) + "  " + str(domain.get("name", domain_id))
		graph_node.custom_minimum_size = Vector2(350, 150)
		graph_node.position_offset = CapabilityMapLayout.domain_position(index)
		graph_node.resizable = false
		for relation_type in RELATION_TYPE_ORDER:
			var relation_row := HBoxContainer.new()
			var relation_label := Label.new()
			relation_label.text = str(RELATION_TYPE_NAMES[relation_type])
			relation_label.add_theme_font_size_override("font_size", 9)
			relation_label.add_theme_color_override("font_color", RELATION_TYPE_COLORS[relation_type])
			relation_row.add_child(relation_label)
			graph_node.add_child(relation_row)
			var slot_index := graph_node.get_child_count() - 1
			var type_id := _relation_type_id(str(relation_type))
			var relation_color: Color = RELATION_TYPE_COLORS[relation_type]
			graph_node.set_slot(slot_index, true, type_id, relation_color, true, type_id, relation_color)
		var content := VBoxContainer.new()
		graph_node.add_child(content)
		var count := (domain["mechanics"] as Array).size()
		var ready_count := int(domain.get("ready_count", 0))
		var stats := Label.new()
		stats.text = "%d механик  ·  %d готово  ·  %d подгруппы" % [count, ready_count, int(domain.get("category_count", 0))]
		content.add_child(stats)
		var subtitle := Label.new()
		subtitle.text = str(domain.get("subtitle", ""))
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.add_theme_font_size_override("font_size", 11)
		content.add_child(subtitle)
		var category_names := PackedStringArray()
		for group in domain["groups"]:
			category_names.append(str(group.get("category_name", group.get("name", ""))))
		var categories_label := Label.new()
		categories_label.text = " · ".join(category_names)
		categories_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		categories_label.add_theme_font_size_override("font_size", 10)
		content.add_child(categories_label)
		var open_button := Button.new()
		open_button.text = "Открыть область →"
		open_button.pressed.connect(open_domain.bind(domain_id))
		content.add_child(open_button)
		_graph.add_child(graph_node)
	var aggregate: Dictionary = {}
	for edge in _edges:
		var relation_type := str(edge["type"])
		if _current_mode == "dependencies" and relation_type != "requires" and relation_type != "conflicts":
			continue
		var source := str(edge["source_id"])
		var target := str(edge["target_id"])
		var source_def := _definitions.get(source) as ObjectCapabilityDefinition
		var target_def := _definitions.get(target) as ObjectCapabilityDefinition
		if source_def == null or target_def == null:
			continue
		var source_domain := str(CapabilityMapData.get_domain_for_category(source_def.category_id)["id"])
		var target_domain := str(CapabilityMapData.get_domain_for_category(target_def.category_id)["id"])
		if source_domain == target_domain or not _domain_node_names.has(source_domain) or not _domain_node_names.has(target_domain):
			continue
		var key := source_domain + ">" + target_domain + ":" + relation_type
		if not aggregate.has(key):
			aggregate[key] = {"source": source_domain, "target": target_domain, "type": relation_type, "count": 0, "types": {}}
		var entry: Dictionary = aggregate[key]
		entry["count"] = int(entry["count"]) + 1
		(entry["types"] as Dictionary)[str(edge["type"])] = int((entry["types"] as Dictionary).get(str(edge["type"]), 0)) + 1
		aggregate[key] = entry
	for pair in aggregate.values():
		var source_node := str(pair["source"])
		var target_node := str(pair["target"])
		var type_id := _relation_type_id(str(pair["type"]))
		_graph.connect_node(str(_domain_node_names[source_node]), type_id - 1, str(_domain_node_names[target_node]), type_id - 1)
		var source_graph_node := _graph.get_node(str(_domain_node_names[source_node])) as GraphNode
		var target_graph_node := _graph.get_node(str(_domain_node_names[target_node])) as GraphNode
		var summary := "%s · %d связей" % [_relation_caption(str(pair["type"])), int(pair["count"])]
		if source_graph_node != null:
			source_graph_node.tooltip_text += "\n→ %s: %s" % [str(_domains[source_node]["name"]), summary]
		if target_graph_node != null:
			target_graph_node.tooltip_text += "\n← %s: %s" % [str(_domains[target_node]["name"]), summary]
	_domain_edges = []
	for pair in aggregate.values():
		_domain_edges.append(pair)


func _build_domain_toolbar() -> void:
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 5)
	_layout.add_child(filters)
	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.placeholder_text = "Найти механику в этой области…"
	_search_input.text_changed.connect(_on_search_changed)
	filters.add_child(_search_input)
	_category_filter = OptionButton.new()
	_category_filter.add_item("Все подгруппы")
	_category_filter.set_item_metadata(0, "")
	var domain: Dictionary = _domains.get(_current_domain_id, {})
	for group in domain.get("groups", []):
		_category_filter.add_item(str(group.get("category_name", group.get("name", ""))))
		_category_filter.set_item_metadata(_category_filter.item_count - 1, str(group.get("id", "")))
	_category_filter.item_selected.connect(_on_category_selected)
	filters.add_child(_category_filter)
	_relation_filter = OptionButton.new()
	_relation_filter.add_item("Все зависимости" if _current_mode == "dependencies" else "Все связи")
	_relation_filter.set_item_metadata(0, "")
	for relation_type in RELATION_TYPE_ORDER:
		if _current_mode == "dependencies" and relation_type != "requires" and relation_type != "conflicts":
			continue
		_relation_filter.add_item(str(RELATION_TYPE_NAMES[relation_type]))
		_relation_filter.set_item_metadata(_relation_filter.item_count - 1, str(relation_type))
	_relation_filter.item_selected.connect(_on_relation_selected)
	filters.add_child(_relation_filter)
	for relation_index in range(_relation_filter.item_count):
		if str(_relation_filter.get_item_metadata(relation_index)) == _selected_relation_type:
			_relation_filter.select(relation_index)
	_status_filter = OptionButton.new()
	_status_filter.add_item("Все состояния")
	_status_filter.set_item_metadata(0, "all")
	_status_filter.add_item("Готовые")
	_status_filter.set_item_metadata(1, "ready")
	_status_filter.add_item("В разработке")
	_status_filter.set_item_metadata(2, "planned")
	_status_filter.item_selected.connect(_on_status_selected)
	filters.add_child(_status_filter)


func _build_domain_graph() -> void:
	_graph = _create_graph()
	_layout.add_child(_graph)
	_nodes_by_id.clear()
	_node_names_by_id.clear()
	var domain: Dictionary = _domains.get(_current_domain_id, {})
	var mechanics: Array = domain.get("mechanics", [])
	var group_indices: Dictionary = {}
	for group_index in range((domain.get("groups", []) as Array).size()):
		var group: Dictionary = domain["groups"][group_index]
		for capability_id in group["mechanics"]:
			group_indices[str(capability_id)] = group_index
	var visible_ids: Dictionary = {}
	var index_by_id: Dictionary = {}
	var group_local_counts: Dictionary = {}
	for capability_id in mechanics:
		var id := str(capability_id)
		var definition := _definitions.get(id) as ObjectCapabilityDefinition
		if definition == null or not _matches_filters(definition):
			continue
		visible_ids[id] = true
		var group_index := int(group_indices.get(id, 0))
		index_by_id[id] = int(group_local_counts.get(group_index, 0))
		group_local_counts[group_index] = int(group_local_counts.get(group_index, 0)) + 1
	for capability_id in mechanics:
		var id := str(capability_id)
		if not visible_ids.has(id):
			continue
		var definition := _definitions[id] as ObjectCapabilityDefinition
		var node_name := "Mechanic_" + id
		_node_names_by_id[id] = node_name
		var graph_node := _create_mechanic_node(node_name, definition, str(group_indices.get(id, 0)))
		graph_node.position_offset = CapabilityMapLayout.mechanic_position(
			int(index_by_id[id]),
			int(group_indices.get(id, 0))
		)
		_graph.add_child(graph_node)
		_nodes_by_id[id] = graph_node
	_graph.clear_connections()
	for edge in _edges:
		var source := str(edge["source_id"])
		var target := str(edge["target_id"])
		if not _nodes_by_id.has(source) or not _nodes_by_id.has(target):
			continue
		var relation_type := str(edge["type"])
		if _current_mode == "dependencies" and relation_type != "requires" and relation_type != "conflicts":
			continue
		if not _selected_relation_type.is_empty() and relation_type != _selected_relation_type:
			continue
		var type_id := _relation_type_id(relation_type)
		_graph.connect_node(str(_node_names_by_id[source]), type_id - 1, str(_node_names_by_id[target]), type_id - 1)


func _create_graph() -> GraphEdit:
	var graph := GraphEdit.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.show_grid = true
	graph.show_zoom_buttons = true
	graph.minimap_enabled = true
	graph.minimap_size = Vector2(190, 130)
	graph.add_valid_connection_type(0, 0)
	for type_id in RELATION_TYPE_IDS.values():
		graph.add_valid_connection_type(int(type_id), int(type_id))
	graph.type_names = {
		1: "Обязательная зависимость",
		2: "Конфликт",
		3: "Рекомендация",
		4: "Расширение",
		5: "Альтернатива",
		6: "Тематическая связь"
	}
	return graph


func _create_mechanic_node(node_name: String, definition: ObjectCapabilityDefinition, group_index: String) -> GraphNode:
	var node := GraphNode.new()
	node.name = node_name
	node.title = definition.display_name
	node.custom_minimum_size = Vector2(190, 145)
	node.resizable = false
	for relation_type in RELATION_TYPE_ORDER:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(RELATION_TYPE_NAMES[relation_type])
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", RELATION_TYPE_COLORS[relation_type])
		row.add_child(label)
		node.add_child(row)
		var slot_index := node.get_child_count() - 1
		var type_id := _relation_type_id(str(relation_type))
		var color: Color = RELATION_TYPE_COLORS[relation_type]
		node.set_slot(slot_index, true, type_id, color, true, type_id, color)
	var status := Label.new()
	status.text = "%s  ·  %s" % [CapabilityMapData.get_group_for_category(definition.category_id), "Готово" if definition.is_ready() else "В разработке"]
	status.add_theme_font_size_override("font_size", 9)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_child(status)
	var actions := HBoxContainer.new()
	var relations_button := Button.new()
	relations_button.text = "Связи"
	relations_button.tooltip_text = "Показать ближайшие входящие и исходящие связи"
	relations_button.pressed.connect(open_local_focus.bind(definition.capability_id))
	actions.add_child(relations_button)
	var open_button := Button.new()
	open_button.text = "Карточка"
	open_button.tooltip_text = definition.description
	open_button.pressed.connect(_on_focus_pressed.bind(definition.capability_id))
	actions.add_child(open_button)
	node.add_child(actions)
	_focus_button_count += 1
	return node


func _build_local_from_catalog() -> void:
	var definition := _definitions.get(_focused_capability_id) as ObjectCapabilityDefinition
	if definition == null:
		_hint.text = "Механика не найдена в каталоге."
		return
	var neighbors := CapabilityMapData.get_neighbors(_focused_capability_id, _edges)
	_build_local_graph(_focused_capability_id, neighbors, definition, false)


func _build_local_graph(
	capability_id: String,
	neighbors: Array[Dictionary],
	focused_definition: ObjectCapabilityDefinition,
	add_hint: bool = true
) -> void:
	_focused_capability_id = capability_id
	_graph = _create_graph()
	_layout.add_child(_graph)
	_nodes_by_id.clear()
	_node_names_by_id.clear()
	var center := _create_local_node("FocusedCapability", focused_definition, "Выбранная механика", true)
	center.position_offset = Vector2(360, 250)
	_graph.add_child(center)
	_nodes_by_id[capability_id] = center
	_node_names_by_id[capability_id] = "FocusedCapability"
	var unique_neighbors: Array[Dictionary] = []
	var neighbor_indices: Dictionary = {}
	for entry in neighbors:
		var neighbor_id := str(entry.get("capability_id", ""))
		if neighbor_id.is_empty() or neighbor_id == capability_id or not _definitions.has(neighbor_id):
			continue
		if not neighbor_indices.has(neighbor_id):
			neighbor_indices[neighbor_id] = unique_neighbors.size()
			unique_neighbors.append(entry)
	for index in range(unique_neighbors.size()):
		var entry: Dictionary = unique_neighbors[index]
		var neighbor_id := str(entry["capability_id"])
		var neighbor_definition := _definitions.get(neighbor_id) as ObjectCapabilityDefinition
		if neighbor_definition == null:
			continue
		var relation_type := str(entry.get("type", entry.get("relation_type", "related")))
		var explanation := str(entry.get("explanation", ""))
		var domain_info := CapabilityMapData.get_domain_for_category(neighbor_definition.category_id)
		var node_name := "Neighbor_" + str(index)
		var node := _create_local_node(node_name, neighbor_definition, _relation_caption(relation_type), false)
		node.tooltip_text = "%s\\n%s\\n%s" % [
			str(domain_info.get("name", "Другая область")),
			str(RELATION_TYPE_NAMES.get(relation_type, "Связано")),
			explanation if not explanation.is_empty() else "Объяснение для этой связи пока не добавлено."
		]
		node.position_offset = CapabilityMapLayout.local_position(index + 1, unique_neighbors.size() + 1)
		_graph.add_child(node)
		_nodes_by_id[neighbor_id] = node
		_node_names_by_id[neighbor_id] = node_name
	for entry in neighbors:
		var neighbor_id := str(entry.get("capability_id", ""))
		if not _node_names_by_id.has(neighbor_id):
			continue
		var relation_type := str(entry.get("type", entry.get("relation_type", "related")))
		var type_id := _relation_type_id(relation_type)
		var neighbor_name := str(_node_names_by_id[neighbor_id])
		var neighbor_node := _nodes_by_id.get(neighbor_id) as GraphNode
		var explanation := str(entry.get("explanation", ""))
		var relation_summary := "%s: %s" % [_relation_caption(relation_type), explanation if not explanation.is_empty() else "Объяснение пока не добавлено."]
		if neighbor_node != null and not neighbor_node.tooltip_text.contains(relation_summary):
			neighbor_node.tooltip_text += "\n" + relation_summary
		if bool(entry.get("is_reverse", false)):
			_graph.connect_node(neighbor_name, type_id - 1, "FocusedCapability", type_id - 1)
		else:
			_graph.connect_node("FocusedCapability", type_id - 1, neighbor_name, type_id - 1)
	if add_hint:
		_hint.text = "Показаны %d наиболее значимых прямых связей. Наведи курсор на соседний узел, чтобы увидеть тип связи и объяснение." % unique_neighbors.size()


func _create_local_node(node_name: String, definition: ObjectCapabilityDefinition, subtitle: String, is_center: bool) -> GraphNode:
	var node := GraphNode.new()
	node.name = node_name
	node.title = definition.display_name
	node.custom_minimum_size = Vector2(230, 185)
	node.resizable = false
	for relation_type in RELATION_TYPE_ORDER:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(RELATION_TYPE_NAMES[relation_type])
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", RELATION_TYPE_COLORS[relation_type])
		row.add_child(label)
		node.add_child(row)
		var slot_index := node.get_child_count() - 1
		var type_id := _relation_type_id(str(relation_type))
		var color: Color = RELATION_TYPE_COLORS[relation_type]
		node.set_slot(slot_index, true, type_id, color, true, type_id, color)
	var content := VBoxContainer.new()
	node.add_child(content)
	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle_label)
	var domain := CapabilityMapData.get_domain_for_category(definition.category_id)
	var category_label := Label.new()
	category_label.text = str(domain.get("name", definition.category_name)) + " · " + ("Готово" if definition.is_ready() else "В разработке")
	category_label.add_theme_font_size_override("font_size", 9)
	content.add_child(category_label)
	if not is_center:
		var relations_button := Button.new()
		relations_button.text = "Исследовать связи"
		relations_button.pressed.connect(open_local_focus.bind(definition.capability_id))
		content.add_child(relations_button)
	var open_button := Button.new()
	open_button.text = "Открыть карточку в каталоге"
	open_button.pressed.connect(_on_focus_pressed.bind(definition.capability_id))
	content.add_child(open_button)
	var color := Color(0.98, 0.72, 0.32) if is_center else Color(0.55, 0.72, 0.95)
	node.add_theme_color_override("title_color", color)
	_focus_button_count += 1
	return node


func _build_domain_edges() -> Array[Dictionary]:
	var aggregate: Dictionary = {}
	for edge in _edges:
		var source_definition := _definitions.get(str(edge["source_id"])) as ObjectCapabilityDefinition
		var target_definition := _definitions.get(str(edge["target_id"])) as ObjectCapabilityDefinition
		if source_definition == null or target_definition == null:
			continue
		var source_domain := str(CapabilityMapData.get_domain_for_category(source_definition.category_id)["id"])
		var target_domain := str(CapabilityMapData.get_domain_for_category(target_definition.category_id)["id"])
		if source_domain == target_domain:
			continue
		var key := source_domain + ">" + target_domain + ":" + str(edge["type"])
		if not aggregate.has(key):
			aggregate[key] = {
				"source_domain": source_domain,
				"target_domain": target_domain,
				"type": str(edge["type"]),
				"count": 0,
				"explanations": []
			}
		var value: Dictionary = aggregate[key]
		value["count"] = int(value["count"]) + 1
		var explanations: Array = value["explanations"]
		var explanation := str(edge.get("explanation", ""))
		if not explanation.is_empty() and explanations.size() < 3 and not explanations.has(explanation):
			explanations.append(explanation)
		aggregate[key] = value
	var result: Array[Dictionary] = []
	for value in aggregate.values():
		result.append(value)
	return result


func _matches_filters(definition: ObjectCapabilityDefinition) -> bool:
	var query_match := true
	if not _search_query.is_empty():
		var searchable := (
			definition.display_name + " " + definition.description + " " + definition.category_name + " "
			+ " ".join(definition.keywords) + " " + " ".join(definition.synonyms) + " "
			+ " ".join(definition.example_queries) + " " + CapabilityMapData.get_group_for_category(definition.category_id)
		).to_lower().replace("ё", "е")
		query_match = _matches_searchable_text(searchable, _search_query)
	if not query_match:
		return false
	if not _selected_category_id.is_empty() and definition.category_id != _selected_category_id:
		return false
	if _selected_status == "ready" and not definition.is_ready():
		return false
	if _selected_status == "planned" and definition.is_ready():
		return false
	return true


func _matches_searchable_text(searchable: String, query: String) -> bool:
	if query.is_empty() or searchable.contains(query):
		return true
	var query_tokens := _tokenize_search(query)
	var searchable_tokens := _tokenize_search(searchable)
	for query_token in query_tokens:
		var found := false
		for searchable_token in searchable_tokens:
			if _tokens_share_search_stem(query_token, searchable_token):
				found = true
				break
		if not found:
			return false
	return not query_tokens.is_empty()


func _tokenize_search(value: String) -> PackedStringArray:
	var normalized := value.to_lower().replace("ё", "е")
	for punctuation in [",", ".", "!", "?", ":", ";", "(", ")", "[", "]", "-", "_", "\n", "\t"]:
		normalized = normalized.replace(punctuation, " ")
	var tokens := PackedStringArray()
	for raw_token in normalized.split(" ", false):
		var token := raw_token.strip_edges()
		if token.length() >= 2 and not tokens.has(token):
			tokens.append(token)
	return tokens


func _tokens_share_search_stem(first: String, second: String) -> bool:
	if first == second:
		return true
	var shared_length := mini(4, mini(first.length(), second.length()))
	return shared_length >= 4 and first.left(shared_length) == second.left(shared_length)


func _on_search_changed(value: String) -> void:
	_search_query = value.strip_edges().to_lower().replace("ё", "е")
	_rebuild_domain_graph_only()


func _on_category_selected(index: int) -> void:
	_selected_category_id = str(_category_filter.get_item_metadata(index))
	_rebuild_domain_graph_only()


func _on_relation_selected(index: int) -> void:
	_selected_relation_type = str(_relation_filter.get_item_metadata(index))
	_rebuild_domain_graph_only()


func _on_status_selected(index: int) -> void:
	_selected_status = str(_status_filter.get_item_metadata(index))
	_rebuild_domain_graph_only()


func _rebuild_domain_graph_only() -> void:
	if _current_mode != "domain" and _current_mode != "dependencies":
		return
	var previous_search := _search_input.text if _search_input != null else _search_query
	var previous_category := _selected_category_id
	var previous_relation := _selected_relation_type
	var previous_status := _selected_status
	_rebuild_view()
	if _search_input != null:
		_search_input.text = previous_search
	if _category_filter != null:
		for index in range(_category_filter.item_count):
			if str(_category_filter.get_item_metadata(index)) == previous_category:
				_category_filter.select(index)
	if _relation_filter != null:
		for index in range(_relation_filter.item_count):
			if str(_relation_filter.get_item_metadata(index)) == previous_relation:
				_relation_filter.select(index)
	if _status_filter != null:
		for index in range(_status_filter.item_count):
			if str(_status_filter.get_item_metadata(index)) == previous_status:
				_status_filter.select(index)


func open_domain(domain_id: String) -> void:
	if not _domains.has(domain_id):
		return
	_current_domain_id = domain_id
	_current_mode = "domain"
	_selected_category_id = ""
	_selected_relation_type = ""
	_selected_status = "all"
	_search_query = ""
	_rebuild_view()


func open_local_focus(capability_id: String) -> void:
	if not _definitions.has(capability_id):
		return
	_focused_capability_id = capability_id
	_current_mode = "local"
	_rebuild_view()


func _show_overview() -> void:
	_current_mode = "overview"
	_current_domain_id = ""
	_selected_relation_type = ""
	_rebuild_view()


func _show_current_domain() -> void:
	if _current_domain_id.is_empty():
		return
	_current_mode = "domain"
	_selected_relation_type = ""
	_rebuild_view()


func _show_local_focus() -> void:
	if _focused_capability_id.is_empty():
		return
	open_local_focus(_focused_capability_id)


func _show_dependencies() -> void:
	_current_mode = "dependencies"
	_selected_relation_type = ""
	_rebuild_view()


func _go_back() -> void:
	if _current_mode == "local":
		_current_mode = "domain" if not _current_domain_id.is_empty() else "overview"
	elif _current_mode == "dependencies":
		_current_mode = "domain"
	else:
		_current_mode = "overview"
	_selected_relation_type = ""
	_rebuild_view()


func _on_focus_pressed(capability_id: String) -> void:
	focus_requested.emit(capability_id)
	_close_window()


func _domain_order(domain_id: String) -> int:
	for index in range(CapabilityMapData.DOMAINS.size()):
		if str(CapabilityMapData.DOMAINS[index]["id"]) == domain_id:
			return index
	return 999


func _relation_type_id(relation_type: String) -> int:
	return int(RELATION_TYPE_IDS.get(relation_type, RELATION_TYPE_IDS["related"]))


func _relation_caption(relation_type: String) -> String:
	return str(RELATION_TYPE_NAMES.get(relation_type, "Связано"))


func get_domain_count() -> int:
	return _domains.size()

func get_domain_mechanic_count(domain_id: String) -> int:
	var domain: Dictionary = _domains.get(domain_id, {})
	return (domain.get("mechanics", []) as Array).size()


func get_domain_id_for_category(category_id: String) -> String:
	return str(CapabilityMapData.get_domain_for_category(category_id).get("id", ""))


func get_domain_position(index: int) -> Vector2:
	return CapabilityMapLayout.domain_position(index)


func get_mechanic_count() -> int:
	return _definitions.size()


func get_edge_count() -> int:
	return _edges.size()


func get_explained_edge_count() -> int:
	var count := 0
	for edge in _edges:
		if not str(edge.get("explanation", "")).strip_edges().is_empty():
			count += 1
	return count


func get_domain_edge_count() -> int:
	return _domain_edges.size()


func get_visible_node_count() -> int:
	var count := 0
	for value in _nodes_by_id.values():
		var node := value as GraphNode
		if node != null and node.visible:
			count += 1
	return count


func get_visible_mechanic_count() -> int:
	if _current_mode == "overview":
		var count := 0
		for domain in _domains.values():
			count += (domain["mechanics"] as Array).size()
		return count
	if _current_domain_id.is_empty():
		return get_visible_node_count()
	var domain: Dictionary = _domains.get(_current_domain_id, {})
	var count := 0
	for capability_id in domain.get("mechanics", []):
		var definition := _definitions.get(str(capability_id)) as ObjectCapabilityDefinition
		if definition != null and _matches_filters(definition):
			count += 1
	return count


func get_node_count() -> int:
	return _graph.get_child_count() if _graph != null else 0


func get_connection_count() -> int:
	return _graph.get_connection_list().size() if _graph != null else 0


func get_focus_button_count() -> int:
	return _focus_button_count


func get_relation_type_count() -> int:
	return RELATION_TYPE_IDS.size()


func has_connection(from_node: String, to_node: String) -> bool:
	return _graph.is_node_connected(from_node, 0, to_node, 0) if _graph != null else false


func filter_full_map(query: String) -> void:
	_search_query = query.strip_edges().to_lower().replace("ё", "е")
	if _search_input != null:
		_search_input.text = query
	_rebuild_domain_graph_only()


func set_full_category_filter(category_id: String) -> void:
	_selected_category_id = category_id.strip_edges().to_lower()
	_rebuild_domain_graph_only()


func set_full_relation_filter(relation_type: String) -> void:
	_selected_relation_type = relation_type.strip_edges().to_lower()
	_rebuild_domain_graph_only()


func _close_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null
	_layout = null
	_toolbar = null
	_graph = null
	_hint = null
	_breadcrumb = null
	_search_input = null
	_category_filter = null
	_relation_filter = null
	_status_filter = null
	_nodes_by_id.clear()
	_node_names_by_id.clear()
	_domain_node_names.clear()
	_focus_button_count = 0
	_search_query = ""
	_selected_category_id = ""
	_selected_relation_type = ""
	_selected_status = "all"
