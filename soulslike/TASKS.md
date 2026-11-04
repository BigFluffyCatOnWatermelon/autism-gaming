# Development Tasks

## Phase 1 — playable combat slice

- [x] Independent Godot project and main scene.
- [x] Camera-relative movement with camera yaw decoupled from player facing.
- [x] Smooth-follow isometric camera.
- [x] Keyboard/mouse and baseline gamepad controls.
- [x] Sprint stamina drain and delayed regeneration.
- [x] Dodge with invulnerability frames.
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
- [x] Godot 4.7.2 headless editor import and 240-frame main-scene smoke test in GitHub Actions.
- [x] Automated W/S movement-direction test.
- [x] Automated J-key and left-mouse attack routing tests.
- [x] Automated light-attack hit test.
- [x] Automated bonfire rest/checkpoint/resource restore test.
- [x] Automated soul-spend/Vitality level-up test.
- [ ] Visually validate camera framing, hit volumes, telegraphs and animation timing on Windows.

## Phase 2 — combat depth

- [ ] Weapon Resource definitions, unique move sets and equipment slots.
- [ ] Backstab, riposte animation, critical finishers and poise break.
- [ ] Damage types/resistances and armor mitigation.
- [ ] More enemy archetypes: shield guard, duelist, archer, caster and brute.
- [ ] Gamepad remapping and accessibility options.

## Phase 3 — progression

- [ ] Full inventory, equipment load, armor and upgrade materials.
- [x] Basic level and eight-attribute progression at bonfires; core derived stats for Vitality, Endurance, Strength and Dexterity.
- [ ] Complete remaining attribute effects, attribute scaling and balancing.
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
