import Phaser from 'phaser';
import { GAME_CONFIG, STARTING_ITEMS } from '../../config/gameConfig.js';
import { createGrassTexture, createPlayerTextures, createWorldObjectTextures } from '../utils/PixelArt.js';
import { GameLogger } from '../utils/Logger.js';
import { PlayerController } from '../entities/Player.js';
import { CameraController } from '../systems/CameraController.js';
import { CombatSystem } from '../systems/CombatSystem.js';

/**
 * Главная игровая сцена. Здесь размещается мир и соединяются системы.
 * Сам баланс вынесен в config/gameConfig.js, а интерфейс — в GameUI.js.
 */
export class WorldScene extends Phaser.Scene {
  constructor() {
    super('WorldScene');
    this.resources = [];
    this.projectiles = [];
    this.selectedSlot = 0;
    this.backpackSlots = GAME_CONFIG.inventory.startingBackpackSlots;
    this.debugEnabled = GAME_CONFIG.debug.enabledAtStart;
    this.debugSelection = null;
    this.nextEntityId = 1;
    this.uiUpdateTimer = 0;
  }

  create() {
    this.logger = new GameLogger(GAME_CONFIG.debug.logLimit);
    this.playerData = {
      health: GAME_CONFIG.player.maxHealth,
      maxHealth: GAME_CONFIG.player.maxHealth,
      stamina: GAME_CONFIG.player.maxStamina,
      maxStamina: GAME_CONFIG.player.maxStamina,
      armor: GAME_CONFIG.player.armor,
      level: 1,
      experience: 0,
      arrows: GAME_CONFIG.inventory.startingArrows,
      backpackSlots: this.backpackSlots,
      gold: 0,
    };

    createGrassTexture(this);
    createPlayerTextures(this);
    createWorldObjectTextures(this);
    this.createWorld();

    this.player = new PlayerController(this);
    this.cameraController = new CameraController(this, this.player.sprite);
    this.combat = new CombatSystem(this);

    this.input.mouse.disableContextMenu();
    this.input.on('pointerdown', (pointer) => this.handlePointerDown(pointer));
    this.input.on('pointermove', (pointer) => this.handlePointerMove(pointer));
    this.bindKeyboard();
    this.applySavedSettings();

    this.log('Мир загружен. Добро пожаловать!', 'success');
    this.game.events.emit('scene-ready', this);
    this.game.events.emit('inventory-update', this.getInventoryData());
    this.game.events.emit('settings-update', this.settings);
    this.game.events.emit('debug-toggle', this.debugEnabled);
  }

  createWorld() {
    const world = GAME_CONFIG.world;
    const left = -world.width / 2;
    const top = -world.height / 2;

    // Один повторяемый пиксельный тайл покрывает всю карту травой.
    this.add.tileSprite(left, top, world.width, world.height, 'grass-tile')
      .setOrigin(0, 0)
      .setDepth(-100);

    this.physics.world.setBounds(left, top, world.width, world.height);
    this.cameras.main.setBounds(left, top, world.width, world.height);

    // Слегка более тёмные пятна земли — только декор, не препятствия.
    const decoration = this.add.graphics().setDepth(-90);
    decoration.fillStyle(0x315f35, 0.13);
    for (let i = 0; i < 150; i += 1) {
      const x = Phaser.Math.Between(left, -left);
      const y = Phaser.Math.Between(top, -top);
      decoration.fillRect(x, y, Phaser.Math.Between(3, 9), Phaser.Math.Between(2, 5));
    }

    const spawnRadius = world.keepSpawnClearRadius;
    for (let i = 0; i < world.treeCount + world.rockCount; i += 1) {
      let x = 0;
      let y = 0;
      let attempts = 0;
      do {
        x = Phaser.Math.Between(left + 90, -left - 90);
        y = Phaser.Math.Between(top + 90, -top - 90);
        attempts += 1;
      } while (Math.hypot(x, y) < spawnRadius && attempts < 20);

      const type = i < world.treeCount ? 'tree' : 'rock';
      this.createResource(type, x, y);
    }
  }

  createResource(type, x, y) {
    const isTree = type === 'tree';
    const texture = isTree ? 'tree-sprite' : 'rock-sprite';
    const sprite = this.add.image(x, y, texture).setDepth(y + 1);
    sprite.setScale(isTree ? 1.25 : 1.35);

    const shadow = this.add.ellipse(
      x,
      y + (isTree ? 23 : 10),
      isTree ? 35 : 32,
      isTree ? 13 : 10,
      0x101b12,
      0.35,
    ).setDepth(y);

    const target = {
      id: `resource-${this.nextEntityId++}`,
      type,
      label: isTree ? 'Дерево' : 'Камень',
      x,
      y,
      health: isTree ? 90 : 110,
      maxHealth: isTree ? 90 : 110,
      radius: isTree ? 29 : 24,
      sprite,
      shadow,
      active: true,
    };
    this.resources.push(target);
    return target;
  }

