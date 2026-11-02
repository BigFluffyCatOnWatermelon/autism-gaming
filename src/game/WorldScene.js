/**
 * Main playable sandbox scene.
 *
 * Systems are deliberately separated by responsibility:
 * - world drawing and camera live here;
 * - frequently tuned values live in gameConfig.js;
 * - damage rules live in CombatSystem.js;
 * - HUD / inventory / settings / inspector live in GameUI.js.
 *
 * This first world is intentionally empty. It contains grass, the player and
 * the combat test effects, but no trees, rocks or enemies yet.
 */
import Phaser from 'phaser';
import { GAME_CONFIG } from '../config/gameConfig.js';
import {
  calculateDamage,
  pointInArc,
  distanceToSegment,
} from './CombatSystem.js';
import { GameUI } from '../ui/GameUI.js';

const DIRECTIONS = ['down', 'left', 'right', 'up'];
const WEAPON_COLORS = {
  sword: 0xe9f4ff,
  pickaxe: 0xc0d5df,
  axe: 0xe8c47b,
  bow: 0xa9dbac,
};

export class WorldScene extends Phaser.Scene {
  constructor() {
    super('WorldScene');

    this.playerSprite = null;
    this.playerShadow = null;
    this.cursors = null;
    this.keys = {};
    this.ui = null;

    this.stats = {
      health: GAME_CONFIG.player.health,
      stamina: GAME_CONFIG.player.stamina,
      strength: GAME_CONFIG.player.strength,
      agility: GAME_CONFIG.player.agility,
    };

    this.hotbar = ['sword', 'pickaxe', 'axe', 'bow', 'arrows', null, null, null, null];
    this.selectedHotbarIndex = 0;
    this.backpack = ['sword', 'pickaxe', 'axe', 'bow', 'arrows'];
    this.arrowCount = GAME_CONFIG.inventory.startingArrows;
    this.armor = { head: null, body: null, legs: null, feet: null };

    this.facing = 'down';
    this.lastMoveAngle = -Math.PI / 2;
    this.lastAimAngle = -Math.PI / 2;
    this.isCrouching = false;
    this.isSprinting = false;
    this.isRolling = false;
    this.rollDirection = { x: 0, y: 0 };
    this.rollEndsAt = 0;
    this.lastRollAt = -Infinity;
    this.lastAttackAt = -Infinity;
    this.weaponCooldowns = {};
    this.lastCameraZoom = 0;
    this.lastHudUpdate = 0;
    this.debugMode = false;
    this.combatTargets = [];
    this.debugTargets = [];
  }

  preload() {
    // Original, small pixel-art files are kept in public/assets.
    this.load.image('grass', '/assets/grass.png');
    this.load.image('shadow', '/assets/shadow.png');
    this.load.spritesheet('player', '/assets/player.png', {
      frameWidth: 32,
      frameHeight: 40,
    });
    this.load.spritesheet('items', '/assets/items.png', {
      frameWidth: 32,
      frameHeight: 32,
    });
  }

  create() {
    const world = GAME_CONFIG.world;
    const startX = world.width / 2;
    const startY = world.height / 2;

    this.createGrassWorld();
    this.createAnimations();
    this.createPlayer(startX, startY);
    this.createKeyboard();
    this.createCamera();
    this.createDebugTargets();

    this.ui = new GameUI(this);
    this.applySettings(this.ui.settings);

    // Prevent the browser's right-click menu from interrupting the secondary attack.
    this.input.mouse.disableContextMenu();
    this.input.on('pointerdown', pointer => this.handlePointerDown(pointer));

    // Disable browser scrolling while game controls are active.
    this.input.keyboard.addCapture([
      Phaser.Input.Keyboard.KeyCodes.SPACE,
      Phaser.Input.Keyboard.KeyCodes.UP,
      Phaser.Input.Keyboard.KeyCodes.DOWN,
      Phaser.Input.Keyboard.KeyCodes.LEFT,
      Phaser.Input.Keyboard.KeyCodes.RIGHT,
    ]);

    this.ui.addLog('system', 'Phaser запустил мир 3600 × 3600.');
    this.ui.addLog('system', 'Управление: WASD, Shift, C, Space, B, F3.');
    this.ui.addLog('system', 'ЛКМ — замах / выстрел, ПКМ — тычок мечом.');

    this.cameras.main.fadeIn(280, 8, 13, 25);
  }

