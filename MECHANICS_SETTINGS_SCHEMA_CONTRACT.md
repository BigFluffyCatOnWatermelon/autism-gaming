# Единый контракт схемы настроек механик

Статус: проектный контракт этапа 2. Реализация ведётся частями; реализованные части и непроверенные ограничения перечислены в разделе 13. Контракт не меняет сохранённые значения до реализации мигратора.

## 1. Единственный источник истины

**Component владеет значением. Capability владеет пользовательским представлением.**

- `ObjectComponentDefinition` — канонический источник ключа, типа, default, ограничений и проверки значения.
- `ObjectCapabilityDefinition.settings_schema` — presentation overlay: подпись, описание, группа, порядок, уровень, видимость и редактор. Каждое поле ссылается на пару `component_id + setting_key`.
- `ObjectCapabilitySelection.settings_by_component` — единственное хранилище изменённых значений.
- `ObjectCapabilityService` — валидация, зависимости и применение значений.
- Сериализация и legacy-форматы — внутренний слой. UI не редактирует JSON/CSV/словари напрямую.

Ключ уникален внутри компонента, а не глобально. Одинаковый `setting_key` у разных `component_id` не объединяется автоматически.

## 2. Состав descriptor

### 2.1 Каноническое описание component setting

Обязательные поля:

| Поле | Назначение |
|---|---|
| `key` | Стабильный внутренний ключ; не использовать как подпись |
| `display_name` | Короткая пользовательская подпись |
| `value_type` | Канонический тип значения |
| `default_value` | Default для нового компонента |
| `group_name` | Пользовательская группа |

Дополнительные поля:

| Поле | Назначение |
|---|---|
| `description` | Пояснение, что меняет параметр |
| `required` | Нельзя сохранить механику без корректного значения |
| `nullable` | Разрешено ли пустое значение |
| `has_range`, `minimum`, `maximum`, `step` | Ограничения числового поля |
| `unit` | Секунды, градусы, пиксели, проценты и т. п. |
| `options` | Enum-значения с пользовательскими подписями |
| `default_provider` | ID доверенного GDScript-провайдера динамического default |
| `deprecated`, `legacy_aliases` | Устаревшее поле и его миграционные ключи |

### 2.2 Capability presentation descriptor

| Поле | Назначение |
|---|---|
| `component_id`, `setting_key` | Ссылка на каноническое поле |
| `display_name`, `description` | Контекстная подпись и пояснение |
| `group_id`, `group_name`, `group_order` | Группа |
| `order` | Порядок поля внутри группы |
| `level` | Basic / Advanced / Expert |
| `visibility` | Условия отображения |
| `editor` | Явный вид редактора |

Capability overlay не должен независимо менять `value_type`, `default_value`, диапазон и единицы component setting. Если меняется семантика значения, меняется канонический component descriptor и добавляется миграция. Обязательность `required` принадлежит только component descriptor. Capability overlay может задавать `level` и другое presentation metadata, но не `required`, тип, default или ограничения.

## 3. Типы и редакторы

| Тип | Редактор | Сохраняемое значение |
|---|---|---|
| Boolean | Switch / checkbox | bool |
| Integer | Числовое поле, slider при диапазоне | int |
| Float | Числовое поле, slider при диапазоне | float |
| String | Однострочный/многострочный текст | String |
| Vector2 | Связанные X/Y поля | Vector2 |
| Color | Color picker | Color либо legacy hex через adapter |
| Enum | Dropdown value/label | стабильное enum value |
| CatalogReference | Выбор из каталога проекта | стабильный ID |
| ResourceReference | Типизированный resource picker | resource path/resource |
| GameplayTableReference | FileDialog с проверкой типа таблицы | путь к GameplayTableDefinition |
| StructuredList | Таблица со строками и действиями | typed Array |
| StructuredObject | Специализированный вложенный редактор | typed Dictionary/Resource |

Тип String сам по себе не означает свободный ввод ID, пути, CSV или JSON. Способ ввода задаётся editor metadata или typed reference.

### Запрещено в обычном UI

- Универсальная JSON textarea для `*_json`.
- CSV-поля для списков предметов, инструментов, фракций, сезонов и других сущностей.
- Свободный ввод `item_id`, `tool_id`, `object_id`, component ID или capability ID, если есть каталог.
- Строковый enum без списка допустимых вариантов.
- Второе редактирование того же значения во вкладке Components.

JSON допустим только как внутреннее хранение/сериализация/обмен/диагностика. Сложные данные редактируются визуально, сериализация выполняется программно.

## 4. Специализированные редакторы

