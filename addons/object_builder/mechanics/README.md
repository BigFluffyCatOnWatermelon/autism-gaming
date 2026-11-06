# Object Builder mechanic modules — batch 01

Эта папка содержит автономные пакеты механик для Object Builder. Пакеты не интегрируются автоматически в центральные каталоги, загрузчики или интерфейс.

## Состав партии

| Пакет | ID механик | Количество |
|---|---|---:|
| `object_identity` | `has_unique_identity`, `can_be_enabled`, `can_be_disabled`, `has_custom_name`, `supports_tags`, `supports_factions`, `supports_rarity`, `supports_levels`, `supports_experience_points`, `supports_metadata` | 10 |
| `visual_appearance` | `has_sprite`, `has_multiple_visual_parts`, `supports_directional_sprites`, `supports_tint`, `supports_opacity`, `casts_visual_shadow`, `supports_outline`, `supports_layer_order`, `supports_flip`, `supports_palette_swap` | 10 |

Всего: **2 пакета, 20 отдельных component definitions**.

## Контракт

Каждый пакет содержит `module.cfg`, `module.gd`, `component.gd`, независимые скрипты компонентов, `tests/smoke.gd` и `INTEGRATION_REQUEST.md`. Все пользовательские настройки используют только String, Integer, Float, Boolean и Vector2.

Для восстановления runtime-состояния компоненты предоставляют `export_runtime_state()` и `import_runtime_state()`. Ядро должно сохранить это состояние вместе с экземпляром объекта. Сами пакеты не меняют проектные определения, реестры, фабрику, UI или загрузчик.

## Проверка

Smoke-тесты проверяют выполнение поведения и граничные случаи. Тесты требуют запуска внутри проекта Godot, где доступны `ObjectComponent`, `ObjectComponentDefinition` и `ObjectCapabilityDefinition`. В текущей среде Godot не запускался; прохождение тестов не заявляется.
