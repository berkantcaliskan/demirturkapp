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
2. The selected platforms are built and retained in Actions for 14 days.
3. The default stable-branch delivery is **iOS testing**, which uploads to internal
   TestFlight without submitting for App Store review. Android can be selected
   separately or together with iOS. A production delivery submits the AAB to
   Google Play production and the IPA for Apple review with automatic release
   after approval; store listings and declarations must be complete first.
4. Missing connections are listed by secret **name only** in the prepare summary.
   The final delivery job checks only the requested platforms. Missing Play
   credentials do not block an iOS-only delivery.

For a trial upload, manually run **Release to stores** on `stable`, choosing
`testing` and the desired `platform`. That uses Play's internal track and internal
TestFlight, without submitting an App Store release. Repository variables
`STORE_AUTO_DESTINATION` (testing/production) and `STORE_AUTO_PLATFORM`
(ios/android/both) can override stable-push defaults; absent variables mean
testing and ios.
The workflow refuses store operations from any other branch. Store processing,
review, managed publishing settings and device automatic-update preferences can
delay availability after a successful upload.

## One-time connections

Set these in repository **Settings → Environments → stores → Environment secrets**.
The `stores` environment allows deployments only from the protected `stable`
branch; development and pull-request jobs cannot read these keys. No manual
approval gate is configured, so eligible releases remain automatic. Optional
non-secret variables below are repository Actions variables.
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

App Store Connect and distribution signing are configured; internal TestFlight
delivery has been verified. The public listing, privacy declarations, screenshots
and review information must be completed before production submission. Google Play also
needs an app record and at least one manually uploaded build before Fastlane
can manage subsequent releases. Use a dedicated Play credential; the existing
Firebase push sender credential is unrelated and must not be reused.

Signing material is decoded only into temporary runner storage and removed in
an always-run cleanup step. It is never included in build artifacts. Workflow
permissions are read-only and third-party actions in the automated pipeline are
pinned to commit IDs. The older manual APK workflow also uses the restricted
`stores` environment and must be run on `stable`.

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
change production data. Backend hardening and the account-settings migrations
were deployed on 2026-11-28, after updating registration and staff provisioning.
The deferred registration guard is required because Auth Admin writes its server
marker after inserting a user in the same transaction. Live registration, email
and phone login, password changes and account deletion were verified. Verify payment
flows and device notifications before the first customer release. iOS Firebase
registration, APNs credentials/capabilities and a physical-device push test also
remain separate setup. Staff MFA was deferred and is not introduced by CI.

References: [Flutter continuous delivery](https://docs.flutter.dev/deployment/cd),
[Fastlane App Store uploads](https://docs.fastlane.tools/actions/upload_to_app_store/),
[Fastlane Google Play uploads](https://docs.fastlane.tools/actions/upload_to_play_store/).
