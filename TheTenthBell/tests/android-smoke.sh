#!/usr/bin/env bash
set -euo pipefail
apk=$(find install -name '*.apk' -print -quit)
pkg=com.grimsalvage.tenthbell
mkdir -p android-results
adb install -r "$apk"
adb shell wm size 720x1280
adb shell wm density 320
adb shell settings put system screen_off_timeout 1800000
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
activity=$(adb shell cmd package resolve-activity --brief "$pkg" | tr -d '\r' | tail -1)
wait_log() {
  for i in $(seq 1 40); do
    if adb logcat -d | grep -F "$1" >/dev/null; then return 0; fi
    sleep 1
  done
  adb logcat -d > android-results/failure-logcat.txt
  echo "Did not observe: $1"; exit 1
}
shot() { adb exec-out screencap -p > "android-results/$1.png"; }
adb logcat -c
adb shell am start -W -n "$activity"
wait_log 'TenthBell: station ready'
sleep 2
shot 01-selection
adb shell input tap 524 748
sleep 1
adb shell input tap 440 1204
wait_log 'TenthBell: start hero=12 wave=1'
for i in $(seq 1 16); do
  adb shell input tap 170 1156
  if adb logcat -d | grep -F "TenthBell: signature used" >/dev/null; then break; fi
  sleep 1
done
wait_log "TenthBell: signature used"
adb shell input tap 535 1156
wait_log "TenthBell: bell used"
shot 02-combat
adb shell input tap 640 76
wait_log 'TenthBell: paused'
sleep 1
shot 03-pause
adb shell input tap 360 544
wait_log 'TenthBell: resumed'
adb shell input keyevent KEYCODE_HOME
sleep 1
adb shell am force-stop "$pkg"
adb logcat -c
adb shell am start -W -n "$activity"
wait_log 'TenthBell: station ready'
sleep 2
shot 04-checkpoint
adb shell input tap 490 1204
wait_log 'TenthBell: continued wave=1'
sleep 3
adb shell pidof "$pkg"
shot 05-continued
adb logcat -d > android-results/logcat.txt
if grep -E 'SCRIPT ERROR:|FATAL EXCEPTION|Parse Error:|Failed to load script' android-results/logcat.txt; then exit 1; fi
echo 'ANDROID INSTALL, LAUNCH, SELECTION, TOUCH COMBAT, PAUSE, RESUME AND CHECKPOINT PASSED' | tee android-results/result.txt
