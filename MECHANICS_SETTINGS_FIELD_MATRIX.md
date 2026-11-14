# Матрица объявлений настроек механик — часть 1

> Источник: исходники ветки `feature/web-object-builder-godot-integration`, прямое чтение 10 файлов `addons/web_object_builder/mechanics/*/module.gd`. Это декларативная инвентаризация, не runtime-проверка. Значения в таблице приведены как исходные GDScript-литералы. `—` означает, что поле явно не задано в декларации; это не следует трактовать как обязательное/необязательное без отдельного контракта.

## Методика и важные различия

- Обычные записи `settings` извлекаются по `key/value_type/default_value/minimum/maximum/group_name/required`.
- Сокращённые записи `fields` разворачиваются так же, как это делает `_settings_for()` в пакетах `defense` и `destruction`.
- Параметры, добавляемые программно при сборке компонента (например, `enabled`), не являются исходными объявлениями `settings` и должны учитываться отдельной колонкой в полном реестре.
- В `characteristics` схема формируется динамически из defaults конкретной характеристики; значения current/min/max нельзя считать общими константами.
- Эта часть содержит 173 исходных объявлений полей в 10 пакетах после добавления двух резервных production-table descriptors.

## Реестр полей

Владелец — capability/component ID из соответствующего package module. Название — пользовательская подпись поля из исходной схемы. Зарезервированные source-only компоненты отмечены отдельно ниже.

