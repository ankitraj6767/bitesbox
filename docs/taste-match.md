# Taste Passport and Taste Match

## Customer behavior

Signed-in customers can optionally save food types, a maximum spice level,
favorite menu categories, and an item-price ceiling on the mobile Profile screen
or storefront Account page. Guest browsing and guest carts are unchanged. The
recommendation rail only appears for a customer when the `taste_match` feature
flag is enabled and the CMS `TASTE_MATCH` section is active.

If the customer has neither saved preferences nor recommendation history, the
rail remains available with a setup prompt and products from existing popular,
curated, or customer-rated menu data. Each tile has a localized reason label.
Selecting a tile opens its normal product detail; the existing cart RPC remains
responsible for current price, modifiers, coupons, and availability.

Taste choices are recommendation filters, not allergy or medical advice. The
copy does not claim that a food type is allergy-safe.

## Data, privacy, and ranking

`customer_taste_profiles` stores the owner row and `customer_taste_categories`
stores its category choices. Both tables have RLS and owner-read policies, and
client writes are revoked. `my_taste_profile()` and
`save_my_taste_profile(...)` derive identity from `auth.uid()` and check the
caller has the customer role. The save RPC accepts only catalog food and spice
enum values, active categories, and a price from ₹1 through ₹100,000.

Recommendations are calculated in Postgres for the authenticated customer and
selected active outlet. Food type, maximum spice, and the current item price are
hard filters. Categories, saved favorites, published positive food reviews,
fulfilled order history, outlet sales, current ratings, and catalog curation
rank the remaining items. The query excludes inactive/deleted products,
categories, and variants, plus items that cannot be ordered at that outlet. For
variant products it uses the cheapest currently orderable variant price; order
snapshot prices are never used. Results have deterministic tie-breaks and at
most three products per category.

The `reason_code` field is a stable API contract localized by both clients:

| Code | English reason |
| --- | --- |
| `FAVORITE_CATEGORY` | From a category you like |
| `SAVED_FAVORITE` | You saved this |
| `POSITIVE_REVIEW` | You rated this highly |
| `ORDERED_BEFORE` | You ordered this before |
| `MILD_SPICE` | Mild spice |
| `FOOD_TYPE_MATCH` | Matches a food type you chose |
| `POPULAR_AT_OUTLET` | Popular at this outlet |
| `POPULAR_MENU_PICK` | Popular on our menu |
| `CURATED_MENU_PICK` | Picked for our menu |
| `CUSTOMER_RATED_MENU_PICK` | Customer-rated dish |
| `TASTE_PROFILE_MATCH` | Matches your taste profile |

No taste preferences, customer identifiers, or recommendation events are added
to storefront analytics. Taste profile updates are published only for Realtime
refresh; RLS limits profile rows to their owner.

## Refresh and rollout

Mobile invalidates the home feed after a profile save, favorite change, review,
or successful order, and listens to owner-scoped favorite/profile and order
updates. Storefront refreshes after its local favorite/profile/outlet/language
actions and listens for the signed-in customer's favorite, profile, and order
changes.

The migration seeds `taste_match` disabled and adds a `requires_auth` CMS section
that stays invisible while the flag is off. Settings can change the flag through
the existing feature-flag controls. The English and Hindi copy is present, but
Hindi food and promotional copy has **not** been human-reviewed in this change;
keep the flag disabled until that review is complete.

After the migrations are applied in a local development database, regenerate the
shared database types with `npm run db:types`. Database lint and SQL coverage are
`npm run db:lint` and `npm run db:test`; this change does not apply migrations to
a hosted project.
