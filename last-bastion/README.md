# Grim Salvage: Last Bastion — Milestone A preview

This is a separate Godot 4.4.1 project and separate Android application ID from the original Java game. It is an early vertical slice, not the complete game.

Select one of the glowing build pads, buy an archer or frost tower, and start the wave. Tap a lane near the hero to move the knight. The knight fights automatically; Shield Strike is an active area attack. Tapping a built tower lets you upgrade or sell it. Defend the Bastion through 10 waves. Gold, tower layout and progress are saved between runs; an interrupted battle restarts its wave. A loss repairs the Bastion and lets you retry the wave.

Included: Human Knight, three animated enemy roles plus a wave-10 large enemy, archers/frost towers, tower upgrades, leveling, gold, touch controls, shield strike, 10-wave objective, pause and local save. This preview does not include character creation, companion/rescue systems, gear, crafting, camp, audio, story, or a full boss mechanic. There is no internet, login, analytics, advertising or purchasing.

## Run

Import this folder with Godot 4.4.1 stable. For Android, install matching Android templates, OpenJDK 17, Android SDK, and a debug keystore, then export preset `Android`. See https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_android.html. The `Last Bastion Android` GitHub Actions workflow builds an APK. Debug keys generated in CI are temporary; APKs from separate workflow runs may require uninstalling the previous preview before installing a new one.
