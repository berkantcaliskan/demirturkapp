# Demirtürk Mobil

Flutter customer and administration portal for Android and iOS.

## V15 branch and Xcode

Branch `codex/v15-xcode` includes the V14 features and the current V15
hardening work, with version `1.0.15+15`. Staff password and MFA changes remain
deferred. Flutter analysis and 11 widget/unit tests pass on Windows; an iOS
native build has not yet been verified on a Mac.

On a Mac with Flutter 3.50.0, Xcode and the iOS simulator installed:

```sh
git clone --branch codex/v15-xcode --single-branch https://github.com/berkantcaliskan/demirturkapp.git
cd demirturkapp
bash scripts/open-ios.sh
```

The script resolves Flutter dependencies, generates the local Swift Package
Manager configuration and opens `ios/Runner.xcworkspace`. If Flutter requests
CocoaPods for a plugin fallback, install CocoaPods and rerun the script. In
Xcode choose the `Runner` scheme and a simulator. For a physical iPhone,
select the company's Apple development team under Signing & Capabilities.
The current bundle ID is `com.sirket.senettakip.senetTakip`, deployment target
iOS 15.0. Keychain entitlements are configured for all Runner build modes.

Android Firebase configuration is present. iOS push still needs its own
Firebase app registration, APNs credentials and signing capability. Until
that platform setup is completed, the app continues without iOS push.

The pending migration `20261122125818_harden_portal_runtime.sql` and updated
registration functions are source changes, **not deployed by creating this
branch**. Before applying that migration to an existing backend, first deploy
the updated `register-phone-account` and `provision-staff-account` functions;
they supply the server-only creation marker required by the new signup gate.
Then apply the migration and validate registration/contract approval before
distributing V15. Do not reapply historical migrations blindly on the live
project. Production Android signing also requires the configured company key;
the private key and its password are excluded from this repository.

## Backend

Supabase provides Auth, PostgreSQL, RLS, Realtime, Edge Functions and private
Storage. The mobile app only receives the Supabase publishable key. Never ship
the service-role key, FCM service-account credentials or webhook secret in the
app.

Apply the migrations in order:

- `supabase/migrations/202611090001_initial_schema.sql`
- `supabase/migrations/202611090002_notifications_messaging_persistence.sql`
- `supabase/migrations/202611100003_link_customer_after_phone_verification.sql`
- `supabase/migrations/202611100004_backfill_verified_customer_links.sql`
- `supabase/migrations/202611100005_staff_roles_routing_and_access.sql`
- `supabase/migrations/202611110006_contract_number_format.sql`
- `supabase/migrations/202611110007_yearly_contract_numbers.sql`
- `supabase/migrations/202611110008_role_based_staff_ids.sql`
- `supabase/migrations/202611110009_private_customer_contract_documents.sql`
- `supabase/migrations/202611120010_contract_first_and_customer_matching.sql`
- `supabase/migrations/202611130011_secure_customer_ticket_creation.sql`
- `supabase/migrations/202611130012_staff_roster_and_assignment_sync.sql`
- `supabase/migrations/202611130013_username_signup_and_unlinked_customer_accounts.sql`
- `supabase/migrations/202611130014_server_only_staff_roster.sql`
- `supabase/migrations/202611140015_harden_portal_access.sql`

The last migration requires mobile builds that use `create_contract_record`
and `get_or_create_customer_ticket`. It removes the legacy contract RPC and
direct client writes to support tickets. Update any older app installations
before rolling out these database permissions.

Migration 2 creates the **private** Storage bucket named `payment-receipts`
with a 10 MB size limit and PDF/JPEG/PNG MIME allowlist. Receipt objects must
be under the linked customer UUID folder. The customer link is
`customers.auth_user_id`; staff accounts are promoted through a trusted SQL or
server operation by setting `profiles.staff_role` to `sales_advisor`,
`accounting` or `management`. Sales advisors only see assigned customers and
their assigned advisor conversations; accounting and management share full
staff access including promissory notes. Row-level security scopes customer,
ticket, message, payment and receipt access to the linked customer or permitted
staff role. A unique partial index permits one accounting profile. Staff IDs
are generated from role, Istanbul year/month and the transliterated name, such
as `SD202611/ERT`, `M202611/OZL` or `Y202611/BER`; name prefixes extend when
already in use.
Contracts use the database-issued format `S/{YYYY}{six-digit sequence}`,
such as `S/2026000001`. The sequence is atomic and restarts for each contract
year.

