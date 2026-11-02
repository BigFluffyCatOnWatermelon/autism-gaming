import Phaser from 'phaser';
import { GAME_CONFIG } from '../../config/gameConfig.js';

/**
 * Контроллер игрока. Отвечает за движение, состояния и смену кадров
 * пиксельной анимации. Числа скорости и выносливости лежат в gameConfig.js.
 */
export class PlayerController {
  constructor(scene) {
    this.scene = scene;
    this.sprite = scene.physics.add.sprite(
      GAME_CONFIG.player.spawnX,
      GAME_CONFIG.player.spawnY,
      'player-idle-down-0',
    );
    this.sprite.setScale(GAME_CONFIG.player.spriteScale);
    this.sprite.setDepth(20);
    this.sprite.setCollideWorldBounds(true);
    this.sprite.body.setSize(GAME_CONFIG.player.bodyWidth, GAME_CONFIG.player.bodyHeight);
    this.sprite.body.setOffset(5, 19);

    // Тень рисуется отдельно, чтобы оставаться под ногами при любой анимации.
    this.shadow = scene.add.ellipse(this.sprite.x, this.sprite.y + 17, 30, 12, 0x101b12, 0.35)
      .setDepth(18);

    const keyboard = scene.input.keyboard;
    this.keys = keyboard.addKeys({
      up: Phaser.Input.Keyboard.KeyCodes.W,
      down: Phaser.Input.Keyboard.KeyCodes.S,
      left: Phaser.Input.Keyboard.KeyCodes.A,
      right: Phaser.Input.Keyboard.KeyCodes.D,
      run: Phaser.Input.Keyboard.KeyCodes.SHIFT,
      crouch: Phaser.Input.Keyboard.KeyCodes.CTRL,
      dodge: Phaser.Input.Keyboard.KeyCodes.SPACE,
    });
    this.cursors = keyboard.createCursorKeys();

    this.facing = 'down';
    this.moving = false;
    this.running = false;
    this.crouching = false;
    this.rolling = false;
    this.rollUntil = 0;
    this.rollCooldownUntil = 0;
    this.invulnerableUntil = 0;
    this.animationTime = 0;
    this.animationFrame = 0;
    this.currentTexture = '';
    this.lastMove = { x: 0, y: 1 };
  }

  update(time, delta) {
    const inputX = Number(this.keys.right.isDown || this.cursors.right.isDown)
      - Number(this.keys.left.isDown || this.cursors.left.isDown);
    const inputY = Number(this.keys.down.isDown || this.cursors.down.isDown)
      - Number(this.keys.up.isDown || this.cursors.up.isDown);
    const inputLength = Math.hypot(inputX, inputY);
    const moveX = inputLength ? inputX / inputLength : 0;
    const moveY = inputLength ? inputY / inputLength : 0;

    this.moving = inputLength > 0;
    this.crouching = this.keys.crouch.isDown && !this.rolling;
    this.running = this.keys.run.isDown && this.moving && !this.crouching && !this.rolling;

    if (this.moving) this.lastMove = { x: moveX, y: moveY };

    if (Phaser.Input.Keyboard.JustDown(this.keys.dodge)) this.tryDodge(time, moveX, moveY);

    if (this.rolling) {
      if (time >= this.rollUntil) {
        this.rolling = false;
        this.sprite.body.setVelocity(0, 0);
      } else {
        this.sprite.body.setVelocity(
          this.rollDirection.x * GAME_CONFIG.dodge.speed,
          this.rollDirection.y * GAME_CONFIG.dodge.speed,
        );
      }
    } else {
      const speed = this.crouching
        ? GAME_CONFIG.player.crouchSpeed
        : this.running
          ? GAME_CONFIG.player.runSpeed
          : GAME_CONFIG.player.walkSpeed;

      this.sprite.body.setVelocity(moveX * speed, moveY * speed);

      // Выносливость восстанавливается, когда персонаж не перекатывается.
      this.scene.playerData.stamina = Math.min(
        GAME_CONFIG.player.maxStamina,
        this.scene.playerData.stamina + (GAME_CONFIG.player.staminaRegen * delta) / 1000,
      );
    }

    this.updateFacing(moveX, moveY);
    this.updateAnimation(time, delta);
    this.shadow.setPosition(this.sprite.x, this.sprite.y + 17);
    this.shadow.setScale(this.crouching ? 0.82 : 1);
    this.sprite.setAlpha(time < this.invulnerableUntil ? (Math.floor(time / 65) % 2 ? 0.45 : 1) : 1);
  }

  updateFacing(moveX, moveY) {
    if (this.rolling && this.lastMove) {
      this.facing = this.directionFromVector(this.rollDirection.x, this.rollDirection.y);
      return;
    }
    if (this.moving) {
      this.facing = this.directionFromVector(moveX, moveY);
      return;
    }

    const pointer = this.scene.input.activePointer;
    const angle = Phaser.Math.Angle.Between(this.sprite.x, this.sprite.y, pointer.worldX, pointer.worldY);
    this.facing = this.directionFromVector(Math.cos(angle), Math.sin(angle));
  }

  directionFromVector(x, y) {
    if (Math.abs(x) > Math.abs(y)) return x < 0 ? 'left' : 'right';
    return y < 0 ? 'up' : 'down';
  }

  updateAnimation(time, delta) {
    this.animationTime += delta;
    if (this.animationTime > (this.running ? 85 : 145)) {
      this.animationTime = 0;
      this.animationFrame += 1;
    }

    let pose = 'idle';
    let frame = 0;
    if (this.rolling) {
      pose = 'roll';
    } else if (this.crouching) {
      pose = 'crouch';
    } else if (this.moving) {
      pose = 'walk';
      frame = this.animationFrame % 4;
    }

    const textureKey = `player-${pose}-${this.facing}-${frame}`;
    if (textureKey !== this.currentTexture) {
      this.sprite.setTexture(textureKey);
      this.currentTexture = textureKey;
    }
  }

  tryDodge(time, moveX, moveY) {
    if (this.rolling || time < this.rollCooldownUntil) return;
    if (this.scene.playerData.stamina < GAME_CONFIG.dodge.staminaCost) {
      this.scene.log('Недостаточно выносливости для переката', 'warn');
      return;
    }

    const pointer = this.scene.input.activePointer;
    const aimAngle = Phaser.Math.Angle.Between(this.sprite.x, this.sprite.y, pointer.worldX, pointer.worldY);
    const directionX = this.moving ? moveX : Math.cos(aimAngle);
    const directionY = this.moving ? moveY : Math.sin(aimAngle);
    const length = Math.hypot(directionX, directionY) || 1;

    this.rollDirection = { x: directionX / length, y: directionY / length };
    this.rolling = true;
    this.rollUntil = time + GAME_CONFIG.dodge.duration;
    this.rollCooldownUntil = time + GAME_CONFIG.dodge.cooldown;
    this.invulnerableUntil = time + GAME_CONFIG.dodge.invulnerabilityMs;
    this.scene.playerData.stamina -= GAME_CONFIG.dodge.staminaCost;
    this.scene.log('Перекат', 'combat');
  }

  get aimingAngle() {
    const pointer = this.scene.input.activePointer;
    return Phaser.Math.Angle.Between(this.sprite.x, this.sprite.y, pointer.worldX, pointer.worldY);
  }

  getCenter() {
    return { x: this.sprite.x, y: this.sprite.y };
  }
}