  bindKeyboard() {
    const keyboard = this.input.keyboard;
    this.uiKeys = {
      inventory: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.B),
      settings: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ESC),
      debug: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.F3),
      close: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ESC),
    };

    this.hotbarKeys = Array.from({ length: 9 }, (_, index) =>
      keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ONE + index),
    );

    this.game.events.on('ui-action', (action) => this.handleUIAction(action));
  }

  applySavedSettings() {
    const defaults = { cameraShake: GAME_CONFIG.camera.enableShake, showGrid: false, zoomMultiplier: 1 };
    try {
      this.settings = { ...defaults, ...JSON.parse(localStorage.getItem('autism-gaming-settings') || '{}') };
    } catch {
      this.settings = defaults;
    }
    this.cameraController?.setShakeEnabled(this.settings.cameraShake);
  }

  saveSettings() {
    localStorage.setItem('autism-gaming-settings', JSON.stringify(this.settings));
    this.game.events.emit('settings-update', this.settings);
  }

  handleUIAction(action) {
    if (!action || !action.type) return;
    switch (action.type) {
      case 'select-slot':
        this.selectSlot(action.index);
        break;
      case 'expand-backpack':
        this.expandBackpack();
        break;
      case 'setting':
        this.updateSetting(action.key, action.value);
        break;
      case 'debug-property':
        this.setDebugProperty(action.id, action.key, action.value);
        break;
      case 'debug-target':
        this.selectDebugTarget(action.target);
        break;
      case 'clear-logs':
        this.logger.entries.length = 0;
        this.game.events.emit('logs-cleared');
        break;
      case 'close-overlays':
        this.game.events.emit('ui-close-overlays');
        break;
      default:
        break;
    }
  }

  updateSetting(key, value) {
    if (!(key in this.settings)) return;
    this.settings[key] = value;
    if (key === 'cameraShake') this.cameraController.setShakeEnabled(value);
    this.saveSettings();
    this.log(`Настройка изменена: ${key} = ${value}`);
  }

  bindKeyboardEvents() {
    // Оставлено для будущих дополнительных действий с клавиатуры.
  }

  update(time, delta) {
    this.player.update(time, delta);
    this.cameraController.update({
      running: this.player.running,
      crouching: this.player.crouching,
    });

    this.updateProjectiles(delta);
    this.updateHoverSelection();

    if (Phaser.Input.Keyboard.JustDown(this.uiKeys.inventory)) {
      this.game.events.emit('ui-toggle-inventory');
    }
    if (Phaser.Input.Keyboard.JustDown(this.uiKeys.settings)) {
      this.game.events.emit('ui-toggle-settings');
    }
    if (Phaser.Input.Keyboard.JustDown(this.uiKeys.debug)) {
      this.toggleDebug();
    }

    this.hotbarKeys.forEach((key, index) => {
      if (Phaser.Input.Keyboard.JustDown(key)) this.selectSlot(index);
    });

    this.uiUpdateTimer += delta;
    if (this.uiUpdateTimer >= 120) {
      this.uiUpdateTimer = 0;
      this.game.events.emit('player-update', this.getPlayerData());
    }
  }

  handlePointerDown(pointer) {
    if (this.debugEnabled) {
      const entity = this.getInspectableEntityAt(pointer.worldX, pointer.worldY);
      if (entity) {
        this.selectDebugEntity(entity);
        return;
      }
    }

    const selected = STARTING_ITEMS[this.selectedSlot];
    if (!selected) return;
    const angle = Phaser.Math.Angle.Between(
      this.player.sprite.x, this.player.sprite.y, pointer.worldX, pointer.worldY,
    );

    if (selected.id === 'sword') {
      this.combat.attack('sword', pointer.button === 2 ? 'secondary' : 'primary', angle);
    } else if (selected.id === 'bow') {
      this.combat.attack('bow', 'primary', angle);
    } else if (selected.id === 'axe' || selected.id === 'pickaxe') {
      this.combat.attack(selected.id, 'primary', angle);
    } else if (selected.id === 'arrow') {
      this.selectSlot(3);
      this.combat.attack('bow', 'primary', angle);
    }
  }

  handlePointerMove(pointer) {
    this.lastPointerWorld = { x: pointer.worldX, y: pointer.worldY };
  }

  getInspectableEntityAt(x, y) {
    const playerDistance = Phaser.Math.Distance.Between(x, y, this.player.sprite.x, this.player.sprite.y);
    if (playerDistance < 34) return { type: 'player', id: 'player', label: 'Игрок' };

    let nearest = null;
    let nearestDistance = GAME_CONFIG.debug.entityInspectRadius;
    for (const resource of this.resources) {
      if (!resource.active) continue;
      const distance = Phaser.Math.Distance.Between(x, y, resource.x, resource.y);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = resource;
      }
    }
    return nearest;
  }

  updateHoverSelection() {
    if (!this.debugEnabled || !this.lastPointerWorld) return;
    const hovered = this.getInspectableEntityAt(this.lastPointerWorld.x, this.lastPointerWorld.y);
    this.game.events.emit('debug-hover', hovered ? hovered.label : null);
  }

  selectDebugEntity(entity) {
    this.debugSelection = entity;
    this.game.events.emit('debug-selection', this.getDebugEntityData(entity));
    this.log(`Отладчик: выбран объект «${entity.label}»`, 'debug');
  }

  selectDebugTarget(target) {
    if (target === 'player') {
      this.selectDebugEntity({ type: 'player', id: 'player', label: 'Игрок' });
      return;
    }
    if (target.startsWith('weapon:')) {
      const weaponId = target.split(':')[1];
      this.selectDebugEntity({
        type: 'weapon', id: target, weaponId,
        label: GAME_CONFIG.weapons[weaponId]?.name ?? weaponId,
      });
      return;
    }
    if (target.startsWith('config:')) {
      const category = target.split(':')[1];
      this.selectDebugEntity({ type: 'config', id: target, category, label: `Параметры: ${category}` });
    }
  }

  flattenNumericProperties(value, prefix = '', output = {}) {
    for (const [key, entry] of Object.entries(value)) {
      const path = prefix ? `${prefix}.${key}` : key;
      if (typeof entry === 'number') output[path] = entry;
      else if (entry && typeof entry === 'object' && !Array.isArray(entry)) {
        this.flattenNumericProperties(entry, path, output);
      }
    }
    return output;
  }

  setNestedNumericValue(object, path, value) {
    const keys = path.split('.');
    let target = object;
    for (const key of keys.slice(0, -1)) {
      if (!target || typeof target[key] !== 'object') return false;
      target = target[key];
    }
    const lastKey = keys[keys.length - 1];
    if (!target || typeof target[lastKey] !== 'number') return false;
    target[lastKey] = value;
    return true;
  }

  getDebugEntityData(entity) {
    if (entity.type === 'weapon') {
      const weapon = GAME_CONFIG.weapons[entity.weaponId];
      return {
        id: entity.id, label: entity.label, type: 'weapon',
        properties: this.flattenNumericProperties(weapon),
      };
    }
    if (entity.type === 'config') {
      return {
        id: entity.id, label: entity.label, type: 'config',
        properties: this.flattenNumericProperties(GAME_CONFIG[entity.category]),
      };
    }
    if (entity.type === 'player') {
      return {
        id: 'player',
        label: 'Игрок',
        type: 'player',
        properties: {
          health: this.playerData.health,
          maxHealth: this.playerData.maxHealth,
          stamina: this.playerData.stamina,
          maxStamina: this.playerData.maxStamina,
          armor: this.playerData.armor,
          arrows: this.playerData.arrows,
          walkSpeed: GAME_CONFIG.player.walkSpeed,
          runSpeed: GAME_CONFIG.player.runSpeed,
        },
      };
    }
    return {
      id: entity.id,
      label: entity.label,
      type: entity.type,
      properties: {
        health: entity.health,
        maxHealth: entity.maxHealth,
        x: Math.round(entity.x),
        y: Math.round(entity.y),
        radius: entity.radius,
      },
    };
  }

  setDebugProperty(id, key, value) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return;

    if (id.startsWith('weapon:')) {
      const weaponId = id.split(':')[1];
      const weapon = GAME_CONFIG.weapons[weaponId];
      if (weapon && this.setNestedNumericValue(weapon, key, numeric)) {
        this.log(`Изменено оружие ${weapon.name}: ${key} = ${numeric}`, 'debug');
        this.game.events.emit('debug-selection', this.getDebugEntityData({
          type: 'weapon', id, weaponId, label: weapon.name,
        }));
      }
      return;
    }

    if (id.startsWith('config:')) {
      const category = id.split(':')[1];
      const config = GAME_CONFIG[category];
      if (config && this.setNestedNumericValue(config, key, numeric)) {
        this.log(`Изменена категория ${category}: ${key} = ${numeric}`, 'debug');
        this.game.events.emit('debug-selection', this.getDebugEntityData({
          type: 'config', id, category, label: `Параметры: ${category}`,
        }));
      }
      return;
    }

    if (id === 'player') {
      const allowed = ['health', 'maxHealth', 'stamina', 'maxStamina', 'armor', 'arrows', 'walkSpeed', 'runSpeed'];
      if (!allowed.includes(key)) return;
      if (key === 'walkSpeed') GAME_CONFIG.player.walkSpeed = numeric;
      else if (key === 'runSpeed') GAME_CONFIG.player.runSpeed = numeric;
      else this.playerData[key] = numeric;
      this.playerData.health = Phaser.Math.Clamp(this.playerData.health, 0, this.playerData.maxHealth);
      this.playerData.stamina = Phaser.Math.Clamp(this.playerData.stamina, 0, this.playerData.maxStamina);
      this.log(`Изменено значение игрока: ${key} = ${numeric}`, 'debug');
      this.game.events.emit('player-update', this.getPlayerData());
      this.game.events.emit('debug-selection', this.getDebugEntityData({ type: 'player' }));
      return;
    }

    const entity = this.resources.find((item) => item.id === id && item.active);
    if (!entity || !['health', 'maxHealth', 'x', 'y', 'radius'].includes(key)) return;
    entity[key] = numeric;
    if (key === 'x' || key === 'y') {
      entity.sprite.setPosition(entity.x, entity.y);
      entity.shadow.setPosition(entity.x, entity.y + (entity.type === 'tree' ? 23 : 10));
    }
    if (key === 'health') entity.health = Phaser.Math.Clamp(entity.health, 0, entity.maxHealth);
    this.log(`Изменено значение ${entity.label}: ${key} = ${numeric}`, 'debug');
    this.game.events.emit('debug-selection', this.getDebugEntityData(entity));
  }

  getPlayerData() {
    const item = STARTING_ITEMS[this.selectedSlot];
    const weapon = item ? GAME_CONFIG.weapons[item.id] : null;
    return {
      ...this.playerData,
      selectedSlot: this.selectedSlot,
      selectedItem: item?.name ?? 'Пусто',
      weapon: weapon ? {
        name: weapon.name,
        damageType: weapon.damageType,
        damage: weapon.damage ?? weapon.slash?.damage ?? 0,
        slash: weapon.slash,
        thrust: weapon.thrust,
      } : null,
      running: this.player.running,
      crouching: this.player.crouching,
    };
  }

  getInventoryData() {
    return {
      hotbar: STARTING_ITEMS,
      selectedSlot: this.selectedSlot,
      backpackSlots: this.backpackSlots,
      maxBackpackSlots: GAME_CONFIG.inventory.maxBackpackSlots,
      equipment: [
        { id: 'helmet', name: 'Шлем', icon: '⛑' },
        { id: 'chest', name: 'Нагрудник', icon: '▣' },
        { id: 'gloves', name: 'Перчатки', icon: '♧' },
        { id: 'legs', name: 'Поножи', icon: '▥' },
        { id: 'boots', name: 'Сапоги', icon: '◈' },
      ],
      stats: this.getPlayerData(),
    };
  }

  selectSlot(index) {
    if (index < 0 || index >= GAME_CONFIG.inventory.hotbarSlots) return;
    this.selectedSlot = index;
    this.game.events.emit('hotbar-selection', index);
    this.game.events.emit('player-update', this.getPlayerData());
    this.game.events.emit('inventory-update', this.getInventoryData());
  }

  expandBackpack() {
    if (this.backpackSlots >= GAME_CONFIG.inventory.maxBackpackSlots) {
      this.log('Рюкзак уже максимального размера', 'warn');
      return;
    }
    this.backpackSlots = Math.min(
      GAME_CONFIG.inventory.maxBackpackSlots,
      this.backpackSlots + GAME_CONFIG.inventory.backpackSlotStep,
    );
    this.playerData.backpackSlots = this.backpackSlots;
    this.game.events.emit('inventory-update', this.getInventoryData());
    this.log(`Вместимость рюкзака увеличена: ${this.backpackSlots} слотов`, 'success');
  }

  findResourceInDirection(x, y, angle, range) {
    let nearest = null;
    let nearestDistance = range;
    for (const resource of this.resources) {
      if (!resource.active) continue;
      const dx = resource.x - x;
      const dy = resource.y - y;
      const distance = Math.hypot(dx, dy);
      const targetAngle = Math.atan2(dy, dx);
      const angleDifference = Math.abs(Phaser.Math.Angle.Wrap(targetAngle - angle));
      if (distance < nearestDistance && angleDifference < Phaser.Math.DegToRad(36)) {
        nearest = resource;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  showAttackTrail(angle, range, arcDegrees, mode) {
    const graphics = this.add.graphics().setDepth(1000);
    const origin = this.player.getCenter();
    const start = angle - Phaser.Math.DegToRad(arcDegrees / 2);
    const end = angle + Phaser.Math.DegToRad(arcDegrees / 2);

    if (mode === 'secondary') {
      graphics.lineStyle(6, 0x83e6ff, 0.75);
      graphics.lineBetween(
        origin.x + Math.cos(angle) * 14,
        origin.y + Math.sin(angle) * 14,
        origin.x + Math.cos(angle) * range,
        origin.y + Math.sin(angle) * range,
      );
      graphics.lineStyle(2, 0xf0fbff, 1);
      graphics.lineBetween(
        origin.x + Math.cos(angle) * 14,
        origin.y + Math.sin(angle) * 14,
        origin.x + Math.cos(angle) * range,
        origin.y + Math.sin(angle) * range,
      );
    } else {
      graphics.lineStyle(mode === 'tool' ? 4 : 6, mode === 'tool' ? 0xe8c47c : 0xc4b5fd, 0.95);
      graphics.beginPath();
      graphics.arc(origin.x, origin.y, range * 0.8, start, end, false);
      graphics.strokePath();
      graphics.lineStyle(2, 0xffffff, 0.8);
      graphics.beginPath();
      graphics.arc(origin.x, origin.y, range * 0.8 - 5, start, end, false);
      graphics.strokePath();
    }

    this.tweens.add({
      targets: graphics,
      alpha: 0,
      duration: 170,
      onComplete: () => graphics.destroy(),
    });
  }

  applyKnockback(target, angle, force) {
    this.tweens.add({
      targets: target.sprite,
      x: target.x + Math.cos(angle) * (force * 0.06),
      y: target.y + Math.sin(angle) * (force * 0.06),
      yoyo: true,
      duration: 65,
    });
  }

  spawnArrow(angle, weapon) {
    const origin = this.player.getCenter();
    const sprite = this.add.image(
      origin.x + Math.cos(angle) * 26,
      origin.y + Math.sin(angle) * 26,
      'arrow-sprite',
    ).setRotation(angle).setScale(1.4).setDepth(700);

    this.projectiles.push({
      sprite,
      vx: Math.cos(angle) * weapon.projectileSpeed,
      vy: Math.sin(angle) * weapon.projectileSpeed,
      life: weapon.projectileLifetime,
      damage: weapon.damage,
      damageType: weapon.damageType,
    });
  }

  updateProjectiles(delta) {
    for (let i = this.projectiles.length - 1; i >= 0; i -= 1) {
      const arrow = this.projectiles[i];
      const seconds = delta / 1000;
      arrow.sprite.x += arrow.vx * seconds;
      arrow.sprite.y += arrow.vy * seconds;
      arrow.life -= delta;

      const target = this.resources.find((item) =>
        item.active && Phaser.Math.Distance.Between(
          arrow.sprite.x, arrow.sprite.y, item.x, item.y,
        ) < item.radius * 0.65,
      );

      if (target) {
        this.combat.damageTarget(target, arrow.damage, arrow.damageType, 'bow');
        this.cameraController.shake(0.0016, 80);
        arrow.sprite.destroy();
        this.projectiles.splice(i, 1);
      } else if (arrow.life <= 0) {
        arrow.sprite.destroy();
        this.projectiles.splice(i, 1);
      }
    }
  }

  destroyResource(target) {
    target.active = false;
    this.tweens.add({
      targets: [target.sprite, target.shadow],
      alpha: 0,
      scaleX: 0.35,
      scaleY: 0.35,
      duration: 240,
      onComplete: () => {
        target.sprite.destroy();
        target.shadow.destroy();
      },
    });
    this.log(`${target.label} разрушено`, 'success');
    if (target.type === 'tree') this.playerData.gold += 1;
  }

  toggleDebug() {
    this.debugEnabled = !this.debugEnabled;
    this.game.events.emit('debug-toggle', this.debugEnabled);
    this.log(this.debugEnabled ? 'Режим отладки включён' : 'Режим отладки выключен', 'debug');
  }

  log(message, type = 'info', data = null) {
    return this.logger.log(message, type, data);
  }
}
