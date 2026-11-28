# e-Demirtürk financial integration

Status: **code and isolated tests only; not deployed to either live project**.
The user explicitly deferred connecting the CRM Supabase project. Current live
accounts and financial records have not been changed by this implementation.

## Ownership and data flow

e-Demirtürk is the financial source of truth. Its document templates, styling,
internal notes, full identity numbers and addresses are not imported. The mobile
app keeps its existing appearance and receives an allowlisted financial DTO:
contract total, actual collected amount, remaining balance, planned deposit and
down payments, actual prepayments, refunds, installments, partial payments,
payment dates, methods, receipt numbers and source timestamp.

A finance-authorized operator checks the customer's identity and approved
contract, then uses **CRM ödeme eşleştirmesi** to select up to ten CRM plans for
that customer. One CRM plan cannot be assigned to a second customer, including
after unlinking. Correcting ownership requires a separately audited data repair;
the ordinary UI cannot silently move financial history. No phone/name match
automatically grants a new app account access to an existing contract.

`mobile-finance-export` runs in the CRM project. Its company scope comes only
from server configuration. A dedicated bridge key permits only this export API;
the CRM service-role key stays inside the CRM project. The mobile project's
`crm-finance` function validates the current user through Supabase Auth, reads
the approved mapping under RLS, fetches the export, validates the entire result
and imports it in one database transaction. Client-provided plan IDs cannot
override a customer's existing mapping during refresh.

The mobile app displays `customer_finance_snapshots` and canonical imported
`promissory_notes`. Existing non-CRM customer payment flows remain available.
Activating a CRM mapping hides legacy notes for that customer to prevent double
counting. Unlinking archives imported notes without deleting receipts/history;
legacy notes become visible again. Session clearing also clears finance caches.

## Preparing CRM records

In the CRM accounting screen, select the relevant plan when creating a
collection. Installment collections also require a specific note. Use **Senede
bağla** to allocate older, unlinked collections. Several receipts can pay one
note partially; a collected allocation cannot later be silently reassigned.

Only `COLLECTED` entries count as received money. Planned down payments and
deposits are not proof of collection. Refunded and pending entries do not
increase paid totals. A full settlement closes the plan only when actual
collected money equals the complete contract amount.

Unallocated collected entries matching a plan issuer's name block publication
until accounting allocates them. This name comparison only detects incomplete
records; it never establishes ownership. Historical entries with different or
incomplete customer names must be reconciled by accounting during onboarding.
The integration cannot infer missing relationships or certify source records.
Unbalanced plans, duplicate records, overpayments and unknown note references
are rejected; they do not overwrite the last validated snapshot.

## Configuration before deployment

Prepare both projects, preserving their existing security settings:

1. CRM: apply `20261127135910_mobile_finance_export.sql` on the current CRM
   backend branch, which already includes the saved-note archive migration.
2. CRM: deploy **only** `mobile-finance-export` with JWT gateway verification
   disabled. Its handler requires the dedicated bridge key. The protected Meta
   configuration is unchanged; do not replace the whole CRM config or enable
   unrelated Meta functions.
3. Set CRM server secrets `CRM_MOBILE_COMPANY` (exact company name) and
   `CRM_MOBILE_BRIDGE_KEY` (random key of at least 32 characters).
4. Mobile: apply `20261127135910_crm_finance_bridge.sql` after the portal's
   existing migrations. Deploy `crm-finance` with user JWT verification enabled
   and `crm-finance-worker` with its own handler-authenticated secret.
5. Set mobile server secrets `CRM_FINANCE_EXPORT_URL` (the CRM function URL),
   the same `CRM_MOBILE_BRIDGE_KEY`, and a **different** random
   `CRM_FINANCE_WORKER_SECRET` of at least 32 characters. None belong in Flutter
   build defines, the APK, a public repository or workflow logs.
6. Store the worker endpoint and its worker secret in Supabase Vault as
   `crm_finance_worker_url` and `crm_finance_worker_secret`. After reconciling
   source records, run `supabase/rollout/enable-crm-finance-sync.sql` to activate
   the per-minute job. This rollout file is deliberately not an automatic
   migration. The existing pg_cron/pg_net setup is required.

The scheduled worker refreshes up to 20 due customers per minute with at most
five parallel requests and a 45-second claim lease. Failed records do not
monopolize later batches. Larger installations may require a higher throughput
after measuring the CRM API. The app also refreshes the visible customer's
data; a 30-second cache suppresses duplicate reads. Scheduling must be enabled
before relying on imported payment state for unattended payment reminders.

Customer ID, mapping version and source timestamp checks reject stale responses
and in-flight results from an old mapping. Refresh failure preserves validated
data and shows its timestamp. Network reads have a 12-second timeout and a
2 MB response cap. No receipt approval in the app can independently mark a
CRM-controlled note paid: accounting must record the collection in e-Demirtürk.
Receipt upload and review/rejection remain available in the portal.

## Verification

Mobile: `flutter analyze --no-fatal-infos`, `flutter test`, then
`npm ci --ignore-scripts --prefix verification/backend` and
`npm test --prefix verification/backend`. GitHub application checks also run
the backend suite and Deno type checks against the committed dependency lock.

CRM: run the existing unit suite and Meta protection checks, plus
`npm ci --ignore-scripts --prefix verification/crm` and
`node verification/crm/mobile-finance.mjs`. `tests/mobile-finance.test.ts`
covers the money calculations and export authentication contract.

SQL tests use PGlite with synthetic records, not production data. They check
roles, RLS, cross-customer isolation, canonical note filtering, repeat imports,
late responses, changed mappings and historical ownership. They do not replace
a live two-project smoke test, a multi-session concurrency test or a device
notification test after deployment.
