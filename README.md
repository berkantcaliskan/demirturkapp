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

After creating each staff login in Supabase Auth, promote it from the SQL
Editor (replace the phone with the Auth user's confirmed phone):

```sql
update public.profiles p
set staff_role = 'sales_advisor' -- accounting | management
from auth.users u
where p.id = u.id and u.phone = '+905xxxxxxxxx';
```

Assign existing customer records to an advisor by setting
`customers.assigned_advisor_id` to that advisor's `profiles.id`. For new
records, select the advisor in the management customer form. Customers can
sign in without a contract; they see a pending-contract state until an
authorized operator attaches or approves their record. Sales advisors do not
see promissory notes. All staff can organize customers into persistent folders.

## Phone authentication

The live project currently has Phone enabled, `phone_autoconfirm=false`, and
Twilio Verify selected. This app checks that setting before customer signup
and does not send an OTP if confirmation would trigger a paid SMS. Do not enable
phone auto-confirm until customer-to-contract linking is changed to a trusted
manual claim flow: automatically trusting an unverified phone could expose a
customer's private contract. The password reset SMS flow is dormant in this
release.

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