| Пакет | Владелец capability/component | Ключ | Название в редакторе | Тип | Default | Минимум | Максимум | Группа | Required |
|---|---|---|---|---|---|---:|---:|---|---|
| ai | has_ai | ai_enabled | AI активен | Boolean | true | — | — | AI | — |
| ai | can_follow_target | follow_distance | Дистанция следования | Float | 48.0 | 0.0 | 100000.0 | Следование | — |
| ai | can_patrol | patrol_points_json | Точки маршрута JSON | String | "[[0,0],[128,0]]" | — | — | Патруль | — |
| ai | can_patrol | patrol_speed | Скорость патруля | Float | 60.0 | 0.0 | 2000.0 | Патруль | — |
| ai | can_patrol | arrival_distance | Радиус прибытия | Float | 8.0 | 1.0 | 10000.0 | Патруль | — |
| ai | can_patrol | loop_route | Зацикливать маршрут | Boolean | true | — | — | Патруль | — |
| ai | can_chase | detection_radius | Радиус обнаружения | Float | 160.0 | 0.0 | 100000.0 | Преследование | — |
| ai | can_flee | health_threshold | Порог здоровья | Float | 0.25 | 0.0 | 1.0 | Отступление | — |
| ai | can_flee | flee_distance | Дистанция отступления | Float | 128.0 | 0.0 | 100000.0 | Отступление | — |
| ai | can_guard_area | guard_center | Центр охраны | Vector2 | Vector2.ZERO | — | — | Охрана | — |
| ai | can_guard_area | guard_radius | Радиус охраны | Float | 128.0 | 0.0 | 100000.0 | Охрана | — |
| ai | can_wander | wander_radius | Радиус блуждания | Float | 96.0 | 0.0 | 100000.0 | Блуждание | — |
| ai | can_wander | target_duration | Время цели | Float | 3.0 | 0.1 | 3600.0 | Блуждание | — |
| ai | can_assist | assist_radius | Радиус помощи | Float | 128.0 | 0.0 | 100000.0 | Помощь | — |
| ai | can_assist | ally_health_threshold | Порог здоровья союзника | Float | 0.35 | 0.0 | 1.0 | Помощь | — |
| ai | can_call_for_help | help_radius | Радиус сигнала | Float | 256.0 | 0.0 | 100000.0 | Сигнал | — |
| ai | supports_dialogue | dialogue_json | Реплики JSON | String | "{\"greeting\":[\"Привет!\"]}" | — | — | Диалог | — |
| ai | supports_dialogue | enabled | Поведение включено | Boolean | false | — | — | Основное | — |
| animals | can_be_tamed | taming_progress_required | Требуемый прогресс | Float | 3.0 | 0.1 | 10000.0 | Приручение | — |
| animals | can_be_tamed | taming_progress_per_feed | Прогресс за кормление | Float | 1.0 | 0.0 | 1000.0 | Приручение | — |
| animals | can_be_tamed | taming_foods_csv | Подходящий корм | String | "" | — | — | Приручение | — |
| animals | can_be_fed | accepted_foods_csv | Допустимый корм | String | "hay,apple" | — | — | Кормление | — |
| animals | can_be_fed | nutrition_per_feed | Питательность | Float | 20.0 | 0.1 | 100.0 | Кормление | — |
| animals | can_breed | offspring_object_id | ID потомства | String | "animal_offspring" | — | — | Размножение | — |
| animals | can_breed | breeding_cooldown_seconds | Период восстановления | Float | 86400.0 | 0.0 | 31536000.0 | Размножение | — |
| animals | can_produce_resources | production_table_path | Путь к ресурсу производства | String | "" | — | — | Производство | — |
| animals | can_produce_resources | resource_item_id | Предмет | String | "milk" | — | — | Производство | — |
| animals | can_produce_resources | production_interval | Интервал производства | Float | 3600.0 | 0.1 | 31536000.0 | Производство | — |
| animals | can_produce_resources | amount_per_cycle | Количество за цикл | Integer | 1 | 1 | 999999 | Производство | — |
| animals | can_produce_resources | production_table_json | Таблица результатов (резерв) | String | "[]" | — | — | Производство | — |
| animals | has_habitat | allowed_biomes_csv | Допустимые биомы | String | "plains,forest" | — | — | Среда | — |
| animals | has_habitat | minimum_temperature | Минимальная температура | Float | -10.0 | -100.0 | 100.0 | Среда | — |
| animals | has_habitat | maximum_temperature | Максимальная температура | Float | 35.0 | -100.0 | 100.0 | Среда | — |
| animals | has_happiness | starting_happiness | Начальное настроение | Float | 50.0 | 0.0 | 100.0 | Настроение | — |
| animals | has_happiness | feed_bonus | Бонус за кормление | Float | 5.0 | 0.0 | 100.0 | Настроение | — |
| animals | has_happiness | pet_bonus | Бонус за поглаживание | Float | 10.0 | 0.0 | 100.0 | Настроение | — |
| animals | has_daily_routine | schedule_json | Расписание действий | String | "[{\"start\":6,\"end\":12,\"action\":\"graze\"}]" | — | — | Распорядок | — |
| animals | has_daily_routine | default_action | Действие по умолчанию | String | "idle" | — | — | Распорядок | — |
| animals | can_be_mounted | mount_speed | Скорость верхом | Float | 120.0 | 0.0 | 10000.0 | Верховая езда | — |
| animals | can_migrate | migration_by_season_json | Маршруты миграции JSON | String | "{}" | — | — | Миграция | — |
| animals | can_be_petted | affection_gain | Привязанность за контакт | Float | 5.0 | 0.0 | 100.0 | Контакт | — |
| animals | can_be_petted | pet_cooldown_seconds | Задержка контакта | Float | 30.0 | 0.0 | 86400.0 | Контакт | — |
| animation | plays_idle_animation | animation_name | Название анимации | String | "idle" | — | — | Анимация | — |
| animation | plays_walk_animation | animation_name | Название анимации | String | "walk" | — | — | Анимация | — |
| animation | plays_run_animation | animation_name | Название анимации | String | "run" | — | — | Анимация | — |
| animation | plays_attack_animation | animation_name | Название анимации | String | "attack" | — | — | Анимация | — |
| animation | plays_hit_animation | animation_name | Название анимации | String | "hit" | — | — | Анимация | — |
| animation | plays_death_animation | animation_name | Название анимации | String | "death" | — | — | Анимация | — |
| animation | supports_animation_blending | blend_seconds | Длительность перехода | Float | 0.15 | 0.0 | 10.0 | Анимация | — |
| animation | supports_animation_events | emit_started | Событие начала | Boolean | true | — | — | Анимация | — |
| animation | supports_animation_events | emit_finished | Событие завершения | Boolean | true | — | — | Анимация | — |
| animation | supports_frame_events | frames_csv | Кадры для событий (через запятую) | String | "" | — | — | Анимация | — |
| animation | supports_animation_variants | variant_map_json | Таблица вариантов JSON | String | "{}" | — | — | Анимация | — |
| animation | supports_animation_variants | enabled | Включено | Boolean | false | — | — | Состояния и события | — |
| audio_effects | plays_footsteps | surface_streams_json | Звуки поверхностей JSON | String | "{}" | — | — | Шаги | — |
| audio_effects | plays_footsteps | volume_db | Громкость (dB) | Float | 0.0 | -80.0 | 24.0 | Звук | — |
| audio_effects | plays_footsteps | pitch_scale | Высота тона | Float | 1.0 | 0.01 | 4.0 | Звук | — |
| audio_effects | plays_footsteps | bus | Аудиошина | String | "Master" | — | — | Звук | — |
| audio_effects | plays_footsteps | max_distance | Максимальная дистанция | Float | 1200.0 | 1.0 | 100000.0 | Звук | — |
| audio_effects | plays_footsteps | attenuation | Затухание | Float | 1.0 | 0.0 | 10.0 | Звук | — |
| audio_effects | emits_particles | particle_scene_path | Сцена эффекта | String | "" | — | — | Частицы | — |
| audio_effects | emits_particles | particle_amount | Количество частиц | Integer | 24 | 1 | 10000 | Частицы | — |
| audio_effects | emits_particles | particle_lifetime | Время жизни | Float | 0.8 | 0.05 | 120.0 | Частицы | — |
| audio_effects | emits_particles | particle_one_shot | Однократный выброс | Boolean | true | — | — | Частицы | — |
| audio_effects | emits_particles | particle_spread | Разброс | Float | 45.0 | 0.0 | 180.0 | Частицы | — |
| audio_effects | emits_particles | particle_velocity_min | Минимальная скорость | Float | 20.0 | 0.0 | 10000.0 | Частицы | — |
| audio_effects | emits_particles | particle_velocity_max | Максимальная скорость | Float | 80.0 | 0.0 | 10000.0 | Частицы | — |
| audio_effects | emits_particles | particle_color | Цвет частиц (HEX) | String | "#ffffff" | — | — | Частицы | — |
| audio_effects | has_trail_effect | trail_color | Цвет следа | String | "#ffffff88" | — | — | След | — |
| audio_effects | has_trail_effect | trail_width | Толщина следа | Float | 4.0 | 0.1 | 256.0 | След | — |
| audio_effects | has_trail_effect | trail_length | Количество точек | Integer | 16 | 2 | 2048 | След | — |
| audio_effects | has_trail_effect | trail_z_index | Z-индекс | Integer | -1 | — | — | След | — |
| audio_effects | has_light_effect | light_color | Цвет света | String | "#fff2c4" | — | — | Свет | — |
| audio_effects | has_light_effect | light_energy | Энергия | Float | 1.0 | 0.0 | 16.0 | Свет | — |
| audio_effects | has_light_effect | light_texture_path | Текстура света | String | "" | — | — | Свет | — |
| audio_effects | has_light_effect | light_scale | Масштаб света | Float | 1.0 | 0.01 | 100.0 | Свет | — |
| audio_effects | supports_screen_shake | shake_intensity | Интенсивность | Float | 4.0 | 0.0 | 1000.0 | Камера | — |
| audio_effects | supports_screen_shake | shake_duration | Длительность | Float | 0.15 | 0.0 | 30.0 | Камера | — |
| audio_effects | supports_screen_shake | enabled | Включено | Boolean | false | — | — | Дополнительные события | — |
| characteristics | all 9 resource components | current_value | Текущее значение | Float | dynamic per capability | dynamic | dynamic | Значение | — |
| characteristics | all 9 resource components | maximum_value | Максимум | Float | dynamic per capability | dynamic | 1000000.0 | Границы | — |
| characteristics | all 9 resource components | minimum_value | Минимум | Float | dynamic per capability | -1000000.0 | 1000000.0 | Границы | — |
| combat | can_block | damage_reduction | Снижение урона | Float | 0.75 | 0.0 | 1.0 | Блок | — |
| combat | can_parry | parry_window | Окно парирования | Float | 0.25 | 0.0 | 2.0 | Парирование | — |
| combat | can_parry | counter_multiplier | Множитель контратаки | Float | 1.5 | 1.0 | 20.0 | Парирование | — |
| combat | can_dodge | dodge_duration | Длительность | Float | 0.35 | 0.01 | 10.0 | Уклонение | — |
| combat | can_dodge | invulnerability | Неуязвимость во время уклонения | Boolean | true | — | — | Уклонение | — |
| combat | can_aim | aim_cone_degrees | Угол помощи прицеливания | Float | 8.0 | 0.0 | 90.0 | Прицеливание | — |
| combat | can_charge_attack | charge_time | Время полного заряда | Float | 1.0 | 0.01 | 60.0 | Заряд | — |
| combat | can_charge_attack | maximum_multiplier | Максимальный множитель | Float | 2.5 | 1.0 | 100.0 | Заряд | — |
| combat | can_critical_hit | critical_chance | Шанс критического удара | Float | 0.1 | 0.0 | 1.0 | Критический удар | — |
| combat | can_critical_hit | critical_multiplier | Множитель урона | Float | 2.0 | 1.0 | 100.0 | Критический удар | — |
| combat | can_combo_attack | combo_window | Окно между ударами | Float | 0.8 | 0.0 | 10.0 | Комбо | — |
| combat | can_combo_attack | combo_multipliers | Множители шагов через запятую | String | "1.0,1.15,1.4" | — | — | Комбо | — |
| combat | can_target_enemy | maximum_distance | Дальность выбора цели | Float | 600.0 | 0.0 | 100000.0 | Цель | — |
| construction | can_be_placed | placement_enabled | Разрешить размещение | Boolean | true | — | — | Размещение | — |
| construction | can_be_placed | world_bounds_json | Границы мира JSON | String | "{}" | — | — | Размещение | — |
| construction | can_be_placed | allowed_terrain_csv | Допустимые поверхности | String | "" | — | — | Размещение | — |
| construction | can_be_placed | placement_clearance | Минимальная дистанция | Float | 0.0 | 0.0 | 100000.0 | Размещение | — |
| construction | can_be_placed | snap_to_grid_enabled | Привязка к сетке | Boolean | false | — | — | Сетка | — |
| construction | can_be_placed | grid_size | Размер ячейки | Vector2 | Vector2(16.0,16.0) | — | — | Сетка | — |
| construction | can_be_placed | grid_origin | Начало сетки | Vector2 | Vector2.ZERO | — | — | Сетка | — |
| construction | can_be_placed | rotation_enabled | Разрешить поворот | Boolean | false | — | — | Поворот | — |
| construction | can_be_placed | rotation_step_degrees | Шаг поворота | Float | 90.0 | 1.0 | 360.0 | Поворот | — |
| construction | can_be_placed | preview_enabled | Показывать предпросмотр | Boolean | false | — | — | Предпросмотр | — |
| construction | can_be_placed | preview_alpha | Прозрачность предпросмотра | Float | 0.45 | 0.0 | 1.0 | Предпросмотр | — |
| construction | can_be_placed | valid_color | Цвет допустимого размещения | String | "#66dd88" | — | — | Предпросмотр | — |
| construction | can_be_placed | invalid_color | Цвет недопустимого размещения | String | "#ee6677" | — | — | Предпросмотр | — |
| construction | snaps_to_grid | grid_size | Размер ячейки | Vector2 | Vector2(16.0,16.0) | — | — | Сетка | — |
| construction | snaps_to_grid | grid_origin | Начало сетки | Vector2 | Vector2.ZERO | — | — | Сетка | — |
| construction | supports_rotation_placement | rotation_step_degrees | Шаг поворота | Float | 90.0 | 1.0 | 360.0 | Поворот | — |
| construction | has_build_cost | build_cost_json | Стоимость и материалы JSON | String | "{}" | — | — | Стоимость | — |
| construction | has_build_cost | materials_required | Требовать и списывать материалы | Boolean | false | — | — | Материалы | — |
| construction | requires_build_materials | material_costs_json | Материалы JSON (пусто — стоимость постройки) | String | "{}" | — | — | Материалы | — |
| construction | can_be_upgraded | max_upgrade_level | Максимальный уровень | Integer | 3 | 0 | 100 | Улучшение | — |
| construction | can_be_upgraded | upgrade_costs_json | Стоимость уровней JSON | String | "{}" | — | — | Улучшение | — |
| construction | can_be_dismantled | refund_ratio | Доля возврата | Float | 0.5 | 0.0 | 1.0 | Разбор | — |
| construction | supports_build_preview | preview_alpha | Прозрачность предпросмотра | Float | 0.45 | 0.0 | 1.0 | Предпросмотр | — |
| construction | supports_build_preview | valid_color | Цвет допустимого размещения | String | "#66dd88" | — | — | Предпросмотр | — |
| construction | supports_build_preview | invalid_color | Цвет недопустимого размещения | String | "#ee6677" | — | — | Предпросмотр | — |
| construction | has_build_stages | build_duration | Время строительства | Float | 10.0 | 0.01 | 604800.0 | Этапы | — |
| construction | has_build_stages | stage_thresholds_json | Пороги этапов JSON | String | "[0.25,0.5,0.75,1.0]" | — | — | Этапы | — |
| construction | supports_blueprint | include_placement_data | Сохранять размещение | Boolean | true | — | — | Чертёж | — |
| containers | stores_items | initial_contents_json | Начальное содержимое JSON | String | "[]" | — | — | Содержимое | — |
| containers | has_container_capacity | max_slots | Максимум стопок | Integer | 24 | 1 | 10000 | Вместимость контейнера | — |
| containers | has_container_capacity | max_weight | Максимальный вес контейнера (0 — без лимита) | Float | 0.0 | 0.0 | 100000000.0 | Вместимость контейнера | — |
| containers | can_be_locked | initially_locked | Заперт изначально | Boolean | false | — | — | Замок | — |
| containers | can_be_locked | lock_key_id | ID ключа для запирания | String | "" | — | — | Запирание | — |
| containers | can_be_locked | unlock_enabled | Разрешить отпирание | Boolean | false | — | — | Отпирание | — |
| containers | can_be_locked | unlock_requires_key | Требовать ключ для отпирания | Boolean | false | — | — | Отпирание | — |
| containers | can_be_locked | unlock_key_id | ID ключа для отпирания | String | "" | — | — | Отпирание | — |
| containers | can_be_unlocked | requires_key | Требовать ключ | Boolean | false | — | — | Замок | — |
| containers | can_be_unlocked | unlock_key_id | ID ключа | String | "" | — | — | Замок | — |
| containers | can_be_looted | loot_enabled | Разрешить обыск | Boolean | true | — | — | Доступ | — |
| containers | has_shared_storage | shared_group_id | ID общего хранилища | String | "" | — | — | Общее хранилище | — |
| containers | has_shared_storage | allow_links | Разрешить связывание контейнеров | Boolean | false | — | — | Связи | — |
| containers | supports_container_links | allow_links | Разрешить связывание | Boolean | true | — | — | Связи | — |
| containers | has_container_permissions | owner_id | ID владельца | String | "" | — | — | Права | — |
| containers | has_container_permissions | allowed_factions_csv | Разрешённые фракции | String | "" | — | — | Права | — |
| containers | has_container_permissions | public_access | Публичный доступ | Boolean | true | — | — | Права | — |
| containers | supports_auto_sort | default_sort | Режим сортировки | String | "name" | — | — | Сортировка | — |
| containers | has_container_persistence | persistent | Сохранять содержимое | Boolean | true | — | — | Сохранение | — |
| containers | has_container_persistence | enabled | Включено | Boolean | false | — | — | Основное | — |
| defense | has_armor | armor_percent_reduction | Процент снижения | Float | 0.2 | 0.0 | 1.0 | Броня | — |
| defense | has_armor | armor_flat_reduction | Плоское снижение | Float | 5.0 | 0.0 | 100000.0 | Броня | — |
| defense | has_damage_resistance | damage_resistances_json | Сопротивления по типам (JSON) | String | "{}" | — | — | Сопротивления | — |
| defense | has_immunity | immune_effects_csv | Иммунитеты через запятую | String | "" | — | — | Иммунитет | — |
| defense | has_shield | shield_current | Текущий заряд щита | Float | 50.0 | 0.0 | 1000000.0 | Щит | — |
| defense | has_shield | shield_maximum | Максимальный заряд | Float | 50.0 | 0.0 | 1000000.0 | Щит | — |
| defense | reduces_projectile_damage | projectile_reduction | Снижение урона снарядов | Float | 0.5 | 0.0 | 1.0 | Снаряды | — |
| defense | reflects_projectiles | projectile_reflection_enabled | Отражать снаряды | Boolean | true | — | — | Отражение | — |
| defense | has_invulnerability_window | invulnerability_duration | Длительность окна | Float | 0.5 | 0.0 | 10.0 | Неуязвимость | — |
| defense | has_weak_points | weak_points_json | Множители точек попадания (JSON) | String | "{}" | — | — | Уязвимые места | — |
| defense | resists_status_effects | status_resistances_json | Сопротивления эффектам (JSON) | String | "{}" | — | — | Сопротивления | — |
| defense | regenerates_health | enabled | Включено | Boolean | false | — | — | Основное | — |
| defense | regenerates_health | health_regeneration_per_second | Здоровье в секунду | Float | 1.0 | 0.0 | 100000.0 | Регенерация | — |
| destruction | can_break_into_parts | parts_json | Список частей (JSON) | String | "[]" | — | — | Части | — |
| destruction | has_destruction_stages | stage_thresholds | Пороги стадий через запятую | String | "0.75,0.5,0.25" | — | — | Стадии | — |
| destruction | spawns_debris | debris_scene_path | Сцена обломка | String | "" | — | — | Обломки | — |
| destruction | spawns_debris | debris_count | Количество | Integer | 4 | 0 | 256 | Обломки | — |
| destruction | drops_loot_on_destroy | loot_table_path | Путь к ресурсу таблицы добычи | String | "" | — | — | Добыча | — |
| destruction | drops_loot_on_destroy | loot_table_json | Резервная таблица добычи (визуальный список; legacy JSON) | String | "[]" | — | — | Добыча | — |
| destruction | plays_destroy_animation | animation_player_path | Путь к AnimationPlayer | String | "AnimationPlayer" | — | — | Анимация | — |
| destruction | plays_destroy_animation | destroy_animation | Название анимации | String | "destroy" | — | — | Анимация | — |
| destruction | leaves_remains | remains_scene_path | Сцена остатков (если не встроена) | String | "" | — | — | Остатки | — |
| destruction | falls_when_destroyed | fall_angle_degrees | Угол падения | Float | 78.0 | 1.0 | 120.0 | Падение | — |
| destruction | falls_when_destroyed | fall_duration | Длительность падения | Float | 0.48 | 0.05 | 5.0 | Падение | — |
| destruction | can_be_repaired | repair_amount | Здоровье за ремонт | Float | 25.0 | 0.0 | 1000000.0 | Ремонт | — |
| destruction | can_regrow | regrowth_seconds | Время восстановления | Float | 30.0 | 0.0 | 86400.0 | Восстановление | — |
| destruction | can_explode_on_destroy | enabled | Включено | Boolean | false | — | — | Основное | — |
| destruction | can_explode_on_destroy | explosion_radius | Радиус взрыва | Float | 96.0 | 0.0 | 100000.0 | Взрыв | — |
| destruction | can_explode_on_destroy | explosion_damage | Урон взрыва | Float | 25.0 | 0.0 | 1000000.0 | Взрыв | — |

