# Бой — runtime-модуль

Содержит десять механик каталога. Атака и получение урона используют существующие AttackComponent и DamageableComponent. Восемь дополнительных правил используют общий компонент CombatRule.

## API правил
Блок: `block_damage`; парирование: `resolve_parry`; уклонение: `begin_dodge`; прицеливание: `set_aim_direction`; заряд: `get_charge_multiplier`; крит: `roll_critical_hit`; комбо: `register_combo_hit` и `advance_combo`; цель: `set_target`, `get_target`, `clear_target`.

Возвращённые значения — результат расчёта, а не автоматическое изменение чужого компонента. Runtime должен интегрировать их в pipeline атаки/получения урона.

## Статус
Компоненты и тестовый сценарий добавлены. UI/реестр и интеграция боевого pipeline ещё не завершены; статус каталога не повышать.
