import { describe, expect, it, vi } from "vitest";
import { tasteMatchOrderRefreshSubscription } from "./taste-match-refresh";

describe("Taste Match refresh", () => {
  it("refreshes for the signed-in customer’s order, favorites and Taste Passport changes", () => {
    const refresh = vi.fn();
    const subscription = tasteMatchOrderRefreshSubscription(
      "customer-1",
      refresh,
    );

    expect(subscription.channelName).toBe("taste-match-updates:customer-1");
    expect(subscription.changes).toEqual([
      {
        event: "UPDATE",
        schema: "public",
        table: "orders",
        filter: "user_id=eq.customer-1",
      },
      {
        event: "*",
        schema: "public",
        table: "customer_favorites",
        filter: "user_id=eq.customer-1",
      },
      {
        event: "*",
        schema: "public",
        table: "customer_taste_profiles",
        filter: "user_id=eq.customer-1",
      },
    ]);
    subscription.onChange();
    expect(refresh).toHaveBeenCalledOnce();
  });
});
