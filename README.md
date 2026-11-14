# Demirtürk Mobil

Flutter customer and administration portal for Android and iOS.

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

The app inbox reads persistent `notifications` rows and subscribes to Supabase
Realtime. Payment receipt submissions/reviews and support chat messages create
database notifications. Each notification creates a durable `push_outbox` row.
The `send-push` Edge Function sends FCM HTTP v1 notifications to registered
Android, iOS and web devices and removes invalid tokens.

Create a Firebase project, register each platform, enable Cloud Messaging and
configure the iOS APNs Authentication Key. In Xcode enable Push Notifications
and Background Modes > Remote notifications. For web, create a Web Push
certificate and set its VAPID key. Supply the public Firebase client config at
build time using `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`,
`FIREBASE_PROJECT_ID`, `FIREBASE_IOS_BUNDLE_ID` and `FIREBASE_WEB_VAPID_KEY`.
Web deployments also need a `firebase-messaging-sw.js` service worker matching
the same Firebase project config; replace its `YOUR_FIREBASE_*` values before
deploying the web build.

Deploy the function and configure the Supabase webhook:

```powershell
supabase secrets set PUSH_WEBHOOK_SECRET=<long-random-secret>
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<service-account-json>'
supabase functions deploy send-push
```

Supabase supplies `SUPABASE_URL` and `SUPABASE_SECRET_KEYS` to the function.
The function reads the platform-managed default secret key server-side and
falls back to the legacy `SUPABASE_SERVICE_ROLE_KEY` only for older projects.
Never paste a secret key into this repository or Flutter configuration.
In Database > Webhooks create an INSERT webhook on `public.push_outbox`, target
the deployed `send-push` function, and add the header
`x-webhook-secret: <same-long-random-secret>`.

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

## Current integration status

The app contains Supabase client initialization, customer and
admin data repositories, customer project/notes views, payment submission and
review, receipt upload, persistent preferences, support messaging, and push
device registration. Staff accounts and `profiles.staff_role` values are
provisioned in Supabase; selecting a staff role in the app never grants access.
A verified customer
phone is linked automatically only when exactly one unlinked contract has that
phone number.

The configured Supabase URL and publishable key reach the live project. The
live schema is incomplete: the `push_outbox`, `customer_folders`,
`staff_notifications`, and `customer_contract_documents` relations are missing.
Apply any unapplied migrations 1 through 9 in order before using the updated
app. Migration 5 adds staff roles, customer
assignment/folders, role scoped access policies, routed direct chats, quick
conversation notifications and staff inbox Realtime. Migration 7 sets the final
year-based contract-number format; migration 8 assigns role-based staff IDs.
Migration 9 creates private per-customer PDF/Word contract storage and private
message attachments.
Existing manager accounts
must be assigned `management` or `accounting` in `profiles.staff_role`; promote
staff only from the trusted Supabase dashboard. Firebase client configuration,
APNs, push-function deployment and webhook, and bank/customer seed data remain
separate setup items. Database push outbox and in-app notifications are
generated by the backend; external push delivery still depends on configuring
Firebase and the Supabase webhook.