## Реестр полей — часть 2

| Пакет | Владелец capability/component | Ключ | Название в редакторе | Тип | Default | Минимум | Максимум | Группа | Required |
|---|---|---|---|---|---|---:|---:|---|---|
| harvesting | can_be_harvested | enabled | Доступна добыча | Boolean | true | — | — | Добыча | — |
| harvesting | can_be_harvested | harvest_time_seconds | Время добычи | Float | 2.0 | 0.05 | 3600.0 | Добыча | — |
| harvesting | requires_tool | enabled | Требовать инструмент | Boolean | false | — | — | Инструмент | — |
| harvesting | requires_tool | required_tool_id | ID инструмента | String | "axe" | — | — | Инструмент | — |
| harvesting | requires_tool | minimum_tool_level | Минимальный уровень | Integer | 0 | 0 | 999 | Инструмент | — |
| harvesting | requires_tool | tool_requirements_json | Уровни инструментов JSON | String | "{}" | — | — | Инструмент | — |
| harvesting | requires_tool | minimum_mining_power | Минимальная мощность инструмента | Float | 0.0 | 0.0 | 100000.0 | Инструмент | — |
| harvesting | requires_tool | tool_power_json | Мощность инструментов JSON | String | "{}" | — | — | Инструмент | — |
| harvesting | has_harvest_progress | harvest_duration | Длительность шкалы | Float | 2.0 | 0.05 | 3600.0 | Прогресс | — |
| harvesting | yields_resources | resource_table_path | Путь к ресурсу таблицы | String | "" | — | — | Ресурсы | — |
| harvesting | yields_resources | resource_table_json | Старая таблица ресурсов JSON (резерв) | String | "[]" | — | — | Ресурсы | — |
| harvesting | has_regrowth | regrowth_seconds | Время отрастания | Float | 60.0 | 0.0 | 604800.0 | Восстановление | — |
| harvesting | has_seasonal_yield | enabled | Сезонная добыча включена | Boolean | false | — | — | Сезоны | — |
| harvesting | has_seasonal_yield | seasonal_yields_json | Множители сезонов JSON | String | "{\"spring\":1.0,\"summer\":1.0,\"autumn\":1.0,\"winter\":0.5}" | — | — | Сезоны | — |
| harvesting | has_quality_variants | enabled | Варианты качества включены | Boolean | false | — | — | Качество | — |
| harvesting | has_quality_variants | quality_chances_json | Шансы качества JSON | String | "{\"normal\":0.7,\"fine\":0.2,\"rare\":0.1}" | — | — | Качество | — |
| harvesting | has_tool_efficiency | enabled | Эффективность включена | Boolean | false | — | — | Инструменты | — |
| harvesting | has_tool_efficiency | tool_efficiency_json | Эффективность инструментов JSON | String | "{\"axe\":1.0,\"pickaxe\":1.0}" | — | — | Инструменты | — |
| harvesting | has_multi_stage_harvest | enabled | Этапы добычи включены | Boolean | false | — | — | Этапы | — |
| harvesting | has_multi_stage_harvest | harvest_stages_json | Пороги этапов JSON | String | "[0.33,0.66,1.0]" | — | — | Этапы | — |
| harvesting | can_be_mined | required_tool_id | ID инструмента | String | "pickaxe" | — | — | Добыча | — |
| harvesting | can_be_mined | minimum_mining_power | Минимальная мощность | Float | 1.0 | 0.0 | 100000.0 | Добыча | — |
| harvesting | can_be_mined | tool_power_json | Мощность инструментов JSON | String | "{\"pickaxe\":{\"power\":1.0}}" | — | — | Добыча | — |
| interaction | can_interact | enabled | Взаимодействие включено | Boolean | true | — | — | Взаимодействие | — |
| interaction | can_be_picked_up | enabled | Подбор включён | Boolean | true | — | — | Подбор | — |
| interaction | can_be_picked_up | one_time_pickup | Только один раз | Boolean | true | — | — | Подбор | — |
| interaction | can_be_activated | enabled | Активация включена | Boolean | true | — | — | Активация | — |
| interaction | can_be_activated | start_active | Активен при запуске | Boolean | false | — | — | Активация | — |
| interaction | can_be_opened | enabled | Открытие включено | Boolean | true | — | — | Открытие | — |
| interaction | can_be_opened | starts_open | Открыт при запуске | Boolean | false | — | — | Открытие | — |
| interaction | can_be_closed | enabled | Закрытие включено | Boolean | true | — | — | Закрытие | — |
| interaction | can_be_closed | starts_open | Открыт при запуске | Boolean | false | — | — | Закрытие | — |
| interaction | can_be_toggled | enabled | Переключение включено | Boolean | true | — | — | Переключение | — |
| interaction | can_be_toggled | initial_state | Включено при запуске | Boolean | false | — | — | Переключение | — |
| interaction | can_be_used | enabled | Использование включено | Boolean | true | — | — | Использование | — |
| interaction | can_be_used | maximum_uses | Максимум применений (0 — без лимита) | Integer | 0 | 0 | 1000000 | Использование | — |
| interaction | has_interaction_range | interaction_range | Радиус взаимодействия | Float | 96.0 | 0.0 | 100000.0 | Дальность | — |
| interaction | shows_interaction_prompt | prompt_text | Текст подсказки | String | "Взаимодействовать" | — | — | Подсказка | — |
| interaction | shows_interaction_prompt | prompt_range | Радиус показа | Float | 96.0 | 0.0 | 100000.0 | Подсказка | — |
| interaction | shows_interaction_prompt | enabled | Показывать подсказку | Boolean | true | — | — | Подсказка | — |
| interaction | supports_hold_interaction | hold_duration | Время удержания | Float | 1.0 | 0.05 | 120.0 | Удержание | — |
| interaction | supports_hold_interaction | enabled | Удержание включено | Boolean | true | — | — | Удержание | — |
| inventory | has_inventory | slot_capacity | Количество слотов | Integer | 24 | 1 | 10000 | Инвентарь | — |
| inventory | has_inventory | initial_items_json | Начальное содержимое JSON | String | "[]" | — | — | Инвентарь | — |
| inventory | has_equipment_slots | equipment_slots_csv | Слоты через запятую | String | "head,chest,legs,feet,hand,offhand,accessory" | — | — | Экипировка | — |
| inventory | supports_hotbar | hotbar_slots | Количество быстрых слотов | Integer | 9 | 1 | 32 | Панель | — |
| inventory | supports_item_filters | filter_rules_json | Правила фильтрации JSON | String | "{}" | — | — | Фильтры | — |
| inventory | supports_item_sorting | default_sort | Сортировка по умолчанию | String | "name" | — | — | Сортировка | — |
| inventory | supports_stack_splitting | allow_split | Разрешить разделение | Boolean | true | — | — | Стопки | — |
| inventory | supports_quick_transfer | transfer_mode | Режим переноса | String | "all" | — | — | Перемещение | — |
| inventory | has_weight_capacity | max_weight | Максимальный переносимый вес (0 — без лимита) | Float | 100.0 | 0.0 | 1000000.0 | Вес инвентаря | — |
| inventory | supports_item_crafting | recipes_table_path | Путь к ресурсу рецептов | String | "" | — | — | Рецепты | — |
| inventory | supports_item_crafting | recipes_json | Таблица рецептов (резерв) | String | "{}" | — | — | Рецепты | — |
| inventory | supports_item_binding | allow_binding | Разрешить закрепление | Boolean | true | — | — | Закрепление | — |
| inventory | supports_item_binding | enabled | Включено | Boolean | false | — | — | Дополнительные функции хранилища | — |
| items | is_pickup_item | pickup_enabled | Разрешить подбор | Boolean | true | — | — | Подбор | — |
| items | is_pickup_item | pickup_radius | Радиус подбора | Float | 48.0 | 0.0 | 10000.0 | Подбор | — |
| items | is_stackable | max_stack_size | Максимум в стопке | Integer | 99 | 1 | 999999 | Стопка | — |
| items | is_stackable | initial_count | Начальное количество | Integer | 1 | 1 | 999999 | Стопка | — |
| items | has_item_weight | weight_per_unit | Вес единицы | Float | 1.0 | 0.0 | 1000000.0 | Вес | — |
| items | has_item_value | base_value | Базовая стоимость | Float | 0.0 | 0.0 | 1000000000.0 | Стоимость | — |
| items | has_item_value | currency_id | ID валюты | String | "coins" | — | — | Стоимость | — |
| items | is_consumable | consume_amount | Количество за применение | Integer | 1 | 1 | 999999 | Использование | — |
| items | can_be_equipped | equipment_slot | Основной слот | String | "hand" | — | — | Экипировка | — |
| items | can_be_equipped | allowed_slots_csv | Разрешённые слоты через запятую | String | "hand" | — | — | Экипировка | — |
| items | can_be_dropped | drop_enabled | Разрешить выбрасывание | Boolean | true | — | — | Выброс | — |
| items | can_be_traded | trade_enabled | Разрешить обмен | Boolean | true | — | — | Обмен | — |
| items | can_be_traded | trade_price_multiplier | Множитель цены | Float | 1.0 | 0.0 | 100000.0 | Обмен | — |
| items | has_item_durability | durability_enabled | Использовать прочность | Boolean | true | — | — | Прочность | — |
| items | has_item_durability | maximum_durability | Максимальная прочность | Float | 100.0 | 0.0 | 1000000.0 | Прочность | — |
| items | has_item_durability | starting_durability | Начальная прочность | Float | 100.0 | 0.0 | 1000000.0 | Прочность | — |
| items | has_item_durability | uses_enabled | Ограничить число применений | Boolean | false | — | — | Применения | — |
| items | has_item_durability | maximum_uses | Максимум применений | Integer | 10 | 0 | 999999 | Применения | — |
| items | has_item_durability | starting_uses | Начальные применения | Integer | 10 | 0 | 999999 | Применения | — |
| items | has_item_uses | maximum_uses | Максимум применений | Integer | 10 | 0 | 999999 | Применения | — |
| items | has_item_uses | starting_uses | Начальные применения | Integer | 10 | 0 | 999999 | Применения | — |
| movement | can_move | move_speed | Скорость движения | Float | 120.0 | 0.0 | 2000.0 | Движение | — |
| movement | can_walk | walk_speed | Скорость ходьбы | Float | 80.0 | 0.0 | 2000.0 | Движение | — |
| movement | can_run | run_speed | Скорость бега | Float | 180.0 | 0.0 | 2000.0 | Движение | — |
| movement | can_jump | jump_height | Высота прыжка | Float | 48.0 | 1.0 | 1000.0 | Движение | — |
| movement | can_jump | jump_duration | Длительность прыжка | Float | 0.45 | 0.05 | 5.0 | Движение | — |
| movement | can_dash | dash_distance | Дистанция рывка | Float | 96.0 | 1.0 | 2000.0 | Движение | — |
| movement | can_dash | dash_duration | Длительность рывка | Float | 0.18 | 0.03 | 2.0 | Движение | — |
| movement | can_dash | cooldown_seconds | Перезарядка | Float | 0.6 | 0.0 | 60.0 | Движение | — |
| movement | can_fly | flight_speed | Скорость полёта | Float | 160.0 | 0.0 | 2000.0 | Движение | — |
| movement | can_swim | swim_speed | Скорость плавания | Float | 70.0 | 0.0 | 2000.0 | Движение | — |
| movement | can_swim | requires_swimming_state | Требовать состояние плавания | Boolean | true | — | — | Движение | — |
| movement | can_climb | climb_speed | Скорость лазания | Float | 80.0 | 0.0 | 2000.0 | Движение | — |
| movement | can_teleport | max_range | Максимальная дальность (0 — без ограничения) | Float | 0.0 | 0.0 | 100000.0 | Движение | — |
| movement | has_patrol_route | route_json | Маршрут JSON | String | "[[0,0],[128,0],[128,128]]" | — | — | Движение | — |
| movement | has_patrol_route | patrol_speed | Скорость патруля | Float | 60.0 | 0.0 | 2000.0 | Движение | — |
| movement | has_patrol_route | loop_route | Зацикливать маршрут | Boolean | true | — | — | Движение | — |
| movement | has_patrol_route | enabled | Включено | Boolean | false | — | — | Дополнительные режимы | — |
| object_identity | has_unique_identity | identity_id | ID объекта | String | "" | — | — | Идентификация | — |
| object_identity | can_be_enabled | initially_enabled | Включён изначально | Boolean | false | — | — | Состояние | — |
| object_identity | can_be_enabled | allow_enable | Разрешить включение | Boolean | true | — | — | Правила | — |
| object_identity | can_be_disabled | initially_enabled | Включён изначально | Boolean | true | — | — | Состояние | — |
| object_identity | can_be_disabled | allow_disable | Разрешить отключение | Boolean | true | — | — | Правила | — |
| object_identity | has_custom_name | custom_name | Имя объекта | String | "" | — | — | Имя | — |
| object_identity | supports_tags | tags_csv | Начальные метки | String | "" | — | — | Метки | — |
| object_identity | supports_factions | faction_id | ID фракции | String | "neutral" | — | — | Фракция | — |
| object_identity | supports_rarity | rarity | Редкость | String | "common" | — | — | Редкость | — |
| object_identity | supports_levels | initial_level | Начальный уровень | Integer | 1 | 1 | 999 | Прогресс | — |
| object_identity | supports_experience_points | initial_experience | Начальный опыт | Integer | 0 | 0 | 2147483647 | Прогресс | — |
| object_identity | supports_metadata | metadata_json | Начальные данные JSON | String | "{}" | — | — | Метаданные | — |
| physics | has_collision | collision_enabled | Коллизия включена | Boolean | true | — | — | Коллизия | — |
| physics | blocks_movement | blocking_enabled | Блокировать движение | Boolean | true | — | — | Блокировка | — |
| physics | blocks_movement | collision_layer_bit | Слой коллизии (1–32) | Integer | 1 | 1 | 32 | Блокировка | — |
| physics | can_be_pushed | push_impulse | Сила толчка | Float | 160.0 | 0.0 | 100000.0 | Толчок | — |
| physics | can_be_pushed | mass_floor | Минимальная масса | Float | 0.1 | 0.01 | 1000.0 | Толчок | — |
| physics | can_be_pulled | pull_impulse | Сила притяжения | Float | 120.0 | 0.0 | 100000.0 | Притяжение | — |
| physics | can_be_pulled | maximum_distance | Максимальная дальность (0 — без ограничения) | Float | 1200.0 | 0.0 | 100000.0 | Притяжение | — |
| physics | has_mass | mass | Масса | Float | 1.0 | 0.01 | 1000000.0 | Физика | — |
| physics | affected_by_gravity | gravity_scale | Масштаб гравитации | Float | 1.0 | -100.0 | 100.0 | Физика | — |
| physics | can_bounce | bounce | Сила отскока | Float | 0.65 | 0.0 | 1.0 | Отскок | — |
| physics | can_bounce | friction | Трение | Float | 0.2 | 0.0 | 1.0 | Отскок | — |
| physics | can_roll | angular_speed | Угловая скорость | Float | 5.0 | 0.0 | 100.0 | Качение | — |
| physics | can_roll | maximum_angular_speed | Предел угловой скорости | Float | 20.0 | 0.0 | 200.0 | Качение | — |
| physics | can_slide | sliding_friction | Трение при скольжении | Float | 0.05 | 0.0 | 1.0 | Скольжение | — |
| physics | can_slide | normal_friction | Обычное трение | Float | 1.0 | 0.0 | 1.0 | Скольжение | — |
| physics | has_physics_material | friction | Трение | Float | 0.6 | 0.0 | 1.0 | Материал | — |
| physics | has_physics_material | bounce | Отскок | Float | 0.0 | 0.0 | 1.0 | Материал | — |
| physics | has_physics_material | rough | Шероховатый контакт | Boolean | false | — | — | Материал | — |
| physics | has_physics_material | absorbent | Поглощать отскок другой поверхности | Boolean | false | — | — | Материал | — |
| visual_appearance | has_sprite | texture_path | Путь к текстуре | String | "" | — | — | Изображение | — |
| visual_appearance | has_multiple_visual_parts | part_paths | Пути частей через ; | String | "" | — | — | Части | — |
| visual_appearance | has_multiple_visual_parts | parts_visible | Показывать части | Boolean | true | — | — | Части | — |
| visual_appearance | has_multiple_visual_parts | parts_offset | Смещение частей | Vector2 | Vector2.ZERO | — | — | Части | — |
| visual_appearance | supports_directional_sprites | directions_json | Карта направлений JSON | String | "{}" | — | — | Направления | — |
| visual_appearance | supports_directional_sprites | initial_direction | Начальное направление | String | "down" | — | — | Направления | — |
| visual_appearance | supports_tint | tint_color | Цвет оттенка | String | "#ffffff" | — | — | Цвет | — |
| visual_appearance | supports_opacity | opacity | Непрозрачность | Float | 1.0 | 0.0 | 1.0 | Прозрачность | — |
| visual_appearance | casts_visual_shadow | shadow_offset | Смещение тени | Vector2 | Vector2(0,8) | — | — | Тень | — |
| visual_appearance | casts_visual_shadow | shadow_opacity | Прозрачность тени | Float | 0.35 | 0.0 | 1.0 | Тень | — |
| visual_appearance | casts_visual_shadow | shadow_scale | Масштаб тени | Vector2 | Vector2(1,0.55) | — | — | Тень | — |
| visual_appearance | supports_outline | outline_color | Цвет обводки | String | "#ffffff" | — | — | Обводка | — |
| visual_appearance | supports_outline | outline_width | Толщина обводки | Float | 1.0 | 1.0 | 4.0 | Обводка | — |
| visual_appearance | supports_layer_order | z_index | Порядок отрисовки | Integer | 0 | -4096 | 4096 | Слои | — |
| visual_appearance | supports_layer_order | z_as_relative | Относительный порядок | Boolean | true | — | — | Слои | — |
| visual_appearance | supports_flip | flip_horizontal | Отразить по горизонтали | Boolean | false | — | — | Отражение | — |
| visual_appearance | supports_flip | flip_vertical | Отразить по вертикали | Boolean | false | — | — | Отражение | — |
| visual_appearance | supports_palette_swap | palette_json | Замены цветов JSON | String | "{}" | — | — | Палитра | — |
| world_generation | spawns_by_biome | allowed_biomes_csv | Разрешённые биомы | String | "plains,forest" | — | — | Биомы | — |
| world_generation | has_spawn_conditions | conditions_json | Условия появления JSON | String | "{}" | — | — | Условия | — |
| world_generation | has_random_variants | variants_json | Варианты JSON | String | "[{\"id\":\"default\",\"weight\":1.0}]" | — | — | Варианты | — |
| world_generation | has_procedural_layout | pattern | Шаблон | String | "scatter" | — | — | Структура | — |
| world_generation | has_procedural_layout | object_count | Количество объектов | Integer | 12 | 0 | 100000 | Структура | — |
| world_generation | has_procedural_layout | spacing | Шаг/радиус | Float | 32.0 | 1.0 | 100000.0 | Структура | — |
| world_generation | supports_world_seed | default_seed | Seed мира | Integer | 1 | — | — | Seed | — |
| world_generation | has_density_rules | max_per_region | Максимум на регион | Integer | 20 | 0 | 1000000 | Плотность | — |
| world_generation | has_density_rules | density_by_region_json | Лимиты регионов JSON | String | "{}" | — | — | Плотность | — |
| world_generation | can_spread | spread_radius | Радиус распространения | Integer | 1 | 1 | 32 | Распространение | — |
| world_generation | can_spread | max_spread_cells | Максимум новых клеток | Integer | 4 | 1 | 10000 | Распространение | — |
| world_generation | can_spread | allow_diagonal | Диагональные клетки | Boolean | false | — | — | Распространение | — |
| world_generation | can_grow | growth_duration | Время полного роста | Float | 60.0 | 0.01 | 31536000.0 | Рост | — |
| world_generation | can_grow | growth_stages_json | Пороги стадий JSON | String | "[0.25,0.5,0.75,1.0]" | — | — | Рост | — |
| world_generation | adapts_to_environment | adaptation_rules_json | Правила адаптации JSON | String | "{}" | — | — | Адаптация | — |
| world_generation | supports_region_rules | allowed_regions_csv | Разрешённые регионы | String | "" | — | — | Регионы | — |
| world_generation | supports_region_rules | blocked_regions_csv | Запрещённые регионы | String | "" | — | — | Регионы | — |
| world_generation | supports_region_rules | region_rules_json | Правила регионов JSON | String | "{}" | — | — | Регионы | — |
| world_time | has_day_night_schedule | schedule_json | Фазы суток | String | "[{\"start\":6,\"end\":18,\"phase\":\"day\"},{\"start\":18,\"end\":6,\"phase\":\"night\"}]" | — | — | Сутки | — |
| world_time | has_day_night_schedule | default_phase | Фаза по умолчанию | String | "day" | — | — | Сутки | — |
| world_time | changes_by_season | seasonal_values_json | Значения сезонов JSON | String | "{}" | — | — | Сезоны | — |
| world_time | has_timed_activation | delay_seconds | Задержка активации | Float | 2.0 | 0.0 | 31536000.0 | Таймер | — |
| world_time | has_cooldown | cooldown_seconds | Длительность перезарядки | Float | 3.0 | 0.0 | 31536000.0 | Перезарядка | — |
| world_time | supports_timed_respawn | respawn_delay | Задержка возрождения | Float | 30.0 | 0.0 | 31536000.0 | Возрождение | — |
| world_time | has_lifespan | lifespan_seconds | Время жизни | Float | 60.0 | 0.0 | 31536000.0 | Срок жизни | — |
| world_time | reacts_to_weather | allowed_weather_csv | Допустимая погода | String | "" | — | — | Погода | — |
| world_time | reacts_to_weather | weather_effects_json | Эффекты погоды JSON | String | "{}" | — | — | Погода | — |
| world_time | has_periodic_output | production_table_path | Путь к ресурсу производства | String | "" | — | — | Производство | — |
| world_time | has_periodic_output | output_item_id | Предмет | String | "resource" | — | — | Производство | — |
| world_time | has_periodic_output | output_interval | Интервал | Float | 60.0 | 0.1 | 31536000.0 | Производство | — |
| world_time | has_periodic_output | amount_per_cycle | Количество за цикл | Integer | 1 | 1 | 999999 | Производство | — |
| world_time | has_periodic_output | production_table_json | Таблица результатов (резерв) | String | "[]" | — | — | Производство | — |
| world_time | supports_signal_triggers | event_rules_json | Правила событий JSON | String | "{}" | — | — | Сигналы | — |
| world_time | supports_event_schedule | events_json | События JSON | String | "[]" | — | — | Расписание | — |
| world_time | supports_event_schedule | hour_tolerance | Допуск по времени | Float | 0.25 | 0.0 | 12.0 | Расписание | — |

