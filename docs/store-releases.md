# Development and store releases

`development` contains ongoing work. Pushes and pull requests run the analyzer,
Flutter tests and release-tool checks. No store keys are used in pull requests.
`stable` is the release branch: merging a tested change there starts **Release
to stores**. `codex/v15-xcode` retains the original V15 Xcode handoff.

`stable` is the repository's default branch. It requires a pull request with
passing **Flutter checks** and **Release tool checks**, including for repository
administrators; force pushes and branch deletion are disabled. Work on
`development`, then open a pull request from `development` to `stable` when ready.

## What is automatic

1. Application checks must pass before release work starts.
2. Signed Android APK/AAB files are built and retained in Actions for 14 days.
3. With the store connections configured, the AAB is submitted to Google Play
   production; the IPA is submitted for Apple review with automatic release
   after approval. Existing store listings, screenshots, review information and
   privacy declarations must already be complete in the consoles.
4. Missing connections are listed by secret **name only** in the prepare summary.
   The final delivery job fails when either store is unconfigured; an APK artifact
   alone is never reported as successful store delivery.

For a trial upload, manually run **Release to stores** on `stable`, choosing
`testing`. That uses Play's internal track and internal TestFlight, without
submitting an App Store release. A push to `stable` always selects production.
The workflow refuses store operations from any other branch. Store processing,
review, managed publishing settings and device automatic-update preferences can
delay availability after a successful upload.

## One-time connections

Set these in repository **Settings → Secrets and variables → Actions → Secrets**.
Never commit keys or send private key values in chat. Grant credentials access
only to this application and the release operations they need.

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the existing production/upload PKCS12 key; preserve its identity |
| `ANDROID_KEYSTORE_PASSWORD` | Password for that key |
| `ANDROID_KEY_PASSWORD` | Optional, only if the alias password differs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Dedicated Google Play Android Publisher service account JSON |
| `IOS_CERTIFICATE_BASE64` | Base64 of an Apple Distribution certificate **including its private key**, exported as P12 |
| `IOS_CERTIFICATE_PASSWORD` | Password protecting that P12 |
| `IOS_PROFILE_BASE64` | Base64 of an App Store distribution profile for the exact iOS bundle ID |
| `APPLE_TEAM_ID` | Apple Developer team owning that profile |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer ID |
| `ASC_PRIVATE_KEY_BASE64` | Base64 of that API key's private P8 file |

Optional repository variables: `ANDROID_KEY_ALIAS` defaults to `demirturk`;
`ANDROID_BUILD_BASE` defaults to `100000`. If Play already contains a higher
version code, increase the base before enabling uploads. Do not replace an
existing app's signing key with a newly generated key.

App IDs already in this source:

- Android: `com.sirket.senettakip.senet_takip`
- iOS: `com.sirket.senettakip.senetTakip`

App Store Connect has **not yet been opened** as of this setup. First enroll or
activate Apple Developer membership, create the matching app record, complete
its listing/review/privacy requirements and create the distribution credentials
and API key. These cannot be supplied by the repository itself. Google Play also
needs an app record and at least one manually uploaded build before Fastlane
can manage subsequent releases. Use a dedicated Play credential; the existing
Firebase push sender credential is unrelated and must not be reused.

Signing material is decoded only into temporary runner storage and removed in
an always-run cleanup step. It is never included in build artifacts. Workflow
permissions are read-only and third-party actions are pinned to commit IDs.

## Version numbers and retries

The public version is `pubspec major.minor.(patch + workflow run number)`;
starting from V15, run 1 produces `1.0.16`. Android uses
`ANDROID_BUILD_BASE + run_number * 100 + run_attempt`. iOS uses
`run_number.run_attempt`. A retry keeps the public version and increments the
build number. Use **Re-run all jobs**, not just failed jobs, so prepare runs
again. Check the store console first when an upload partly succeeded; rebuilding
does not withdraw an earlier submission. Release jobs are serialized, but GitHub
may coalesce queued runs; a newer stable release can supersede pending commits.
Do not delete/recreate the workflow or decrease the source version/build base.

## Application readiness is a separate check

This automation builds and submits the source. It does not deploy Supabase or
change production data. The V15 backend hardening migration
`20261122125818_harden_portal_runtime.sql` is still pending production deployment;
deploy the updated `register-phone-account` and `provision-staff-account` functions
**before** applying it. Verify live registration, contract permissions, payment
flows and device notifications before the first customer release. iOS Firebase
registration, APNs credentials/capabilities and a physical-device push test also
remain separate setup. Staff MFA was deferred and is not introduced by CI.

References: [Flutter continuous delivery](https://docs.flutter.dev/deployment/cd),
[Fastlane App Store uploads](https://docs.fastlane.tools/actions/upload_to_app_store/),
[Fastlane Google Play uploads](https://docs.fastlane.tools/actions/upload_to_play_store/).
