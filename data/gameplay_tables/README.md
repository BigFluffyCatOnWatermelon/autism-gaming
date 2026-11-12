# Gameplay tables

Создавайте здесь отдельные ресурсы типа **GameplayTableDefinition** через Godot: FileSystem → New Resource → GameplayTableDefinition. Выберите `table_type`, заполните `table_id` и массив `entries`, затем укажите путь к ресурсу в соответствующем свойстве механики.

## Типы таблиц

- `yield` — обычная добыча / сбор. Запись: `item_id`, `chance` (0–1), `min`, `max`.
- `loot` — добыча при разрушении. Те же поля, но отдельный тип таблицы.
- `recipe` — рецепт. Запись: `recipe_id`, `ingredients` (словарь item_id → количество), `output` (словарь с item_id и amount).
- `production` — периодический выпуск. Запись: `item_id`, `amount_per_cycle`. Интервал остаётся настройкой механики.

Пример содержимого `entries` для yield/loot:

```gdscript
[
    {"item_id": "wood", "chance": 1.0, "min": 2, "max": 5},
    {"item_id": "stone", "chance": 0.25, "min": 1, "max": 2}
]
```

Пример recipes:

```gdscript
[
    {
        "recipe_id": "cake_slice_recipe",
        "ingredients": {"bread": 1, "milk": 1},
        "output": {"item_id": "cake_slice", "amount": 1}
    }
]
```

Пример production:

```gdscript
[
    {"item_id": "milk", "amount_per_cycle": 1},
    {"item_id": "manure", "amount_per_cycle": 2}
]
```

## Подключение

- Harvesting → `resource_table_path` — тип `yield`.
- Destruction → `loot_table_path` — тип `loot`.
- Inventory → `recipes_table_path` — тип `recipe`.
- Animals → `production_table_path` — тип `production`.
- WorldTime → `production_table_path` — тип `production`.

Если путь пустой, механика продолжает читать старое JSON-поле. Если внешний ресурс не найден или у него неверный тип, выводится предупреждение и используется legacy JSON. При сохранении ObjectDefinition новые ресурсы проверяются строго: класс, тип таблицы, структура записей и все ссылки `item_id` должны быть корректны. Ошибка блокирует сохранение объекта. Старые JSON-поля не блокируются этой проверкой и остаются резервным путём совместимости.

Существующие объекты автоматически не переписываются и не мигрируются. Путь можно выбрать кнопкой «Выбрать .tres». Рядом доступна команда «Создать из JSON»: она создаёт отдельный ресурс из текущей legacy-таблицы и подставляет его путь, не удаляя исходные настройки. Старые JSON-поля оставлены как резерв для обратной совместимости.
