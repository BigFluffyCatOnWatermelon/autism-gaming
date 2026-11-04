# Ashen Oath — standalone Soulslike project

Open **this folder** (the one containing `project.godot`) in Godot 4.7.2. Do not open the repository root for this game.

## Camera and controls

| Input | Action |
|---|---|
| WASD | Move relative to camera |
| Mouse | Orbit third-person camera |
| Mouse wheel | Zoom camera |
| Shift | Sprint |
| Space | Dodge with invulnerability frames |
| Left mouse / J | Light attack |
| Middle mouse / K | Heavy attack |
| Right mouse / L | Guard |
| F | Timed parry |
| Q | Use Estus flask |
| E | Interact / rest at bonfire |
| Tab | Lock/unlock target |
| V | Switch equipped weapon |
| Esc | Pause |

The camera is positioned behind the character rather than looking down from above. Mouse input orbits around the player with an **inverted vertical axis** (move the mouse up to look up); the wheel changes distance, and the rig smoothly follows at shoulder height. A collision ray shortens the camera arm near walls. Lock-on turns the camera toward the selected enemy.

The mouse is captured during gameplay. Click the game window after closing a menu to capture it again. Camera pitch, distance, sensitivity, follow speed and collision margin are exported on the Player node for tuning in the Inspector.

## Current combat slice

- **Ashen Longsword**: fast standard moveset, balanced stamina use and reach.
- **Grave Cleaver**: slower, heavier hits with greater reach and poise damage.
- Weapon definitions are editable Godot Resources in `data/weapons/`.
- Each moveset has independent damage, attribute scaling, stamina costs, attack timings, reach, poise damage and backstab multiplier.
- Enemies recover poise over time. Powerful hits can break poise and cause a longer stagger.
- The **Ashen Shield Guard** reduces incoming damage while facing the player. Heavy hits with enough poise damage break its guard.
- Attacking a vulnerable enemy from behind at close range triggers a critical backstab. The Warden of the Bell is immune to backstabs.
- Physical and fire resistance are supported on enemies; player resistance hooks support physical, fire and magic damage.

## Visuals and animation

Characters are assembled from procedural low-poly meshes at runtime: layered armour, helmets, chest plates, articulated arms and legs, cloaks, swords, the Grave Cleaver and the Guard's tower shield. Idle breathing and gait cycles blend with wind-up, attack follow-through, block, dodge, stagger, hit and death poses. These are original procedural placeholder models/animations, not imported motion-capture or final production assets.

Combat effects include impact rings and sparks, critical-hit bursts, parry flashes, dodge trails, healing motes and death effects. The Ashen Outskirts includes dressed stonework, broken arches, graves, rubble, dead trees, flickering torches and rising bonfire embers.

## Existing systems

Sprint/stamina, dodge/i-frames, guard, timed parry/riposte, Estus, lock-on, soul rewards, death stain recovery, bonfire checkpoint/rest, level-up attributes, save data and the two-phase Warden boss.

## Validation

GitHub Actions runs the Godot 4.7.2 editor import, scene smoke test and gameplay integration scene. Headless tests cover movement, input, camera, weapon switching, critical hits, shield guard break, bonfire and progression. They cannot judge the final camera feel, visuals or attack timing; those still need a hands-on check in the Windows Godot editor.

See `PROJECT_STATE.md`, `TASKS.md` and `CHANGELOG.md` for implementation status.
