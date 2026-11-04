# Project State — Ashen Oath

Last updated: 2026-11-04

## Direction

Original dark-fantasy 3D Soulslike for Windows, Godot 4.7.2, GDScript. Top-down camera with a slight isometric angle. This is a completely independent project nested in the repository at `soulslike/`.

## Implemented in the initial foundation

- Standalone Godot project configuration and dedicated main scene.
- Input bootstrap for keyboard, mouse and baseline gamepad buttons.
- CharacterBody3D player with camera-relative movement, sprint stamina drain and regeneration.
- Dodge action with stamina cost and a brief invulnerability window.
- Light/heavy attacks with wind-up, active and recovery phases; one queued follow-up attack.
- Blocking with stamina damage and guard-break stagger.
- Reusable health component and typed damage payload.
- Enemy idle/chase/telegraph/attack/recovery/stunned/dead state flow.
- Enemy damage, stagger, death and soul reward.
- Minimal HUD for health, stamina, souls and action state.
- Death restart loop for rapid combat testing.

## Not implemented yet

No save system, bonfires, persistent death-drop souls, leveling, inventory, equipment, weapon data catalog, magic, NPCs, quests, world links, boss phases, animation assets, audio, lock-on, parry, critical attacks, ladders, traps, or finished art direction. The current character/enemy/floor meshes are greybox placeholders for validating scale and combat logic, not final game art.

## Verification status

The repository branch was created through GitHub. This initial source set has not yet been opened or run in the Godot 4.7.2 editor/headless runtime in this environment. Treat runtime validation as pending; fix parser/runtime errors before expanding the feature set.
