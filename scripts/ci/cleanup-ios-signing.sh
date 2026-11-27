#!/usr/bin/env bash
set -euo pipefail

keychain="$RUNNER_TEMP/demirturk-signing.keychain-db"
if [[ -f "$keychain" ]]; then
  security delete-keychain "$keychain"
fi
if [[ -n "${IOS_PROFILE_UUID:-}" ]]; then
  rm -f "$HOME/Library/MobileDevice/Provisioning Profiles/$IOS_PROFILE_UUID.mobileprovision"
fi
rm -f "$RUNNER_TEMP/distribution.p12" "$RUNNER_TEMP/distribution.mobileprovision" \
  "$RUNNER_TEMP/profile.plist" "$RUNNER_TEMP/ios-signing.json" "$RUNNER_TEMP/ExportOptions.plist"
