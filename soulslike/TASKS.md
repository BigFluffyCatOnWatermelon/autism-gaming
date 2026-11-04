# Development Tasks

## Phase 1 — playable combat slice

- [x] Independent Godot project and main scene.
- [x] Third-person over-the-shoulder camera with mouse orbit, inverted vertical axis, wheel zoom, soft follow and wall collision.
- [x] Procedural low-poly player, enemy and boss models with modular armour, helmets, cloaks, shields and weapons.
- [x] Procedural locomotion, breathing, attack wind-up/follow-through, guard, dodge lean, stagger and death poses.
- [x] Combat VFX for hit sparks, critical strikes, parries, dodge trails, healing and death.
- [x] Arena dressing with columns, broken arch fragments, grave markers, rubble, dead trees, animated torches and bonfire embers.
- [x] Camera-relative WASD movement and target-lock camera framing.
- [x] Keyboard/mouse and baseline gamepad controls.
- [x] Sprint stamina drain and delayed regeneration.
- [x] Dodge with stamina cost and invulnerability frames.
- [x] Light/heavy attack timing and buffered follow-up.
- [x] Guard, guard break and timed parry/riposte.
- [x] Limited healing flasks.
- [x] Enemy detect/chase/telegraph/attack/recovery/stagger/death/reset.
- [x] Bonfire rest, checkpoint, enemy reset and attribute level-up interface.
- [x] Persistent character level and eight attributes; core combat attributes affect health, stamina and attack damage.
- [x] Persistent souls, death stain and retrieval.
- [x] Target lock and interaction prompt.
- [x] First original two-phase boss and boss health bar.
- [x] Expanded HUD, on-screen controls, pause menu and ruined arena layout.
- [x] Godot 4.7.2 headless editor import and main-scene smoke test in GitHub Actions.
- [x] Automated movement, attack routing, melee hit, bonfire and progression checks.
- [x] Automated camera orbit/zoom, weapon switching, backstab critical, shield mitigation and guard-break checks.
- [ ] Visually validate camera framing, occlusion, hit volumes, telegraphs and animation timing on Windows.

## Phase 2 — combat depth

- [x] Weapon Resource definitions with per-weapon movesets, scaling, reach, stamina and poise values.
- [x] Switch between Ashen Longsword and Grave Cleaver with V.
- [x] Backstab criticals with weapon-specific multipliers; first boss is immune.
- [x] Enemy poise and delayed poise recovery.
- [x] Physical/fire resistance hooks and player damage-resistance hooks.
- [x] Shield Guard archetype, frontal mitigation and heavy-weapon guard break.
- [ ] Backstab/riposte presentation, finisher animations and hit-stop.
- [ ] Additional duelist, archer, caster and brute archetypes.
- [ ] Gamepad remapping and accessibility options.

## Phase 3 — progression

- [ ] Full inventory, equipment load, armour and upgrade materials.
- [x] Basic level and eight-attribute progression at bonfires; core derived stats for Vitality, Endurance, Strength and Dexterity.
- [ ] Remaining attribute effects, weapon scaling balance and armour mitigation.
- [ ] Consumables, spell slots and multiple magic schools.
- [ ] Expanded save slots, backup saves and robust world-state persistence.

## Phase 4 — bosses and world

- [x] First original boss with two phases and distinct attack patterns.
- [ ] Two more original bosses.
- [ ] Interconnected chapter locations and shortcuts.
- [ ] NPC dialogue, shops, quests and progression flags.
- [ ] Secrets, traps, lifts, ladders and hidden routes.

## Phase 5 — polish and release slice

- [ ] Original character rigs, animation, VFX, models and environment art.
- [ ] Audio, music, ambience and surface-specific footsteps.
- [ ] Performance, balance, UX and accessibility pass.
- [ ] End-to-end chapter acceptance test after repeated deaths/reloads.
