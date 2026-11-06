@tool
extends "res://addons/object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"initial_experience": 0})
    set_option("initial_experience", maxi(0, int(get_option("initial_experience", 0))))


func get_experience() -> int:
    return int(get_option("initial_experience", 0))


func add_experience(amount: int) -> bool:
    if amount <= 0:
        return fail("Количество опыта должно быть больше нуля.")
    var current := get_experience()
    if amount > 2147483647 - current:
        return fail("Достигнут максимальный лимит опыта.")
    return set_option("initial_experience", current + amount)


func spend_experience(amount: int) -> bool:
    if amount <= 0 or amount > get_experience():
        return fail("Недостаточно опыта или указано неверное количество.")
    return set_option("initial_experience", get_experience() - amount)
