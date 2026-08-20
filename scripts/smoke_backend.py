#!/usr/bin/env python3
"""
End-to-end smoke test for the Bites Box backend.

Signs in as each seeded role and exercises the real read surfaces and business
functions through PostgREST — so RLS, RBAC and the pricing engine are all on the
path exactly as they are for the apps. No service key is used anywhere.

    python3 scripts/smoke_backend.py
    python3 scripts/smoke_backend.py --url https://<ref>.supabase.co --anon <key>

Exits non-zero on the first failure, which makes it usable in CI.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any

LOCAL_ANON = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9."
    "CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
)

GREEN, RED, YELLOW, DIM, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"

failures: list[str] = []
checks = 0


class ApiError(RuntimeError):
    """A business or transport error returned by the API."""


def request(
    url: str,
    *,
    method: str = "GET",
    token: str | None,
    anon: str,
    body: dict[str, Any] | None = None,
) -> Any:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("apikey", anon)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            raise ApiError(f"HTTP {error.code}: {raw[:200]}") from None

        # Postgres business errors put the stable code in `hint`.
        code = payload.get("hint") or payload.get("error_code") or payload.get("code")
        message = payload.get("message") or payload.get("error_description") or raw[:200]
        raise ApiError(f"{code}: {message}") from None


def sign_in(base: str, anon: str, email: str, password: str) -> str:
    payload = request(
        f"{base}/auth/v1/token?grant_type=password",
        method="POST",
        token=None,
        anon=anon,
        body={"email": email, "password": password},
    )
    token = payload.get("access_token") if isinstance(payload, dict) else None
    if not token:
        raise ApiError(f"no access token returned for {email}")
    return token


def rpc(base: str, anon: str, token: str | None, name: str, args: dict[str, Any] | None = None) -> Any:
    return request(
        f"{base}/rest/v1/rpc/{name}",
        method="POST",
        token=token,
        anon=anon,
        body=args or {},
    )


def check(label: str, fn) -> None:
    """Run one assertion block, recording pass/fail without aborting the suite."""
    global checks
    checks += 1
    try:
        detail = fn()
        print(f"  {GREEN}✓{RESET} {label}" + (f" {DIM}{detail}{RESET}" if detail else ""))
    except AssertionError as error:
        failures.append(f"{label}: {error}")
        print(f"  {RED}✗{RESET} {label} {RED}{error}{RESET}")
    except ApiError as error:
        failures.append(f"{label}: {error}")
        print(f"  {RED}✗{RESET} {label} {RED}{error}{RESET}")


def expect_error(label: str, fn, expected_code: str) -> None:
    """Assert that a call is rejected with a specific business error code."""
    global checks
    checks += 1
    try:
        fn()
    except ApiError as error:
        if expected_code in str(error):
            print(f"  {GREEN}✓{RESET} {label} {DIM}rejected with {expected_code}{RESET}")
            return
        failures.append(f"{label}: expected {expected_code}, got {error}")
        print(f"  {RED}✗{RESET} {label} {RED}expected {expected_code}, got {error}{RESET}")
        return

    failures.append(f"{label}: expected {expected_code} but the call succeeded")
    print(f"  {RED}✗{RESET} {label} {RED}expected {expected_code}, but it succeeded{RESET}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:54321")
    parser.add_argument("--anon", default=LOCAL_ANON)
    args = parser.parse_args()

    base, anon = args.url.rstrip("/"), args.anon

    print(f"\n{YELLOW}Bites Box backend smoke test{RESET}  {DIM}{base}{RESET}")

    # ── Guest surfaces (no session at all) ────────────────────────────────
    print(f"\n{YELLOW}Guest (anonymous){RESET}")

    def guest_config():
        data = rpc(base, anon, None, "app_config")
        assert data["branch"]["name"], "branch name missing"
        assert data["settings"], "no public settings exposed"
        return f"branch={data['branch']['name']} settings={len(data['settings'])} flags={len(data['feature_flags'])}"

    check("app_config readable without signing in", guest_config)

    def guest_menu():
        data = rpc(base, anon, None, "menu_catalog")
        assert len(data["categories"]) >= 10, "expected the seeded categories"
        assert len(data["products"]) >= 30, "expected the seeded products"
        return f"categories={len(data['categories'])} products={len(data['products'])}"

    check("menu browsable before login", guest_menu)

    def guest_search():
        data = rpc(base, anon, None, "search_menu", {"p_query": "biriyani"})
        assert data["count"] > 0, "typo-tolerant search found nothing"
        return f"'biriyani' → {data['count']} results"

    check("search is typo tolerant", guest_search)

    def guest_home():
        data = rpc(base, anon, None, "home_feed")
        kinds = [section["kind"] for section in data["sections"]]
        assert len(kinds) >= 4, f"home feed too sparse: {kinds}"
        return f"{len(kinds)} sections"

    check("home feed composes", guest_home)

    # Guests must not be able to read orders.
    def guest_orders():
        data = request(f"{base}/rest/v1/orders?select=id", token=None, anon=anon)
        assert data == [], f"anonymous user could read {len(data)} orders"
        return "0 rows visible"

    check("orders hidden from anonymous users (RLS)", guest_orders)

    # ── Owner ─────────────────────────────────────────────────────────────
    print(f"\n{YELLOW}Owner{RESET}")
    owner = sign_in(base, anon, "owner@bitesbox.in", "Password123!")

    def owner_session():
        data = rpc(base, anon, owner, "my_session")
        assert data["primary_role"] == "OWNER", data["primary_role"]
        assert len(data["permissions"]) > 50, len(data["permissions"])
        roles = data["roles"]
        assert len(roles) == len({(r["role"], r["branch_id"]) for r in roles}), "duplicate role grants"
        return f"permissions={len(data['permissions'])} roles={len(roles)} branches={len(data['branches'])}"

    check("my_session returns clean role + permission set", owner_session)

    def owner_overview():
        data = rpc(base, anon, owner, "dashboard_overview", {"p_from": "2026-07-01T00:00:00Z"})
        current = data["current"]
        assert current["orders"] >= 9, f"expected the seeded orders, saw {current['orders']}"
        return (
            f"orders={current['orders']} net={current['net_sales']} "
            f"aov={current['average_order_value']} live_ready={data['live']['ready']}"
        )

    check("dashboard_overview", owner_overview)

    def owner_charts():
        data = rpc(
            base, anon, owner, "dashboard_charts",
            {"p_from": "2026-07-01T00:00:00Z", "p_granularity": "day"},
        )
        assert data["top_products"], "no product sales aggregated"
        return f"trend={len(data['revenue_trend'])} top_products={len(data['top_products'])}"

    check("dashboard_charts", owner_charts)

    def owner_ops():
        data = rpc(base, anon, owner, "live_operations")
        columns = {k: len(v) for k, v in (data.get("columns") or {}).items()}
        assert columns, "operations board is empty"
        return f"columns={columns} alerts={len(data['alerts'])} riders={len(data['riders'])}"

    check("live_operations board", owner_ops)

    def owner_tax():
        data = rpc(base, anon, owner, "report_tax_summary", {"p_from": "2026-07-01T00:00:00Z"})
        totals = data["totals"]
        assert float(totals["total_tax"]) > 0, "no GST recorded"
        # CGST and SGST must split the total evenly for intra-state supply.
        assert abs(float(totals["cgst"]) - float(totals["sgst"])) < 0.05, "CGST/SGST split uneven"
        return f"taxable={totals['taxable_amount']} cgst={totals['cgst']} sgst={totals['sgst']}"

    check("GST summary splits CGST/SGST evenly", owner_tax)

    def owner_audit():
        data = rpc(base, anon, owner, "audit_trail", {"p_limit": 5})
        assert isinstance(data, list), "audit trail should be a list"
        return f"{len(data)} entries"

    check("audit_trail readable by owner", owner_audit)

    # ── Serviceability ────────────────────────────────────────────────────
    print(f"\n{YELLOW}Serviceability & pricing{RESET}")

    def zone_a():
        data = rpc(base, anon, owner, "check_serviceability", {"p_latitude": 25.4632, "p_longitude": 85.5252})
        assert data["serviceable"] is True, data
        return f"{data['zone_name']} fee={data['delivery_fee']} eta={data['eta_minutes']}m"

    check("Bakhtiyarpur town is serviceable", zone_a)

    def far_away():
        data = rpc(base, anon, owner, "check_serviceability", {"p_latitude": 25.4780, "p_longitude": 85.7060})
        assert data["serviceable"] is False, data
        assert data["reason_code"] in {"ADDRESS_NOT_SERVICEABLE", "OUTSIDE_MAX_DISTANCE"}, data
        return f"{data['reason_code']} at {round(float(data['distance_km']), 1)} km"

    check("Barh (14 km) is rejected", far_away)

    def free_delivery():
        data = rpc(
            base, anon, owner, "check_serviceability",
            {"p_latitude": 25.4632, "p_longitude": 85.5252, "p_order_amount": 500},
        )
        assert float(data["delivery_fee"]) == 0, data["delivery_fee"]
        return "₹500 order → free delivery"

    check("free-delivery threshold applies", free_delivery)

    # ── Kitchen staff ─────────────────────────────────────────────────────
    print(f"\n{YELLOW}Kitchen staff{RESET}")
    kitchen = sign_in(base, anon, "kitchen1@bitesbox.in", "Password123!")

    def kitchen_session():
        data = rpc(base, anon, kitchen, "my_session")
        assert data["primary_role"] == "KITCHEN_STAFF", data["primary_role"]
        held = set(data["permissions"])
        assert "kitchen.operate" in held
        assert "refund.approve" not in held, "kitchen must not approve refunds"
        assert "settings.update" not in held, "kitchen must not change settings"
        return f"permissions={len(held)}"

    check("kitchen role is correctly scoped", kitchen_session)

    def kitchen_queue():
        data = rpc(base, anon, kitchen, "kitchen_queue")
        counts = data["counts"]
        assert isinstance(counts, dict)
        return f"counts={counts}"

    check("kitchen_queue readable", kitchen_queue)

    expect_error(
        "kitchen cannot read the audit log",
        lambda: rpc(base, anon, kitchen, "audit_trail", {"p_limit": 1}),
        "PERMISSION_DENIED",
    )

    expect_error(
        "kitchen cannot approve a refund",
        lambda: rpc(
            base, anon, kitchen, "approve_refund",
            {"p_refund_id": _any_refund_id(base, anon, owner)},
        ),
        "PERMISSION_DENIED",
    )

    # ── Customer ──────────────────────────────────────────────────────────
    print(f"\n{YELLOW}Customer{RESET}")
    customer = sign_in(base, anon, "aarav.customer@example.com", "Password123!")

    def customer_session():
        data = rpc(base, anon, customer, "my_session")
        assert data["primary_role"] == "CUSTOMER", data["primary_role"]
        held = set(data["permissions"])
        assert held <= {"menu.view", "order.create"}, f"customer has too much: {held}"
        return f"permissions={sorted(held)}"

    check("customer has only ordering permissions", customer_session)

    def customer_orders():
        data = rpc(base, anon, customer, "my_orders", {"p_scope": "ALL"})
        assert data["orders"], "seeded customer should have orders"
        return f"{len(data['orders'])} orders, counts={data['counts']}"

    check("my_orders returns own orders", customer_orders)

    def customer_isolation():
        rows = request(f"{base}/rest/v1/orders?select=id,user_id", token=customer, anon=anon)
        others = [row for row in rows if row["user_id"] != json.loads(
            _decode_jwt_payload(customer))["sub"]]
        assert not others, f"customer saw {len(others)} orders belonging to others"
        return f"{len(rows)} rows, all own"

    check("customer cannot see other customers' orders (RLS)", customer_isolation)

    def customer_cart():
        # Add a dish, then let the server price it. Required modifier groups must
        # be satisfied — the biryani insists on a spice level.
        product = next(
            p for p in rpc(base, anon, customer, "menu_catalog")["products"]
            if p["name"] == "Chicken Dum Biryani"
        )
        detail = rpc(base, anon, customer, "product_detail", {"p_product_id": product["id"]})
        variant = next(v for v in detail["variants"] if v["is_default"])

        required = [g for g in detail["modifier_groups"] if g["is_required"]]
        modifiers = [
            {"modifier_id": group["modifiers"][0]["id"], "quantity": 1}
            for group in required
        ]

        quote = rpc(
            base, anon, customer, "cart_add_item",
            {
                "p_product_id": product["id"],
                "p_variant_id": variant["id"],
                "p_quantity": 2,
                "p_modifiers": modifiers,
                "p_replace_quantity": True,
            },
        )
        totals = quote["totals"]
        line = quote["lines"][0]
        expected_line = (float(line["unit_price"]) + float(line["modifiers_price"])) * 2
        assert abs(float(line["gross_amount"]) - expected_line) < 0.01, (
            f"line total {line['gross_amount']} != {expected_line}"
        )
        assert float(totals["tax_amount"]) > 0, "GST not computed"
        # Inclusive GST: taxable + tax must equal the discounted line value.
        assert abs(
            float(totals["taxable_amount"]) + float(totals["tax_amount"])
            - (float(totals["items_subtotal"]) - float(totals["total_discount"]))
        ) < 0.05, "inclusive GST does not reconcile with the line value"
        return (
            f"2× {variant['name']} → subtotal {totals['items_subtotal']}, "
            f"GST {totals['tax_amount']}, total {totals['grand_total']}"
        )

    check("cart pricing is computed server-side", customer_cart)

    def customer_coupon():
        quote = rpc(base, anon, customer, "apply_coupon", {"p_code": "BIRYANI20"})
        coupon = quote["coupon"]
        assert coupon["valid"] is True, coupon
        assert float(coupon["discount_amount"]) > 0
        assert float(coupon["discount_amount"]) <= 100.01, "max discount cap ignored"
        return f"BIRYANI20 → −{coupon['discount_amount']} (capped at 100)"

    check("coupon validated and capped server-side", customer_coupon)

    expect_error(
        "expired coupon rejected",
        lambda: rpc(base, anon, customer, "apply_coupon", {"p_code": "EXPIRED50"}),
        "COUPON_EXPIRED",
    )

    expect_error(
        "unknown coupon rejected",
        lambda: rpc(base, anon, customer, "apply_coupon", {"p_code": "NOTAREALCODE"}),
        "COUPON_INVALID",
    )

    expect_error(
        "customer cannot accept their own order",
        lambda: rpc(
            base, anon, customer, "accept_order",
            {"p_order_id": rpc(base, anon, customer, "my_orders")["orders"][0]["id"]},
        ),
        "PERMISSION_DENIED",
    )

    expect_error(
        "customer cannot toggle menu availability",
        lambda: rpc(
            base, anon, customer, "set_product_availability",
            {
                "p_product_id": "00000000-0000-0000-0000-000000000000",
                "p_state": "OUT_OF_STOCK",
            },
        ),
        "PERMISSION_DENIED",
    )

    def customer_wallet():
        data = rpc(base, anon, customer, "my_wallet")
        assert "balance" in data
        return f"balance={data['balance']}"

    check("wallet readable by owner of the wallet", customer_wallet)

    # ── Delivery partner ──────────────────────────────────────────────────
    print(f"\n{YELLOW}Delivery partner{RESET}")
    rider = sign_in(base, anon, "rahul.rider@bitesbox.in", "Password123!")

    def rider_deliveries():
        data = rpc(base, anon, rider, "my_deliveries", {"p_include_history": True})
        partner = data["partner"]
        assert partner["onboarding_status"] == "ACTIVE", partner
        return f"{partner['full_name']} active={len(data['active'])} history={len(data['history'])}"

    check("my_deliveries readable", rider_deliveries)

    def rider_earnings():
        data = rpc(base, anon, rider, "my_earnings")
        assert "today" in data and "lifetime" in data
        return f"today={data['today']} lifetime={data['lifetime']} cash={data['cash_in_hand']}"

    check("my_earnings readable", rider_earnings)

    expect_error(
        "rider cannot assign themselves an order",
        lambda: rpc(
            base, anon, rider, "assign_rider",
            {
                "p_order_id": _any_order_id(base, anon, owner),
                "p_delivery_partner_id": rpc(base, anon, rider, "my_deliveries")["partner"]["id"],
            },
        ),
        "PERMISSION_DENIED",
    )

    # ── Support agent ─────────────────────────────────────────────────────
    print(f"\n{YELLOW}Support agent{RESET}")
    support = sign_in(base, anon, "support@bitesbox.in", "Password123!")

    def support_scope():
        data = rpc(base, anon, support, "my_session")
        held = set(data["permissions"])
        assert "support.respond" in held
        assert "refund.create" in held
        assert "refund.approve" not in held, "support must not self-approve refunds"
        assert "settings.update" not in held
        return f"permissions={len(held)}"

    check("support role is correctly scoped", support_scope)

    # ── Finance ───────────────────────────────────────────────────────────
    print(f"\n{YELLOW}Finance{RESET}")
    finance = sign_in(base, anon, "finance@bitesbox.in", "Password123!")

    def finance_payments():
        data = rpc(base, anon, finance, "report_payments", {"p_from": "2026-07-01T00:00:00Z"})
        summary = data["summary"]
        assert summary["captured"] >= 1, summary
        return f"captured={summary['captured']} amount={summary['amount_captured']} unreconciled={summary['unreconciled']}"

    check("finance can read payment reconciliation", finance_payments)

    expect_error(
        "finance cannot change the menu",
        lambda: rpc(
            base, anon, finance, "set_product_availability",
            {
                "p_product_id": "00000000-0000-0000-0000-000000000000",
                "p_state": "OUT_OF_STOCK",
            },
        ),
        "PERMISSION_DENIED",
    )

    # ── Summary ───────────────────────────────────────────────────────────
    print()
    if failures:
        print(f"{RED}✗ {len(failures)} of {checks} checks failed{RESET}")
        for failure in failures:
            print(f"  {RED}·{RESET} {failure}")
        return 1

    print(f"{GREEN}✓ all {checks} checks passed{RESET}\n")
    return 0


def _any_refund_id(base: str, anon: str, token: str) -> str:
    """A real refund id, fetched as a privileged user, for authz probes."""
    rows = request(f"{base}/rest/v1/refunds?select=id&limit=1", token=token, anon=anon)
    assert rows, "seed should contain at least one refund"
    return rows[0]["id"]


def _any_order_id(base: str, anon: str, token: str) -> str:
    rows = request(f"{base}/rest/v1/orders?select=id&limit=1", token=token, anon=anon)
    assert rows, "seed should contain at least one order"
    return rows[0]["id"]


def _decode_jwt_payload(token: str) -> str:
    """Base64url-decode the JWT payload segment (no signature verification)."""
    import base64

    segment = token.split(".")[1]
    padding = "=" * (-len(segment) % 4)
    return base64.urlsafe_b64decode(segment + padding).decode()


if __name__ == "__main__":
    sys.exit(main())