## Сверка с runtime-потребителями

Сверка выполнена по пакетным runtime-скриптам, указанным в `preload()` модулей. «Прямое совпадение» означает, что ключ явно читается в скрипте пакета; это статическая проверка, не запуск игрового цикла.

| Пакет | Runtime-файл(ы) | Прямое чтение настроек | Результат / исключения |
|---|---|---:|---|
| ai | `ai/component.gd` | 17/17 | Все объявленные ключи читаются напрямую |
| animals | `animals/component.gd` | 23/23 | Все объявленные ключи читаются напрямую |
| animation | 10 скриптов в `animation/components/` | 6/6 уникальных | Все шесть ключей распределены между анимационными компонентами; `enabled` добавляется отдельно для дочерних функций |
| audio_effects | `audio_effects/component.gd` | 25/25 уникальных | Все уникальные ключи читаются; повторяющиеся аудио-поля принадлежат разным компонентам |
| characteristics | `characteristics/components/resource_stat.gd` | 3/3 | Схема динамическая: defaults берутся из определения конкретного ресурса |
| combat | `combat/components/combat_rule.gd` | 13/13 | Все объявленные ключи читаются напрямую |
| construction | `construction/component.gd` | 21/22 уникальных | `include_placement_data` не найдено в runtime-компоненте; проверить editor/blueprint consumer |
| containers | `containers/component.gd` | 17/17 уникальных | Все уникальные ключи читаются напрямую |
| defense | `defense/defense_rule.gd` | 12/12 | Все поля сокращённого `fields`-формата читаются напрямую |
| destruction | `destruction/destruction_rule.gd` | 15/15 | Все поля сокращённого `fields`-формата читаются напрямую |
| harvesting | `harvesting/component.gd` | 14/15 напрямую | `harvest_duration` переносится через `merged_setting_key_map` в `can_be_harvested.harvest_time_seconds`; это alias, не потерянная runtime-настройка |
| interaction | 9 скриптов в `interaction/components/` | 10/10 уникальных | Параметры распределены по отдельным компонентам; `can_interact` — зарезервированная встроенная возможность |
| inventory | `inventory/component.gd` | 11/12 уникальных | `transfer_mode` не читается; `transfer_to()` переносит запрошенное количество без ветвления по этому полю |
| items | `items/component.gd` + `scripts/world_controller.gd::_update_component_pickups()` | 17/19 напрямую в компоненте; 18/19 с внешним consumer | `pickup_radius` читается WorldController через `get_setting()` у package-компонента; `currency_id` не найден среди runtime-потребителей |
| movement | 10 скриптов в `movement/components/` | 16/16 | Все объявленные ключи читаются отдельными компонентами |
| object_identity | 10 скриптов в `object_identity/` | 11/11 уникальных | Все уникальные ключи читаются отдельными компонентами |
| physics | 10 скриптов в `physics/components/` | 17/17 уникальных | Все уникальные ключи читаются отдельными компонентами |
| visual_appearance | 10 скриптов в `visual_appearance/` | 18/18 | Все уникальные ключи читаются отдельными компонентами |
| world_generation | `world_generation/component.gd` | 18/18 | Все объявленные ключи читаются напрямую |
| world_time | `world_time/component.gd` | 16/16 | Все объявленные ключи читаются напрямую |

