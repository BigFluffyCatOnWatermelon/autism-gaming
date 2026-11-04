# Ashen Oath — standalone Soulslike project

Open **this folder** (the one containing `project.godot`) in Godot 4.7.2. Do not open the repository root for this game.

## Playable combat slice

- Camera-relative WASD movement with a detached, smooth-follow isometric camera.
- Shift sprint, Space dodge with invulnerability frames, Q healing flask, E interaction.
- Left mouse / J light attack; middle mouse / K heavy attack; right mouse / L guard; F parry.
- Tab toggles lock-on to the nearest living enemy.
- Enemy AI with detection, pursuit, visible red attack telegraph, attack arc, recovery, stagger and parry response.
- Guard reduces incoming damage and consumes stamina; empty stamina causes a guard break.
- A timed parry stuns an attacker and empowers the next strike.
- Bonfire interaction restores health, stamina and flasks, activates a checkpoint and resets regular enemies.
- Death moves carried souls into a persistent world stain. Interact with it to reclaim them. A second death overwrites the previous stain.
- Save data is stored in `user://ashen_oath_save.json`.
- First original boss, **Warden of the Bell**, has two phases, three attack patterns and a boss health bar.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Sprint | Shift | Right shoulder |
| Dodge | Space | B |
| Light attack | Left mouse / J | X |
| Heavy attack | Middle mouse / K | Y |
| Guard | Right mouse / L | Left shoulder |
| Parry | F | — |
| Heal | Q | — |
| Interact | E | A |
| Lock target | Tab | — |
| Restart after death | R | — |

## Project structure

- `scripts/core`: input and persistent run state
- `scripts/player`: movement, combat action queue, dodge, guard, parry, healing, lock-on and interaction
- `scripts/combat`: damage payloads
- `scripts/actors`: health component
- `scripts/enemies`: enemy state machine and telegraphed attack
- `scripts/bosses`: multi-phase boss AI
- `scripts/bonfires`: checkpoint and rest interaction
- `scripts/world`: arena lifecycle and recoverable soul stain
- `scripts/ui`: combat HUD and prompts
- `scenes`: reusable player, enemy, boss, bonfire, soul stain, UI and location scenes

All game content is authored independently under this directory. No farm scripts, scenes, assets or add-ons are referenced.

## Validation

A GitHub Actions workflow downloads Godot 4.7.2 Standard, imports the project headlessly, and starts the main scene for 240 frames on pushes to `soulslike-reboot`.

Latest validation passed: [Godot 4.7.2 headless import + scene smoke test](https://github.com/BigFluffyCatOnWatermelon/autism-gaming/actions/runs/41796382428).

This confirms parsing/import and short startup stability. It does **not** prove final visual quality, animation timing, or Windows input feel; manually test those in the editor.

## Honest status

This is a playable prototype slice, not the completed game brief. It still uses original greybox 3D meshes and does not yet include a finished character rig/animation set, three bosses, interconnected chapter, inventory/equipment, leveling, magic, NPC quests, production audio or complete world-state persistence.
