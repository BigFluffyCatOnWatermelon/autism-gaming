import Phaser from 'phaser';
import { WorldScene } from './game/WorldScene.js';
import './style.css';

// PixelArt + roundPixels keep original low-resolution sprites crisp when
// the browser scales the game canvas to the StackBlitz Preview size.
const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  backgroundColor: '#5b8b3c',
  pixelArt: true,
  antialias: false,
  roundPixels: true,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: 960,
    height: 540,
  },
  render: {
    pixelArt: true,
    antialias: false,
    roundPixels: true,
  },
  scene: [WorldScene],
});

if (import.meta.hot) {
  import.meta.hot.dispose(() => {
    game.destroy(true);
  });
}
