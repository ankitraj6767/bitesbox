# Delivery flow

## Onboarding

`rider_onboarding_status` describes a progression, and each step now has exactly
one owner:

```
PENDING ──submit_rider_document──► DOCUMENTS_SUBMITTED
        ──review_rider_document──► VERIFIED
              ──approve_rider────► ACTIVE ──suspend_rider──► SUSPENDED
```

Which documents are required is configuration, not code:

```json
settings['rider.required_documents'] = ["DRIVING_LICENCE", "AADHAAR", "PROFILE_PHOTO"]
```

A bicycle rider has no vehicle RC, and what an outlet insists on changes with
local rules, so `app.required_rider_documents()` reads the setting.

| Function | Who | Does |
| --- | --- | --- |
| `my_rider_onboarding()` | the rider | Checklist: submitted, approved, outstanding |
| `submit_rider_document(type, path, number, issued_on, expires_on)` | the rider | Uploads one document; advances to `DOCUMENTS_SUBMITTED` once all required ones are in |
| `review_rider_document(id, approve, reason)` | staff | Approves or rejects; all approved ⇒ `VERIFIED` |
| `approve_rider(id)` | ADMIN / OWNER | `VERIFIED → ACTIVE` and mints the partner code |
| `suspend_rider(id, reason, until)` | ADMIN / OWNER | `ACTIVE → SUSPENDED` |

A rejection must carry a reason. There is no way to reject a licence and leave
the rider staring at a red mark with nothing to fix.

`approve_rider` is where `partner_code` comes from — `app.next_partner_code`
builds `BB-BKP01-001` from the prefix setting, the branch code and a per-branch
sequence, with a bounded retry because soft-deleted rows make a naive count
collide. It appears on COD settlement sheets and kitchen tickets, so it has to be
short, unambiguous and never reused.

MANAGER cannot approve or suspend a rider. `rider.approve` and `rider.suspend`
sit with ADMIN and OWNER only — activating a rider is granting someone the right
to carry cash.

### Profile

`delivery_partners` has no self-update RLS policy. Riders and staff are both
`authenticated`, so a column grant cannot separate them. Instead
`update_my_rider_profile()` accepts exactly the fields a rider owns: phones,
alternate contact, emergency contact, UPI id, vehicle model.

Suite `070` asserts that a rider's direct `update delivery_partners set
onboarding_status = 'ACTIVE', cash_in_hand = 0` **matches zero rows** and leaves
status, cash owed, rating and order limit unchanged. No policy means no rows, not
an error — so the test asserts the values, not an exception.

## Duty

```
OFFLINE ⇄ AVAILABLE ⇄ BUSY
        └► ON_BREAK
```

`set_duty_state(state, lat, lng, battery, reason)` writes
`delivery_partners.duty_state` and appends to `delivery_partner_availability`,
which is append-only and fills `duration_seconds` on the previous row when the
next transition arrives. That is the shift record.

Going `OFFLINE` with live deliveries raises `ACTIVE_DELIVERIES_PENDING`. A rider
cannot clock out holding someone's dinner.

## Dispatch

`available_riders(branch_id, order_id)` ranks candidates with one deterministic
score. Lower is better:

```
active_load × 100                      load dominates everything
+ distance_to_store_km × 10            (15 km assumed if no fix)
+ (5 − rating_average) × 5
+ 50 if duty_state <> 'AVAILABLE'
```

Filtered to `ACTIVE`, not deleted, same branch, `AVAILABLE` or `BUSY`, and under
`max_concurrent_orders`. Manual dispatch consumes this list; automatic dispatch
reuses the identical score, so the two can never disagree about who the best
rider is.

`assign_rider(order_id, partner_id, mode, offer_ttl_seconds)` requires
`delivery.assign` on the order's branch and refuses:

```
NOT_A_DELIVERY_ORDER      self-pickup
ORDER_NOT_ASSIGNABLE      order no longer active
RIDER_NOT_FOUND
RIDER_NOT_ACTIVE          still in onboarding
RIDER_WRONG_BRANCH        belongs to another outlet
RIDER_AT_CAPACITY         already at max_concurrent_orders
ORDER_ALREADY_PICKED_UP   cannot reassign what has left the store
```

Reassigning to the same rider returns `changed: false`. Reassigning to a
different one cancels the live assignment, increments `attempt_number` and writes
a `RIDER_REASSIGN` audit entry. `delivery_assignments_active_order_key` is a
partial unique index over the live statuses, so two live assignments for one
order cannot exist even under a race.

Manual dispatch lands `ACCEPTED` — a human decided. `AUTO` mode lands `OFFERED`
with `expires_at`, and `respond_to_assignment` accepts or declines.
`job_expire_assignments` sweeps unanswered offers back to dispatch every minute.

### Payout

`app.tg_assignment_payout`, a BEFORE INSERT trigger, computes
`base_payout + distance_payout + surge_payout` from `delivery_payout_config`:

```
base_payout    flat per trip                       default ₹20
distance_payout max(0, distance − free_km) × per_km_payout
surge_payout   peak_bonus when app.in_peak_window()
```

A trigger rather than logic inside `assign_rider`, so every future writer of an
assignment row gets it too. `total_payout` is always the sum of its parts — suite
`040` asserts that equality rather than trusting whatever the caller passed.

## The trip

```
ACCEPTED ──rider_arrived_at_store──► AT_STORE
         ──verify_pickup(code)─────► PICKED_UP   → order OUT_FOR_DELIVERY
         ──rider_arrived_at_customer► AT_CUSTOMER
         ──complete_delivery(otp)──► COMPLETED   → order DELIVERED
         └─fail_delivery(reason)───► FAILED      → order DELIVERY_FAILED