The supported staff roster is:

- Sales advisors (`sales_advisor`): Ertuğrul, Levent, Hazal
- Accounting (`accounting`): Özlem
- Management (`management`): Murat, Berkant

Staff IDs are allocated automatically when the profile receives its staff
role. Names are transliterated and IDs are unique, for example `SD202611/ERT`,
`SD202611/LEV`, `SD202611/HAZ`, `M202611/OZL`, `Y202611/MUR` and
`Y202611/BER` for accounts provisioned in November 2026. Once assigned, an ID
stays the same if the employee's name or role changes. The app has staff login
only; staff registration is not available in the customer-facing UI.

Do not expose staff registration in the app. Create each staff account through
the protected `provision-staff-account` Edge Function described below; it
assigns only the employee's fixed role and returns the generated staff ID.

For new customer records, select an advisor in the management customer form.
The database verifies that the selected profile is a sales advisor and
automatically routes open advisor conversations to the assigned advisor,
including when an existing assignment changes. Customers can
sign in without a contract; they see a pending-contract state until an
authorized operator attaches or approves their record. Sales advisors do not
see promissory notes. All staff can organize customers into persistent folders.

## Phone-number usernames

Customer and staff accounts now share the normal sign-in screen. The password
field uses the same boxed style as the other inputs. Known staff username
numbers enable an unrestricted password input silently; customer registration
keeps the six-digit numeric password. The phone hint never grants a role:
permissions still come from the authenticated database profile. Staff passwords
are not stored in app code. New server-provisioned staff passwords must contain
letters and numbers, with 6–128 characters. Rotating the existing staff accounts
is a separate authorized operation once the new passwords are supplied.

Customers create an account with only a Turkish mobile number and a six-digit
password. The number is normalized to `+90XXXXXXXXXX`, so a leading `0`, a
`+90` prefix, spaces and punctuation do not change the username. Registration
uses the `register-phone-account` Edge Function and does not send an SMS. The
Supabase Auth session remains in place behind the scenes because database RLS
uses that session to scope customer data; the service key is only used by the
Edge Function and is never included in the APK.

An unverified username phone is not proof that the person owns a preloaded
contract. New accounts therefore receive a pending customer record and do not
automatically claim an existing contract by phone/name matching. Management
must confirm the person's identity before linking the account to an existing
contract. Keep this restriction unless a separate trusted proof-of-ownership
step is added.

Staff accounts are provisioned through the server-only
`provision-staff-account` Edge Function. It accepts only the six names and
roles in the roster above, marks the Auth phone usable without sending SMS,
sets the profile role and contact number, and lets the database assign the
unique staff ID. Reserve the name/phone/role pairs in the service-only
`staff_account_roster` table. `STAFF_PHONE_ROSTER` remains an optional server
secret override. Provisioning requires either a random
`STAFF_PROVISIONING_SECRET` of at least 32 characters or a short-lived
SHA-256 key hash in the service-only `staff_provisioning_access` table. Remove
temporary access immediately after provisioning. Both Edge Functions use the
roster to reserve employee usernames and reject mismatched requests.
Keep the real phone values and provisioning secret out of this public source
repository and the mobile app.
Password reset by SMS is not available in this release.

## In-app and push notifications

The customer inbox uses `notifications`, and the staff inbox uses
`staff_notifications`. Both subscribe to Supabase Realtime. Messages, receipt
reviews and contract approvals enqueue FCM notifications in `push_outbox`.
Foreground notifications use the `demirturk_updates` Android channel. Tapping
a notification opens its conversation, payments or contracts screen.

Firebase project `demirturk-mobil-4954e` supplies the public Android and web
configuration in `backend_config.dart`. Build defines can override those values.
iOS deployment also requires its own Firebase app registration, APNs key and
Xcode Push Notifications capability. Web push requires a Web Push certificate
and `FIREBASE_WEB_VAPID_KEY`.