### Найденные расхождения и зарезервированные компоненты

1. **Construction — `include_placement_data`.** Поле есть в декларации `supports_blueprint`, но строковый ключ не читается в `construction/component.gd`. До проверки всех editor/blueprint-потребителей считать его неподключённым.
2. **Inventory — `transfer_mode`.** Поле объявлено у `supports_quick_transfer`, но не используется `inventory/component.gd`. Текущая реализация `transfer_to()` не выбирает режим: она переносит переданное количество и обрабатывает извлечённые стопки по отдельности.
3. **Items — `currency_id`.** Объявлено вместе с `base_value`, но не читается `items/component.gd`; внешний потребитель валюты в проверенных исходниках не найден. Не удалять до проверки торговой/экономической интеграции.
4. **Items — `pickup_radius`.** Пакет `items` объявляет это поле у компонента `is_pickup_item` со значением по умолчанию 48.0, но `items/component.gd` его не читает. Пакетный capability ID `is_pickup_item` исключён из `module.cfg` как карточка: пользовательская встроенная карточка с тем же ID использует core-компонент `pickup`, где `pickup_radius` имеет default 24.0. Пакетный компонент `is_pickup_item` остаётся в списке component_ids, но не привязан к текущей карточке. Это потенциальный legacy/orphan-компонент и конфликтующий источник одноимённого параметра.
5. **Interaction — `can_interact`.** Пакетный модуль содержит старое определение и скрипт, но они исключены из `module.cfg`; встроенная карточка `can_interact` использует core-компонент `interactable`. Дочерние функции взаимодействия маппятся в него через `merged_component_id` и `merged_setting_key_map`.
6. **Harvesting — `harvest_duration`.** Не читается напрямую как самостоятельный ключ: при объединении `has_harvest_progress` в `can_be_harvested` он переименовывается в `harvest_time_seconds`. Runtime использует канонический ключ `can_be_harvested.harvest_time_seconds`.

