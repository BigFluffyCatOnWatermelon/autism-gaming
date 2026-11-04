# Project State — Ashen Oath

Last updated: 2026-11-04

## Direction

Original dark-fantasy 3D Soulslike for Windows, Godot 4.7.2, GDScript. Slightly isometric top-down camera. Standalone project in `soulslike/`; legacy farm project is untouched.

## Implemented in source

- Standalone Godot project and ruined-arena main scene.
- WASD movement using a fixed world compass; independent smooth-follow camera rig decoupled from player yaw.
- Keyboard/mouse and baseline gamepad movement/buttons.
- Sprint, stamina drain and delayed stamina regeneration.
- Dodge with stamina cost and invulnerability frames.
- Light/heavy attacks with wind-up, active and recovery phases and one buffered follow-up.
- Guard with damage reduction and stamina-based guard break.
- Timed parry window, attacker stun and empowered follow-up strike.
- Three limited-use healing flasks replenished at a bonfire.
- Target lock, nearest-interactable prompt and interaction.
- Enemies with detection, chase, visible wind-up telegraph, frontal attack arc, recovery, stagger, parry stun, death and bonfire reset.
- Enemy soul rewards.
- Bonfire checkpoint/rest restores health, stamina and flasks.
- Persistent carried souls, death stain and retrieval; a later death replaces the previous stain.
- Save data for souls, stain, checkpoint and defeated-boss flags.
- Original first boss, Warden of the Bell: two phases, different wind-up/recovery timings and three attack patterns.
- HUD for vitality, stamina, souls, Estus charges, action state, interactions and boss health.

## Verification status

- Branch exists on GitHub and changes are committed separately from main.
- Camera-relative movement issue has been addressed by separating the camera's world-space orientation from player yaw.
- Source and scenes are authored, but Godot 4.7.2 headless/editor startup is not available in this environment. **Parser/runtime validation remains pending**. Do not claim the build is verified until it is opened and run locally.

## Not implemented

Three total bosses, finished character rigs/animations/final art, full weapon roster and data-driven move sets, backstab/critical finishers, complete damage-type resistance and poise system, inventory, equipment and upgrades, leveling, spells, NPCs, quests, interconnected regions, secrets/lifts/ladders/traps, comprehensive world-state persistence, production music/SFX and final balancing.
