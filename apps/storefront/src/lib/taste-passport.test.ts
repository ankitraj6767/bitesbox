import { describe, expect, it } from "vitest";
import { isTasteSetup, buildSaveTasteProfileArgs } from "./taste-passport";
import { tasteReasonLabel } from "./site";

describe("Taste Passport editing", () => {
  it("normalizes the customer choices into the owner-scoped RPC contract", () => {
    expect(
      buildSaveTasteProfileArgs({
        foodTypes: ["VEG", "VEG"],
        maxSpice: "MILD",
        categoryIds: ["category-b", "category-a", "category-b"],
        priceCeiling: "250",
      }),
    ).toEqual({
      p_food_types: ["VEG"],
      p_max_spice: "MILD",
      p_category_ids: ["category-a", "category-b"],
      p_price_ceiling: 250,
    });
  });

  it("sends an empty constraint set as optional values", () => {
    expect(
      buildSaveTasteProfileArgs({
        foodTypes: [],
        maxSpice: "ANY",
        categoryIds: [],
        priceCeiling: "",
      }),
    ).toEqual({ p_food_types: [], p_category_ids: [] });
  });

  it("rejects unsupported food, spice, category count and price values", () => {
    expect(() =>
      buildSaveTasteProfileArgs({
        foodTypes: ["ALLERGY_SAFE"],
        maxSpice: "ANY",
        categoryIds: [],
        priceCeiling: "",
      }),
    ).toThrow();
    expect(() =>
      buildSaveTasteProfileArgs({
        foodTypes: [],
        maxSpice: "EXTREME",
        categoryIds: [],
        priceCeiling: "",
      }),
    ).toThrow();
    expect(() =>
      buildSaveTasteProfileArgs({
        foodTypes: [],
        maxSpice: "ANY",
        categoryIds: Array.from(
          { length: 21 },
          (_, index) => `category-${index}`,
        ),
        priceCeiling: "",
      }),
    ).toThrow();
    expect(() =>
      buildSaveTasteProfileArgs({
        foodTypes: [],
        maxSpice: "ANY",
        categoryIds: [],
        priceCeiling: "0",
      }),
    ).toThrow();
  });
});

describe("Taste Match storefront fallback and labels", () => {
  it("shows setup for an empty profile while the server supplies fallback products", () => {
    expect(isTasteSetup({ taste_state: "SETUP" })).toBe(true);
    expect(isTasteSetup({ taste_state: "MATCHED" })).toBe(false);
    expect(isTasteSetup(null)).toBe(false);
  });

  it("localizes stable reason codes", () => {
    expect(tasteReasonLabel("MILD_SPICE", "en")).toBe("Mild spice");
    expect(tasteReasonLabel("MILD_SPICE", "hi")).toBe("हल्का तीखापन");
    expect(tasteReasonLabel("UNKNOWN", "en")).toBe(
      "Matches your taste profile",
    );
  });
});
