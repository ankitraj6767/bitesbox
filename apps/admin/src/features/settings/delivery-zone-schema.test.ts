import { describe, expect, it } from "vitest";
import { deliveryZoneFormSchema } from "./delivery-zone-schema";

const radiusZone = {
  name: "Bakhtiyarpur Town",
  description: null,
  kind: "RADIUS" as const,
  min_distance_km: 0,
  max_distance_km: 3,
  polygon: null,
  delivery_fee: 20,
  min_order_amount: 99,
  free_delivery_threshold: 349,
  per_km_surcharge: 0,
  surcharge_after_km: null,
  peak_surcharge: 10,
  peak_starts_at: "19:30",
  peak_ends_at: "22:00",
  dynamic_surcharge: 0,
  base_eta_minutes: 25,
  extra_eta_minutes: 0,
  cod_enabled: true,
  max_cod_amount: 2000,
  is_serviceable: true,
  is_active: true,
  priority: 10,
};

describe("delivery zone validation", () => {
  it("accepts an existing radius zone and its live pricing controls", () => {
    expect(deliveryZoneFormSchema.safeParse(radiusZone).success).toBe(true);
  });

  it("rejects overlapping radius bounds that would make the zone ambiguous", () => {
    const result = deliveryZoneFormSchema.safeParse({
      ...radiusZone,
      min_distance_km: 4,
    });
    expect(result.success).toBe(false);
    if (!result.success)
      expect(result.error.issues.map((issue) => issue.message)).toContain(
        "The outer distance must be greater than the inner distance.",
      );
  });

  it("accepts one polygon ring in longitude, latitude order", () => {
    const result = deliveryZoneFormSchema.safeParse({
      ...radiusZone,
      kind: "POLYGON",
      min_distance_km: null,
      max_distance_km: null,
      polygon: [
        [
          [85.51, 25.46],
          [85.54, 25.46],
          [85.53, 25.49],
        ],
      ],
    });
    expect(result.success).toBe(true);
  });

  it("rejects invalid coordinates and polygon holes the serviceability engine cannot evaluate", () => {
    const badCoordinate = deliveryZoneFormSchema.safeParse({
      ...radiusZone,
      kind: "POLYGON",
      min_distance_km: null,
      max_distance_km: null,
      polygon: [
        [
          [185, 25],
          [86, 25],
          [86, 26],
        ],
      ],
    });
    const unsupportedHole = deliveryZoneFormSchema.safeParse({
      ...radiusZone,
      kind: "POLYGON",
      min_distance_km: null,
      max_distance_km: null,
      polygon: [
        [
          [85, 25],
          [86, 25],
          [86, 26],
        ],
        [
          [85.2, 25.2],
          [85.3, 25.2],
          [85.3, 25.3],
        ],
      ],
    });

    expect(badCoordinate.success).toBe(false);
    expect(unsupportedHole.success).toBe(false);
  });

  it("requires the inputs that make optional surcharges take effect", () => {
    expect(
      deliveryZoneFormSchema.safeParse({ ...radiusZone, per_km_surcharge: 5 })
        .success,
    ).toBe(false);
    expect(
      deliveryZoneFormSchema.safeParse({
        ...radiusZone,
        peak_starts_at: null,
        peak_ends_at: null,
      }).success,
    ).toBe(false);
  });
});
