# Интеграция: дополнительные механики разрушения

**Статус: подключено к Object Builder.**

Девять дополнительных возможностей зарегистрированы в центральных реестрах: can_break_into_parts, has_destruction_stages, spawns_debris, drops_loot_on_destroy, plays_destroy_animation, leaves_remains, can_be_repaired, can_regrow и can_explode_on_destroy. Базовое breaks_when_health_empty остаётся встроенным компонентом.

Возможности доступны в простом режиме, их настройки редактируются стандартным Inspector и сохраняются через ObjectCapabilitySelection. Для механик, выполняемых при уничтожении, автоматически добавляется breaks_when_health_empty; can_be_repaired требует has_health.

Публичные операции: get_parts_plan, spawn_break_parts, get_destruction_stage, get_debris_spawn_data, spawn_debris, roll_loot, play_destroy_animation, spawn_remains, repair_health, start_regrowth, tick_regrowth и get_explosion_payload.

Компонент создаёт заданные сцены частей, обломков и остатков при корректно настроенных путях ресурсов; таблица добычи возвращает выбранные записи; ремонт вызывает Health.heal(); таймер восстановления и данные взрыва передаются игровой сцене. Игровой код отвечает за момент вызова и применение результатов.

GitHub Actions / Godot 4.7.2 прошёл импорт/разбор, Object System smoke-тесты и запуск основной сцены.