### Количество определений и фактические manifest-списки

- В 20 исходных `module.gd` суммарно 197 записей `DEFINITIONS` (включая зарезервированные `can_interact` и `is_pickup_item`).
- В 20 `module.cfg` объявлено 196 component IDs и 195 capability IDs. `can_interact` исключён из package component/capability manifests; `is_pickup_item` исключён только из package capability manifest, поскольку пользовательская карточка встроенная.
- Встроенный каталог добавляет отдельные карточки `can_interact` и `is_pickup_item`; это объясняет, почему число исходных записей модулей, число manifest capability IDs и число карточек каталога не совпадают.
- Прежнее утверждение «40 Implemented / 160 Planned» нельзя считать runtime-состоянием загруженных пакетов без проверки результата регистрации `MechanicModuleLoader`: package manifests объявляют 195 capability IDs, а сами модули выставляют им `runtime_status = Implemented`. Нужна сверка фактической регистрации и readiness, а не арифметика по одному источнику.


## Статусы реализации, зависимости и связи каталога

### Статусы package-модулей

| Статус в `module.gd` | Пакеты | Capability IDs в manifests |
|---|---|---:|
| `Implemented` | ai, animals, audio_effects, characteristics, combat, construction, containers, defense, destruction, harvesting, inventory, items, world_generation, world_time | 136 |
| `Planned` | animation, interaction, movement, object_identity, physics, visual_appearance | 59 |

