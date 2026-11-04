# Changelog

## 0.3.1 — 2026-11-04

- Corrected the follow camera offset and set the initial enemy detection distance to give the player a short safe approach.
- Added a GitHub Actions workflow using Godot 4.7.2 Standard.
- Confirmed headless editor import/class registration and a 240-frame main-scene smoke test passed.

## 0.3.0 — 2026-11-04

- Fixed the movement/camera coupling: the isometric camera now follows in world space and no longer spins with the player's facing direction.
- Rebuilt input bootstrap for keyboard, mouse and analogue gamepad movement.
- Added sprint regeneration delay, timed parry/riposte, target lock and healing flasks.
- Added a persistent bonfire checkpoint/rest loop, enemy reset, soul stain and soul retrieval.
- Added readable enemy attack telegraphs, hit flash and resettable death states.
- Added the Warden of the Bell, an original two-phase boss with a boss health bar.
- Expanded the arena with ruined geometry, torch lighting and an improved HUD.

## 0.1.0 — 2026-11-04

- Created the independent Godot project and first combat arena.
- Added initial player, enemy, health and souls HUD foundation.