| Данные | Редактор |
|---|---|
| Loot / resource drops | Предмет из каталога, количество min/max, шанс, условия |
| Recipes | Входы, количество, результат, время и требования |
| Production | Ресурс/предмет, интервал, количество за цикл |
| Tool requirements | Инструмент из каталога, уровень/сила, тип материала |
| Resistances / immunities | Таблица типа урона/эффекта и множителя/флага |
| Weak points | Зоны/части, множитель урона, условия попадания |
| Patrol / movement routes | Упорядоченный список точек с визуальным редактированием |
| Dialogue | Темы и списки реплик |
| Conditions / rules | Конструктор условий из операторов и ссылок на каталог |
| World generation | Таблицы регионов, биомов, плотности и сезонов |
| Animation variants/events | Каталог анимаций и typed frame events |

Если визуальный редактор структуры ещё не реализован, поле не показывается как JSON в обычном режиме.

## 5. Группы, уровни и видимость

- Группы имеют `group_id`, `group_name`, `group_order`; поля — `order`.
- Пустые группы скрываются; component ID не используется как заголовок.
- Basic — обычные настройки; Advanced — точная настройка поведения; Expert — редкие/технические настройки.
- Advanced и Expert скрыты по умолчанию и открываются явным переключателем.
- Уровень не заменяет условную видимость: поле может быть Advanced и показываться только при включённой функции.

В текущих 20 package-модулях нет `level`/ `advanced` metadata, поэтому 347 package-полей получают Basic по умолчанию. Это нужно классифицировать вручную; нельзя автоматически считать все JSON-поля Expert.

## 6. Валидация

- Component layer проверяет тип и числовые ограничения; `required` хранится в component descriptor.
- `required` проверяется `ObjectCapabilityService.validate_selections()`; UI должен показывать обязательность и проверять пустое значение до отправки.
- Enum принимает только значения из options.
- CatalogReference проверяет существование ID в нужном каталоге.
- ResourceReference и GameplayTableReference проверяют тип ресурса/таблицы.
- Числа должны быть конечными; minimum не выше maximum; step положительный.
- UI показывает фактически сохранённое значение после нормализации.
- Неизвестные legacy-поля сохраняются при чтении/повторной записи, даже если редактор их не отображает.

`pickup.item_id` помечено required только в core component descriptor. Web UI показывает обязательность и использует поисковый каталог предметов; backend повторно проверяет пустое значение.

## 7. Defaults

- Статический default принадлежит component descriptor.
- Динамический default объявляется стабильным `default_provider` и реализуется доверенным GDScript-кодом.
- Не хранить исполняемый код или произвольный путь функции в данных.
- `characteristics` генерирует defaults из `DEFINITIONS[item].defaults`; это должно стать типизированным provider.
- Default применяется при создании нового значения, но не перезаписывает сохранённые значения старого объекта.

## 8. Ссылки и миграции

- В UI показывать название/детали ресурса, в данных хранить стабильный ID/path.
- Существующие `merged_setting_key_map` и `merged_component_id` остаются источниками миграции объединённых механик.
- `harvest_duration` переносится в `can_be_harvested.harvest_time_seconds`; alias сохраняется до проверки старых объектов.
- Legacy package component `is_pickup_item` и core `pickup` должны сводиться через явную миграцию, сохраняя старый pickup radius 48.0.
- Неизвестные поля не удалять; формат сериализации не менять без версии/миграции.

## 9. API и хранение

UI продолжает отправлять типизированные изменения как список `{ component_id, setting_key, value }`. Черновые значения остаются в `ObjectCapabilitySelection.settings_by_component`. Не создавать отдельный JavaScript источник defaults, ranges или состояния. Формат сериализации не зависит от того, какой UI-editor показан пользователю.

## 10. Текущие проблемы, которые контракт устраняет

1. Низкоуровневый Components inspector всё ещё использует устаревший ограниченный renderer и остаётся вторым путём редактирования.
2. Основной `openCapabilitySettingsDialog()` теперь группирует поля и читает level/required/options/units/editor metadata.
3. Сырые `*_json`/`*_csv` и неразмеченные ID больше не отображаются как свободный ввод в основном инспекторе механик; для legacy table data сохранён только программный импорт.
4. `renderComponentsInspector()` оставляет отдельный низкоуровневый путь редактирования тех же настроек.
5. `renderInstalled()` и `renderBehaviorInspector()` дублируют список механик.
6. Статические счётчики каталога 200/160/40 не пересчитывают package-level readiness.
7. Шесть package-групп имеют runtime_status Planned; UI блокирует их подключение независимо от наличия component scripts.

## 11. Чек-лист контракта перед renderer

