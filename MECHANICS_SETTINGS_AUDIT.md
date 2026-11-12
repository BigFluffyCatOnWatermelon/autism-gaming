# Аудит настроек игровых механик

> Снимок исходников ветки `feature/web-object-builder-godot-integration`. Это инвентаризация интерфейса и структуры данных, а не подтверждение runtime-работоспособности механик. Godot не запускался, GitHub Actions не использовались.

## 1. Объём инвентаризации

- Библиотека содержит 196 capability ID; шесть встроенных карточек добавляют четыре новых ID и переопределяют две библиотечные записи, поэтому базовый каталог содержит 200 уникальных ID. Package manifests объявляют 195 capability IDs; один из них (`falls_when_destroyed`) отсутствует в library data и добавляется отдельно. При успешной регистрации всех пакетов итоговый реестр должен содержать 201 ID. Статические счётчики 40/160 в `ObjectCapabilityLibraryData` не отражают package-level статусы и требуют замены на расчёт из реестра.
- Найдено **20 пакетов механик** в `addons/web_object_builder/mechanics`.
- В декларациях пакетов найдено **347 объявлений ключей настроек**, 315 уникальных ключей внутри пакетов и 291 различных имени ключей по всем пакетам. Повтор ключа сам по себе не доказывает дублирование: ключи изолированы компонентом; требуется сравнивать смысл и владельца значения.
- Источники: `ObjectCapabilityLibraryData`, `ObjectCapabilityCatalog`, `ObjectComponentCatalog`, `ObjectComponentDefinition`, `mechanics/*/module.gd`, `mechanics/*/component.gd`.

## 2. Реестр пакетов и полей

Повторная сверка всех 20 файлов `addons/web_object_builder/mechanics/*/module.gd` с владельцами компонентов выявила, что часть предыдущих подсчётов не учитывала дополнительные поля `enabled`, заданные отдельными словарями настроек. Матрица теперь содержит владельца capability/component ID для каждого поля.

| Пакет | Объявлений полей | Уникальных ключей в пакете |
|---|---:|---:|
| ai | 18 | 18 |
| animals | 23 | 23 |
| animation | 12 | 7 |
| audio_effects | 25 | 25 |
| characteristics | 3 | 3 |
| combat | 13 | 13 |
| construction | 28 | 22 |
| containers | 20 | 18 |
| defense | 13 | 13 |
| destruction | 16 | 16 |
| harvesting | 23 | 15 |
| interaction | 19 | 10 |
| inventory | 13 | 13 |
| items | 21 | 19 |
| movement | 17 | 17 |
| object_identity | 12 | 12 |
| physics | 19 | 19 |
| visual_appearance | 18 | 18 |
| world_generation | 18 | 18 |
| world_time | 16 | 16 |
| **Итого** | **347** | **315** |

По всем пакетам насчитывается 291 различное имя ключа. Встроенные core-компоненты добавляют ещё 35 отдельных объявлений; всего в статической матрице 382 объявления. Повтор ключа не означает общую настройку: владельцем всегда является пара capability/component ID.

Полная таблица с типом, исходным default, диапазоном, группой и владельцем находится в `MECHANICS_SETTINGS_FIELD_MATRIX.md`. Для `characteristics` три поля генерируются динамически для девяти resource components; конкретные defaults приведены отдельной таблицей.

## 3. Поля, которые сейчас требуют визуальных редакторов

### JSON-поля

Найденные JSON-настройки (их нельзя оставлять обычными текстовыми/textarea-контролами в пользовательском режиме):

- **ai:** patrol_points_json, dialogue_json
- **animals:** schedule_json, migration_by_season_json
- **animation:** variant_map_json
- **audio_effects:** surface_streams_json
- **construction:** world_bounds_json, build_cost_json, material_costs_json, upgrade_costs_json, stage_thresholds_json
- **containers:** initial_contents_json
- **harvesting:** tool_requirements_json, tool_power_json, resource_table_json, seasonal_yields_json, quality_chances_json, tool_efficiency_json, harvest_stages_json
- **inventory:** initial_items_json, filter_rules_json, recipes_json
- **movement:** route_json
- **object_identity:** metadata_json
- **visual_appearance:** directions_json, palette_json
- **world_generation:** conditions_json, variants_json, density_by_region_json, growth_stages_json, adaptation_rules_json, region_rules_json
- **world_time:** schedule_json, seasonal_values_json, weather_effects_json, event_rules_json, events_json

Важное уточнение: отдельные GameplayTableDefinition и FileDialog уже существуют для таблиц yield/loot/recipe/production. Это частичная основа, а не завершённые визуальные редакторы. В текущем диалоге механики старые поля с суффиксом `_json` явно превращаются в textarea; обработка JSON для loot_table_json валидирует массив, но пользователь всё равно редактирует сериализованный текст. Для прочих JSON-ключей общий fallback также остаётся текстовым полем.