Все шесть пакетов со статусом `Planned` имеют runtime-скрипты и публичные методы. Но Web UI блокирует подключение карточки, если `capability.status !== "Работает"`. Наличие скрипта поэтому не делает такую механику доступной пользователю. Статус нельзя просто массово переключить на Implemented: сначала нужно проверить вызовы этих API игровым циклом и работу после подключения.

### Реестр ID

- `ObjectCapabilityLibraryData.create_definitions()` создаёт 196 библиотечных ID; два из них (`can_interact`, `is_pickup_item`) переопределяются встроенными карточками.
- `ObjectCapabilityCatalog._make_builtin_definitions()` добавляет шесть встроенных карточек: `has_health`, `can_receive_damage`, `can_attack`, `breaks_when_health_empty`, `can_interact`, `is_pickup_item`. После учёта двух перекрытий исходная база каталога содержит 200 уникальных ID.
- Package modules содержат 197 исходных записей `DEFINITIONS`; manifests регистрируют 196 component IDs и 195 capability IDs. В package capability IDs 194 совпадают с библиотечными ID, а `falls_when_destroyed` из Destruction отсутствует в библиотечном списке и добавляется как новый ID.
- Следовательно, при успешной регистрации всех 20 модулей статический путь кода даёт **201 уникальный capability ID**, а не 200. Godot не запускался, поэтому это вывод по коду регистрации, не измеренный runtime-счётчик.
- `get_builtin_total_count()`, `get_planned_count()` и `get_implemented_count()` в `ObjectCapabilityLibraryData` возвращают константы 200/160/40. Они не пересчитывают статус после регистрации модулей и не отражают package-level статусы. Это отдельная задача для рефакторинга каталога.

### Явные зависимости и конфликты