```

### A rider holds no permissions

The `DELIVERY_PARTNER` role has zero rows in `role_permissions`. Suite `040`
asserts that count is zero.

Authority comes from `app.is_assigned_rider(order_id, user_id)` — being the
partner on the live assignment for *that* order. `delivery.view` /
`delivery.pickup` / `delivery.complete` on the role would have granted it against
every order at the branch, which leaked the rider roster to riders, let one rider
read another's assignments, and let one rider complete another's delivery.

Suite `040` runs the entire rider flow with no permissions and asserts that
`rider_amit` calling `complete_delivery` on Rahul's assignment gets
`PERMISSION_DENIED`.

### Pickup verification

Two codes, both stored only as `hash_code(code, salt)` — the plaintext exists on
the kitchen ticket and in the customer's app, never in a column.

`verify_pickup(assignment_id, code)` checks `verification_codes` where
`purpose = 'PICKUP_CODE'`, unconsumed and unexpired. Wrong code increments
`attempts` and raises `PICKUP_CODE_INVALID` with `attempts_left`. Two limits
apply: `max_attempts` on the code row, and
`app.consume_rate_limit('pickup_code', assignment_id, 6, 600, 300)` — six tries
per ten minutes then a five-minute lockout. Both raise `TOO_MANY_ATTEMPTS`.

On success the code is consumed, so it cannot be replayed, and the order moves
`PICKED_UP` then immediately `OUT_FOR_DELIVERY` so the customer sees motion
rather than a screen that has stopped.

The response returns the destination, contact and `cod_amount`. The rider gets the
customer's address at pickup, not before.

Requirement can be turned off per deployment via
`delivery.require_pickup_verification`.

### Delivery verification

The customer's delivery OTP is issued **at pickup**, not at placement. A customer
cannot be handed a code for food that has not left the kitchen.

`complete_delivery(assignment_id, otp, cash_collected, proof_photo_path, note,
manager_override)`:

```
DELIVERY_OTP_REQUIRED     no OTP supplied
DELIVERY_OTP_UNAVAILABLE  none live for this order
DELIVERY_OTP_INVALID      wrong; attempts_left returned
TOO_MANY_ATTEMPTS         6 per 15 min, then 10 min lockout
DELIVERY_NOT_IN_PROGRESS  not PICKED_UP or AT_CUSTOMER
OVERRIDE_NOT_PERMITTED    override without delivery.override
COD_AMOUNT_MISMATCH       cash short of payable_amount
```

`manager_override` exists for the dead phone and the lost OTP. It requires
`delivery.override` on the branch, sets
`orders.delivery_verification_method` accordingly, and is audited. Suite `040`
asserts a rider cannot grant it to themselves.

Completing twice returns `changed: false` and posts **one**
`delivery_earnings` row. `delivery_earnings (assignment_id, entry_type)` is
uniquely indexed, so a repeat cannot pay twice. The suite asserts the earnings
count stays at 1.

`fail_delivery(assignment_id, reason, note)` is the honest ending: customer not
reachable, address wrong, refused. It raises the refund rather than leaving money
in limbo.

## Live tracking

Two tables, deliberately:

```
delivery_partner_locations   ONE row per rider, updated in place (primary key
                             is delivery_partner_id). What the customer app
                             subscribes to. No row-per-second growth.

delivery_location_events     Append-only breadcrumb trail, one sample per
                             delivery.location_sample_seconds (default 20),
                             written only during an active trip. Dispute
                             evidence and distance auditing.
