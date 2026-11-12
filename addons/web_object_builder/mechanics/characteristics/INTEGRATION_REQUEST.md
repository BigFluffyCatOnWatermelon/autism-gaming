# Интеграция: характеристики

<badge>Подключено к Object Builder</badge>

Девять характеристик зарегистрированы в центральных реестрах и доступны в простом режиме: stamina, mana, energy, hunger, thirst, temperature, weight limit, mood и reputation. Health остаётся отдельной встроенной возможностью.

Параметры редактируются стандартным Inspector Object Builder и хранятся в ObjectCapabilitySelection. ObjectCapabilityService создаёт привязку, ObjectFactory создаёт runtime-компонент.

Публичные операции: get_value, get_maximum, set_value, add_value, spend_value, get_ratio и tick(delta, rate_per_second). Положительная скорость увеличивает значение, отрицательная уменьшает. Голод и жажда не убывают автоматически: игровой код должен вызывать tick() с отрицательной скоростью.

Проверки регистрации, валидации выбора, Component Binding и создания runtime-компонента добавлены в tests/object_system_smoke.gd. GitHub Actions на Godot 4.7.2 подтвердил импорт/разбор, smoke-тесты и запуск основной сцены.
