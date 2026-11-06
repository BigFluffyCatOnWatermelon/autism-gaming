# Стандарт автономного модуля механики — API v1

**Цель:** разрабатывать каждую игровую механику в отдельном чате и отдельной папке, не загружая контекст всего Object Builder и не меняя ядро при каждой новой возможности.

Главный принцип проекта: **«Сложность — внутри. Простота — снаружи».** Техническая реализация модуля может быть сложной, но пользовательская карточка, настройки и поведение должны быть простыми и понятными.

## 1. Что считается модулем

Модуль — самостоятельный пакет, который содержит runtime-код, пользовательскую карточку возможности, настройки, описание и собственные тесты.

~~~text
addons/object_builder/mechanics/<module_id>/
├── module.cfg
├── module.gd
├── component.gd
├── README.md
└── tests/
    └── smoke.gd
~~~

При необходимости внутри пакета можно добавлять другие компоненты, ресурсы и скрипты. Не выноси файлы механики в центральные папки, пока модуль не проходит отдельную проверку.

Один пакет описывает одну пользовательскую механику. Он может содержать несколько runtime-компонентов, если для поведения действительно нужны независимые части.

## 2. Манифест module.cfg

Минимальный формат:

~~~ini
[mechanic]
id="harvestable"
version=1
api_version=1
entrypoint="module.gd"
component_ids=["harvestable"]
capability_ids=["can_be_harvested"]
~~~

Правила:
- **id** — постоянный уникальный ID модуля, только латинские строчные буквы, цифры и подчёркивание.
- **version** — версия самого модуля, начинается с 1.
- **api_version** — версия контракта загрузчика. Для этой системы всегда 1.
- **entrypoint** — относительный путь к главному скрипту пакета. Нельзя использовать абсолютные пути или выходить из папки через две точки.
- **component_ids** и **capability_ids** — точные списки ID, которые возвращает module.gd. Списки не должны содержать дубликаты.

Если пакет содержит несколько компонентов или пользовательских карточек, перечисли их все в манифесте.

## 3. Контракт module.gd

Главный скрипт наследуется от RefCounted, помечается директивой @tool и реализует два метода. Runtime-компонент также должен быть помечен @tool: пакет загружается в редакторе и в runtime.

~~~gdscript
@tool
extends RefCounted

const COMPONENT_SCRIPT = preload(
    "res://addons/object_builder/mechanics/harvestable/component.gd"
)


func build_component_definitions() -> Array:
    var component := ObjectComponentDefinition.new()
    component.component_id = "harvestable"
    component.display_name = "Сбор ресурса"
    component.description = "Позволяет собирать ресурс по заданным правилам."
    component.category = "Interaction"
    component.category_id = "Interaction"
    component.category_display_name = "Взаимодействие"
    component.component_version = 1
    component.component_script = COMPONENT_SCRIPT
    component.setting_definitions = [
        {
            "key": "harvest_time",
            "display_name": "Время сбора",
            "value_type": "Float",
            "default_value": 1.0,
            "group_name": "Сбор",
            "has_range": true,
            "minimum": 0.1,
            "maximum": 60.0
        }
    ]
    component.settings = {"harvest_time": 1.0}
    return [component]


func build_capability_definitions() -> Array:
    var capability := ObjectCapabilityDefinition.new()
    capability.capability_id = "can_be_harvested"
    capability.display_name = "Можно собирать"
    capability.description = "Игрок может собрать этот объект."
    capability.category_id = "interaction"
    capability.category_name = "Взаимодействие"
    capability.icon = "hand"
    capability.keywords = PackedStringArray(["сбор", "ресурс", "урожай"])
    capability.component_ids = PackedStringArray(["harvestable"])
    capability.available_in_simple_mode = true
    capability.runtime_status = "Implemented"
    capability.implementation_note = "Сбор выполняет runtime-компонент Harvestable."
    capability.version = 1
    capability.definition_schema_version = 1
    return [capability]
~~~

Это пример структуры, а не готовая механика Harvestable. Разработчик должен подставить конкретную логику и ID своего задания.

Загрузчик проверяет типы, ID и соответствие манифесту, затем вызывает существующие реестры:
- ObjectComponentCatalog.register_definitions();
- ObjectCapabilityCatalog.register_definitions().

Если регистрация возможности завершается ошибкой, загрузчик пытается откатить регистрацию компонентов. Не вызывай эти реестры вручную из runtime-компонента.

## 4. Контракт runtime-компонента

Каждый runtime-компонент наследуется от ObjectComponent:

~~~gdscript
@tool
extends ObjectComponent

var harvest_time: float = 1.0


func _on_configured() -> void:
    harvest_time = maxf(0.1, float(get_setting("harvest_time", 1.0)))
