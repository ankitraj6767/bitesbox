import { describe, expect, it } from "vitest";
import { messageForDeliveryZoneDatabaseError } from "./delivery-zone-errors";

describe("delivery zone database errors", () => {
  it("does not incorrectly blame the owner's outlet access for a database authorization error", () => {
    expect(messageForDeliveryZoneDatabaseError("42501")).toBe(
      "The database could not complete the authorization check for this change. Refresh and try again; if it continues, contact support.",
    );
  });

  it("keeps the duplicate-zone message specific", () => {
    expect(messageForDeliveryZoneDatabaseError("23505")).toMatch(
      /already exists/,
    );
  });
});
