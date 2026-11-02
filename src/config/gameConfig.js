/**
 * Central gameplay configuration.
 *
 * Keep frequently tuned values here instead of scattering magic numbers
 * through scenes and UI. Debug Inspector fields are declared at the bottom:
 * adding a field there makes it editable at runtime with F3.
 */
export const GAME_CONFIG = {
  world: {
    width: 3600, // World width in world pixels.
    height: 3600, // World height in world pixels.
    grassTileSize: 32, // Source tile size. Keep in sync with grass.png.
    detailCount: 1700, // Extra grass pixels scattered over the base tile.
  },

  player: {
    maxHealth: 100, // Maximum health.
    maxStamina: 100, // Maximum stamina.
    walkSpeed: 155, // Normal movement speed, world pixels per second.
    runMultiplier: 1.65, // Shift movement speed multiplier.
    crouchMultiplier: 0.52, // C movement speed multiplier.
    rollSpeedMultiplier: 3.3, // Dodge movement speed multiplier.
    rollDurationMs: 260, // Length of one dodge.
    rollCooldownMs: 680, // Delay before another dodge.
    rollStaminaCost: 22, // Stamina spent when a dodge starts.
    staminaRunDrain: 19, // Stamina drained per second while sprinting.
    staminaRegen: 16, // Stamina restored per second when not spending it.
    strength: 10, // Attribute used by the damage formula.
    agility: 10, // Attribute reserved for movement and critical chance.
    defense: 0, // Flat incoming damage reduction.
    hurtFlashMs: 180, // Future damage feedback duration.
  },

  camera: {
    baseZoom: 1.85, // Normal camera zoom.
    runZoom: 1.58, // Smaller zoom while sprinting (wider field of view).
    crouchZoom: 2.15, // Larger zoom while crouching (closer view).
    followLerp: 0.12, // Camera follow smoothing; 1 means no smoothing.
    zoomTransitionMs: 230, // Smooth camera zoom transition.
    shakeDurationMs: 125, // Duration of impact shake.
    shakeIntensity: 0.006, // Phaser camera shake intensity.
  },

  combat: {
    attackStaminaCost: 7, // Stamina spent per melee attack.
    defaultCooldownMs: 380, // Fallback cooldown.
    damageAttributeScale: 0.025, // Strength damage scaling per point over 10.
    slashRadius: 76, // Sword sweep range.
    slashArcDegrees: 112, // Sweep angle in front of the player.
    slashDurationMs: 230, // Visual lifetime of sword sweep.
    thrustRange: 112, // Sword thrust reach.
    thrustWidth: 25, // Half-width of thrust hit line.
    thrustDurationMs: 170, // Visual lifetime of thrust trail.
    toolEffectDurationMs: 210, // Visual lifetime of tool impact.
    arrowSpeed: 620, // Arrow projectile speed.
    arrowRange: 620, // Maximum arrow travel distance.
  },

  weapons: {
    sword: {
      damage: 24,
      damageType: 'cutting',
      cooldownMs: 420,
      reach: 76,
      slash: {
        name: 'Размашистый удар',
        damage: 26,
        damageType: 'cutting',
        cooldownMs: 520,
        staminaCost: 9,
        reach: 76,
        arcDegrees: 118,
      },
      thrust: {
        name: 'Тычок',
        damage: 19,
        damageType: 'piercing',
        cooldownMs: 310,
        staminaCost: 6,
        reach: 116,
        width: 24,
      },
    },
    pickaxe: {
      damage: 20,
      damageType: 'piercing',
      cooldownMs: 610,
      reach: 66,
      stoneMultiplier: 2.4, // Pickaxes are effective against stone.
      woodMultiplier: 0.45,
    },
    axe: {
      damage: 25,
      damageType: 'cutting',
      cooldownMs: 560,
      reach: 72,
      woodMultiplier: 2.5, // Axes are effective against trees and wood.
      stoneMultiplier: 0.35,
    },
    bow: {
      damage: 18,
      damageType: 'piercing',
      cooldownMs: 520,
      reach: 620,
      projectileSpeed: 620,
      staminaCost: 3,
    },
  },

  inventory: {
    hotbarSlots: 9, // Always shown at the bottom of the screen.
    baseBackpackSlots: 12, // Initially available backpack slots.
    maxBackpackSlots: 24, // Future shop expansion limit.
    backpackExpansionStep: 3, // Slots per future purchase.
    startingArrows: 30,
  },

  settings: {
    screenShake: true,
    cameraEffects: true,
    showFps: false,
    masterVolume: 0.7, // Reserved for when sound is added.
  },
};

/**
 * Runtime inspector schema.
 * Every field has a human-readable label, bounds, step and an explanation.
 * To make another value editable in F3, add a descriptor here.
 */