~~~

Доступный общий API:
- component_id, binding_id, target_node_path;
- object_root и get_object_root();
- settings, get_setting(key, fallback), get_settings();
- configure_context(root, binding_id, node_path);
- configure(values) и точка настройки _on_configured().

Компонент не должен зависеть от конкретного имени сцены, конкретного дерева или конкретного игрока. Если механике нужен игрок, цель, инвентарь или контейнер, опиши маленький контракт получателя/интерфейс через методы и сигналы. Не подключай модуль напрямую к world_controller.gd, если такую интеграцию не запросили в отдельном задании.

Для поиска других компонентов того же объекта используй ObjectFactory.get_component() / ObjectFactory.get_components(). Не обходи всё дерево сцены каждый кадр без необходимости.

## 5. Настройки и карточка

Настройки объявляются в ObjectComponentDefinition.setting_definitions. Поддерживаемые типы API v1:
- String;
- Integer;
- Float;
- Boolean;
- Vector2.

Для числовых значений можно указывать has_range, minimum, maximum; дополнительно используй понятный group_name, display_name и default_value.

Пользовательская карточка в ObjectCapabilityDefinition должна иметь:
- постоянный capability_id;
- пользовательское название и короткое описание;
- корректную категорию и ключевые слова;
- component_ids, которые действительно реализуют поведение;
- простые значения по умолчанию;
- корректную версию поведения и схему данных.

Схема настроек capability автоматически формируется из определений компонентов. Не дублируй её вручную без необходимости. Пользовательский уровень сложности и переименование настроек добавляй только когда это действительно улучшает простой режим.

Используй runtime_status = "Implemented" только для полностью работающей механики с тестами. Не делай карточку доступной, если runtime пока является заглушкой.

## 6. Зависимости и границы

Для API v1:
- разрешены зависимости от уже встроенных компонентов и возможностей;
- не рассчитывай на порядок загрузки между двумя пользовательскими модулями;
- не создавай циклических зависимостей;
- если механике нужен другой новый модуль, явно укажи это в README и в отчёте интеграции — не копируй чужую реализацию.

Модуль не должен менять центральные файлы:
- scripts/object_system/object_component_catalog.gd;
- scripts/object_system/object_capability_library_data.gd;
- scripts/object_system/object_capability_catalog.gd;
- scripts/object_system/object_factory.gd;
- addons/object_builder/plugin.gd;
- общий UI и мировые игровые контроллеры.

Эти изменения относятся к отдельному этапу интеграции, а не к разработке модуля.

## 7. Тестирование

В tests/smoke.gd проверяй:
1. регистрацию модуля через MechanicModuleLoader.register_module();
2. наличие его capability и component ID в каталогах;
3. создание объекта через ObjectFactory.instantiate();
4. основные успешные сценарии;
5. отказ, неверные данные, пустые значения и граничные условия;
6. удаление/отключение поведения и сохранность состояния, если это относится к механике.

Запуск одного теста:

~~~bash
godot --headless --path . --script res://addons/object_builder/mechanics/<module_id>/tests/smoke.gd
~~~

После интеграции модуль должен проходить общий tests/object_system_smoke.gd и Godot CI проекта.

## 8. Загрузка и отключение

Загрузчик автоматически сканирует res://addons/object_builder/mechanics/:
- при включении Object Builder в редакторе;
- перед созданием объекта через ObjectFactory в runtime.

Для ручной операции доступны:
- MechanicModuleLoader.register_module(path);
- MechanicModuleLoader.register_modules_in_directory(path);
- MechanicModuleLoader.unregister_module(module_id);
- MechanicModuleLoader.get_loaded_module_ids().

При отключении загрузчик проверяет, что другие capability не используют компоненты отключаемого модуля. Если зависимость найдена, модуль не выгружается.

GDScript-модули выполняются как обычный доверенный код проекта. Это система пакетов и регистрации, а не безопасная песочница для неизвестных скриптов.

## 9. Что сдаёт чат-разработчик

Результат одного задания:
- целую папку одного модуля;
- рабочий module.cfg, module.gd и runtime-код;
- короткий README с настройками, методами и сигналами;
- автономный smoke-тест;
- список допущений и зависимостей;
- команду запуска теста и честный результат проверки.

Чат-разработчик не меняет общие каталоги, дорожную карту, PR и остальные механики. Основной чат проверяет пакет и отдельно подключает его к проекту.

**Полезные документы:** MECHANIC_MODULE_CHAT_PROMPT.md — готовая инструкция для отдельного чата; MECHANIC_MODULE_REQUEST_TEMPLATE.md — короткое задание на одну механику.
