# Интеграция: бой

<badge>Подключено к Object Builder</badge>

Восемь новых механик зарегистрированы в центральных реестрах и доступны в простом режиме: блокирование, парирование, уклонение, прицеливание, заряженная атака, критический удар, комбо и выбор цели. Атака и получение урона используют существующие core-компоненты Attack и Damageable; повторно они не регистрируются.

Публичные методы: block_damage, resolve_parry, begin_dodge, set_aim_direction, get_charge_multiplier, roll_critical_hit, register_combo_hit, advance_combo, set_target, get_target и clear_target.

Правила предоставляют рабочие операции, но не перехватывают ввод и не меняют игровой pipeline самостоятельно. Runtime должен вызывать их в правильный момент и применить возвращённый результат: например, учесть block_damage() при расчёте урона, обработать результат resolve_parry() или начать окно begin_dodge(). Настройки доступны через обычный Inspector и сериализуются через ObjectCapabilitySelection.

Проверки регистрации, валидации выбора, Component Binding и runtime-вызова правила блока добавлены в tests/object_system_smoke.gd. Выполнение Godot CI ещё требуется подтвердить.