- В package-модулях найдено 10 явных dependency edges: `regenerates_health → has_health`; `can_break_into_parts`, `has_destruction_stages`, `spawns_debris`, `drops_loot_on_destroy`, `plays_destroy_animation`, `leaves_remains`, `falls_when_destroyed` и `can_explode_on_destroy` требуют `breaks_when_health_empty); `can_be_repaired → has_health`.
- Встроенные карточки добавляют ещё 2 зависимости: `can_receive_damage → has_health` и `breaks_when_health_empty → has_health`.
- В библиотеке есть 72 curated relation rows: 34 `recommends`, 34 `related`, 2 `extends`. Среди них нет `requires` или `conflicts`; эти отношения носят рекомендательный/описательный характер и не являются ограничениями совместимости.
- В package-модулях не объявлены `incompatible_capability_ids` и `compatibility_rules`; в curated relations также нет `conflicts`. На данный момент явная матрица несовместимостей пустая.
- `ObjectCapabilityCatalog._validate_dependency_graph()` проверяет циклы обязательных зависимостей и симметричность объявленных конфликтов. Но проверка конфликта ничего не ограничивает, пока сами конфликты не объявлены.

### UI gate и текущая модель редактирования

Проверен активный интерфейс `addons/web_object_builder/web/app.js`:
- `fieldType()` поддерживает только String, Integer, Float, Boolean и Vector2. Для цветов, enum, typed object/resource references, каталожных ссылок и специализированных таблиц нет универсальных редакторов.
- `openCapabilitySettingsDialog()` строит плоский список полей; `group_name`, `level`, `required`, enum options и units не используются для группировки/выбора режима. JSON по суффиксу `_json` превращается в textarea; отдельные resource-table path имеют picker.
- `renderComponentsInspector()` оставляет отдельное редактирование низкоуровневых компонентов и ручное добавление/удаление. Это второй путь изменения параметров наряду с настройками механики.
- `renderInstalled()` и `renderBehaviorInspector()` показывают установленные механики в двух разных областях интерфейса.
- `renderCapabilityDetail()` разрешает подключение только при статусе `Работает`; поэтому шесть package-групп со статусом Planned недоступны через обычную кнопку подключения, даже если их component scripts существуют.


## Встроенные компоненты каталога (отдельно от package-модулей)

Эти 35 полей объявлены в `ObjectComponentDefinition.get_builtin_setting_definitions()` и не входят в счётчик 347 package-объявлений.

| Core component | Ключ | Название в редакторе | Тип | Default | Минимум | Максимум | Группа | Required |
|---|---|---|---|---|---:|---:|---|---|
| damageable | can_receive_damage | Принимать урон | Boolean | true | — | — | Защита | — |
| damageable | material_type | Материал | String | "" | — | — | Добыча | — |
| damageable | required_tool_id | Требуемый инструмент | String | "" | — | — | Инструмент | — |
| damageable | hit_radius | Радиус попадания | Float | 18.0 | 1.0 | 512.0 | Попадание | — |
| damageable | damage_multiplier | Множитель входящего урона | Float | 1.0 | 0.0 | 10.0 | Сопротивление | — |
| damageable | flat_reduction | Плоское снижение урона | Float | 0.0 | 0.0 | 1000000.0 | Сопротивление | — |
| attack | attack_damage | Урон атаки | Float | 12.0 | 0.0 | 1000000.0 | Атака | — |
| attack | attack_range | Дистанция атаки | Float | 220.0 | 0.0 | 100000.0 | Атака | — |
| attack | cooldown | Перезарядка | Float | 0.4 | 0.0 | 60.0 | Атака | — |
| attack | require_range | Проверять дистанцию | Boolean | true | — | — | Ограничения | — |
| attack | can_attack | Разрешить атаку | Boolean | true | — | — | Ограничения | — |
| destructible | destroy_on_zero_health | Разрушать при нулевом здоровье | Boolean | true | — | — | Условия | — |
| destructible | disable_collision_on_destroy | Отключать коллизии | Boolean | true | — | — | После разрушения | — |
| destructible | disable_damage_on_destroy | Отключать получение урона | Boolean | true | — | — | После разрушения | — |
| destructible | hide_on_destroy | Скрывать объект | Boolean | true | — | — | После разрушения | — |
| destructible | remove_on_destroy | Удалять объект | Boolean | false | — | — | После разрушения | — |
| destructible | destroy_delay | Задержка удаления | Float | 0.0 | 0.0 | 300.0 | После разрушения | — |
| destructible | restore_health_on_repair | Восстанавливать здоровье при починке | Boolean | true | — | — | Восстановление | — |
| pickup | item_id | Предмет | String | "" | — | — | Предмет | **true** |
| pickup | quantity | Количество | Integer | 1 | 1 | 99999 | Предмет | — |
| pickup | pickup_radius | Радиус подбора | Float | 24.0 | 1.0 | 512.0 | Доступность | — |
| pickup | can_be_picked_up | Разрешить подбор | Boolean | true | — | — | Доступность | — |
| pickup | remove_object_when_empty | Удалить объект после подбора | Boolean | true | — | — | После подбора | — |
| interactable | can_be_interacted_with | Разрешить взаимодействие | Boolean | true | — | — | Доступность | — |
| interactable | prompt_text | Текст подсказки | String | "E — Взаимодействовать" | — | — | Подсказка | — |
| interactable | interaction_radius | Радиус взаимодействия | Float | 72.0 | 1.0 | 512.0 | Дистанция | — |
| interactable | interaction_method | Метод объекта | String | "" | — | — | Действие | — |
| interactable | interact_once | Только один раз | Boolean | false | — | — | Действие | — |
| interactable | cooldown_seconds | Перезарядка взаимодействия | Float | 0.25 | 0.0 | 60.0 | Действие | — |
| health | max_health | Максимальное здоровье | Float | 100.0 | 1.0 | 1000000.0 | Здоровье | — |
| health | starting_health | Начальное здоровье | Float | 100.0 | 0.0 | 1000000.0 | Здоровье | — |
| health | invulnerable | Неуязвимость | Boolean | false | — | — | Защита | — |
| health | can_heal | Разрешить лечение | Boolean | true | — | — | Восстановление | — |
| health | regeneration_enabled | Автоматическая регенерация | Boolean | false | — | — | Восстановление | — |
| health | health_regeneration_per_second | Здоровье в секунду | Float | 1.0 | 0.0 | 100000.0 | Восстановление | — |

### Динамические defaults характеристик

В пакете `characteristics` defaults берутся из `DEFINITIONS[item].defaults` и подставляются в `_settings_for()`. Поэтому одинаковая схема полей имеет разные исходные значения для разных capability:

| Capability | Текущее | Минимум | Максимум |
|---|---:|---:|---:|
| has_stamina | 100.0 | 0.0 | 100.0 |
| has_mana | 100.0 | 0.0 | 100.0 |
| has_energy | 100.0 | 0.0 | 100.0 |
| has_hunger | 100.0 | 0.0 | 100.0 |
| has_thirst | 100.0 | 0.0 | 100.0 |
| has_temperature | 37.0 | 30.0 | 42.0 |
| has_weight_limit | 0.0 | 0.0 | 50.0 |
| has_mood | 0.0 | -100.0 | 100.0 |
| has_reputation | 0.0 | -100.0 | 100.0 |

**Обязательность:** среди встроенных полей только `pickup.item_id` явно помечено `required: true`. Поля `pickup.item_id`, `animals.resource_item_id` и `world_time.output_item_id` используют typed `catalog_reference` редактор с `reference_type = item`; остальные ID-поля ещё требуют классификации. Для этого поля задан presentation editor `catalog_reference` с `reference_type = item`; фактический Web picker ещё не реализован. В package-декларациях обязательность практически нигде не задана; пустой default не означает required.


## Уровни сложности полей (Basic / Advanced / Expert)

- Во всех 20 package-модулях отсутствуют декларации `level` и `advanced` для полей. `ObjectCapabilityCatalog._resolve_settings_schema()` поэтому назначает им уровень **Basic** по умолчанию — включая большие JSON-строки, ID и технические таблицы.
- У встроенных карточек есть точечные overrides:
  - `health`: `can_heal` — Advanced; `invulnerable` — Expert.
  - `damageable`: `flat_reduction` — Advanced; остальные overrides для `material_type`, `required_tool_id`, `hit_radius` — Basic.
  - `attack`: `require_range`, `can_attack` — Advanced.
  - `destructible`: `destroy_delay`, `disable_collision_on_destroy`, `disable_damage_on_destroy` — Advanced; `hide_on_destroy`, `remove_on_destroy` — Expert.
  - `pickup`: `pickup_radius`, `can_be_picked_up`, `remove_object_when_empty` — Advanced; `item_id`, `quantity` — Basic.
  - `interactable`: `interaction_method`, `interact_once`, `cooldown_seconds` — Advanced; `can_be_interacted_with`, `prompt_text`, `interaction_radius` — Basic.
- Поля core-компонентов, не перечисленные в этих overrides, также остаются Basic.
- Активный Web UI не использует `level` при построении формы. Поэтому Advanced/Expert сейчас не скрываются и не группируются, а package JSON/ID поля ошибочно выглядят как обычные Basic-настройки.
