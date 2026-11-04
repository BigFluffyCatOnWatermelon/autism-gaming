# Ashen Oath — standalone Soulslike project

This folder is an independent Godot 4.7.2 project. Open **this folder** (the one containing `project.godot`) in Godot; do not open the repository root for this game.

## Current playable slice

- 3D top-down / slightly isometric arena.
- WASD movement, Shift sprint, Space dodge with a short invulnerability window.
- Left mouse / J light attack; middle mouse / K heavy attack.
- Right mouse / L block.
- Enemy detection, pursuit, telegraphed melee wind-up, recovery, stagger and death.
- Stamina costs and regeneration; souls awarded for kills.
- Health/stamina HUD and restart after death (R also restarts).

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Sprint | Shift | Right shoulder |
| Dodge | Space | B |
| Light attack | Left mouse / J | X |
| Heavy attack | Middle mouse / K | Y |
| Block | Right mouse / L | Left shoulder |

The gamepad baseline is mapped through Godot's standard joypad events. Analog movement dead-zone tuning and target lock are scheduled for a later pass.

## Project structure

- `scripts/core`: input setup and shared runtime services
- `scripts/player`: player movement and action state machine
- `scripts/combat`: typed damage payloads
- `scripts/actors`: reusable health component
- `scripts/enemies`: enemy AI
- `scripts/world`: arena lifecycle
- `scripts/ui`: combat HUD
- `scenes`: player, enemy, UI and location scenes
- `data`: future Resource-based content definitions

## Development rules

All assets, scenes and scripts for this game must be authored independently under this directory. Do not reference files outside `soulslike/`, the old farm project, Cozy Village & Farm, or the archived browser game. Keep the root project's existing game untouched.

The first commit establishes the project and a combat test arena. It is not the complete game described in the design brief. See `PROJECT_STATE.md` and `TASKS.md`.