Migration `20261122110114_push_delivery_and_payment_reminders.sql` installs the
queue, device registration RPC, restricted worker functions and scheduled jobs.
Payment reminders run daily at 10.00 Europe/Istanbul, selecting each note's
`due_date` for two days before, the due date and two days after. Paid notes and
submitted receipts awaiting review are excluded. Event keys suppress duplicate
reminders. The worker checks payment state again before sending.

The migration creates `portal_push_endpoint` and `portal_push_webhook_secret`
in Supabase Vault. Store the FCM sender service-account JSON in the separate
Vault secret `portal_fcm_service_account`. Use the Firebase Cloud Messaging API
Admin role on the Firebase project for this service account. Private credentials
belong in Vault and are accessed through a service-role-only function.

The live Android sender was configured and validated on 2026-11-22 using
`demirturk-push-sender@demirturk-mobil-4954e.iam.gserviceaccount.com` with that
FCM-only role. Its uploaded certificate expires on 2028-11-22; rotate the key
and update the Vault secret before then. The live worker and FCM validation
requests both returned HTTP 200. Delivery to a physical device still requires
installing V14, signing in, granting notification permission and a delivery test.

Deploy `supabase/functions/send-push/index.ts` as `send-push`, with JWT checking
disabled because the worker authenticates its webhook secret in its function
body. Supabase supplies its server key to the worker. Database inserts wake the
worker through pg_net, and a cron job retries pending work every minute. A lease
protects concurrent claims, successful device deliveries are recorded separately,
and notifications expire after 24 hours. Transient failures use backoff and
invalid device tokens are removed.

## Local build configuration

```powershell
flutter run `
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY `
  --dart-define=FIREBASE_APP_ID=YOUR_PLATFORM_APP_ID `
  --dart-define=FIREBASE_SENDER_ID=YOUR_SENDER_ID `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID `
  --dart-define=FIREBASE_IOS_BUNDLE_ID=YOUR_IOS_BUNDLE_ID `
  --dart-define=FIREBASE_WEB_VAPID_KEY=YOUR_WEB_PUSH_VAPID_KEY
```

The configured Supabase project URL and publishable key are public client
configuration; RLS remains the authorization boundary. Override them with
`--dart-define=SUPABASE_URL=...` and
`--dart-define=SUPABASE_PUBLISHABLE_KEY=...` for another deployment. There is
no demo login or demo customer data; portal access requires a real Supabase
session.

## Persistence and chat behavior

Customer support chats use Supabase tables and Realtime, so messages are saved
before being sent and appear live on connected devices. Advisor/finance chats
stay until explicitly deleted. Ending a general company chat hides it from the
customer and preserves it for staff in the dated closed-chat archive. Theme
preferences are stored per account. Uploaded receipt files stay in private
Storage until explicitly deleted.

## Branches and automated store delivery

The CRM financial integration is prepared in source and isolated tests;
live deployment is pending. See [CRM finance setup](docs/crm-finance.md).

Use `development` for ongoing work and `stable` for releases. Tested changes
merged into `stable` start signed Android/iOS builds and store submission.
Store credentials and complete app records are required before delivery can
succeed. See [store release setup](docs/store-releases.md) for the exact status,
secret names, TestFlight/internal testing and production behavior.

## Current integration status

The app contains Supabase client initialization, customer and
admin data repositories, customer project/notes views, payment submission and
review, receipt upload, persistent preferences, support messaging, and push
device registration. Staff accounts and `profiles.staff_role` values are
provisioned in Supabase; selecting a staff role in the app never grants access.
Phone numbers are login identifiers without SMS verification. Contract access
is linked by authorized staff after an independent identity check; matching a
phone number alone does not grant access to an existing contract.

The configured Supabase URL and publishable key reach the live project. Its
folder, contract-document, notification and push queue migrations have been
applied. The Android Firebase sender, worker and scheduled reminders are
configured as described above. iOS/APNs and web VAPID setup remain separate
platform-specific work. Passing server validation does not replace a physical
device notification test or release-signing checks before distribution.