### CSV, ID и ссылочные поля

Поля, требующие выбора из каталога, списка или специализированного редактора, а не ручного ввода строки:

- **animals:** taming_foods_csv, accepted_foods_csv, offspring_object_id, resource_item_id, allowed_biomes_csv
- **animation:** frames_csv
- **construction:** allowed_terrain_csv
- **containers:** lock_key_id, unlock_key_id, shared_group_id, owner_id, allowed_factions_csv
- **harvesting:** required_tool_id
- **inventory:** equipment_slots_csv
- **items:** currency_id, allowed_slots_csv
- **object_identity:** identity_id, tags_csv, faction_id
- **world_generation:** allowed_biomes_csv, allowed_regions_csv, blocked_regions_csv
- **world_time:** allowed_weather_csv, output_item_id

Список не означает, что все значения должны выбираться из одного каталога: например, tags, biomes, factions, tools, items, object references и equipment slots — разные типы ссылок и должны иметь разные источники/валидаторы.

## 4. Повторяющиеся ключи: что проверить, а что не сливать автоматически

Повторяющиеся имена, замеченные в пакетах:

- `patrol_speed`, `loop_route` — AI и Movement; проверить, не осталось ли двух владельцев одного маршрута.
- `production_table_path`, `amount_per_cycle` — Animals и World Time; общий тип редактора допустим, но производственные процессы и их runtime-состояния не следует автоматически сливать.
- `allowed_biomes_csv` — Animals и World Generation; возможен общий каталог биомов, но разные правила применения.
- `schedule_json` — Animals и World Time; это разные расписания и разные схемы данных.
- `max_weight` — Containers и Inventory; разные ограничения и разные владельцы состояния, не объединять.
- `default_sort` — Containers и Inventory; общий UI-перечень вариантов, но значения принадлежат разным системам.
- `maximum_distance` — Combat и Physics; проверить семантику, не считать дублем только по имени.
- `cooldown_seconds` — Movement и World Time; одинаковый тип времени, но разные действия.
- `enabled` повторяется у вложенных возможностей; это ожидаемые независимые переключатели, если они не управляют одним и тем же действием.
- В Containers повторяются `unlock_key_id` и `allow_links`; в Harvesting — `required_tool_id`, `minimum_mining_power`, `tool_power_json); в Construction — параметры сетки/поворота/preview; в Audio Effects — параметры аудио. Проверить повторные объявления внутри одного компонента/составной механики и оставить один источник значения.

## 5. Фактическая архитектура настроек

1. `ObjectCapabilityDefinition` — пользовательская карточка механики. Хранит capability ID, имя, описание, связи, component IDs и `settings_schema`.
2. `ObjectComponentDefinition` — низкоуровневая реализация. Хранит component ID, runtime script, `setting_definitions` и значения по умолчанию `settings`.
3. В большинстве пакетных механик `module.gd` содержит декларацию `DEFINITIONS`: в ней повторяются component ID, имя, описание, defaults и settings. Затем эти данные копируются в component definition и capability definition.
4. `ObjectCapabilityCatalog._resolve_settings_schema()` строит публичную схему из определений компонентов и накладывает capability overrides. Поэтому UI получает компонентно-адресованные настройки вида capability → component → setting key.
5. Значения черновика Web хранятся в `state.mechanicSettings[capabilityId][componentId][settingKey]`. Это отдельный слой пользовательского черновика; его нельзя путать с runtime-state компонента.
6. Встроенные core-компоненты дополнительно объявляют настройки в `ObjectComponentDefinition.get_builtin_setting_definitions()`.

**Архитектурный вывод:** описание одной функции частично повторяется в `DEFINITIONS`, `ObjectComponentDefinition`, capability schema и UI-специальных ветках. Следующий этап должен сделать типизированный контракт поля единым, не создавая вторую копию значений по умолчанию и не перенося runtime-логику в JavaScript.

## 6. Текущие места настройки в UI

- Левая панель **«Поведение → Подключённые механики»** выводит карточки; клик открывает `openCapabilitySettingsDialog()`.
- Правая вкладка **«Поведение»** повторно выводит те же установленные карточки и тоже открывает тот же диалог. Это дублирование списка/точки входа, хотя сам обработчик настроек общий.
- Правая вкладка **«Компоненты»** динамически добавляется в `bind()`. Она напрямую показывает настройки `state.components`, позволяет вручную добавлять/удалять компоненты и сохранять их отдельно. Это второй путь редактирования параметров тех же runtime-компонентов и потенциальный конфликт с настройками capability.
- Правая вкладка **«Связи»** отображает связи, часть которых также доступна из диалога механики через `mechanicRelationMarkup()`. Нужно решить, является ли это одним редактором связей с двумя представлениями или лишним дублированием.
- Диалог механики строит плоский список полей. Он не использует `group_name` для группировки; метаданные `level` / Basic-Advanced-Expert не передаются в конфигурацию формы. В результате схема уже содержит часть UX-метаданных, но UI их не применяет.
- `fieldType()` поддерживает только String, Integer, Float, Boolean и Vector2. String всегда становится текстовым полем, если нет специальной ветки `resource_path` или суффикса `_json`. Enum, каталог, массив, цвет, ресурс, диапазон/ползунок и составная структура не представлены единым типизированным контролом.
- Поля вроде `required_tool_id`, `item_id`, `offspring_object_id`, `faction_id`, `currency_id`, `output_item_id` остаются строками; CSV-списки также вводятся вручную.
- JSON import/export всего ObjectDefinition и технические свойства Godot не являются редактором механик. Их не удалять в рамках этого рефакторинга.

## 7. Выводы и порядок исправления

1. Сначала согласовать единую схему поля: тип, подпись, описание, группа, порядок, default, обязательность, ограничения, единицы, варианты выбора, источник/тип ссылки, уровень сложности, видимость и правила сериализации.
2. Явно разделить публичную схему UI и внутренние component settings. Значения и defaults должны иметь один канонический владелец.
3. Реализовать единый рендерер контролов, который читает схему; не добавлять условия по конкретным ключам в `openCapabilitySettingsDialog()`.
4. Добавить редакторы для JSON/CSV/reference fields: сначала loot/yield/recipes/production, затем маршруты/расписания/правила/варианты/фильтры/цветовые палитры и другие структуры.
5. Свести пользовательское редактирование к одному инспектору механики. Технический Components inspector убрать из обычного режима или перенести в отдельный диагностический режим после переноса его функций.
6. Разобрать дубли ключей по смыслу и владельцу данных, а не переименовывать/объединять их автоматически.
7. Только после этого мигрировать все пакеты и удалять legacy JSON UI, сохранив чтение старых сохранений.

## 8. Что ещё нужно завершить в этапе 1

- [ ] Для каждого из 326 объявлений поля выгрузить тип, default, диапазон, обязательность, группу и компонент-владелец в полную таблицу.
- [ ] Пройти все 200 capability definitions и связать каждую с её пакетным component definition, включая объединённые/скрытые возможности.
- [ ] Составить полную матрицу required/incompatible/merged dependencies.
- [ ] Сверить настройки каждого поля с runtime-потребителем и миграциями legacy keys.
- [ ] Отметить уже существующие визуальные редакторы по каждому составному типу.
- [ ] Завершить классификацию повторов ключей: дублирование значения, допустимая повторная схема или разные семантики.



## 9. Перепроверка runtime-источников и связей — 2026-11-12

- Для каждого пакета установлен путь runtime script из preload в `module.gd`. В пакетах с отдельными дочерними скриптами (animation, interaction, movement, object_identity, physics, visual_appearance) один пакет соответствует нескольким runtime-файлам.
- Явные `requires` в пакетных определениях найдены в Defense: `regenerates_health → has_health`; и Destruction: восемь возможностей требуют `breaks_when_health_empty`, `can_be_repaired` требует `has_health`. Это не полная матрица: связи из `ObjectCapabilityDefinition`, каталога и миграций нужно свести отдельно.
- Обнаружены merged-пакеты и родительские capability: AI → `has_ai`; Animation → `plays_idle_animation`; Audio Effects → `plays_ambient_sound` / `emits_particles`; Construction → `has_build_cost` / `can_be_placed`; Containers и Inventory → `stores_items`; Defense → `has_armor` / `has_health`; Destruction → `breaks_when_health_empty`; Harvesting → `can_be_harvested`; Interaction → `is_pickup_item` / `can_interact`; Items → `has_item_durability`; Movement → `can_move` / `has_ai`.
- Явный признак обязательности `required` почти не задаётся в пакетных декларациях. Встроенная схема компонента `pickup` отдельно помечает `item_id` как required. Не следует выводить обязательность из пустого default.
- Поля с одинаковыми именами и разными defaults подтверждены: например, `unlock_key_id` и `allow_links` в Containers; `required_tool_id`, `minimum_mining_power`, `tool_power_json` в Harvesting; `grid_size`, `grid_origin`, `rotation_step_degrees`, `preview_alpha`, `valid_color`, `invalid_color` в Construction; `volume_db`, `pitch_scale`, `bus`, `max_distance`, `attenuation` в Audio Effects. Это разные компонентные записи внутри одного пакета, поэтому перед объединением требуется определить владельца и семантику.
- Дополнительно к ранее указанным JSON/CSV полям найдены Defense: `damage_resistances_json`, `weak_points_json`, `status_resistances_json`, `immune_effects_csv`; Destruction: `parts_json`, `loot_table_json`; Combat: `combo_multipliers`; Destruction: `stage_thresholds`. Строковый тип сам по себе не задаёт визуальный редактор — нужно учитывать формат данных и runtime-парсер.

Проверка runtime-потребителей уточнила несколько случаев: `harvest_duration` — не потерянная настройка, а legacy alias, который `merged_setting_key_map` переносит в `can_be_harvested.harvest_time_seconds`; `construction.include_placement_data`, `inventory.transfer_mode` и `items.currency_id` не найдены в соответствующих runtime-компонентах. `items.pickup_radius` читается внешним consumer `WorldController._update_component_pickups()` для package-компонента `is_pickup_item`; встроенная карточка использует core-компонент `pickup` с тем же ключом и другим default (24.0 против 48.0). Это два pickup-пути, один из которых legacy/secondary. `interaction.can_interact` также является зарезервированной встроенной карточкой на core-компоненте `interactable`.
- Этап 1 остаётся открытым до построчной сверки всех полей с runtime-потребителями, конфликтами, миграциями и итоговой регистрацией каталога. Этот документ и матрица — статический аудит исходников, не запуск Godot и не runtime-приёмка.


## 10. Сверка ключей с runtime-кодом — 2026-11-12

Подробная таблица по каждому пакету и runtime-файлу добавлена в конец `MECHANICS_SETTINGS_FIELD_MATRIX.md`. По пакетным скриптам напрямую подтверждено чтение всех уникальных ключей в AI, Animals, Animation, Audio Effects, Characteristics, Combat, Containers, Defense, Destruction, Interaction, Movement, Object Identity, Physics, Visual Appearance, World Generation и World Time.

Открытые несоответствия:
- Construction: `include_placement_data` не читается `construction/component.gd`; нужен поиск editor/blueprint-потребителя.
- Inventory: `transfer_mode` не читается `inventory/component.gd`; `transfer_to()` не ветвится по режиму.
- Items: `currency_id` не читается компонентом предмета; внешний экономический consumer не подтверждён.
- Items: package `pickup_radius` читается `WorldController._update_component_pickups()` у package component `is_pickup_item`. Встроенная карточка `is_pickup_item` использует core component `pickup`; это два pickup-пути с разными defaults (24.0 и 48.0), которые нужно мигрировать/унифицировать без потери старых объектов.
- Harvesting: `harvest_duration` переносится в `harvest_time_seconds` через явную карту миграции; это допустимый alias, который нужно сохранить при будущей унификации.
- Interaction: package `can_interact` не регистрируется; встроенная карточка использует core `interactable`. Дочерние возможности используют явные merge mappings.

**Уточнение статуса каталога:** исходные package-модули содержат 197 записей `DEFINITIONS`, manifests содержат 196 component IDs и 195 capability IDs. Две встроенные карточки (`can_interact`, `is_pickup_item`) не должны повторно регистрироваться из package manifest. Library data содержит 198 уникальных ID; вместе с двумя встроенными карточками получается 200. Это не подтверждает успешность регистрации всех 195 package capabilities в текущем Godot-сеансе.

Этап 1 остаётся открытым до проверки оставшихся внешних consumers, конфликтов, миграций и фактического readiness реестра. Runtime-потребители сверены статически; Godot и GUI не запускались.


## 11. Встроенные настройки и обязательность

- В `ObjectComponentDefinition.get_builtin_setting_definitions()` найдено ещё 35 полей шести core-компонентов: `health`, `damageable`, `attack`, `destructible`, `pickup`, `interactable`. Они вынесены в отдельную таблицу `MECHANICS_SETTINGS_FIELD_MATRIX.md`; не входят в 347 package-объявлений.
- С учётом встроенных полей статический реестр содержит 382 исходных объявлений (347 package + 35 core). Это число объявлений, а не число уникальных настроек: одинаковые ключи могут принадлежать разным component IDs.
- Единственное поле с явным `required: true` в проверенных декларациях — `pickup.item_id`. `ObjectCapabilityService.validate_selections()` проверяет его на null/пустую строку и запрещает сохранить подключённую возможность без значения.
- Web UI при построении формы не передаёт `required` в markup и не показывает пользователю обязательность поля; ошибка появляется только при backend-валидации.
- Package-модули не задают required metadata. Нельзя трактовать пустые значения как required автоматически.
- `ObjectComponentDefinition.set_setting()` проверяет тип и диапазон, но не обязательность. Проверка required находится уровнем выше в `ObjectCapabilityService.validate_selections()`.