  createGrassWorld() {
    const { width, height, detailCount } = GAME_CONFIG.world;

    // One repeated tile covers the entire world; the camera reveals only a
    // small region at a time, so the empty map has almost no draw overhead.
    // Tile only the visible canvas, not the 3600×3600 world. Phaser's docs
    // explicitly recommend scrolling TileSprite.tilePosition instead of
    // creating huge TileSprites, which waste memory and hurt performance.
    this.ground = this.add.tileSprite(this.scale.width / 2, this.scale.height / 2, this.scale.width * 2.5, this.scale.height * 2.5, 'grass')
      .setOrigin(0.5, 0.5)
      .setScrollFactor(0)
      .setDepth(0);

    this.scale.on(Phaser.Scale.Events.RESIZE, gameSize => {
      // Slightly oversize the fixed layer so even the widest debug zoom has no empty edges.
      this.ground
        .setPosition(gameSize.width / 2, gameSize.height / 2)
        .setSize(gameSize.width * 2.5, gameSize.height * 2.5);
    });

    // Extra tiny pixel clusters break up the repeated tile without importing
    // large tilesets. Seeded randomness makes the same world on every reload.
    const details = this.add.graphics().setDepth(1);
    let seed = 240519;
    const random = () => {
      seed = (seed * 1664525 + 1013904223) >>> 0;
      return seed / 4294967296;
    };
    const greens = [0x3f783e, 0x76a64e, 0x9ab969, 0x588b42, 0x477b3b];

    for (let index = 0; index < detailCount; index++) {
      const x = Math.floor(random() * width);
      const y = Math.floor(random() * height);
      const color = greens[Math.floor(random() * greens.length)];
      details.fillStyle(color, 0.75 + random() * 0.25);
      details.fillRect(x, y, 2, 2);
      if (random() > 0.62) details.fillRect(x + 2, y - 1, 1, 2);
    }

    // A subtle world edge is useful when testing camera bounds.
    this.worldBoundary = this.add.graphics().setDepth(2);
    this.redrawWorldBoundary();
  }

  createAnimations() {
    // Sprite rows: down, left, right, up. Four tiny poses are supplied per row.
    DIRECTIONS.forEach((direction, row) => {
      const firstFrame = row * 4;
      this.anims.create({
        key: `walk-${direction}`,
        frames: this.anims.generateFrameNumbers('player', {
          start: firstFrame,
          end: firstFrame + 3,
        }),
        frameRate: 9,
        repeat: -1,
      });
      this.anims.create({
        key: `idle-${direction}`,
        frames: [
          { key: 'player', frame: firstFrame },
          { key: 'player', frame: firstFrame + 1 },
        ],
        frameRate: 2,
        repeat: -1,
      });
    });
  }

  createPlayer(x, y) {
    this.playerShadow = this.add.image(x, y + 5, 'shadow')
      .setScale(2.15, 1.8)
      .setAlpha(0.72)
      .setDepth(y - 1);

    this.playerSprite = this.add.sprite(x, y, 'player', 0)
      .setScale(1.7)
      .setOrigin(0.5, 0.86)
      .setDepth(y + 2);
    this.playerSprite.play('idle-down');

    this.playerGlow = this.add.ellipse(x, y + 2, 58, 24, 0x13240f, 0.12)
      .setDepth(y);

    this.playerPosition = { x, y };
    this.playerColliderRadius = 18;

    // A hidden outline is enabled only in developer mode.
    this.debugHighlight = this.add.graphics().setDepth(999999).setVisible(false);
  }

