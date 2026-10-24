#!/usr/bin/env bash
set -euo pipefail
ruma_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ruma_root/.local/android.env"
export ADB_SERVER_SOCKET=tcp:localhost:5038
export ANDROID_ADB_SERVER_PORT=5038
export QT_QPA_PLATFORM=xcb
ADB_LIBUSB=1 "$ANDROID_HOME/platform-tools/adb" -P 5038 start-server
exec "$ANDROID_HOME/emulator/emulator" -avd Ruma_API35 \
  -memory 2048 -cores 2 -gpu auto -no-audio \
  -camera-back none -camera-front none "$@"