- [ ] У каждого поля есть владелец и стабильный key.
- [ ] У каждого поля есть label и понятное описание либо задача на описание.
- [ ] Type/default/range берутся только из component definition.
- [ ] Нет конфликтующих capability overrides для type/default/range.
- [x] Enum содержит value/label пары и проходит schema validation.
- [ ] Catalog/resource references имеют тип и проверку существования.
- [ ] Сложные данные не представлены raw JSON/CSV.
- [x] Required проверяется backend и визуально обозначается UI.
- [x] Level и group отображаются в общем renderer механик.
- [ ] Legacy aliases и неизвестные поля сохраняются.
- [ ] Один параметр имеет один источник истины и один обычный путь редактирования.

## 12. Порядок внедрения

1. Утвердить контракт и проверить его на текущих built-in/package полях.
2. Расширить descriptor и schema validation без изменения сохранённых значений.
3. Добавить единый renderer стандартных типов и групп.
4. Подключить Basic/Advanced/Expert и required.
5. Подключить typed catalog/resource references.
6. Реализовать специализированные редакторы.
7. Убрать дублирующий Components inspector из обычного режима, сохранив debug/advanced путь.
8. Добавить миграции для legacy JSON/CSV и объединённых component keys.
9. Проверить runtime wiring и GUI в Godot; статический анализ не считать GUI-приёмкой.

## 13. Реализация — 2026-11-13 и 2026-11-14

### Реализовано в исходниках (статическая проверка)

- `ObjectComponentDefinition.get_setting_definitions()` возвращает нормализованные копии descriptors: group/ordering metadata, Basic/Advanced/Expert, visibility, unit, nullable/required, options и editor metadata. Исходные `setting_definitions`, defaults и сохранённые значения не мутируются.
- Старые `group_name` и порядок объявления используются как fallback. Обычные String поля получают text editor; `*_id`, `*_json`, `*_csv`, `*_path` и другие технические строковые структуры не превращаются в свободный ввод без явного typed editor.
- `ObjectComponentCatalog` проверяет базовые типы метаданных, уровни, совместимость editor с value type, options, enum default, reference/resource types, числовые границы, default в диапазоне и положительный конечный step. Поддержан Color в setting validation и Variant type.
- `ObjectCapabilityCatalog` разрешает overlay менять только presentation metadata. Попытка переопределить тип, default, диапазон, единицы, required, options или другое каноническое поле отклоняется при регистрации.
- `pickup.item_id` остаётся required только в component descriptor и размечено как `catalog_reference` / `reference_type = item`.
- `animals.resource_item_id` и `world_time.output_item_id` также используют `catalog_reference` / `reference_type = item`.
- `drops_loot_on_destroy.loot_table_json` получил первый `StructuredList` editor (`loot_table`): строки предмет/chance/min/max используют item catalog, Add/Remove и сериализацию обратно в прежний JSON-массив. Поле находится в Expert, поскольку основной путь — `loot_table_path` / `.tres`.
- Backend передаёт options из `ItemCatalogService`; UI показывает название и категорию, поддерживает поиск, а в `ObjectCapabilitySelection` сохраняет стабильный item ID.
- Основной Web mechanic renderer строит группы по схеме, открывает Basic по умолчанию, сворачивает Advanced и Expert, и использует Switch, Number, Slider/Range, Text, Multiline Text, Enum, Vector2, Color, item catalog select и существующий GameplayTable picker.
- Строковые legacy JSON/CSV и неразмеченные ID не рендерятся как свободные поля. Для имеющихся GameplayTableDefinition сохранён программный перенос legacy JSON в ресурс без обычной JSON textarea.
- Сохранение остаётся на едином пути `capability_settings_save` → `ObjectCapabilitySelection`; отдельное JS-хранилище значений или defaults не добавлялось.
- `tests/object_builder_capability_metadata_smoke.gd` расширен проверками нормализации, overlay, editor/options, ranges/defaults, Color и каталожных item options.

### Осталось выполнить / проверить

- Godot smoke-тесты и GUI-приёмка не запускались: Godot отсутствует в доступной среде. Статическая проверка не считается runtime-проверкой.
- Typed pickers для tools (пока сервис умеет фильтровать tools, но все поля ещё не размечены), objects, остальных resources и tables требуют подключения и приёмки.
- Универсальные `StructuredList` / `StructuredObject` editors ещё не завершены: реализован только первый `loot_table` editor; recipes, production, resistances, weak points, routes, schedules, loot conditions и другие составные данные остаются открытыми.
- Условия `visibility` пока не вычисляются: основной renderer показывает `always`, а условные поля помечает как пока недоступные.
- Components inspector и некоторые дублирующие пути UI остаются отдельной задачей плана.
- Полная совместимость старых сохранений, неизвестных полей и сторонних расширений требует отдельной проверки и миграционного этапа.
- Поведение renderer, каталожного picker, сохранения, переключения объектов и Undo должно быть вручную проверено в настольном Godot.

