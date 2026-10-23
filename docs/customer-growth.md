# Customer growth features

This release adds referrals, saved favorites, Hindi content support, a public web
storefront, and customer/operator outlet selection. It stays within the existing
single-brand Bites Box model. The database and existing Edge Functions remain the
source of truth for price, discounts, tax, serviceability, payment, wallet entries,
order state, and branch access.

## Referral program

Migration `20261023092506_customer_growth_localization_outlets.sql` assigns
non-guessable customer codes and adds referral attribution, reward settings, audit
events, and the `referral.manage` permission. The program settings and the
independent `referrals` feature flag both start disabled. The migration contains
no offer amount, minimum spend, cap, or expiry selected as a business promise.

Before an owner enables the feature:

1. Confirm the actual customer and finance terms with the business owner. Do not
   derive values from test fixtures or example copy.
2. Have an OWNER or ADMIN with AAL2 configure both rewards, the minimum eligible
   order, the per-inviter cap, expiry policy, and program enabled state in Admin →
   Referrals.
3. Enable the separate `referrals` feature flag only after the terms are approved.
   Settings alone cannot turn on customer attribution.
4. Run a test invitation in a non-production project and verify attribution,
   qualification, wallet idempotency, refund reversal, audit activity, and branch
   scope before expanding the rollout.

The server accepts one attribution per customer, refuses self-referrals, and only
allows attribution before the first eligible paid and delivered order. Qualification
requires a completed/delivered order with captured payment, no refund, and the
configured minimum order total. COD and split COD wait for settlement. Wallet
credits use the existing append-only ledger and deterministic idempotency keys.
Any completed partial or full refund reverses available referral value. The
forward-only migration `20261023101500_preserve_wallet_refund_on_referral_reversal.sql`
keeps wallet credit issued for that same refund intact and records any unrecovered
reward shortfall for operators.

The program currently makes referrals and rewards visible in the customer and
admin surfaces. Reward credits enqueue a localized transactional notice through
the existing notification queue (`20261023114000` and `20261023114100`). It uses
the profile language with English fallback, respects push opt-out, and preserves
the in-app account notice. It does not advertise or upsell; any future promotional
referral campaign must separately honor marketing consent and every channel
preference.

## Hindi content and language preference

Flutter uses generated English/Hindi resources under
`apps/mobile/lib/l10n/`. Signed-in language preference is stored in
`profiles.preferred_language` and synchronized into the session. The storefront
reads that preference for signed-in customers and a first-party locale cookie for
guests. Database-managed Hindi menu, add-on, offer, and CMS copy is optional and
falls back to the canonical English text until an authorized editor supplies
human-reviewed Hindi. Do not machine-translate food, allergen, or promotional
claims.

Authorized menu and CMS editors can save translations through the permissioned
`save_menu_translations` RPC. Every edit is subject to the existing audit and
branch rules. Keep English and Hindi product claims aligned, and review layouts
with large text scaling before release. This source release does not certify a
human translation review or a physical-device Devanagari layout check. Several
legacy Flutter address, support, wallet, group-order, and order-tracking screens
still contain hard-coded English; finish extracting those strings before claiming
complete Hindi coverage.

## Storefront setup

The customer site lives in `apps/storefront` on port 3001 and is a separate Next.js
application from the privileged admin console. Local setup uses the root npm
workspace install and these public configuration values:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY   # Supabase publishable/anon key only
NEXT_PUBLIC_SITE_URL            # canonical URL for this environment
```

The publishable key is safe for browser use because all authorization remains in
Supabase Auth, RLS, and RPC checks. Never put a service-role key, Razorpay secret,
webhook secret, or notification provider credential in a `NEXT_PUBLIC_*` variable.
Guest carts use browser storage partitioned by outlet. Checkout moves through the
existing server-priced cart, order, create-payment, verify-payment, and webhook
contracts. Customer order routes are private and marked `noindex`; the sitemap is
generated dynamically from active public menu data.

After phone verification, a customer can explicitly import saved guest items.
`20261023113000_idempotent_guest_cart_import.sql` binds each import request to the
authenticated account, outlet, payload hash, and retry key. The database calls
the existing cart mutation RPC for every line, so product/modifier/availability
and current pricing are revalidated. A retry returns the recorded result instead
of adding the items twice; reusing a key with changed contents is rejected.

Preview and production deployment are intentionally separate release steps. Set
the URL/key/site URL per environment, verify a preview with test credentials, and
follow [deployment.md](deployment.md) for review gates. No storefront deployment
or DNS change is part of this source release.

## Favorites and outlet selection

`customer_favorites` is keyed by authenticated customer and product. RLS blocks
cross-customer reads and writes; the RPC also avoids duplicate toggles. Favorites
remain saved while an outlet changes, but each read reports current activity and
availability for the selected outlet. Adding a saved dish to a cart uses the
current menu and server cart validation again.

The public outlet list includes active outlets only. The mobile app checks saved
address serviceability when available; the storefront checks a signed-in default
address before persisting an outlet switch. Guests select among active public
outlets. Carts are isolated by outlet, so changing outlets does not silently move
cart lines. In Admin, the active branch cookie is accepted only when its ID is in
the authenticated session's branch list; the database still enforces branch scope
for each request.

The storefront analytics RPC accepts an allow-list of event names and stores only
event, branch, product, and time identifiers. It does not accept address, phone,
email, payment payload, or visitor fingerprint data. Metrics are aggregate and
staff-only.

## Forward recovery

There is no down migration. If the rollout is paused, turn off the `referrals`
feature flag and stop the storefront release while preserving attribution and
wallet history. Correct schema behavior only with a reviewed forward migration;
never edit a migration already applied to an environment or write wallet balances
directly.
