# Интеграция: характеристики

Содержит девять характеристик: stamina, mana, energy, hunger, thirst, temperature, weight limit, mood и reputation. Health уже реализован отдельно.

Все механики используют ограниченное числовое состояние: current_value, maximum_value и minimum_value. Публичные операции: get_value, set_value, add_value, spend_value, get_ratio и tick(delta, rate_per_second). Положительная скорость увеличивает значение, отрицательная уменьшает.

До включения в UI/реестр: проверить сохранение runtime-состояния, тесты границ и восстановление после сериализации. Не помечать как работающие до прохождения smoke-тестов.