```

`publish_rider_location(lat, lng, accuracy, heading, speed, battery, is_moving)`:

1. Picks the most advanced live assignment (`AT_CUSTOMER` > `PICKED_UP` >
   `AT_STORE` > `ACCEPTED`) to decide the destination — branch before pickup,
   customer after.
2. Computes `haversine_km` and an ETA at `max(speed, 8)` kmph, defaulting to 18
   when the device reports nothing. A realistic urban average beats a null on the
   customer's screen.
3. Upserts the single location row.
4. Appends a breadcrumb only if the last one is older than the sample interval.
5. Fires `RIDER_NEARBY` once inside `delivery.nearby_radius_km` (default 0.5),
   deduplicated by `rider_nearby:{order_id}`.
6. Returns `should_keep_publishing`, so the app stops burning GPS when there is
   nothing to track.

A customer calling it gets `NOT_A_DELIVERY_PARTNER`. The suite asserts that.

When the trip ends, `order_id` on the location row is cleared — the suite asserts
tracking is detached, so a customer cannot keep watching a rider after their food
has arrived.

### On the client

`RiderLocationPublisher` (`delivery_providers.dart`) streams
`LocationAccuracy.high` with `distanceFilter: 40` and its own 8-second minimum
interval, so a stationary rider at a traffic light does not spam the RPC. Each
successful publish also writes `riderLastFixProvider`, which is what the rider's
own map renders from.

`LiveMap` (`shared/widgets/live_map.dart`) renders a real `GoogleMap` when
`Env.mapsEnabled`, and a `_MapFallback` panel with an "Open in maps" hand-off when
no API key is configured. So a build without a Maps key still ships something
useful instead of a grey box.

The route line is a straight dashed polyline, not a Directions API path. Fetching
a route per GPS fix would cost a call every few seconds for a decoration riders do
not navigate by — they use Google Maps for that, which is what the hand-off button
opens.

Marker positions are not interpolated between fixes. A smoothly gliding marker
that is a guess is worse than a stepping one that is true.

Customer side: `order_tracking_screen.dart` shows `_RiderMap` only when
`order.rider!.liveLocation?.isFresh`. A stale fix shows no map rather than a rider
frozen where they were ten minutes ago.

## Earnings

`delivery_earnings` is an append-only ledger. Balances are always derived, never
stored as a mutable number.

```
DELIVERY_PAYOUT  DISTANCE_BONUS  SURGE_BONUS  TIP
INCENTIVE        PENALTY         ADJUSTMENT   CASH_SHORTFALL
```

`my_earnings(from, to)` is the rider's own view — today, this week, per-trip
breakdown. `post_delivery_earning(partner_id, type, amount, description)` is the
staff path for incentives, penalties and adjustments, and requires a permission.

`cash_in_hand` on `delivery_partners` tracks COD not yet handed over. It goes up
at collection and down at `settle_cod` — see
[payment-flow.md](payment-flow.md#cod).

## Serviceability

`check_serviceability(lat, lng, branch_id)` returns `serviceable`, `reason_code`,
`zone_name`, the fee and the distance. Zones are polygons with per-zone minimum
order and fee; the answer is computed server-side and re-checked at placement, so
a customer cannot pin an address outside the zone and get it delivered anyway.

## Scheduled repair

| Job | Cadence | Does |
| --- | --- | --- |
| `job_expire_assignments` | minute | Expires an unanswered offer, returns the order to dispatch |
| `job_detect_delays` | minute | Flags `is_delayed`, alerts the customer |

## Rider app

`apps/mobile/lib/features/delivery/screens/`:

| Screen | Contents |
| --- | --- |
| `rider_shell.dart` | `RiderScaffold`, `DutyStatePill`, `RiderPrimaryButton`, `RiderStat`, `RiderWaypoint`, `riderNavigate()`, `showRiderReasonSheet()` |
| `rider_home_screen.dart` | Duty toggle, today's stats, active and offered deliveries |
| `rider_delivery_screen.dart` | One trip: waypoints, `_RouteMap`, pickup code entry, OTP entry, COD collection, proof photo, fail-delivery |
| `rider_earnings_screen.dart` | Ledger by day and trip, cash in hand |
| `rider_profile_screen.dart` | Onboarding checklist, editable contact fields, vehicle, sign out |

## Tested

`supabase/tests/040_delivery_flow.test.sql` walks one order from
`READY_FOR_PICKUP` to `DELIVERED` as the real actors and asserts:

- dispatching a rider still in onboarding raises `RIDER_NOT_ACTIVE`
- OPERATIONS can dispatch an active rider; manual dispatch starts `ACCEPTED`
- `total_payout = base + distance + surge`
- `DELIVERY_PARTNER` holds zero permissions, and the whole flow still works
- a wrong pickup code raises `PICKUP_CODE_INVALID`; the right one releases the
  order to `OUT_FOR_DELIVERY` and consumes the code
- pickup issues exactly one live delivery OTP
- going `OFFLINE` mid-delivery raises `ACTIVE_DELIVERIES_PENDING`
- completing with no OTP, a wrong OTP, or a self-granted override all fail
- another rider completing this delivery raises `PERMISSION_DENIED`
- the right OTP delivers, records `CUSTOMER_OTP`, and posts exactly one payout
- completing twice does not post a second payout
- live tracking is detached once the delivery ends
- a customer calling `publish_rider_location` raises `NOT_A_DELIVERY_PARTNER`

`070_rider_lifecycle.test.sql` asserts the onboarding chain: the checklist, three
outstanding documents, a document needing a real file, an already-expired document
refused, all three submitted advancing to `DOCUMENTS_SUBMITTED`, a rider unable to
approve their own document or activate themselves, a rejection requiring a reason,
activation before verification refused, and a rider's attempted self-promotion
matching zero rows.
