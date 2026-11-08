extends RefCounted
class_name CapabilityMapDataService

const RELATION_TYPE_ORDER := ["requires", "conflicts", "recommends", "extends", "alternative", "related"]
const RELATION_TYPE_IDS := {
	"requires": 1,
	"conflicts": 2,
	"recommends": 3,
	"extends": 4,
	"alternative": 5,
	"related": 6
}

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
	if not RELATION_TYPE_IDS.has(relation_type):
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
		var a_type := RELATION_TYPE_ORDER.find(str(a["type"]))
		var b_type := RELATION_TYPE_ORDER.find(str(b["type"]))
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