/**
 * Combat math is kept outside the scene so future enemies, trees, rocks
 * and other world objects can use the same damage rules.
 */

import { GAME_CONFIG } from '../config/gameConfig.js';

export const DAMAGE_TYPES = {
  cutting: 'Режущий',
  piercing: 'Колющий',
  crushing: 'Дробящий',
};

/**
 * Material resistance / vulnerability table.
 * Example: axe.damage * woodMultiplier is already weapon-specific, while
 * this table describes the material itself. Keeping both layers separate
 * lets future enemies (e.g. an Ent) have their own damage profile.
 */
const MATERIAL_MATCHUPS = {
  wood: { cutting: 1.15, piercing: 0.65, crushing: 0.9 },
  stone: { cutting: 0.3, piercing: 0.8, crushing: 1.2 },
  flesh: { cutting: 1.0, piercing: 1.0, crushing: 1.0 },
  nature: { cutting: 1.35, piercing: 0.75, crushing: 0.9 },
};

/**
 * Calculate final damage without applying it. The caller decides whether a
 * target was hit and then applies the result to that target's health.
 */
export function calculateDamage(attack, target = {}, playerStats = {}) {
  const type = attack.damageType || 'crushing';
  const material = target.material || target.kind || 'flesh';
  const materialMultiplier = MATERIAL_MATCHUPS[material]?.[type] ?? 1;

  // Strength 10 is the neutral baseline. This keeps early characters readable.
  const strength = Number(playerStats.strength ?? 10);
  const attributeMultiplier = Math.max(0.25, 1 + ((strength - 10) * GAME_CONFIG.combat.damageAttributeScale));

  // Weapon specialisation is separate from natural material resistance.
  // This is what makes an axe useful against an Ent-like nature target while
  // a pickaxe remains the right tool for stone.
  const materialBonus = {
    wood: attack.woodMultiplier,
    stone: attack.stoneMultiplier,
    nature: attack.natureMultiplier,
  }[material];
  const toolMultiplier = Number(materialBonus || 1);

  const rawDamage = Number(attack.damage || 0);
  const damage = Math.max(0, Math.round(rawDamage * materialMultiplier * toolMultiplier * attributeMultiplier));

  return {
    damage,
    rawDamage,
    damageType: type,
    damageLabel: DAMAGE_TYPES[type] || type,
    material,
    materialMultiplier,
    toolMultiplier,
    attributeMultiplier,
  };
}

/** Shortest signed angle between two radians values. */
export function angleDifference(a, b) {
  let difference = (a - b) % (Math.PI * 2);
  if (difference > Math.PI) difference -= Math.PI * 2;
  if (difference < -Math.PI) difference += Math.PI * 2;
  return difference;
}

/** Is a world point inside a forward-facing circular attack sector? */
export function pointInArc(originX, originY, targetX, targetY, angle, radius, arcDegrees) {
  const dx = targetX - originX;
  const dy = targetY - originY;
  const distance = Math.hypot(dx, dy);
  if (distance > radius || distance < 0.001) return false;
  const targetAngle = Math.atan2(dy, dx);
  return Math.abs(angleDifference(targetAngle, angle)) <= (arcDegrees * Math.PI / 360);
}

/** Distance from a point to a finite line segment; used by thrust attacks. */
export function distanceToSegment(px, py, x1, y1, x2, y2) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const lengthSquared = (dx * dx) + (dy * dy);
  if (lengthSquared === 0) return Math.hypot(px - x1, py - y1);
  const t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / lengthSquared));
  const nearestX = x1 + t * dx;
  const nearestY = y1 + t * dy;
  return Math.hypot(px - nearestX, py - nearestY);
}
