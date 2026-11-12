# Интеграция: защита

**Статус: подключено к Object Builder.**

Десять защитных возможностей зарегистрированы в центральных реестрах и доступны в простом режиме: has_armor, has_damage_resistance, has_immunity, has_shield, reduces_projectile_damage, reflects_projectiles, has_invulnerability_window, has_weak_points, resists_status_effects и regenerates_health.

Настройки редактируются штатным Inspector Object Builder и сохраняются через ObjectCapabilitySelection. Component Bindings создаются ObjectCapabilityService, runtime-компоненты — ObjectFactory. Регенерация здоровья автоматически требует has_health.

Публичные операции: calculate_armored_damage, calculate_typed_damage, is_effect_immune, absorb_damage_with_shield, calculate_projectile_damage, reflect_projectile, begin_invulnerability_window, tick_invulnerability_window, is_invulnerable, get_weak_point_multiplier, get_status_effect_multiplier, regenerate_health, get_shield_ratio и restore_shield.

Игровая сцена вызывает нужные методы при расчёте урона и обработке эффектов. Сам компонент не перехватывает ввод и не встраивается в Damageable автоматически.

GitHub Actions / Godot 4.7.2 прошёл импорт/разбор, Object System smoke-тесты и запуск основной сцены.
