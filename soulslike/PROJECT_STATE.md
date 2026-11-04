# Project State — Ashen Oath

Last updated: 2026-11-04

## Direction

Original dark-fantasy 3D Soulslike for Windows, Godot 4.7.2, GDScript. Third-person over-the-shoulder camera inspired by the genre, with mouse orbit, zoom, soft follow, collision handling and target-lock framing. Standalone project in `soulslike/`; the legacy farm project and `main` are untouched.

## Implemented in source

- Standalone Godot project and ruined-arena main scene.
- Third-person orbit camera behind the player, mouse look, wheel zoom, configurable pitch/distance/sensitivity, smooth shoulder-height follow and collision ray.
- Camera-relative WASD movement; target lock smoothly turns the camera toward a valid enemy.
- Explicit player input processing and direct physical keyboard/mouse fallback in addition to InputMap actions.
- Keyboard/mouse and baseline gamepad movement/buttons.
- Sprint, stamina drain and delayed stamina regeneration.
- Dodge with stamina cost and invulnerability frames.
- Weapon Resources with two distinct movesets: Ashen Longsword and Grave Cleaver; V cycles equipped weapons.
- Weapon-specific damage, scaling, stamina costs, wind-up/active/recovery windows, reach, poise damage and critical multiplier.
- Light/heavy attacks with wind-up, active and recovery phases and one buffered follow-up.
- Guard, guard break and timed parry/riposte.
- Physical/fire resistance and player resistance hooks for physical, fire and magic.
- Enemy poise with delayed recovery, stagger breaks, shield frontal mitigation and heavy-attack guard breaks.
- Rear-position critical backstabs against vulnerable enemies; the Warden of the Bell is immune.
- Three limited-use healing flasks replenished at a bonfire.
- Target lock, nearest-interactable prompt and interaction.
- Enemies with detection, chase, visible wind-up telegraph, frontal attack arc, recovery, stagger, parry stun, death and bonfire reset.
- New Ashen Shield Guard archetype with frontal block, physical resistance and a guard-break threshold.
- Enemy soul rewards.
- Bonfire checkpoint/rest restores health, stamina and flasks.
- Persistent carried souls, death stain and retrieval; a later death replaces the previous stain.
- Save data for souls, stain, checkpoint, defeated-boss flags, level and eight character attributes.
- Bonfire level-up menu with an increasing soul cost; Vitality, Endurance, Strength and Dexterity affect player stats.
- Original first boss, Warden of the Bell: two phases, different wind-up/recovery timings and three attack patterns.
- HUD for vitality, stamina, souls, Estus charges, equipped weapon, action state, interactions, boss health and on-screen controls.
- Functional pause menu; cursor is released for menus and recaptured on resume.

## Controls

- WASD: camera-relative movement; Shift: sprint; Space: dodge.
- Mouse: orbit camera; wheel: zoom.
- Left mouse / J: light attack; middle mouse / K: heavy attack; right mouse / L: guard.
- F: parry; Q: Estus; E: interact; Tab: lock/unlock target; V: switch weapon; Esc: pause.
- Mouse is captured during play. Click the game window to recapture after returning from a menu.

## Verification

- GitHub branch: `soulslike-reboot`.
- GitHub Actions uses Godot **4.7.2 Standard**.
- Integration coverage includes headless editor import, main-scene startup, W/S movement, J and left-mouse attack routing, melee damage, camera orbit/zoom, weapon switching, backstab critical damage, shield mitigation/guard break, bonfire rest/checkpoint/resource restore and persistent Vitality level-up.
- Automated checks do not replace visual Windows validation for camera feel, occlusion, combat telegraphs, animations or balance.

## Not implemented

Finished character rigs/animations/final art, full armour/equipment/load system, additional enemy archetypes beyond the shield guard, two additional bosses, full damage-type effect roster, spells, NPCs, quests, interconnected regions, secrets/lifts/ladders/traps, comprehensive world-state persistence, production music/SFX and final balancing.
