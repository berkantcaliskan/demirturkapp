#!/usr/bin/env bash
set -euo pipefail
umask 077

keychain="$RUNNER_TEMP/demirturk-signing.keychain-db"
certificate="$RUNNER_TEMP/distribution.p12"
profile="$RUNNER_TEMP/distribution.mobileprovision"

# Python's decoder works identically on Linux and macOS.
python3 - <<'PY'
import base64, os
from pathlib import Path
temp = Path(os.environ['RUNNER_TEMP'])
for variable, filename in [('IOS_CERTIFICATE_BASE64', 'distribution.p12'),
                           ('IOS_PROFILE_BASE64', 'distribution.mobileprovision')]:
    (temp / filename).write_bytes(base64.b64decode(os.environ[variable], validate=True))
PY

security cms -D -i "$profile" > "$RUNNER_TEMP/profile.plist"
python3 scripts/ci/release.py ios-profile
profile_uuid=$(python3 -c 'import json,os; print(json.load(open(os.path.join(os.environ["RUNNER_TEMP"], "ios-signing.json")))["uuid"])')
profile_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$profile_dir"
cp "$profile" "$profile_dir/$profile_uuid.mobileprovision"

keychain_password=$(openssl rand -hex 32)
echo "::add-mask::$keychain_password"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$certificate" -P "$IOS_CERTIFICATE_PASSWORD" -t cert -f pkcs12 -k "$keychain" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$keychain_password" "$keychain" > /dev/null
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
security find-identity -v -p codesigning "$keychain" | grep -q 'Apple Distribution'
