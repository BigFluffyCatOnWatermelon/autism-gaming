import Phaser from 'phaser';

export class PlaygroundScene extends Phaser.Scene {
  constructor() {
    super('PlaygroundScene');

    this.player = null;
    this.cursors = null;
    this.wasd = null;
    this.resetKey = null;
    this.startPosition = { x: 480, y: 300 };
    this.speed = 260;
  }

  create() {
    const { width, height } = this.scale;

    this.drawBackground(width, height);
    this.createLabels(width);
    this.createPlayer();

    this.cursors = this.input.keyboard.createCursorKeys();
    this.wasd = this.input.keyboard.addKeys('W,A,S,D');
    this.resetKey = this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.R);

    this.add.text(width - 28, height - 24, 'R — вернуть объект в центр', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '13px',
      color: '#64748b',
    }).setOrigin(1, 1);
  }

  drawBackground(width, height) {
    const grid = this.add.graphics();

    grid.lineStyle(1, 0x25304a, 0.42);

    for (let x = 0; x <= width; x += 48) {
      grid.lineBetween(x, 0, x, height);
    }

    for (let y = 0; y <= height; y += 48) {
      grid.lineBetween(0, y, width, y);
    }

    const frame = this.add.graphics();
    frame.lineStyle(2, 0x34415f, 0.8);
    frame.strokeRoundedRect(18, 18, width - 36, height - 36, 18);
  }

  createLabels(width) {
    this.add.text(38, 34, 'AUTISM GAMING', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '15px',
      fontStyle: 'bold',
      color: '#c4b5fd',
      letterSpacing: 2,
    });

    this.add.text(38, 62, 'Игровой движок работает', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '25px',
      fontStyle: 'bold',
      color: '#f8fafc',
    });

    this.add.text(38, 98, 'Тестовая сцена · Phaser 4 · Vite', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '14px',
      color: '#94a3b8',
    });

    this.add.text(width - 38, 42, 'TECHNICAL PREVIEW', {
      fontFamily: 'Arial, sans-serif',
      fontSize: '12px',
      color: '#64748b',
      letterSpacing: 1.5,
    }).setOrigin(1, 0);
  }

  createPlayer() {
    const { x, y } = this.startPosition;

    this.playerShadow = this.add.circle(x, y + 5, 23, 0x020617, 0.45);
    this.playerGlow = this.add.circle(x, y, 29, 0x8b5cf6, 0.12);
    this.player = this.add.circle(x, y, 19, 0x8b5cf6);
    this.playerCore = this.add.circle(x, y, 7, 0xede9fe);
  }

  update(_time, delta) {
    if (Phaser.Input.Keyboard.JustDown(this.resetKey)) {
      this.player.setPosition(this.startPosition.x, this.startPosition.y);
    }

    let directionX = 0;
    let directionY = 0;

    if (this.cursors.left.isDown || this.wasd.A.isDown) directionX -= 1;
    if (this.cursors.right.isDown || this.wasd.D.isDown) directionX += 1;
    if (this.cursors.up.isDown || this.wasd.W.isDown) directionY -= 1;
    if (this.cursors.down.isDown || this.wasd.S.isDown) directionY += 1;

    if (directionX === 0 && directionY === 0) return;

    const length = Math.hypot(directionX, directionY);
    const distance = (this.speed * delta) / 1000;
    const nextX = this.player.x + (directionX / length) * distance;
    const nextY = this.player.y + (directionY / length) * distance;

    const padding = 42;
    this.player.setPosition(
      Phaser.Math.Clamp(nextX, padding, this.scale.width - padding),
      Phaser.Math.Clamp(nextY, padding, this.scale.height - padding),
    );

    this.playerShadow.setPosition(this.player.x, this.player.y + 5);
    this.playerGlow.setPosition(this.player.x, this.player.y);
    this.playerCore.setPosition(this.player.x, this.player.y);
  }
}