export const DEBUG_FIELDS = [
  // Player and character attributes.
  { scope: 'player', path: 'player.maxHealth', label: 'Макс. здоровье', min: 1, max: 1000, step: 1, description: 'Верхний предел здоровья.' },
  { scope: 'player', path: 'player.maxStamina', label: 'Макс. выносливость', min: 1, max: 1000, step: 1, description: 'Верхний предел выносливости.' },
  { scope: 'player', path: 'player.walkSpeed', label: 'Скорость ходьбы', min: 20, max: 600, step: 5, description: 'Скорость в мировых пикселях в секунду.' },
  { scope: 'player', path: 'player.runMultiplier', label: 'Множитель бега', min: 1, max: 3, step: 0.05, description: 'Во сколько раз бег быстрее ходьбы.' },
  { scope: 'player', path: 'player.crouchMultiplier', label: 'Множитель приседа', min: 0.1, max: 1, step: 0.05, description: 'Скорость во время приседания.' },
  { scope: 'player', path: 'player.rollSpeedMultiplier', label: 'Скорость переката', min: 1, max: 6, step: 0.1, description: 'Множитель скорости во время переката.' },
  { scope: 'player', path: 'player.rollDurationMs', label: 'Длительность переката', min: 80, max: 800, step: 10, description: 'Продолжительность переката в миллисекундах.' },
  { scope: 'player', path: 'player.rollCooldownMs', label: 'Перезарядка переката', min: 100, max: 2000, step: 20, description: 'Задержка перед следующим перекатом.' },
  { scope: 'player', path: 'player.rollStaminaCost', label: 'Цена переката', min: 0, max: 100, step: 1, description: 'Сколько выносливости тратится на перекат.' },
  { scope: 'player', path: 'player.staminaRunDrain', label: 'Расход при беге', min: 0, max: 100, step: 1, description: 'Расход выносливости в секунду.' },
  { scope: 'player', path: 'player.staminaRegen', label: 'Восстановление выносливости', min: 0, max: 150, step: 1, description: 'Восстановление в секунду.' },
  { scope: 'player', path: 'player.strength', label: 'Сила', min: 0, max: 100, step: 1, description: 'Влияет на наносимый урон.' },
  { scope: 'player', path: 'player.agility', label: 'Ловкость', min: 0, max: 100, step: 1, description: 'Зарезервировано для мобильности и критов.' },
  { scope: 'player', path: 'player.defense', label: 'Защита', min: 0, max: 200, step: 1, description: 'Плоское снижение входящего урона.' },

  // Camera tuning.
  { scope: 'camera', path: 'camera.baseZoom', label: 'Обычный зум', min: 0.7, max: 3.5, step: 0.05, description: 'Базовое приближение камеры.' },
  { scope: 'camera', path: 'camera.runZoom', label: 'Зум при беге', min: 0.7, max: 3.5, step: 0.05, description: 'Меньше значение — шире обзор.' },
  { scope: 'camera', path: 'camera.crouchZoom', label: 'Зум при приседе', min: 0.7, max: 3.5, step: 0.05, description: 'Больше значение — ближе камера.' },
  { scope: 'camera', path: 'camera.followLerp', label: 'Плавность слежения', min: 0.01, max: 1, step: 0.01, description: 'Насколько быстро камера догоняет игрока.' },
  { scope: 'camera', path: 'camera.zoomTransitionMs', label: 'Переход зума', min: 50, max: 1000, step: 10, description: 'Время смены приближения.' },
  { scope: 'camera', path: 'camera.shakeDurationMs', label: 'Длительность тряски', min: 0, max: 1000, step: 10, description: 'Продолжительность тряски камеры.' },
  { scope: 'camera', path: 'camera.shakeIntensity', label: 'Сила тряски', min: 0, max: 0.05, step: 0.001, description: 'Интенсивность тряски при попадании.' },

  // Melee and ranged combat.
  { scope: 'combat', path: 'combat.attackStaminaCost', label: 'Цена обычной атаки', min: 0, max: 50, step: 1, description: 'Базовая стоимость атаки.' },
  { scope: 'combat', path: 'combat.slashRadius', label: 'Радиус размашистого удара', min: 20, max: 200, step: 2, description: 'Дистанция удара по области.' },
  { scope: 'combat', path: 'combat.slashArcDegrees', label: 'Угол размашистого удара', min: 20, max: 240, step: 2, description: 'Ширина сектора перед персонажем.' },
  { scope: 'combat', path: 'combat.slashDurationMs', label: 'След размашистого удара', min: 60, max: 800, step: 10, description: 'Длительность визуального следа.' },
  { scope: 'combat', path: 'combat.thrustRange', label: 'Дальность тычка', min: 20, max: 260, step: 2, description: 'Длина колющего удара.' },
  { scope: 'combat', path: 'combat.thrustWidth', label: 'Ширина тычка', min: 4, max: 80, step: 1, description: 'Половина ширины зоны попадания.' },
  { scope: 'combat', path: 'combat.thrustDurationMs', label: 'След тычка', min: 50, max: 700, step: 10, description: 'Время отображения колющего следа.' },
  { scope: 'combat', path: 'combat.toolEffectDurationMs', label: 'Эффект инструмента', min: 50, max: 700, step: 10, description: 'Время отображения удара топором или киркой.' },
  { scope: 'combat', path: 'combat.arrowSpeed', label: 'Скорость стрелы', min: 100, max: 1600, step: 10, description: 'Скорость полёта стрелы.' },
  { scope: 'combat', path: 'combat.arrowRange', label: 'Дальность стрелы', min: 100, max: 1800, step: 10, description: 'Максимальная дальность полёта стрелы.' },

  // Weapon stats (individual attacks are separate records).
  { scope: 'weapons', path: 'weapons.sword.slash.damage', label: 'Меч · размашистый урон', min: 1, max: 250, step: 1, description: 'Режущий урон по сектору.' },
  { scope: 'weapons', path: 'weapons.sword.slash.cooldownMs', label: 'Меч · перезарядка замаха', min: 80, max: 2000, step: 10, description: 'Задержка между замахами.' },
  { scope: 'weapons', path: 'weapons.sword.slash.staminaCost', label: 'Меч · расход замаха', min: 0, max: 100, step: 1, description: 'Стоимость размашистой атаки.' },
  { scope: 'weapons', path: 'weapons.sword.slash.reach', label: 'Меч · радиус замаха', min: 20, max: 200, step: 2, description: 'Радиус зоны поражения.' },
  { scope: 'weapons', path: 'weapons.sword.thrust.damage', label: 'Меч · урон тычка', min: 1, max: 250, step: 1, description: 'Колющий урон по узкой линии.' },
  { scope: 'weapons', path: 'weapons.sword.thrust.cooldownMs', label: 'Меч · перезарядка тычка', min: 80, max: 2000, step: 10, description: 'Задержка между тычками.' },
  { scope: 'weapons', path: 'weapons.sword.thrust.staminaCost', label: 'Меч · расход тычка', min: 0, max: 100, step: 1, description: 'Стоимость колющей атаки.' },
  { scope: 'weapons', path: 'weapons.pickaxe.damage', label: 'Кирка · урон', min: 1, max: 250, step: 1, description: 'Базовый урон кирки.' },
  { scope: 'weapons', path: 'weapons.pickaxe.stoneMultiplier', label: 'Кирка · бонус по камню', min: 0.1, max: 10, step: 0.1, description: 'Множитель урона по каменным целям.' },
  { scope: 'weapons', path: 'weapons.pickaxe.woodMultiplier', label: 'Кирка · бонус по дереву', min: 0.1, max: 10, step: 0.1, description: 'Множитель урона по деревянным целям.' },
  { scope: 'weapons', path: 'weapons.axe.damage', label: 'Топор · урон', min: 1, max: 250, step: 1, description: 'Базовый урон топора.' },
  { scope: 'weapons', path: 'weapons.axe.woodMultiplier', label: 'Топор · бонус по дереву', min: 0.1, max: 10, step: 0.1, description: 'Множитель урона по деревьям и древесине.' },
  { scope: 'weapons', path: 'weapons.axe.stoneMultiplier', label: 'Топор · бонус по камню', min: 0.1, max: 10, step: 0.1, description: 'Множитель урона по камню.' },
  { scope: 'weapons', path: 'weapons.bow.damage', label: 'Лук · урон стрелы', min: 1, max: 250, step: 1, description: 'Базовый колющий урон стрелы.' },
  { scope: 'weapons', path: 'weapons.bow.cooldownMs', label: 'Лук · перезарядка', min: 80, max: 2000, step: 10, description: 'Задержка между выстрелами.' },

  // Inventory setup.
  { scope: 'inventory', path: 'inventory.baseBackpackSlots', label: 'Открытые ячейки рюкзака', min: 1, max: 24, step: 1, description: 'Количество доступных ячеек до расширений.' },
  { scope: 'inventory', path: 'inventory.maxBackpackSlots', label: 'Максимум ячеек рюкзака', min: 1, max: 60, step: 1, description: 'Верхний предел после будущих покупок.' },
  { scope: 'inventory', path: 'inventory.backpackExpansionStep', label: 'Ячеек за расширение', min: 1, max: 12, step: 1, description: 'Сколько ячеек добавляет покупка.' },
  { scope: 'inventory', path: 'inventory.startingArrows', label: 'Стартовые стрелы', min: 0, max: 999, step: 1, description: 'Начальное количество стрел в колчане.' },
];

export const DEBUG_SCOPES = [
  { id: 'player', label: 'Игрок' },
  { id: 'camera', label: 'Камера' },
  { id: 'combat', label: 'Бой' },
  { id: 'weapons', label: 'Оружие' },
  { id: 'inventory', label: 'Инвентарь' },
];