  createKeyboard() {
    const keyboard = this.input.keyboard;
    this.keys = {
      w: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W),
      a: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A),
      s: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S),
      d: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D),
      up: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.UP),
      left: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.LEFT),
      down: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.DOWN),
      right: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.RIGHT),
      shift: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SHIFT),
      crouch: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.C),
      roll: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE),
      inventory: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.B),
      debug: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.F3),
      escape: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ESC),
      f2: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.F2),
    };

    this.numberKeys = [];
    for (let index = 1; index <= 9; index++) {
      this.numberKeys.push(keyboard.addKey(Phaser.Input.Keyboard.KeyCodes[`NUMPAD${index}`] || (Phaser.Input.Keyboard.KeyCodes.ONE + index - 1)));
    }
  }

  createCamera() {
    const camera = this.cameras.main;
    camera.setBounds(0, 0, GAME_CONFIG.world.width, GAME_CONFIG.world.height);
    camera.setRoundPixels(true);
    camera.setZoom(GAME_CONFIG.camera.baseZoom);
    camera.startFollow(
      this.playerSprite,
      true,
      GAME_CONFIG.camera.followLerp,
      GAME_CONFIG.camera.followLerp,
    );
    this.lastCameraZoom = GAME_CONFIG.camera.baseZoom;
  }

  createDebugTargets() {
    // Register objects here so F3 can inspect them. Future trees, stones,
    // enemies, loot and NPCs should call registerDebugTarget() when created.
    this.debugTargets = [];
    this.registerDebugTarget({
      id: 'player',
      label: 'Персонаж',
      scope: 'player',
      object: this.playerSprite,
      hitRadius: 44,
    });
    this.registerDebugTarget({
      id: 'world',
      label: 'Трава / мир',
      scope: 'world',
      object: this.ground,
      hitTest: () => true, // Fallback target when no object is under the cursor.
    });
    this.registerDebugTarget({ id: 'camera', label: 'Камера', scope: 'camera' });
    this.registerDebugTarget({ id: 'weapons', label: 'Оружие', scope: 'weapons' });
  }

  /**
   * Register any world object for selection in developer mode.
   *
   * Optional fields can describe object-specific properties:
   * { path, label, min, max, step, description, getValue, setValue }.
   * getValue / setValue make the inspector independent of the object's shape.
   */
  registerDebugTarget(target) {
    if (!target?.id || !target?.label) {
      throw new Error('Debug target needs an id and a readable label.');
    }
    const entry = { scope: 'player', hitRadius: 36, ...target };
    const existingIndex = this.debugTargets.findIndex(item => item.id === entry.id);
    if (existingIndex >= 0) this.debugTargets[existingIndex] = entry;
    else this.debugTargets.push(entry);
    return entry;
  }

  getDebugTarget(id) {
    return this.debugTargets.find(target => target.id === id) || null;
  }

  getDebugTargetAt(worldX, worldY) {
    // Prefer concrete objects over the world fallback. This lets new objects
    // register custom hit tests or use their Phaser display bounds.
    const candidates = this.debugTargets.filter(target => target.object || target.hitTest);
    for (const target of candidates) {
      if (target.id === 'world') continue;
      if (typeof target.hitTest === 'function' && target.hitTest(worldX, worldY)) return target;
      if (target.object?.getBounds) {
        const bounds = target.object.getBounds();
        if (Phaser.Geom.Rectangle.Contains(bounds, worldX, worldY)) return target;
      } else if (target.object && Number.isFinite(target.object.x) && Number.isFinite(target.object.y)) {
        const distance = Phaser.Math.Distance.Between(worldX, worldY, target.object.x, target.object.y);
        if (distance <= target.hitRadius) return target;
      }
    }
    return this.getDebugTarget('world');
  }

  update(time, delta) {
    const frameDelta = Math.min(delta, 40);
    this.handleGlobalKeys();
    this.updatePlayer(frameDelta);
    this.updateCamera();
    this.updateGroundTextureScroll();
    this.updateDebugHover();
    this.updateDepth();

    if (time - this.lastHudUpdate > 120) {
      this.ui.updateHud();
      this.ui.updateFps(this.game.loop.actualFps);
      this.lastHudUpdate = time;
    }
  }

  handleGlobalKeys() {
    const just = Phaser.Input.Keyboard.JustDown;

    if (just(this.keys.inventory)) this.ui.toggleInventory();
    if (just(this.keys.debug)) {
      this.debugMode = !this.debugMode;
      this.ui.setDebugOpen(this.debugMode);
      this.debugHighlight.setVisible(this.debugMode);
    }
    if (just(this.keys.f2)) this.ui.toggleLogs();

    if (just(this.keys.escape)) {
      if (this.ui.inventoryOpen) this.ui.setInventoryOpen(false);
      else if (this.ui.settingsOpen) this.ui.setSettingsOpen(false);
      else if (this.ui.debugOpen) {
        this.debugMode = false;
        this.ui.setDebugOpen(false);
        this.debugHighlight.setVisible(false);
      } else if (this.ui.logsOpen) this.ui.setLogsOpen(false);
    }

    if (this.ui.isOverlayOpen()) return;
    this.numberKeys.forEach((key, index) => {
      if (just(key)) this.selectHotbar(index);
    });
  }

  updatePlayer(delta) {
    const now = this.time.now;
    const { player } = GAME_CONFIG;
    const keys = this.keys;

    if (this.isRolling && now >= this.rollEndsAt) this.isRolling = false;

    let dx = Number(keys.d.isDown || keys.right.isDown)
      - Number(keys.a.isDown || keys.left.isDown);
    let dy = Number(keys.s.isDown || keys.down.isDown)
      - Number(keys.w.isDown || keys.up.isDown);
    const overlayPaused = this.ui?.isOverlayOpen();
    if (overlayPaused) { dx = 0; dy = 0; }
    let moving = dx !== 0 || dy !== 0;

    if (moving) {
      const length = Math.hypot(dx, dy);
      dx /= length;
      dy /= length;
      this.lastMoveAngle = Math.atan2(dy, dx);
    }

    if (!overlayPaused && Phaser.Input.Keyboard.JustDown(keys.roll)) this.tryRoll(dx, dy);

    this.isCrouching = !overlayPaused && keys.crouch.isDown && !this.isRolling;
    this.isSprinting = !overlayPaused && keys.shift.isDown && moving && !this.isCrouching && !this.isRolling
      && this.stats.stamina > 0;

    let speed = player.walkSpeed;
    if (this.isCrouching) speed *= player.crouchMultiplier;
    if (this.isSprinting) speed *= player.runMultiplier;
    if (this.isRolling) speed *= player.rollSpeedMultiplier;

    if (this.isRolling) {
      dx = this.rollDirection.x;
      dy = this.rollDirection.y;
      moving = true;
    }

    if (moving && !this.ui.isOverlayOpen()) {
      this.playerSprite.x += dx * speed * (delta / 1000);
      this.playerSprite.y += dy * speed * (delta / 1000);
      this.playerSprite.x = Phaser.Math.Clamp(this.playerSprite.x, 36, GAME_CONFIG.world.width - 36);
      this.playerSprite.y = Phaser.Math.Clamp(this.playerSprite.y, 42, GAME_CONFIG.world.height - 36);
    }

    // Running consumes stamina; when exhausted sprinting automatically stops.
    if (this.isSprinting) {
      this.stats.stamina = Math.max(0, this.stats.stamina - player.staminaRunDrain * (delta / 1000));
    } else if (!this.isRolling) {
      this.stats.stamina = Math.min(player.maxStamina, this.stats.stamina + player.staminaRegen * (delta / 1000));
    }

    // Movement controls the body animation; aim controls the facing direction
    // when standing still, so the character turns toward the mouse naturally.
    const pointer = this.input.activePointer;
    if (pointer && !this.ui.isOverlayOpen()) {
      this.lastAimAngle = Phaser.Math.Angle.Between(
        this.playerSprite.x, this.playerSprite.y - 12,
        pointer.worldX, pointer.worldY,
      );
    }
    const facingAngle = moving ? this.lastMoveAngle : this.lastAimAngle;
    this.facing = this.directionFromAngle(facingAngle);
    this.playPlayerAnimation(moving || this.isRolling);

    const targetScaleY = this.isCrouching ? 1.3 : 1.7;
    this.playerSprite.setScale(1.7, targetScaleY);
    if (this.isRolling) this.playerSprite.setAlpha(0.82);
    else this.playerSprite.setAlpha(1);

    this.playerShadow.setPosition(this.playerSprite.x, this.playerSprite.y + 5);
    this.playerGlow.setPosition(this.playerSprite.x, this.playerSprite.y + 2);
    this.playerPosition.x = this.playerSprite.x;
    this.playerPosition.y = this.playerSprite.y;
  }

  directionFromAngle(angle) {
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    if (Math.abs(cos) > Math.abs(sin)) return cos < 0 ? 'left' : 'right';
    return sin < 0 ? 'up' : 'down';
  }

  playPlayerAnimation(moving) {
    const key = `${moving ? 'walk' : 'idle'}-${this.facing}`;
    if (this.playerSprite.anims.currentAnim?.key !== key) {
      this.playerSprite.play(key, true);
    }
  }

  tryRoll(dx, dy) {
    const now = this.time.now;
    const cfg = GAME_CONFIG.player;
    if (now - this.lastRollAt < cfg.rollCooldownMs || this.stats.stamina < cfg.rollStaminaCost) return;

    let length = Math.hypot(dx, dy);
    if (length < 0.01) {
      dx = Math.cos(this.lastAimAngle);
      dy = Math.sin(this.lastAimAngle);
      length = 1;
    }
    this.rollDirection = { x: dx / length, y: dy / length };
    this.isRolling = true;
    this.rollEndsAt = now + cfg.rollDurationMs;
    this.lastRollAt = now;
    this.stats.stamina = Math.max(0, this.stats.stamina - cfg.rollStaminaCost);
    this.spawnAfterimage();
    this.impactFeedback(0.0025);
    this.ui.addLog('movement', 'Перекат выполнен.');
  }

  spawnAfterimage() {
    const echo = this.add.sprite(
      this.playerSprite.x, this.playerSprite.y, 'player', this.playerSprite.frame.name,
    )
      .setScale(this.playerSprite.scaleX, this.playerSprite.scaleY)
      .setOrigin(0.5, 0.86)
      .setAlpha(0.38)
      .setTint(0x9dc8ff)
      .setDepth(this.playerSprite.depth - 1);

    this.tweens.add({
      targets: echo,
      alpha: 0,
      duration: 260,
      onComplete: () => echo.destroy(),
    });
  }

  updateGroundTextureScroll() {
    // The ground stays screen-sized while its texture follows camera scroll,
    // creating a continuous grassy world without allocating a giant bitmap.
    const camera = this.cameras.main;
    this.ground.tilePositionX = camera.scrollX;
    this.ground.tilePositionY = camera.scrollY;
  }

  redrawWorldBoundary() {
    const { width, height } = GAME_CONFIG.world;
    this.worldBoundary.clear();
    this.worldBoundary.lineStyle(5, 0x355d35, 0.7);
    this.worldBoundary.strokeRect(0, 0, width, height);
  }

  updateCamera() {
    const cfg = GAME_CONFIG.camera;
    let zoom = cfg.baseZoom;
    if (this.isCrouching) zoom = cfg.crouchZoom;
    else if (this.isSprinting) zoom = cfg.runZoom;

    if (!this.ui.settings.cameraEffects) zoom = cfg.baseZoom;

    const camera = this.cameras.main;
    camera.setLerp(cfg.followLerp, cfg.followLerp);
    if (Math.abs(zoom - this.lastCameraZoom) > 0.001) {
      camera.zoomTo(zoom, cfg.zoomTransitionMs, 'Sine.easeInOut');
      this.lastCameraZoom = zoom;
    }
  }

  updateDepth() {
    const depth = this.playerSprite.y;
    this.playerShadow.setDepth(depth - 2);
    this.playerGlow.setDepth(depth - 1);
    this.playerSprite.setDepth(depth + 2);
  }

  updateDebugHover() {
    if (!this.debugMode) return;
    const pointer = this.input.activePointer;
    const target = this.getDebugTargetAt(pointer.worldX, pointer.worldY);
    this.hoveredDebugTarget = target;
    this.debugHighlight.clear();

    if (target?.object && target.id !== 'world') {
      const bounds = target.object.getBounds?.();
      this.debugHighlight.lineStyle(2, 0x65e6c4, 0.95);
      if (bounds) {
        this.debugHighlight.strokeRect(bounds.x - 4, bounds.y - 4, bounds.width + 8, bounds.height + 8);
      } else {
        this.debugHighlight.strokeCircle(target.object.x, target.object.y, target.hitRadius || 30);
      }
    } else {
      // The ground is the fallback target, so show the cursor rather than a
      // rectangle around the screen-fixed repeating grass layer.
      this.debugHighlight.lineStyle(1, 0x65e6c4, 0.55);
      this.debugHighlight.strokeCircle(pointer.worldX, pointer.worldY, 14);
    }
  }

  handlePointerDown(pointer) {
    // The debug inspector can remain open while selecting objects on the
    // uncovered canvas. Inventory, settings and logs pause world clicks.
    if (this.ui.inventoryOpen || this.ui.settingsOpen || this.ui.logsOpen) return;

    if (this.debugMode) {
      const target = this.getDebugTargetAt(pointer.worldX, pointer.worldY);
      if (target) {
        this.ui.setDebugTarget(target.id, target.label, target.scope);
        this.ui.addLog('debug', `Выбран объект: ${target.label}.`);
      }
      this.ui.setDebugOpen(true);
      return;
    }

    if (pointer.button === 2) this.performAttack('secondary');
    else if (pointer.button === 0) this.performAttack('primary');
  }

  selectHotbar(index) {
    if (index < 0 || index >= this.hotbar.length) return;
    this.selectedHotbarIndex = index;
    const itemId = this.hotbar[index];
    this.ui.updateHotbarSelection();
    if (itemId) this.ui.addLog('inventory', `Выбран слот ${index + 1}: ${itemId}.`);
  }

  selectItem(itemId) {
    const index = this.hotbar.indexOf(itemId);
    if (index >= 0) this.selectHotbar(index);
    if (this.ui.debugOpen) this.ui.setDebugTarget('weapons', `Предмет: ${itemId}`);
  }

  getArmorDefense() {
    return Object.values(this.armor).reduce((total, item) => total + (item?.defense || 0), GAME_CONFIG.player.defense);
  }

  get equippedArmorCount() {
    return Object.values(this.armor).filter(Boolean).length;
  }

  performAttack(mode) {
    const itemId = this.hotbar[this.selectedHotbarIndex];
    if (!itemId || itemId === 'arrows') {
      this.ui.showToast(itemId === 'arrows' ? 'Выбери лук, чтобы стрелять.' : 'Пустой слот.', 'warning');
      return;
    }

    const weapon = GAME_CONFIG.weapons[itemId];
    if (!weapon) return;

    const now = this.time.now;
    let profile;
    let attackKind;

    if (itemId === 'sword') {
      attackKind = mode === 'secondary' ? 'thrust' : 'slash';
      profile = weapon[attackKind];
    } else if (itemId === 'bow') {
      attackKind = 'shot';
      profile = {
        name: 'Выстрел из лука',
        damage: weapon.damage,
        damageType: weapon.damageType,
        cooldownMs: weapon.cooldownMs,
        staminaCost: weapon.staminaCost,
        projectileSpeed: weapon.projectileSpeed || GAME_CONFIG.combat.arrowSpeed,
        reach: weapon.reach || GAME_CONFIG.combat.arrowRange,
      };
    } else {
      attackKind = 'tool';
      profile = {
        name: itemId === 'axe' ? 'Удар топором' : 'Удар киркой',
        damage: weapon.damage,
        damageType: weapon.damageType,
        cooldownMs: weapon.cooldownMs,
        staminaCost: GAME_CONFIG.combat.attackStaminaCost,
        reach: weapon.reach,
        woodMultiplier: weapon.woodMultiplier,
        stoneMultiplier: weapon.stoneMultiplier,
        natureMultiplier: weapon.natureMultiplier,
      };
    }

    const cooldownKey = `${itemId}:${attackKind}`;
    if (now < (this.weaponCooldowns[cooldownKey] || 0)) return;
    if (this.stats.stamina < profile.staminaCost) {
      this.ui.showToast('Недостаточно выносливости.', 'warning');
      this.ui.addLog('combat', 'Атака отменена: не хватает выносливости.');
      return;
    }
    if (itemId === 'bow' && this.arrowCount <= 0) {
      this.ui.showToast('Стрелы закончились.', 'warning');
      this.ui.addLog('combat', 'Лук не выстрелил: нет стрел.');
      return;
    }

    this.lastAttackAt = now;
    this.weaponCooldowns[cooldownKey] = now + profile.cooldownMs;
    this.stats.stamina -= profile.staminaCost;
    const angle = this.lastAimAngle;
    const origin = { x: this.playerSprite.x, y: this.playerSprite.y - 13 };
    // Strength scaling is applied once inside calculateDamage().
    const attack = { ...profile };
    const targetsHit = this.resolveAttackTargets(attack, attackKind, origin, angle);

    if (itemId === 'sword' && attackKind === 'slash') this.drawSwordSlash(origin, angle, profile);
    else if (itemId === 'sword' && attackKind === 'thrust') this.drawSwordThrust(origin, angle, profile);
    else if (itemId === 'bow') this.fireArrow(origin, angle, profile);
    else this.drawToolSwing(origin, angle, profile, itemId);

    this.impactFeedback(itemId === 'sword' ? 0.0045 : 0.003);
    const typeName = attack.damageType === 'cutting' ? 'режущий' : attack.damageType === 'piercing' ? 'колющий' : 'дробящий';
    this.ui.addLog('combat',
      `${profile.name}: ${Math.round(attack.damage)} ${typeName} урона · целей: ${targetsHit}.`,
    );
    this.ui.updateHud();
  }

  resolveAttackTargets(attack, attackKind, origin, angle) {
    let hitCount = 0;
    const weaponId = this.hotbar[this.selectedHotbarIndex];
    const range = attack.reach || 60;

    for (const target of this.combatTargets) {
      if (!target.active || target.health <= 0) continue;
      let hit = false;

      if (attackKind === 'slash' || attackKind === 'tool') {
        hit = pointInArc(
          origin.x, origin.y, target.x, target.y,
          angle, range, attack.arcDegrees || GAME_CONFIG.combat.slashArcDegrees,
        );
      } else if (attackKind === 'thrust') {
        const endX = origin.x + Math.cos(angle) * range;
        const endY = origin.y + Math.sin(angle) * range;
        hit = distanceToSegment(target.x, target.y, origin.x, origin.y, endX, endY)
          <= (attack.width || GAME_CONFIG.combat.thrustWidth);
      } else if (attackKind === 'shot') {
        const endX = origin.x + Math.cos(angle) * range;
        const endY = origin.y + Math.sin(angle) * range;
        // A shot only hits targets along the arrow path, not every nearby object.
        hit = distanceToSegment(target.x, target.y, origin.x, origin.y, endX, endY) <= 8;
      }

      if (!hit) continue;

      const result = calculateDamage(attack, target, this.stats);
      target.health = Math.max(0, target.health - result.damage);
      hitCount += 1;
      this.createDamageText(target.x, target.y - 24, result.damage, result.damageType);
      this.spawnParticles(target.x, target.y, 0xf4d58a, 9);
      this.ui.addLog('combat',
        `${target.label || target.id}: -${result.damage} (${result.damageLabel}, ×${result.materialMultiplier.toFixed(2)} материал).`,
      );
      if (target.onDamage) target.onDamage(result, weaponId);
    }
    return hitCount;
  }

  /** Future world objects / enemies can register here without changing the attack code. */
  registerCombatTarget(target) {
    const completeTarget = {
      active: true,
      health: 100,
      material: 'flesh',
      ...target,
    };
    this.combatTargets.push(completeTarget);
    return completeTarget;
  }

  drawSwordSlash(origin, angle, profile) {
    const radius = profile.reach || GAME_CONFIG.combat.slashRadius;
    const spread = (profile.arcDegrees || GAME_CONFIG.combat.slashArcDegrees) * Math.PI / 180;
    const start = angle - spread / 2;
    const points = [{ x: origin.x, y: origin.y }];

    for (let step = 0; step <= 18; step++) {
      const a = start + (spread * step / 18);
      points.push({
        x: origin.x + Math.cos(a) * radius,
        y: origin.y + Math.sin(a) * radius,
      });
    }

    const graphics = this.add.graphics().setDepth(this.playerSprite.y + 30);
    graphics.fillStyle(0xe1f4ff, 0.2);
    graphics.beginPath();
    graphics.moveTo(points[0].x, points[0].y);
    points.slice(1).forEach(point => graphics.lineTo(point.x, point.y));
    graphics.closePath();
    graphics.fillPath();
    graphics.lineStyle(7, 0xe5f4ff, 0.82);
    graphics.strokePoints(points.slice(1), false);
    graphics.lineStyle(2, 0x95d8ff, 0.9);
    graphics.strokePoints(points.slice(1), false);

    this.spawnParticles(
      origin.x + Math.cos(angle) * radius * 0.82,
      origin.y + Math.sin(angle) * radius * 0.82,
      0xd6efff, 12,
    );
    this.tweens.add({
      targets: graphics,
      alpha: 0,
      duration: GAME_CONFIG.combat.slashDurationMs,
      ease: 'Cubic.easeOut',
      onComplete: () => graphics.destroy(),
    });
  }

  drawSwordThrust(origin, angle, profile) {
    const range = profile.reach || GAME_CONFIG.combat.thrustRange;
    const endX = origin.x + Math.cos(angle) * range;
    const endY = origin.y + Math.sin(angle) * range;
    const perpX = -Math.sin(angle);
    const perpY = Math.cos(angle);
    const width = profile.width || GAME_CONFIG.combat.thrustWidth;
    const graphics = this.add.graphics().setDepth(this.playerSprite.y + 30);

    graphics.lineStyle(width, 0xbfeaff, 0.25);
    graphics.lineBetween(origin.x, origin.y, endX, endY);
    graphics.lineStyle(6, 0xeaf7ff, 0.92);
    graphics.lineBetween(origin.x, origin.y, endX, endY);
    graphics.lineStyle(2, 0x78caff, 1);
    graphics.lineBetween(origin.x, origin.y, endX, endY);
    graphics.fillStyle(0xffffff, 0.95);
    graphics.fillTriangle(
      endX, endY,
      endX - Math.cos(angle) * 13 + perpX * 5, endY - Math.sin(angle) * 13 + perpY * 5,
      endX - Math.cos(angle) * 13 - perpX * 5, endY - Math.sin(angle) * 13 - perpY * 5,
    );

    this.spawnParticles(endX, endY, 0xbfeaff, 7);
    this.tweens.add({
      targets: graphics,
      alpha: 0,
      duration: GAME_CONFIG.combat.thrustDurationMs,
      onComplete: () => graphics.destroy(),
    });
  }

  drawToolSwing(origin, angle, profile, itemId) {
    const reach = profile.reach;
    const spread = 62 * Math.PI / 180;
    const start = angle - spread;
    const end = angle + spread;
    const points = [];
    for (let step = 0; step <= 12; step++) {
      const a = start + ((end - start) * step / 12);
      points.push({ x: origin.x + Math.cos(a) * reach, y: origin.y + Math.sin(a) * reach });
    }
    const color = WEAPON_COLORS[itemId] || 0xffffff;
    const graphics = this.add.graphics().setDepth(this.playerSprite.y + 25);
    graphics.lineStyle(8, color, 0.18);
    graphics.strokePoints(points, false);
    graphics.lineStyle(3, color, 0.85);
    graphics.strokePoints(points, false);
    const endPoint = points[Math.floor(points.length / 2)];
    this.spawnParticles(endPoint.x, endPoint.y, color, 10);
    this.tweens.add({
      targets: graphics,
      alpha: 0,
      duration: GAME_CONFIG.combat.toolEffectDurationMs,
      onComplete: () => graphics.destroy(),
    });
  }

  fireArrow(origin, angle, profile) {
    this.arrowCount -= 1;
    const range = GAME_CONFIG.combat.arrowRange;
    const distance = Math.min(range, profile.reach || range);
    const endX = origin.x + Math.cos(angle) * distance;
    const endY = origin.y + Math.sin(angle) * distance;
    const arrow = this.add.image(origin.x, origin.y, 'items', 4)
      .setRotation(angle + Math.PI / 2)
      .setScale(1.15)
      .setDepth(this.playerSprite.y + 30);

    this.tweens.add({
      targets: arrow,
      x: endX,
      y: endY,
      duration: Math.max(120, (distance / (profile.projectileSpeed || GAME_CONFIG.combat.arrowSpeed)) * 1000),
      ease: 'Linear',
      onUpdate: () => {
        // A faint trail makes the arrow readable against the grass.
      },
      onComplete: () => {
        this.spawnParticles(endX, endY, 0xe8d19c, 5);
        arrow.destroy();
      },
    });

    this.ui.renderHotbar();
  }

  spawnParticles(x, y, color, count = 8) {
    for (let index = 0; index < count; index++) {
      const angle = Math.random() * Math.PI * 2;
      const distance = 9 + Math.random() * 24;
      const particle = this.add.rectangle(x, y, 2 + Math.random() * 2, 2 + Math.random() * 2, color)
        .setDepth(this.playerSprite.y + 40);
      this.tweens.add({
        targets: particle,
        x: x + Math.cos(angle) * distance,
        y: y + Math.sin(angle) * distance,
        alpha: 0,
        scale: 0.2,
        duration: 150 + Math.random() * 210,
        ease: 'Cubic.easeOut',
        onComplete: () => particle.destroy(),
      });
    }
  }

  createDamageText(x, y, damage, damageType) {
    const label = this.add.text(x, y, `-${damage} · ${damageType}`, {
      fontFamily: 'monospace',
      fontSize: '12px',
      color: '#fff2c2',
      stroke: '#1c1a20',
      strokeThickness: 3,
    }).setOrigin(0.5).setDepth(this.playerSprite.y + 50);

    this.tweens.add({
      targets: label,
      y: y - 34,
      alpha: 0,
      duration: 720,
      onComplete: () => label.destroy(),
    });
  }

  impactFeedback(intensity) {
    if (!this.ui?.settings.screenShake) return;
    const cfg = GAME_CONFIG.camera;
    if (cfg.shakeDurationMs > 0 && cfg.shakeIntensity > 0) {
      this.cameras.main.shake(cfg.shakeDurationMs, Math.min(intensity, cfg.shakeIntensity));
    }
  }

  applySettings(settings) {
    if (!this.cameras?.main) return;
    if (!settings.cameraEffects) {
      this.cameras.main.setZoom(GAME_CONFIG.camera.baseZoom);
      this.lastCameraZoom = GAME_CONFIG.camera.baseZoom;
    }
  }

  onConfigChanged(path, value) {
    if (path === 'player.maxHealth') this.stats.health = Math.min(this.stats.health, value);
    if (path === 'player.maxStamina') this.stats.stamina = Math.min(this.stats.stamina, value);
    if (path === 'player.health') this.stats.health = Math.min(value, GAME_CONFIG.player.maxHealth);
    if (path === 'player.stamina') this.stats.stamina = Math.min(value, GAME_CONFIG.player.maxStamina);
    if (path === 'inventory.startingArrows') this.arrowCount = value;

    if (path === 'player.strength') this.stats.strength = value;
    if (path === 'player.agility') this.stats.agility = value;

    if (path === 'world.width' || path === 'world.height') {
      this.cameras.main.setBounds(0, 0, GAME_CONFIG.world.width, GAME_CONFIG.world.height);
      this.playerSprite.x = Phaser.Math.Clamp(this.playerSprite.x, 36, GAME_CONFIG.world.width - 36);
      this.playerSprite.y = Phaser.Math.Clamp(this.playerSprite.y, 42, GAME_CONFIG.world.height - 36);
      this.redrawWorldBoundary();
    }
    if (path.startsWith('camera.')) this.lastCameraZoom = -1;
    this.ui.updateHud();
    if (this.ui.inventoryOpen) this.ui.renderInventory();
  }
}
