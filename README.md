# GRIM SALVAGE: The Endless Hunt

A lightweight, offline Android idle RPG where a lone hunter automatically fights mutated creatures while you choose how to spend coins, harvest monster parts, forge equipment, and graft abilities.

## Gameplay

- Automatic combat, enemy attacks, revivals, damage feedback, and escalating endless waves.
- Five enemy species, with a boss encounter every tenth wave.
- Five permanent upgrades, species-specific loot, material selling, three equipment recipes, and five graft mutations.
- Persistent hunter contracts, offline rewards capped at two hours, female and male appearances, and original synthesized audio.
- Portrait-only Android UI rendered with Canvas; no network access, accounts, or runtime permissions.

## Build the APK

The project pins Android Gradle Plugin 8.8.2, Gradle wrapper 8.10.2, JDK 17, compile SDK 35, and minimum Android API 26.

Run locally from the repository root in an Android SDK environment:

```sh
./gradlew --no-daemon testDebugUnitTest
./gradlew --no-daemon assembleDebug
```

GitHub Actions runs those unit tests, builds the debug APK, and runs an emulator startup smoke test. Open **Actions**, select the latest successful **Android build and smoke test** run, and download the [32m`grim-salvage-debug-apk`[0m artifact. Extract it and install `app-debug.apk` on an Android 8.0+ phone.

The first build is not considered verified until that workflow run finishes successfully.
