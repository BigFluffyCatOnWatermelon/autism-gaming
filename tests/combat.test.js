import test from 'node:test';
import assert from 'node:assert/strict';

import { GAME_CONFIG } from '../src/config/gameConfig.js';
import {
  calculateDamage,
  pointInArc,
  distanceToSegment,
  angleDifference,
} from '../src/game/CombatSystem.js';

test('sword sweep is a cutting attack with its own base damage', () => {
  const result = calculateDamage(GAME_CONFIG.weapons.sword.slash, { material: 'flesh' }, { strength: 10 });
  assert.equal(result.damageType, 'cutting');
  assert.equal(result.damage, GAME_CONFIG.weapons.sword.slash.damage);
});

test('sword thrust is a piercing attack distinct from the sweep', () => {
  const result = calculateDamage(GAME_CONFIG.weapons.sword.thrust, { material: 'flesh' }, { strength: 10 });
  assert.equal(result.damageType, 'piercing');
  assert.equal(result.damage, GAME_CONFIG.weapons.sword.thrust.damage);
  assert.notEqual(result.damage, GAME_CONFIG.weapons.sword.slash.damage);
});

test('axe has a meaningful advantage against an Ent-like nature target', () => {
  const axe = GAME_CONFIG.weapons.axe;
  const result = calculateDamage(axe, { material: 'nature' }, { strength: 10 });
  const expected = Math.round(axe.damage * 1.35 * axe.natureMultiplier);
  assert.equal(result.damage, expected);
  assert.ok(result.damage > axe.damage);
});

test('pickaxe is more effective against stone than an ordinary piercing weapon', () => {
  const pickaxe = GAME_CONFIG.weapons.pickaxe;
  const result = calculateDamage(pickaxe, { material: 'stone' }, { strength: 10 });
  assert.equal(result.damageType, 'piercing');
  assert.equal(result.damage, Math.round(pickaxe.damage * 0.8 * pickaxe.stoneMultiplier));
});

test('wood-specific axe bonus and stone penalty are applied independently', () => {
  const axe = GAME_CONFIG.weapons.axe;
  const wood = calculateDamage(axe, { material: 'wood' }, { strength: 10 });
  const stone = calculateDamage(axe, { material: 'stone' }, { strength: 10 });
  assert.ok(wood.damage > stone.damage);
});

test('strength affects damage once and neutral strength keeps base damage', () => {
  const attack = { damage: 20, damageType: 'cutting' };
  const neutral = calculateDamage(attack, { material: 'flesh' }, { strength: 10 });
  const stronger = calculateDamage(attack, { material: 'flesh' }, { strength: 20 });
  assert.equal(neutral.damage, 20);
  assert.equal(stronger.damage, 25);
});

test('sword arc only affects points within range and the front-facing sector', () => {
  assert.equal(pointInArc(0, 0, 50, 0, 0, 70, 100), true);
  assert.equal(pointInArc(0, 0, -50, 0, 0, 70, 100), false);
  assert.equal(pointInArc(0, 0, 100, 0, 0, 70, 100), false);
});

test('thrust line distance handles middle and outside points', () => {
  assert.equal(distanceToSegment(5, 2, 0, 0, 10, 0), 2);
  assert.equal(distanceToSegment(15, 0, 0, 0, 10, 0), 5);
});

test('angle difference uses the shortest direction around the circle', () => {
  const difference = angleDifference(Math.PI - 0.1, -Math.PI + 0.1);
  assert.ok(Math.abs(difference + 0.2) < 1e-9);
});
