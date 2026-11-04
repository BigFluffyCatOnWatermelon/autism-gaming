# Project State — Ashen Oath

Last updated: 2026-11-04

## Direction

Original dark-fantasy 3D Soulslike for Windows, Godot 4.7.2, GDScript. Slightly isometric top-down camera. Standalone project in `soulslike/`; legacy farm project is untouched.

## Implemented in source

- Standalone Godot project and ruined-arena main scene.
- WASD movement using a fixed world compass; independent smooth-follow camera rig decoupled from player yaw.
- Explicit player input processing and direct physical keyboard/mouse fallback in addition to InputMap actions.
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
- Save data for souls, stain, checkpoint, defeated-boss flags, level and eight character attributes.
- Bonfire level-up menu with an increasing soul cost; Vitality, Endurance, Strength and Dexterity affect player stats.
- Original first boss, Warden of the Bell: two phases, different wind-up/recovery timings and three attack patterns.
- HUD for vitality, stamina, souls, Estus charges, action state, interactions, boss health and an on-screen control reminder.
- Functional pause menu with resume, restart area and quit.

## Verification

- GitHub branch: `soulslike-reboot`.
- GitHub Actions executed Godot **4.7.2 Standard**.
- Headless editor import and global class registration passed.
- Main scene smoke test ran for 240 frames and passed.
- Automated gameplay integration passed: simulated forward/back input moves along the expected world axes; light attack damages a target; bonfire restores resources and saves checkpoint; leveling spends souls and increases Vitality-derived health.
- Keyboard/mouse routing is checked separately: W/S move in opposite directions; J and left mouse start attacks; the melee hitbox damages the enemy.
- Latest run: https://github.com/BigFluffyCatOnWatermelon/autism-gaming/actions/runs/41815540492
- Camera/world-compass coupling was removed; camera follows independently in world space.
- The pause-menu node path was corrected and is now included in the successful startup check.
- This confirms parser/import and short startup stability, **not** final visual quality, animation timing, Windows input feel, or the full design brief. Those still require hands-on editor/gameplay validation.

## Not implemented

Two additional bosses, finished character rigs/animations/final art, full weapon roster and data-driven move sets, backstab/critical finishers, complete damage-type resistance and poise system, full inventory/equipment/upgrades, remaining derived attribute effects, spells, NPCs, quests, interconnected regions, secrets/lifts/ladders/traps, comprehensive world-state persistence, production music/SFX and final balancing.
