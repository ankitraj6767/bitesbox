import { describe, expect, it } from "vitest";
import {
  branchHolidaySchema,
  branchHoursSchema,
  branchSettingsSchema,
  featureFlagRolloutSchema,
  taxCategorySchema,
} from "./settings-schema";

const branchSettings = {
  name: "Bites Box Bakhtiyarpur",
  legal_name: "Bites Box Foods Private Limited",
  phone: "+919431100100",
  alternate_phone: "",
  whatsapp_phone: "+919431100100",
  email: "bakhtiyarpur@bitesbox.in",
  address_line1: "Station Road",
  address_line2: "Near Junction",
  landmark: "Railway station",
  city: "Bakhtiyarpur",
  state: "Bihar",
  postal_code: "803212",
  latitude: 25.456,
  longitude: 85.532,
  google_maps_url: "https://maps.google.com/?q=25.456,85.532",
  gstin: "10ABCDE1234F1Z5",
  fssai_licence_no: "20424001000123",
  fssai_valid_till: "2027-03-31",
  timezone: "Asia/Kolkata",
  service_mode: "BOTH",
  default_prep_minutes: 22,
  rush_buffer_minutes: 0,
  max_concurrent_orders: 40,
};

describe("settings validation", () => {
  it("accepts complete branch data and converts blank optional values to null", () => {
    const result = branchSettingsSchema.safeParse({
      ...branchSettings,
      alternate_phone: "",
      fssai_valid_till: "",
      max_concurrent_orders: null,
    });

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.alternate_phone).toBeNull();
      expect(result.data.fssai_valid_till).toBeNull();
    }
  });

  it("rejects bad map coordinates, Indian compliance values and phone formats", () => {
    expect(
      branchSettingsSchema.safeParse({ ...branchSettings, latitude: 120 })
        .success,
    ).toBe(false);
    expect(
      branchSettingsSchema.safeParse({ ...branchSettings, gstin: "bad" })
        .success,
    ).toBe(false);
    expect(
      branchSettingsSchema.safeParse({ ...branchSettings, phone: "9431100100" })
        .success,
    ).toBe(false);
    expect(
      branchSettingsSchema.safeParse({
        ...branchSettings,
        fssai_licence_no: "123",
      }).success,
    ).toBe(false);
  });

  it("accepts overnight hours only when the next-day switch is set", () => {
    const values = {
      day_of_week: 5,
      opens_at: "19:00",
      closes_at: "01:00",
      closes_next_day: true,
      day_part: "DINNER",
      is_closed: false,
    };

    expect(branchHoursSchema.safeParse(values).success).toBe(true);
    expect(
      branchHoursSchema.safeParse({ ...values, closes_next_day: false })
        .success,
    ).toBe(false);
  });

  it("validates closure overrides and special holiday hours", () => {
    expect(
      branchHolidaySchema.safeParse({
        holiday_on: "2026-12-25",
        label: "Christmas",
        is_closed: true,
        opens_at: null,
        closes_at: null,
      }).success,
    ).toBe(true);
    expect(
      branchHolidaySchema.safeParse({
        holiday_on: "2026-99-25",
        label: "Invalid date",
        is_closed: true,
        opens_at: null,
        closes_at: null,
      }).success,
    ).toBe(false);
    expect(
      branchHolidaySchema.safeParse({
        holiday_on: "2026-12-25",
        label: "Late opening",
        is_closed: false,
        opens_at: "10:00",
        closes_at: null,
      }).success,
    ).toBe(false);
  });

  it("derives the combined GST rate and rejects invalid splits", () => {
    const result = taxCategorySchema.safeParse({
      code: "GST_5",
      name: "Restaurant supply",
      description: "Standard supply",
      cgst_rate: 0.025,
      sgst_rate: 0.025,
      igst_rate: 0,
      cess_rate: 0,
      hsn_sac_code: "996331",
      is_inclusive: true,
    });

    expect(result.success).toBe(true);
    if (result.success) expect(result.data.rate).toBe(0.05);
    expect(
      taxCategorySchema.safeParse({
        code: "GST_BAD",
        name: "Invalid tax",
        description: "",
        cgst_rate: 0.8,
        sgst_rate: 0.3,
        igst_rate: 0,
        cess_rate: 0,
        hsn_sac_code: "",
        is_inclusive: true,
      }).success,
    ).toBe(false);
  });

  it("accepts rollout endpoints and rejects percentages outside the contract", () => {
    expect(
      featureFlagRolloutSchema.safeParse({ key: "cod", rollout_percentage: 0 })
        .success,
    ).toBe(true);
    expect(
      featureFlagRolloutSchema.safeParse({
        key: "cod",
        rollout_percentage: 100,
      }).success,
    ).toBe(true);
    expect(
      featureFlagRolloutSchema.safeParse({
        key: "cod",
        rollout_percentage: 100.5,
      }).success,
    ).toBe(false);
  });
});
