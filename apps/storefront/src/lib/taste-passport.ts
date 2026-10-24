export const TASTE_FOOD_TYPES = ["VEG", "NON_VEG", "EGG", "VEGAN"] as const;
export const TASTE_SPICE_LEVELS = [
  "NONE",
  "MILD",
  "MEDIUM",
  "HOT",
  "EXTRA_HOT",
] as const;

export interface TastePassportDraft {
  foodTypes: string[];
  maxSpice: string;
  categoryIds: string[];
  priceCeiling: string;
}

export function buildSaveTasteProfileArgs(draft: TastePassportDraft) {
  const foodTypes = [...new Set(draft.foodTypes)].sort();
  const categoryIds = [...new Set(draft.categoryIds)].sort();
  if (
    foodTypes.some(
      (item) =>
        !TASTE_FOOD_TYPES.includes(item as (typeof TASTE_FOOD_TYPES)[number]),
    )
  ) {
    throw new Error("Choose food types from the menu.");
  }
  if (
    draft.maxSpice !== "ANY" &&
    !TASTE_SPICE_LEVELS.includes(
      draft.maxSpice as (typeof TASTE_SPICE_LEVELS)[number],
    )
  ) {
    throw new Error("Choose a spice level from the menu.");
  }
  if (categoryIds.length > 20) throw new Error("Choose up to 20 categories.");

  const priceText = draft.priceCeiling.trim();
  const price = priceText ? Number(priceText) : null;
  if (
    price !== null &&
    (!Number.isFinite(price) || price < 1 || price > 100_000)
  ) {
    throw new Error("Enter an item price from ₹1 to ₹100,000.");
  }

  return {
    p_food_types: foodTypes,
    ...(draft.maxSpice === "ANY" ? {} : { p_max_spice: draft.maxSpice }),
    p_category_ids: categoryIds,
    ...(price === null ? {} : { p_price_ceiling: price }),
  };
}

export function isTasteSetup(
  section: { taste_state?: unknown } | null | undefined,
) {
  return section?.taste_state === "SETUP";
}
