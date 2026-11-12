@tool
extends RefCounted
## Built-in templates restored from the original Object Builder template library.
## Each entry is converted to the native ObjectDefinition model before it reaches the UI.

const CreationService = preload("res://addons/object_builder/services/object_creation_service.gd")
const PropertyScript = preload("res://scripts/object_system/object_property_definition.gd")
const CapabilityService = preload("res://scripts/object_system/object_capability_service.gd")

const TEMPLATE_DATA: Array[Dictionary] = [
  {
    "id": "tpl_001",
    "category": "Природа",
    "name": "Камень",
    "emoji": "🪨",
    "description": "Добываемый камень",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "can_be_mined",
      "yields_resources"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_002",
    "category": "Природа",
    "name": "Большой валун",
    "emoji": "⛰️",
    "description": "Крупная каменная глыба с большим запасом прочности",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "can_be_mined",
      "yields_resources"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_003",
    "category": "Природа",
    "name": "Медная жила",
    "emoji": "🟠",
    "description": "Месторождение медной руды",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "can_be_mined",
      "yields_resources"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_004",
    "category": "Природа",
    "name": "Железная жила",
    "emoji": "⚙️",
    "description": "Месторождение железной руды",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "can_be_mined",
      "yields_resources"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_005",
    "category": "Природа",
    "name": "Золотая жила",
    "emoji": "🟡",
    "description": "Редкое месторождение золота",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "can_be_mined",
      "yields_resources"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_006",
    "category": "Природа",
    "name": "Угольная жила",
    "emoji": "⚫",
    "description": "Источник угля для топлива",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "can_be_mined",
      "yields_resources"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_007",
    "category": "Природа",
    "name": "Кристальная жила",
    "emoji": "💎",
    "description": "Редкий кристаллический ресурс",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "can_be_mined",
      "yields_resources"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_008",
    "category": "Природа",
    "name": "Дуб",
    "emoji": "🌳",
    "description": "Дерево для рубки и получения древесины",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "requires_tool",
      "yields_resources",
      "leaves_remains"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_009",
    "category": "Природа",
    "name": "Сосна",
    "emoji": "🌲",
    "description": "Хвойное дерево с древесиной и хвоей",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "requires_tool",
      "yields_resources",
      "leaves_remains"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_010",
    "category": "Природа",
    "name": "Пальма",
    "emoji": "🌴",
    "description": "Тропическое дерево с собственными ресурсами",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "requires_tool",
      "yields_resources",
      "leaves_remains"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_011",
    "category": "Природа",
    "name": "Фруктовое дерево",
    "emoji": "🍎",
    "description": "Дерево с повторно появляющимися плодами",
    "type": "Растение",
    "caps": [
      "can_be_harvested",
      "yields_resources",
      "has_regrowth",
      "has_seasonal_yield"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_012",
    "category": "Природа",
    "name": "Сухое дерево",
    "emoji": "🥀",
    "description": "Мёртвое дерево для сухой древесины",
    "type": "Ресурс",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "requires_tool",
      "yields_resources"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_013",
    "category": "Природа",
    "name": "Пень",
    "emoji": "🪵",
    "description": "Остаток дерева после рубки",
    "type": "Декорация",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_be_harvested",
      "yields_resources"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_014",
    "category": "Природа",
    "name": "Куст ягод",
    "emoji": "🫐",
    "description": "Куст с повторным урожаем ягод",
    "type": "Растение",
    "caps": [
      "can_be_harvested",
      "yields_resources",
      "has_regrowth",
      "has_seasonal_yield"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_015",
    "category": "Природа",
    "name": "Кустарник",
    "emoji": "🌿",
    "description": "Декоративный куст с коллизией",
    "type": "Растение",
    "caps": [
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_016",
    "category": "Природа",
    "name": "Высокая трава",
    "emoji": "🌾",
    "description": "Трава для срезания и сбора",
    "type": "Растение",
    "caps": [
      "can_be_harvested",
      "yields_resources",
      "has_regrowth"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_017",
    "category": "Природа",
    "name": "Гриб",
    "emoji": "🍄",
    "description": "Собираемый лесной гриб",
    "type": "Растение",
    "caps": [
      "can_be_harvested",
      "yields_resources"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_018",
    "category": "Природа",
    "name": "Цветок",
    "emoji": "🌼",
    "description": "Декоративный цветок для сбора",
    "type": "Растение",
    "caps": [
      "can_be_harvested",
      "yields_resources"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_019",
    "category": "Ферма",
    "name": "Пшеница",
    "emoji": "🌾",
    "description": "Культура с урожаем и сезонностью",
    "type": "Растение",
    "caps": [
      "can_be_harvested",
      "yields_resources",
      "has_regrowth",
      "has_seasonal_yield"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_020",
    "category": "Ферма",
    "name": "Морковь",
    "emoji": "🥕",
    "description": "Овощная культура",
    "type": "Растение",
    "caps": [
      "can_be_harvested",
      "yields_resources",
      "has_seasonal_yield"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_021",
    "category": "Ферма",
    "name": "Тыква",
    "emoji": "🎃",
    "description": "Крупная сезонная культура",
    "type": "Растение",
    "caps": [
      "can_be_harvested",
      "yields_resources",
      "has_seasonal_yield"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_022",
    "category": "Ферма",
    "name": "Саженец",
    "emoji": "🌱",
    "description": "Молодое дерево для выращивания",
    "type": "Растение",
    "caps": [
      "has_collision",
      "can_regrow"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_023",
    "category": "Ресурсы",
    "name": "Древесина",
    "emoji": "🪵",
    "description": "Материал после рубки дерева",
    "type": "Ресурс",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_024",
    "category": "Ресурсы",
    "name": "Камень-предмет",
    "emoji": "🪨",
    "description": "Подбираемый каменный материал",
    "type": "Ресурс",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_025",
    "category": "Ресурсы",
    "name": "Медная руда",
    "emoji": "🟠",
    "description": "Руда для переплавки",
    "type": "Ресурс",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_026",
    "category": "Ресурсы",
    "name": "Железная руда",
    "emoji": "⚙️",
    "description": "Руда для переплавки",
    "type": "Ресурс",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_027",
    "category": "Ресурсы",
    "name": "Золотая руда",
    "emoji": "🟡",
    "description": "Ценная руда для крафта",
    "type": "Ресурс",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_028",
    "category": "Ресурсы",
    "name": "Уголь",
    "emoji": "⚫",
    "description": "Топливный материал",
    "type": "Ресурс",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_029",
    "category": "Ресурсы",
    "name": "Ягоды",
    "emoji": "🫐",
    "description": "Собираемые ягоды для еды",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "is_consumable"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_030",
    "category": "Ресурсы",
    "name": "Яблоко",
    "emoji": "🍎",
    "description": "Плод для еды и рецептов",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "is_consumable",
      "has_item_value"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_031",
    "category": "Ресурсы",
    "name": "Семена",
    "emoji": "🌰",
    "description": "Семена для посадки",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_032",
    "category": "Ресурсы",
    "name": "Зелье здоровья",
    "emoji": "🧪",
    "description": "Расходуемое зелье",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "is_consumable"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_033",
    "category": "Ресурсы",
    "name": "Монета",
    "emoji": "🪙",
    "description": "Игровая валюта",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_034",
    "category": "Ресурсы",
    "name": "Ключ",
    "emoji": "🗝️",
    "description": "Предмет для открытия замков",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_035",
    "category": "Оружие",
    "name": "Деревянный меч",
    "emoji": "🗡️",
    "description": "Простое оружие ближнего боя",
    "type": "Оружие",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_036",
    "category": "Оружие",
    "name": "Каменный меч",
    "emoji": "⚔️",
    "description": "Улучшенный меч",
    "type": "Оружие",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_037",
    "category": "Оружие",
    "name": "Железный меч",
    "emoji": "⚔️",
    "description": "Надёжное оружие ближнего боя",
    "type": "Оружие",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_038",
    "category": "Оружие",
    "name": "Кинжал",
    "emoji": "🔪",
    "description": "Быстрое оружие с малой дистанцией",
    "type": "Оружие",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_039",
    "category": "Оружие",
    "name": "Боевой топор",
    "emoji": "🪓",
    "description": "Тяжёлое оружие с сильным ударом",
    "type": "Оружие",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_040",
    "category": "Оружие",
    "name": "Лук",
    "emoji": "🏹",
    "description": "Дальнобойное оружие",
    "type": "Оружие",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_041",
    "category": "Оружие",
    "name": "Посох",
    "emoji": "🪄",
    "description": "Оружие для магических атак",
    "type": "Оружие",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_042",
    "category": "Оружие",
    "name": "Копьё",
    "emoji": "🔱",
    "description": "Оружие с увеличенной дистанцией удара",
    "type": "Оружие",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_043",
    "category": "Инструменты",
    "name": "Топор",
    "emoji": "🪓",
    "description": "Инструмент для рубки деревьев",
    "type": "Инструмент",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability",
      "has_tool_efficiency"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_044",
    "category": "Инструменты",
    "name": "Кирка",
    "emoji": "⛏️",
    "description": "Инструмент для добычи камня и руды",
    "type": "Инструмент",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "can_attack",
      "has_item_durability",
      "has_tool_efficiency"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_045",
    "category": "Инструменты",
    "name": "Мотыга",
    "emoji": "🪏",
    "description": "Инструмент для обработки почвы",
    "type": "Инструмент",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_046",
    "category": "Инструменты",
    "name": "Лейка",
    "emoji": "🚿",
    "description": "Инструмент для полива",
    "type": "Инструмент",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_047",
    "category": "Инструменты",
    "name": "Лопата",
    "emoji": "🥄",
    "description": "Инструмент для копания",
    "type": "Инструмент",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_048",
    "category": "Инструменты",
    "name": "Удочка",
    "emoji": "🎣",
    "description": "Инструмент для рыбалки",
    "type": "Инструмент",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_049",
    "category": "Инструменты",
    "name": "Ножницы",
    "emoji": "✂️",
    "description": "Инструмент для стрижки и сбора",
    "type": "Инструмент",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_050",
    "category": "Инструменты",
    "name": "Молоток",
    "emoji": "🔨",
    "description": "Инструмент для строительства и ремонта",
    "type": "Инструмент",
    "caps": [
      "is_pickup_item",
      "can_be_equipped",
      "has_item_durability"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_051",
    "category": "Контейнеры",
    "name": "Маленький сундук",
    "emoji": "📦",
    "description": "Компактное хранилище",
    "type": "Контейнер",
    "caps": [
      "can_interact",
      "can_be_opened",
      "can_be_closed",
      "has_inventory",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_052",
    "category": "Контейнеры",
    "name": "Большой сундук",
    "emoji": "🧰",
    "description": "Вместительное хранилище",
    "type": "Контейнер",
    "caps": [
      "can_interact",
      "can_be_opened",
      "can_be_closed",
      "has_inventory",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_053",
    "category": "Контейнеры",
    "name": "Бочка",
    "emoji": "🛢️",
    "description": "Контейнер для предметов или жидкостей",
    "type": "Контейнер",
    "caps": [
      "can_interact",
      "can_be_opened",
      "has_inventory",
      "has_collision"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_054",
    "category": "Контейнеры",
    "name": "Ящик",
    "emoji": "📦",
    "description": "Простой деревянный ящик",
    "type": "Контейнер",
    "caps": [
      "can_interact",
      "can_be_opened",
      "has_inventory",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_055",
    "category": "Контейнеры",
    "name": "Мешок",
    "emoji": "🎒",
    "description": "Небольшое переносное хранилище",
    "type": "Контейнер",
    "caps": [
      "can_interact",
      "has_inventory"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_056",
    "category": "Контейнеры",
    "name": "Сейф",
    "emoji": "🔐",
    "description": "Защищённое хранилище",
    "type": "Контейнер",
    "caps": [
      "can_interact",
      "can_be_opened",
      "has_inventory",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_057",
    "category": "Здания",
    "name": "Дом",
    "emoji": "🏠",
    "description": "Жилое здание с прочностью и коллизией",
    "type": "Здание",
    "caps": [
      "has_health",
      "can_receive_damage",
      "can_be_repaired",
      "has_collision",
      "blocks_movement"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_058",
    "category": "Здания",
    "name": "Хижина",
    "emoji": "🛖",
    "description": "Небольшое стартовое жилище",
    "type": "Здание",
    "caps": [
      "has_health",
      "has_collision",
      "blocks_movement"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_059",
    "category": "Здания",
    "name": "Амбар",
    "emoji": "🏚️",
    "description": "Хозяйственное здание для хранения",
    "type": "Здание",
    "caps": [
      "has_health",
      "has_collision",
      "blocks_movement"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_060",
    "category": "Здания",
    "name": "Башня",
    "emoji": "🗼",
    "description": "Высокое строение для защиты",
    "type": "Здание",
    "caps": [
      "has_health",
      "has_collision",
      "blocks_movement"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_061",
    "category": "Здания",
    "name": "Колодец",
    "emoji": "🪣",
    "description": "Объект для получения воды",
    "type": "Здание",
    "caps": [
      "can_interact",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_062",
    "category": "Здания",
    "name": "Костёр",
    "emoji": "🔥",
    "description": "Источник тепла и света",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated",
      "can_be_toggled",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_063",
    "category": "Здания",
    "name": "Печь",
    "emoji": "♨️",
    "description": "Станция переработки материалов",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated",
      "has_collision",
      "supports_item_crafting"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_064",
    "category": "Здания",
    "name": "Верстак",
    "emoji": "🛠️",
    "description": "Рабочее место для изготовления предметов",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated",
      "has_collision",
      "supports_item_crafting"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_065",
    "category": "Здания",
    "name": "Наковальня",
    "emoji": "⚒️",
    "description": "Станция обработки металла",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated",
      "has_collision",
      "supports_item_crafting"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_066",
    "category": "Мебель",
    "name": "Кровать",
    "emoji": "🛏️",
    "description": "Мебель для отдыха",
    "type": "Декорация",
    "caps": [
      "can_interact",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_067",
    "category": "Мебель",
    "name": "Стул",
    "emoji": "🪑",
    "description": "Предмет мебели",
    "type": "Декорация",
    "caps": [
      "can_interact",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_068",
    "category": "Мебель",
    "name": "Стол",
    "emoji": "🪵",
    "description": "Стол для интерьера",
    "type": "Декорация",
    "caps": [
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_069",
    "category": "Мебель",
    "name": "Шкаф",
    "emoji": "🚪",
    "description": "Шкаф с открытием и хранением",
    "type": "Контейнер",
    "caps": [
      "can_interact",
      "can_be_opened",
      "can_be_closed",
      "has_inventory",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_070",
    "category": "Мебель",
    "name": "Книжная полка",
    "emoji": "📚",
    "description": "Полка для интерьера",
    "type": "Декорация",
    "caps": [
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_071",
    "category": "Мебель",
    "name": "Фонарь",
    "emoji": "🏮",
    "description": "Стационарный источник света",
    "type": "Декорация",
    "caps": [
      "can_be_activated",
      "can_be_toggled"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_072",
    "category": "Механизмы",
    "name": "Дверь",
    "emoji": "🚪",
    "description": "Открываемая и закрываемая дверь",
    "type": "Механизм",
    "caps": [
      "has_collision",
      "can_interact",
      "can_be_opened",
      "can_be_closed"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_073",
    "category": "Механизмы",
    "name": "Запертая дверь",
    "emoji": "🔒",
    "description": "Дверь с условием открытия",
    "type": "Механизм",
    "caps": [
      "has_collision",
      "can_interact",
      "can_be_opened",
      "can_be_closed"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_074",
    "category": "Механизмы",
    "name": "Ворота",
    "emoji": "🚧",
    "description": "Большой открываемый проход",
    "type": "Механизм",
    "caps": [
      "has_collision",
      "can_interact",
      "can_be_opened",
      "can_be_closed"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_075",
    "category": "Механизмы",
    "name": "Рычаг",
    "emoji": "🕹️",
    "description": "Переключатель для запуска механизма",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated",
      "can_be_toggled"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_076",
    "category": "Механизмы",
    "name": "Кнопка",
    "emoji": "🔘",
    "description": "Кнопка для активации события",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_077",
    "category": "Механизмы",
    "name": "Нажимная плита",
    "emoji": "⬛",
    "description": "Плита, реагирующая на наступание",
    "type": "Механизм",
    "caps": [
      "can_be_activated",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_078",
    "category": "Механизмы",
    "name": "Ловушка-шипы",
    "emoji": "📌",
    "description": "Опасная активируемая ловушка",
    "type": "Механизм",
    "caps": [
      "has_collision",
      "can_be_activated",
      "can_attack"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_079",
    "category": "Механизмы",
    "name": "Взрывная бочка",
    "emoji": "🛢️",
    "description": "Разрушаемый объект со взрывом",
    "type": "Механизм",
    "caps": [
      "has_health",
      "can_receive_damage",
      "breaks_when_health_empty",
      "can_explode_on_destroy"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_080",
    "category": "Механизмы",
    "name": "Телепорт",
    "emoji": "🌀",
    "description": "Точка перехода между зонами",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_081",
    "category": "Механизмы",
    "name": "Подъёмник",
    "emoji": "↕️",
    "description": "Механизм вертикального перемещения",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_082",
    "category": "Персонажи",
    "name": "Игрок",
    "emoji": "🧑",
    "description": "Управляемый персонаж",
    "type": "Персонаж",
    "caps": [
      "has_health",
      "can_receive_damage",
      "can_move",
      "can_walk",
      "can_run",
      "can_attack",
      "has_stamina",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_083",
    "category": "Персонажи",
    "name": "Торговец",
    "emoji": "🧔",
    "description": "NPC для торговли",
    "type": "Персонаж",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "can_interact",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_084",
    "category": "Персонажи",
    "name": "Житель",
    "emoji": "🧑‍🌾",
    "description": "Мирный NPC для диалогов",
    "type": "Персонаж",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "can_interact",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_085",
    "category": "Персонажи",
    "name": "Стражник",
    "emoji": "💂",
    "description": "Охраняющий NPC с атакой",
    "type": "Персонаж",
    "caps": [
      "has_health",
      "can_receive_damage",
      "can_move",
      "can_walk",
      "can_attack",
      "has_armor",
      "has_collision"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_086",
    "category": "Персонажи",
    "name": "Скелет",
    "emoji": "💀",
    "description": "Враждебный противник ближнего боя",
    "type": "Персонаж",
    "caps": [
      "has_health",
      "can_receive_damage",
      "can_move",
      "can_walk",
      "can_attack",
      "breaks_when_health_empty"
    ],
    "health": 100,
    "damage": 12
  },
  {
    "id": "tpl_087",
    "category": "Персонажи",
    "name": "Слизень",
    "emoji": "🟢",
    "description": "Простой монстр для арены",
    "type": "Персонаж",
    "caps": [
      "has_health",
      "can_receive_damage",
      "can_move",
      "can_attack",
      "breaks_when_health_empty"
    ],
    "health": 100,
    "damage": 12
  },
  {
    "id": "tpl_088",
    "category": "Персонажи",
    "name": "Голем",
    "emoji": "🗿",
    "description": "Медленный тяжёлый противник",
    "type": "Персонаж",
    "caps": [
      "has_health",
      "can_receive_damage",
      "can_move",
      "can_attack",
      "has_armor",
      "breaks_when_health_empty"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_089",
    "category": "Персонажи",
    "name": "Летучая мышь",
    "emoji": "🦇",
    "description": "Летающее враждебное существо",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_receive_damage",
      "can_move",
      "can_attack",
      "breaks_when_health_empty"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_090",
    "category": "Животные",
    "name": "Кролик",
    "emoji": "🐇",
    "description": "Мирное животное, которое можно кормить",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "can_be_fed",
      "can_be_tamed",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_091",
    "category": "Животные",
    "name": "Курица",
    "emoji": "🐔",
    "description": "Домашняя птица, дающая яйца",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "can_be_fed",
      "has_collision",
      "can_produce_resources"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_092",
    "category": "Животные",
    "name": "Корова",
    "emoji": "🐄",
    "description": "Домашнее животное для получения молока",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "can_be_fed",
      "has_collision",
      "can_produce_resources"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_093",
    "category": "Животные",
    "name": "Овца",
    "emoji": "🐑",
    "description": "Домашнее животное для получения шерсти",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "can_be_fed",
      "has_collision",
      "can_produce_resources"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_094",
    "category": "Животные",
    "name": "Свинья",
    "emoji": "🐖",
    "description": "Домашнее животное на ферме",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "can_be_fed",
      "has_collision",
      "can_produce_resources"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_095",
    "category": "Животные",
    "name": "Лиса",
    "emoji": "🦊",
    "description": "Осторожное дикое животное",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_096",
    "category": "Животные",
    "name": "Волк",
    "emoji": "🐺",
    "description": "Хищник, способный атаковать",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_receive_damage",
      "can_move",
      "can_attack",
      "has_collision"
    ],
    "health": 30,
    "damage": 12
  },
  {
    "id": "tpl_097",
    "category": "Животные",
    "name": "Олень",
    "emoji": "🦌",
    "description": "Пугливое лесное животное",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_098",
    "category": "Животные",
    "name": "Рыба",
    "emoji": "🐟",
    "description": "Водное существо",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_be_picked_up"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_099",
    "category": "Животные",
    "name": "Питомец",
    "emoji": "🐕",
    "description": "Приручаемый компаньон",
    "type": "Животное",
    "caps": [
      "has_health",
      "can_move",
      "can_walk",
      "can_be_fed",
      "can_be_tamed",
      "can_interact"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_100",
    "category": "Декорации",
    "name": "Каменная статуя",
    "emoji": "🗿",
    "description": "Стационарная декоративная статуя",
    "type": "Декорация",
    "caps": [
      "has_collision"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_101",
    "category": "Декорации",
    "name": "Забор",
    "emoji": "🪵",
    "description": "Ограждение, блокирующее движение",
    "type": "Декорация",
    "caps": [
      "has_collision",
      "blocks_movement"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_102",
    "category": "Декорации",
    "name": "Каменная стена",
    "emoji": "🧱",
    "description": "Сегмент стены с прочностью",
    "type": "Здание",
    "caps": [
      "has_health",
      "can_receive_damage",
      "has_collision",
      "blocks_movement"
    ],
    "health": 100,
    "damage": 0
  },
  {
    "id": "tpl_103",
    "category": "Декорации",
    "name": "Факел на стене",
    "emoji": "🔥",
    "description": "Настенный источник света",
    "type": "Декорация",
    "caps": [
      "can_be_activated",
      "can_be_toggled"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_104",
    "category": "Декорации",
    "name": "Куча листьев",
    "emoji": "🍂",
    "description": "Осенняя декорация",
    "type": "Декорация",
    "caps": [],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_105",
    "category": "Декорации",
    "name": "Снежный сугроб",
    "emoji": "❄️",
    "description": "Зимний элемент окружения",
    "type": "Декорация",
    "caps": [],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_106",
    "category": "Декорации",
    "name": "Лужа",
    "emoji": "💧",
    "description": "Декоративная водная поверхность",
    "type": "Декорация",
    "caps": [],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_107",
    "category": "Декорации",
    "name": "Каменная дорожка",
    "emoji": "🪨",
    "description": "Элемент мощения",
    "type": "Декорация",
    "caps": [],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_108",
    "category": "Транспорт",
    "name": "Телега",
    "emoji": "🛒",
    "description": "Простой транспорт для перемещения",
    "type": "Транспорт",
    "caps": [
      "has_collision",
      "can_be_pushed"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_109",
    "category": "Транспорт",
    "name": "Лодка",
    "emoji": "🛶",
    "description": "Водный транспорт",
    "type": "Транспорт",
    "caps": [
      "has_collision",
      "can_move"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_110",
    "category": "Транспорт",
    "name": "Вагонетка",
    "emoji": "🚋",
    "description": "Шахтёрская вагонетка для рельсов",
    "type": "Транспорт",
    "caps": [
      "has_collision",
      "can_move"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_111",
    "category": "Транспорт",
    "name": "Портал перехода",
    "emoji": "🌀",
    "description": "Объект для перехода между игровыми зонами",
    "type": "Механизм",
    "caps": [
      "can_interact",
      "can_be_activated"
    ],
    "health": 30,
    "damage": 0
  },
  {
    "id": "tpl_112",
    "category": "Ресурсы",
    "name": "Яйцо",
    "emoji": "🥚",
    "description": "Продукт курицы для еды и кулинарии",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "is_consumable"
    ],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_113",
    "category": "Ресурсы",
    "name": "Молоко",
    "emoji": "🥛",
    "description": "Продукт животноводства для еды и рецептов",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "is_consumable"
    ],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_114",
    "category": "Ресурсы",
    "name": "Шерсть",
    "emoji": "🧶",
    "description": "Материал, получаемый при стрижке овец",
    "type": "Ресурс",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_115",
    "category": "Ресурсы",
    "name": "Трюфель",
    "emoji": "🍄",
    "description": "Редкий продукт, который может находить свинья",
    "type": "Предмет",
    "caps": [
      "is_pickup_item",
      "is_stackable",
      "has_item_value"
    ],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_116",
    "category": "Ресурсы",
    "name": "Кристалл",
    "emoji": "💎",
    "description": "Кристаллический материал из кристальной жилы",
    "type": "Ресурс",
    "caps": ["is_pickup_item", "is_stackable", "has_item_value"],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_117",
    "category": "Ресурсы",
    "name": "Гриб (предмет)",
    "emoji": "🍄",
    "description": "Собранный гриб, который можно использовать в еде",
    "type": "Предмет",
    "caps": ["is_pickup_item", "is_stackable", "is_consumable"],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_118",
    "category": "Ресурсы",
    "name": "Зерно пшеницы",
    "emoji": "🌾",
    "description": "Урожай пшеницы после сбора",
    "type": "Предмет",
    "caps": ["is_pickup_item", "is_stackable", "has_item_value"],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_119",
    "category": "Ресурсы",
    "name": "Морковь (предмет)",
    "emoji": "🥕",
    "description": "Собранная морковь",
    "type": "Предмет",
    "caps": ["is_pickup_item", "is_stackable", "is_consumable"],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_120",
    "category": "Ресурсы",
    "name": "Тыква (предмет)",
    "emoji": "🎃",
    "description": "Собранная тыква",
    "type": "Предмет",
    "caps": ["is_pickup_item", "is_stackable", "is_consumable"],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_121",
    "category": "Ресурсы",
    "name": "Растительное волокно",
    "emoji": "🧵",
    "description": "Волокнистый материал, собираемый с высокой травы",
    "type": "Ресурс",
    "caps": ["is_pickup_item", "is_stackable", "has_item_value"],
    "health": 1,
    "damage": 0
  },
  {
    "id": "tpl_122",
    "category": "Ресурсы",
    "name": "Слиток железа",
    "emoji": "🔩",
    "description": "Металл после переплавки железной руды",
    "type": "Ресурс",
    "caps": ["is_pickup_item", "is_stackable", "has_item_value"],
    "health": 1,
    "damage": 0
  }
]

const DEFAULT_TEMPLATE_RELATIONS: Dictionary = {
  "tpl_001": [{"target":"tpl_024","mechanic":"breaks_when_health_empty","kind":"drop","quantity":2}],
  "tpl_002": [{"target":"tpl_024","mechanic":"breaks_when_health_empty","kind":"drop","quantity":5}],
  "tpl_003": [{"target":"tpl_025","mechanic":"breaks_when_health_empty","kind":"drop","quantity":2}],
  "tpl_004": [{"target":"tpl_026","mechanic":"breaks_when_health_empty","kind":"drop","quantity":2}],
  "tpl_005": [{"target":"tpl_027","mechanic":"breaks_when_health_empty","kind":"drop","quantity":1}],
  "tpl_006": [{"target":"tpl_028","mechanic":"breaks_when_health_empty","kind":"drop","quantity":3}],
  "tpl_007": [{"target":"tpl_116","mechanic":"breaks_when_health_empty","kind":"drop","quantity":1}],
  "tpl_008": [
    {"target":"tpl_023","mechanic":"breaks_when_health_empty","kind":"drop","quantity":3},
    {"target":"tpl_013","mechanic":"breaks_when_health_empty","kind":"remains","quantity":1}
  ],
  "tpl_009": [
    {"target":"tpl_023","mechanic":"breaks_when_health_empty","kind":"drop","quantity":2},
    {"target":"tpl_013","mechanic":"breaks_when_health_empty","kind":"remains","quantity":1}
  ],
  "tpl_010": [
    {"target":"tpl_023","mechanic":"breaks_when_health_empty","kind":"drop","quantity":2},
    {"target":"tpl_013","mechanic":"breaks_when_health_empty","kind":"remains","quantity":1}
  ],
  "tpl_011": [{"target":"tpl_030","mechanic":"can_be_harvested","kind":"harvest","quantity":2}],
  "tpl_012": [{"target":"tpl_023","mechanic":"breaks_when_health_empty","kind":"drop","quantity":1}],
  "tpl_013": [{"target":"tpl_023","mechanic":"breaks_when_health_empty","kind":"drop","quantity":1}],
  "tpl_014": [{"target":"tpl_029","mechanic":"can_be_harvested","kind":"harvest","quantity":3}],
  "tpl_016": [{"target":"tpl_121","mechanic":"can_be_harvested","kind":"harvest","quantity":2}],
  "tpl_017": [{"target":"tpl_117","mechanic":"can_be_harvested","kind":"harvest","quantity":1}],
  "tpl_018": [{"target":"tpl_031","mechanic":"can_be_harvested","kind":"harvest","quantity":2}],
  "tpl_019": [{"target":"tpl_118","mechanic":"can_be_harvested","kind":"harvest","quantity":3}],
  "tpl_020": [{"target":"tpl_119","mechanic":"can_be_harvested","kind":"harvest","quantity":1}],
  "tpl_021": [{"target":"tpl_120","mechanic":"can_be_harvested","kind":"harvest","quantity":1}],
  "tpl_063": [
    {"target":"tpl_026","mechanic":"supports_item_crafting","kind":"input","quantity":2},
    {"target":"tpl_028","mechanic":"supports_item_crafting","kind":"input","quantity":1},
    {"target":"tpl_122","mechanic":"supports_item_crafting","kind":"produce","quantity":1}
  ],
  "tpl_064": [
    {"target":"tpl_023","mechanic":"supports_item_crafting","kind":"input","quantity":5},
    {"target":"tpl_024","mechanic":"supports_item_crafting","kind":"input","quantity":1},
    {"target":"tpl_035","mechanic":"supports_item_crafting","kind":"produce","quantity":1}
  ],
  "tpl_065": [
    {"target":"tpl_122","mechanic":"supports_item_crafting","kind":"input","quantity":2},
    {"target":"tpl_037","mechanic":"supports_item_crafting","kind":"produce","quantity":1}
  ],
  "tpl_091": [{"target":"tpl_112","mechanic":"can_produce_resources","kind":"produce","quantity":1}],
  "tpl_092": [{"target":"tpl_113","mechanic":"can_produce_resources","kind":"produce","quantity":1}],
  "tpl_093": [{"target":"tpl_114","mechanic":"can_produce_resources","kind":"produce","quantity":1}],
  "tpl_094": [{"target":"tpl_115","mechanic":"can_produce_resources","kind":"produce","quantity":1}]
}


static var _cache: Dictionary = {}


static func _build_default_relations(template_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entries: Array = DEFAULT_TEMPLATE_RELATIONS.get(template_id, [])
	var placements := {
		"drop": "drop",
		"remains": "replace",
		"harvest": "spawn",
		"produce": "spawn",
		"input": "consume"
	}
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		if not entry is Dictionary:
			continue
		var relation_kind := str(entry.get("kind", "related"))
		var default_y := -12.0 if relation_kind in ["drop", "harvest", "produce"] else 0.0
		var local_position: Dictionary = entry.get("local_position", {"x": 0.0, "y": default_y})
		result.append({
			"relation_id": "builtin_" + template_id + "_" + str(index + 1),
			"target_object_id": "builtin_" + str(entry.get("target", "")),
			"mechanic_id": str(entry.get("mechanic", "")),
			"kind": relation_kind,
			"label": str(entry.get("label", "")),
			"quantity": maxi(1, int(entry.get("quantity", 1))),
			"settings": {
				"placement": str(entry.get("placement", placements.get(relation_kind, "attach"))),
				"local_position": local_position.duplicate(true),
				"rotation": float(entry.get("rotation", 0.0)),
				"local_scale": {"x": 1.0, "y": 1.0}
			}
		})
	return result


static func get_all_definitions() -> Array[ObjectDefinition]:
	var result: Array[ObjectDefinition] = []
	for data in TEMPLATE_DATA:
		var template_id := str(data.get("id", ""))
		if not _cache.has(template_id):
			_cache[template_id] = _build_definition(data)
		var definition := _cache.get(template_id) as ObjectDefinition
		if definition != null:
			result.append(definition)
	return result


static func find_definition(object_id: String) -> ObjectDefinition:
	var clean_id := object_id.strip_edges()
	if not clean_id.begins_with("builtin_"):
		return null
	var template_id := clean_id.trim_prefix("builtin_")
	for data in TEMPLATE_DATA:
		if str(data.get("id", "")) != template_id:
			continue
		if not _cache.has(template_id):
			_cache[template_id] = _build_definition(data)
		var cached := _cache.get(template_id) as ObjectDefinition
		return cached.duplicate(true) as ObjectDefinition if cached != null else null
	return null


static func is_builtin_id(object_id: String) -> bool:
	return object_id.begins_with("builtin_tpl_")


static func _build_definition(data: Dictionary) -> ObjectDefinition:
	var template_id := str(data.get("id", ""))
	var object_type := str(data.get("type", "Другое"))
	var profile_id := _profile_id_for_type(object_type)
	var profile := ObjectCreationProfileRegistry.get_definition(profile_id)
	var creation := CreationService.create_empty_draft({
		"display_name": str(data.get("name", "Новый объект")),
		"category": str(data.get("category", "Без категории")),
		"description": str(data.get("description", "")),
		"tags": [object_type, str(data.get("category", ""))]
	}, profile)
	var definition := creation.get("definition") as ObjectDefinition
	if definition == null:
		return null

	definition.schema_version = ObjectDefinition.CURRENT_SCHEMA_VERSION
	definition.object_id = "builtin_" + template_id
	definition.display_name = str(data.get("name", "Новый объект"))
	definition.description = str(data.get("description", ""))
	definition.category = str(data.get("category", "Без категории"))
	definition.subcategory = ""
	definition.object_type = object_type
	definition.root_type = _root_type_for(data)
	definition.is_template = true
	definition.template_id = definition.object_id
	definition.preview_emoji = str(data.get("emoji", "◆"))
	definition.scene = null
	definition.scene_path = ""

	var template_caps: Array = data.get("caps", [])
	if _has_any(template_caps, ["has_health", "can_receive_damage", "breaks_when_health_empty"]):
		_set_or_add_property(definition, "health", "Здоровье / прочность", "Integer", int(data.get("health", 30)), "Характеристики", 0.0, 99999.0)
	var damage := int(data.get("damage", 0))
	if damage > 0:
		_set_or_add_property(definition, "damage", "Урон", "Integer", damage, "Бой", 0.0, 99999.0)

	definition.capabilities = _build_native_capabilities(template_caps)
	definition.relations = _build_default_relations(template_id)
	return definition


static func _build_native_capabilities(template_caps: Array) -> Array[ObjectCapabilitySelection]:
	var selections: Array[ObjectCapabilitySelection] = []
	for raw_id in template_caps:
		var capability_id := str(raw_id).strip_edges().to_lower()
		var capability := ObjectCapabilityCatalog.get_definition_reference(capability_id)
		# A built-in template may only enable mechanics that actually exist and are
		# marked ready in the native catalogue. Placeholder web-only IDs are ignored.
		if capability == null or not capability.is_ready():
			continue
		var plan := CapabilityService.plan_selection_change(selections, capability_id, true)
		if not bool(plan.get("ok", false)):
			continue
		selections.clear()
		for value in plan.get("selections", []):
			if value is ObjectCapabilitySelection:
				selections.append(value as ObjectCapabilitySelection)
	return selections


static func _set_or_add_property(
	definition: ObjectDefinition,
	property_id: String,
	display_name: String,
	value_type: String,
	default_value: Variant,
	group_name: String,
	minimum: float,
	maximum: float
) -> void:
	for existing in definition.custom_properties:
		if existing == null or existing.property_id != property_id:
			continue
		existing.display_name = display_name
		existing.value_type = value_type
		existing.default_value = default_value
		existing.group_name = group_name
		existing.has_range = true
		existing.minimum = minimum
		existing.maximum = maximum
		return
	var property_definition := PropertyScript.new() as ObjectPropertyDefinition
	property_definition.property_id = property_id
	property_definition.display_name = display_name
	property_definition.value_type = value_type
	property_definition.default_value = default_value
	property_definition.group_name = group_name
	property_definition.has_range = true
	property_definition.minimum = minimum
	property_definition.maximum = maximum
	definition.custom_properties.append(property_definition)


static func _profile_id_for_type(object_type: String) -> String:
	match object_type:
		"Ресурс":
			return "resource"
		"Предмет":
			return "item"
		"Оружие":
			return "weapon"
		"Инструмент":
			return "tool"
		"Здание":
			return "construction"
		"Персонаж":
			return "npc"
		"Животное":
			return "animal"
		"Декорация":
			return "decoration"
		"Транспорт":
			return "transport"
		"Контейнер", "Механизм":
			return "interactive"
		"Растение":
			return "decoration"
		_:
			return "other"


static func _root_type_for(data: Dictionary) -> String:
	var object_type := str(data.get("type", "Другое"))
	var object_name := str(data.get("name", ""))
	var caps: Array = data.get("caps", [])
	if object_type == "Персонаж" or (object_type == "Животное" and object_name != "Рыба"):
		return "CharacterBody2D"
	if object_name == "Рыба":
		return "Area2D"
	if object_type in ["Предмет", "Оружие", "Инструмент", "Контейнер"]:
		return "Area2D"
	if object_type == "Здание":
		return "StaticBody2D"
	if object_type == "Ресурс":
		return "Area2D" if "is_pickup_item" in caps else "StaticBody2D"
	if object_type == "Механизм":
		return "Area2D" if "can_interact" in caps else ("StaticBody2D" if _has_any(caps, ["has_collision", "blocks_movement"]) else "Node2D")
	if object_type == "Транспорт":
		return "CharacterBody2D" if "can_move" in caps else ("RigidBody2D" if "can_be_pushed" in caps else "Node2D")
	if _has_any(caps, ["has_collision", "blocks_movement"]):
		return "StaticBody2D"
	return "Node2D"


static func _has_any(values: Array, candidates: Array) -> bool:
	for candidate in candidates:
		if values.has(candidate):
			return true
	return false
