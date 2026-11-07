# The Tenth Bell

An offline portrait Android RPG about eighteen keepers defending the last station between six worlds. Animated CraftPix characters, original pixel scenery, original bell music and two stairways full of trouble.

## Play

Pick any of the 18 heroes. Basics are automatic; tap an enemy to focus. Use your signature and ring the bell during the red portion of an enemy windup for a perfect interrupt. Each skill has two possible evolutions. After every tenth wave a merchant offers recruits, training, equipment changes and a meal for rescued Iris. Two allies fight automatically beside your keeper; reserves can be swapped at the cart. New formations escalate at waves 11, 21 and 31 and continue scaling indefinitely.

The first hire at wave 10 is free. Weapons and charms drop on seventh-wave and boss clears. Starting charms unlock separately for each hero at their ten-, twenty- and thirty-wave milestones. Iris can be rescued during wave 7 (or a later retry wave). Her rescue and meal bond, best waves and unlocked starting charms persist across runs. Equipment, gold and other recruits belong to the current run.

Pause freezes all combat, timers and projectiles. Backgrounding the app pauses it. A checkpoint stores the beginning of the current wave, or exact purchases at a merchant visit. Continue replays an unfinished wave. Returning to character selection keeps that checkpoint; starting a new run asks before replacing it.

## Build from source

Requires Godot 4.6.3, Python 3 with Pillow, the matching Godot export templates, Android SDK build tools and Java. GitHub Actions performs the full build and an Android install/launch/touch/pause/resume/checkpoint smoke test.

```sh
python -m pip install Pillow==11.3.0
python tools/import_cast.py --zips /path/to/the/six/original/zip/files
python tools/station_art.py
python tools/prepare_fonts.py
python tools/sound.py
godot --headless --editor --import --quit
godot --headless --script res://tests/check_game.gd
godot --headless --export-debug Android /absolute/path/The-Tenth-Bell.apk
```

Without `--zips`, the importer fetches exact pinned source sheets and checks their Git blob SHA-1 against the supplied source packs. Git LFS sheets are resolved from the pinned media endpoint. Original source packs are not redistributed in this repository. All art generators are deterministic. The exported game requires no network access.

## Controls and accessibility

Designed at 360×640 with a centered portrait composition and extra vertical scenery on taller phones. All important actions have large touch targets. Toggle music, effects, haptics and reduced motion in Settings. Desktop testing: Space rings the bell, S uses the signature, P/Escape pauses.

## Credits

Character sprites © CraftPix, from the six supplied free packs: 123681 Samurai, 453698 Shinobi, 622999 Tiny Heroes, 131479 Satyrs, 242415 Schoolgirls and 404916 Graffiti Artists. Game use under https://craftpix.net/file-licenses/. Keep original pack licenses with your own source assets; do not redistribute the raw packs.

Jersey 10 and Pixelify Sans: SIL Open Font License, included alongside the generated fonts. Scenery, enemy art and sound/music are original to this project.

This is a playable v1.0.0 preview signed with a development key. Phone-specific performance and balance still need real player feedback. Package ID: `com.grimsalvage.tenthbell`.
