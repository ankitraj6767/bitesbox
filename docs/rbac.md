# Roles and permissions

10 roles, 70 permissions, mapped through `role_permissions`. Nothing in the codebase
branches on a role name to decide whether an action is allowed — it asks whether the
caller holds a permission.

## Why permissions rather than roles

`if (role === 'MANAGER')` scattered across a codebase is unmaintainable and unsafe.
The day the owner wants a shift supervisor who can accept orders but not issue
refunds, every one of those conditions has to be found and revised.

With permissions, that supervisor is a new row in `role_permissions`. No deployment.

There is exactly one place where a role is checked directly:
`public.run_scheduled_jobs` allows `OWNER` as a break-glass alternative to the
service role.

## The roles

| Role | Surface | Holds |
| --- | --- | --- |
| `CUSTOMER` | Mobile customer shell | `menu.view`, `order.create` |
| `DELIVERY_PARTNER` | Mobile rider shell | **nothing** — see below |
| `KITCHEN_STAFF` | Mobile kitchen shell | Queue, accept/reject/prepare/ready, menu availability, inventory |
| `MANAGER` | Kitchen shell + dashboard | Kitchen, orders, riders, refund requests, review moderation, branch status |
| `OPERATIONS` | Dashboard | Live operations, dispatch, orders, riders, refund requests |
| `FINANCE` | Dashboard | Payments, reconciliation, refund approval and rejection, reports |
| `SUPPORT` | Dashboard | Tickets, customers, refund requests — not approval |
| `MARKETING` | Dashboard | Coupons, promotions, campaigns, CMS |
| `ADMIN` | Everything | All but ownership transfer |
| `OWNER` | Everything | Including role assignment |

`roles.rank` prevents sideways escalation: `manage_user_role` refuses to grant a role
at or above the caller's own rank, and `admin-operation` excludes `OWNER` from the
assignable list entirely.

## A rider holds no permissions at all

This is the least obvious decision here, and it was a fix rather than the original
design.

`DELIVERY_PARTNER` used to hold `delivery.view`, `delivery.pickup` and
`delivery.complete`. Those look necessary — a rider does pick up and complete
deliveries. They were not, and granting them opened three holes:

1. `delivery_assignments_read` grants read on any assignment in the branch to a
   holder of `delivery.view`. Every rider could list every other rider's live jobs,
   with the customer's name, phone number and address on the joined order.
2. `available_riders` treated `delivery.view` as sufficient, so a rider could pull
   the full roster: colleagues' names, numbers and live proximity.
3. `complete_delivery` lets a holder of `delivery.complete` finish a delivery that
   is not theirs — the deliberate manager override. A rider holding the same
   permission could complete a colleague's delivery.

A rider's authority comes from *being the assigned partner*, checked per order:

```sql
-- app.transition_order
elsif v_transition.rider_allowed and v_is_rider then
  v_authorised := true;   -- v_is_rider = app.is_assigned_rider(order_id, actor)
```

and every read they need resolves through `app.is_rider_for_order`, never through
`delivery.view`. Migration `0031` removes the three permissions; suite
`040_delivery_flow` walks a complete delivery with a rider holding none and asserts
that another rider cannot finish it.

Removing them exposed an ordering bug the permission had been masking:
`complete_delivery` sets the assignment to `COMPLETED` *before* transitioning the
order, so by the time `transition_order` asked "is this the assigned rider?" the row
said COMPLETED and the answer was no. Authorisation had been silently falling
through to the permission every rider happened to hold. `app.is_assigned_rider` now
counts the two terminal states a rider writes themselves, which grants no extra
authority because no edge out of `DELIVERED`, `DELIVERY_FAILED` or `COMPLETED` has
`rider_allowed = true`.

## Permission naming

`domain.action`, 70 of them:

```
menu.*      view create update delete price_update availability
order.*     view create accept reject prepare ready cancel note override
delivery.*  view assign pickup complete track override
rider.*     view create update approve suspend
payment.*   view reconcile settings
refund.*    view create approve reject
customer.*  view update block credit
coupon.*    view create update delete
promotion.manage   campaign.manage
cms.*       view update
support.*   view respond close
review.*    view moderate
staff.*     view create update
role.*      assign manage
settings.*  view update      feature_flag.update
analytics.view  report.view  report.export  finance.view
audit.view  branch.manage  kitchen.view  kitchen.operate
notification.send  notification.template
inventory.view  inventory.update
```

A few worth calling out:

- `refund.create` and `refund.approve` are separate, and SUPPORT holds only the
  first. Whoever raises a refund cannot sign it off. Suite `060_refunds` asserts it.
- `rider.approve` and `rider.suspend` sit with ADMIN and OWNER only. A MANAGER can
  maintain a rider (`rider.update`) but not decide whether they may work.
- `delivery.override` is what allows completing a delivery without the customer's
  OTP, and using it writes a `MANUAL_DELIVERY_OVERRIDE` audit entry naming the
  operator.
- `order.override` allows forcing a transition the state machine does not have an
  edge for, and is likewise audited.

## Branch scoping

`user_roles.branch_id` is null for an organisation-wide grant, or a branch for a
scoped one:

```sql
app.has_permission(p_permission, p_branch_id)
  -- a null grant satisfies any branch
  -- a scoped grant satisfies only that branch
```

Every permission check in a branch-aware function passes the branch:

```sql
perform app.require_permission('delivery.assign', v_order.branch_id);
```

With one outlet this is invisible. It is what makes a second outlet a data change.

## Four layers of enforcement

A single check in one place is a single point of failure. The same rule is applied
independently at four levels, and the outer layers exist for clarity rather than
protection.

**1. Navigation** — `visibleNavigation(permissions)` filters the sidebar. Pure
convenience: an operator is never shown a door they cannot open, because that reads
as a broken product. Covered by `src/lib/navigation.test.ts`.

**2. Route** — every dashboard page calls `requirePermission(...)` server-side
before rendering, and redirects to `/no-access`. This one matters: navigating
directly to `/refunds` gets nothing.

**3. RLS** — 158 policies. The boundary that actually holds. A `select * from orders`
returns the caller's own orders, the orders they carry as a rider, or the branch's
orders if they hold `order.view`.

**4. Function** — `app.require_permission` at the top of every privileged RPC.
Belt and braces with RLS, and it produces a clear `PERMISSION_DENIED` with the
required permission in the detail rather than an empty result set.

The Flutter shells add a fifth layer of convenience with the same status: the router
redirect keeps a rider out of `/cart`, and the database independently refuses
anything they try.

## Signup cannot grant privilege

`app.tg_handle_new_user` fires on `auth.users` insert, creates the profile, and
assigns exactly the role marked `is_default` — `CUSTOMER`. Every other role is
granted by an authorised operator through `manage_user_role`, which checks
`role.assign` and the rank comparison, and audits the grant.

There is no code path by which self-signup yields anything but a customer.

## Session

`public.my_session()` returns identity, primary role, every grant, the flat
permission set and the accessible branches in one round trip. The clients cache it
and re-read on every auth transition.

The permission set in the session is for rendering only. Every write re-checks
server-side, so a stale session cannot be used to act.
