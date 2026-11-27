#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Bu betik Xcode ve Flutter kurulu bir Mac'te çalıştırılmalı." >&2
  exit 1
fi
command -v flutter >/dev/null || { echo "Flutter 3.50.0 SDK gerekli." >&2; exit 1; }
xcode-select -p >/dev/null
flutter pub get
flutter build ios --config-only --simulator
open ios/Runner.xcworkspace
