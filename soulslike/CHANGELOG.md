# Changelog

## 0.5.0 — 2026-11-04

- Inverted vertical camera look: moving the mouse up now looks up.
- Replaced primitive capsule visuals with procedural low-poly character rigs for the player, hollows, shield guard and Warden.
- Added layered armour, helmets, chest plates, articulated limbs, cloaks, longsword, Grave Cleaver, club and tower shield.
- Added procedural idle breathing, walk/run cycles, enemy wind-up, player attack follow-through, guard, dodge, stagger, hit flash, enrage and death-collapse animation poses.
- Added impact sparks/rings, critical hit bursts, parry flashes, dodge trails, healing motes and death VFX.
- Added stone columns, broken arch fragments, gravestones, rubble piles, dead trees, flickering torches and rising bonfire embers to the arena.
- Extended CI gameplay checks for camera inversion and runtime visual/VFX creation.

# Changelog

## 0.4.0 — 2026-11-04

- Replaced the fixed overhead view with a third-person over-the-shoulder orbit camera.
- Added mouse look, wheel zoom, adjustable pitch/distance/sensitivity, smooth shoulder-height follow and wall collision.
- Movement now follows camera yaw; target lock turns the camera toward the locked enemy.
- Menus release the mouse cursor and recapture it on resume.
- Added WeaponDefinition Resources for Ashen Longsword and Grave Cleaver with independent damage, scaling, timing, stamina, reach, poise and critical values.
- Added V weapon switching and an equipped-weapon HUD line.
- Added enemy poise, delayed poise recovery and extended stagger on poise break.
- Added frontal shield mitigation, heavy-hit guard break and the Ashen Shield Guard arena enemy.
- Added close-range backstab critical hits; Warden of the Bell is immune.
- Expanded headless integration coverage for camera, weapons, critical hits and shield guard.

## 0.3.6 — 2026-11-04

- Godot 4.7.2 CI passes after explicit player input processing.
- Confirmed W/S movement direction, J-key attack routing, left-mouse attack routing and melee damage in gameplay integration tests.

## 0.3.5 — 2026-11-04

- Explicitly enabled player input processing and added direct keyboard/mouse fallback in PlayerController alongside InputMap.
- Split input routing and hitbox assertions in the gameplay smoke test; it now checks W/S, J, left mouse and actual enemy damage separately.

## 0.3.4 — 2026-11-04

- Fixed the pause overlay node path discovered by headless startup validation.
- Added a gameplay integration test that simulates forward/back movement, verifies melee damage, rests at the bonfire and levels Vitality.
- Godot 4.7.2 import, main-scene startup and gameplay integration all pass in GitHub Actions.

## 0.3.3 — 2026-11-04

- Added soul-cost leveling at the bonfire with all eight character attributes.
- Vitality, Endurance, Strength and Dexterity now directly affect health, stamina or weapon damage.
- Level and attributes persist in the save file.

## 0.3.2 — 2026-11-04

- Added an on-screen keyboard/gamepad control reminder.
- Added a pause menu with resume, restart area and quit actions.

## 0.3.1 — 2026-11-04

- Corrected the follow camera offset and set the initial enemy detection distance to give the player a short safe approach.
- Added a GitHub Actions workflow using Godot 4.7.2 Standard.
- Confirmed headless editor import/class registration and a 240-frame main-scene smoke test passed.

## 0.3.0 — 2026-11-04

- Fixed the movement/camera coupling: the isometric camera now follows in world space and no longer spins with the player's facing direction.
- Rebuilt input bootstrap for keyboard, mouse and analogue gamepad movement.
- Added sprint regeneration delay, timed parry/riposte, target lock and healing flasks.
- Added persistent bonfire checkpoint/rest, enemy reset, soul stain and recoverable souls.
- Added readable enemy attack telegraphs, hit flash and resettable death states.
- Added the Warden of the Bell, an original two-phase boss with a health bar.
- Expanded the arena with torch lighting and an improved HUD.

## 0.1.0 — 2026-11-04

- Created the independent Godot project and first combat arena.
- Added initial player, enemy, health and souls HUD foundation.
