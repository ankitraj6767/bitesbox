# Bites Box vs Swiggy: customer feature review

Reviewed 23 October 2026 against the customer app and Supabase schema in this
repository. Swiggy's product scope is broader than this project: its own business
overview separates food delivery, Instamart groceries, and Dineout reservations and
payments ([Swiggy business overview](https://www.swiggy.com/corporate/our-business/)).

## Feature comparison

| Customer capability | Bites Box today | Swiggy benchmark | Action |
|---|---|---|---|
| Restaurant discovery | One Bites Box menu, outlet hours and serviceability; CMS banners, collections, categories, search suggestions, and menu filters | Search and compare a marketplace of local restaurants | Kept food discovery within Bites Box's single-brand model. A marketplace needs partner onboarding, per-restaurant menus, settlement and dispatch operations. |
| Menu and item selection | Variants, add-ons, dietary tags, availability and special instructions | Restaurant menus with variants and add-ons | Already covered. |
| Cart and checkout | Server-priced cart; coupons, automatic offers, delivery or pickup, scheduling, wallet, loyalty redemption, tips, Razorpay, and pay-at-store | In-app ordering, offers, payment choice and scheduled delivery | Already covered. |
| Order operations | Kitchen acceptance, live status, rider location, notifications, cancellation rules, refunds, support, and reviews | Live ETA, delivery tracking, and order help | Already covered. |
| Repeat purchase | Reorder from order history | Reorder and personalized discovery | Already covered. |
| Group ordering | Added in this release: invite code, shared progress, isolated participant carts, host-controlled merge and checkout | Group ordering ([Swiggy engineering overview](https://blog.swiggy.com/life-at-swiggy/heres-how-swiggy-built-the-group-ordering-feature/)) | Implemented for Bites Box orders. |
| Membership | Wallet and earned loyalty points; no paid subscription | Swiggy One benefits span food, Instamart and dining ([Swiggy user terms](https://www.swiggy.com/terms-and-conditions?is_app=true)) | Not copied as a paid plan: the current app has no cross-vertical service or subscription billing model. |
| Groceries / quick commerce | No consumer grocery catalog, dark stores, or inventory promise | Instamart grocery and household shopping | Not represented as live inventory. This requires a grocery catalog, store inventory, picking, substitutions, and separate delivery SLAs. |
| Dine-in reservations | No seating or booking calendar | Dineout restaurant discovery, booking, offers and bill payment | Requires table inventory, time slots, reservation operations, and venue settlement. |
| Events and gifting | No ticketing or gift fulfillment | Swiggy also surfaces event and gifting experiences | Requires ticket inventory or gift fulfillment and cancellation/refund rules for those products. |

## Changes in this release

- Added an authenticated group-order flow. A host creates a two-hour room and
  shares a high-entropy code. Each participant adds dishes to their own normal
  cart. Only the host can merge participants' lines, and the existing cart RPC
  validates availability, modifiers, and quantities again before checkout.
- Restricted group tables to server functions, enabled RLS, limited invite-code
  disclosure to the host, serialized cart mutations with group merges, and added
  SQL coverage for membership, privacy, host authority, and merge behavior.
- Updated the default storefront palette to a bright orange, slate, and neutral
  surface system inspired by current food-delivery conventions. Existing operator
  color overrides are preserved by the migration.

## Scope boundary

Bites Box is a restaurant operating system for one brand with multiple outlets;
Swiggy is a multi-sided convenience marketplace. Grocery delivery, restaurant
aggregation, dine-in booking, ticketing, and cross-service memberships cannot be
made real by adding screens alone. The current release adds the missing food-order
collaboration flow and improves the food storefront while leaving those distinct
services out of the customer UI until their catalogs and operations exist.
