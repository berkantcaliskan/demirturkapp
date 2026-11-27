"""Prepare release metadata without exposing credential values."""

import datetime
import json
import os
from pathlib import Path
import plistlib
import re
import sys

IOS_BUNDLE = "com.sirket.senettakip.senetTakip"
ANDROID_SECRETS = ("ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD")
PLAY_SECRETS = (*ANDROID_SECRETS, "PLAY_SERVICE_ACCOUNT_JSON")
IOS_SECRETS = (
    "IOS_CERTIFICATE_BASE64", "IOS_CERTIFICATE_PASSWORD", "IOS_PROFILE_BASE64",
    "APPLE_TEAM_ID", "ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY_BASE64",
)


def version_metadata(pubspec, run, attempt, android_base):
    match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", pubspec, re.M)
    if not match:
        raise ValueError("pubspec.yaml must contain version: major.minor.patch+build")
    if not 1 <= run <= 9999 or not 1 <= attempt <= 99:
        raise ValueError("Run/attempt is outside the supported Apple build-number range")
    major, minor, patch, source_build = map(int, match.groups())
    android_build = android_base + run * 100 + attempt
    if not source_build < android_build <= 2100000000:
        raise ValueError("ANDROID_BUILD_BASE must produce an increasing valid Android version code")
    return {
        "version": f"{major}.{minor}.{patch + run}",
        "android_build": str(android_build),
        "ios_build": f"{run}.{attempt}",
    }


def missing_credentials(names, env):
    return [name for name in names if not env.get(name, "").strip()]


def prepare():
    values = version_metadata(
        Path("pubspec.yaml").read_text(encoding="utf-8"),
        int(os.environ["GITHUB_RUN_NUMBER"]),
        int(os.environ["GITHUB_RUN_ATTEMPT"]),
        int(os.environ.get("ANDROID_BUILD_BASE", "100000")),
    )
    summary = [f"## Release {values['version']}",
               f"Android build: {values['android_build']}; iOS build: {values['ios_build']}", ""]
    for platform, names in (("android", ANDROID_SECRETS), ("play", PLAY_SECRETS), ("ios", IOS_SECRETS)):
        missing = missing_credentials(names, os.environ)
        values[f"{platform}_ready"] = str(not missing).lower()
        if missing:
            message = f"{platform}: pending setup; missing " + ", ".join(missing)
            print(f"::warning::{message}")
            summary.append(f"- {message}")
        else:
            summary.append(f"- {platform}: credentials present (validated by build/upload)")
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write("".join(f"{key}={value}\n" for key, value in values.items()))
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
        output.write("\n".join(summary) + "\n")


def profile_metadata(profile, team, now):
    if team not in profile.get("TeamIdentifier", []):
        raise ValueError("Provisioning profile belongs to a different Apple team")
    entitlements = profile.get("Entitlements", {})
    prefixes = profile.get("ApplicationIdentifierPrefix", [])
    expected_ids = {f"{prefix}.{IOS_BUNDLE}" for prefix in prefixes}
    if entitlements.get("application-identifier") not in expected_ids:
        raise ValueError("Provisioning profile does not match the exact application bundle ID")
    if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices") or entitlements.get("get-task-allow"):
        raise ValueError("Use an App Store distribution profile, not development/ad-hoc/enterprise")
    expires = profile["ExpirationDate"].replace(tzinfo=datetime.timezone.utc)
    if expires <= now:
        raise ValueError("Provisioning profile has expired")
    profile_uuid = profile["UUID"]
    if not re.fullmatch(r"[A-Fa-f0-9-]{36}", profile_uuid):
        raise ValueError("Invalid provisioning profile UUID")
    return {"uuid": profile_uuid, "name": profile["Name"]}


def ios_profile():
    temp = Path(os.environ["RUNNER_TEMP"])
    profile = plistlib.loads((temp / "profile.plist").read_bytes())
    team = os.environ["APPLE_TEAM_ID"]
    metadata = profile_metadata(profile, team, datetime.datetime.now(datetime.timezone.utc))
    (temp / "ios-signing.json").write_text(json.dumps(metadata), encoding="utf-8")
    (temp / "ExportOptions.plist").write_bytes(plistlib.dumps({
        "method": "app-store-connect", "teamID": team, "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {IOS_BUNDLE: metadata["name"]},
        "uploadSymbols": True,
        "manageAppVersionAndBuildNumber": False,
    }))
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
        output.write(f"IOS_PROFILE_UUID={metadata['uuid']}\n")


if __name__ == "__main__":
    {"prepare": prepare, "ios-profile": ios_profile}[sys.argv[1]]()
