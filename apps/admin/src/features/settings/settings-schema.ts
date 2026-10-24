import { z } from "zod";

const uuid = z.string().uuid();
const time = z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/);
const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .transform((value) => value || null);
const optionalPhone = z
  .string()
  .trim()
  .max(16)
  .refine(
    (value) => !value || /^\+[1-9][0-9]{7,14}$/.test(value),
    "Use an international phone number such as +919876543210.",
  )
  .transform((value) => value || null);
const optionalEmail = z
  .string()
  .trim()
  .max(254)
  .refine(
    (value) => !value || /^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i.test(value),
    "Enter a valid email address.",
  )
  .transform((value) => value || null);
const optionalDate = z
  .string()
  .trim()
  .refine(
    (value) => !value || /^\d{4}-\d{2}-\d{2}$/.test(value),
    "Enter a valid date.",
  )
  .refine((value) => {
    if (!value) return true;
    const parsed = new Date(`${value}T00:00:00.000Z`);
    return (
      Number.isFinite(parsed.getTime()) &&
      parsed.toISOString().slice(0, 10) === value
    );
  }, "Enter a valid date.")
  .transform((value) => value || null);

export const branchSettingsSchema = z.object({
  name: z.string().trim().min(2).max(120),
  legal_name: optionalText(180),
  phone: z
    .string()
    .trim()
    .regex(
      /^\+[1-9][0-9]{7,14}$/,
      "Use an international phone number such as +919876543210.",
    ),
  alternate_phone: optionalPhone,
  whatsapp_phone: optionalPhone,
  email: optionalEmail,
  address_line1: z.string().trim().min(3).max(180),
  address_line2: optionalText(180),
  landmark: optionalText(120),
  city: z.string().trim().min(2).max(100),
  state: z.string().trim().min(2).max(100),
  postal_code: z
    .string()
    .trim()
    .min(2)
    .max(12)
    .regex(/^[A-Za-z0-9 -]+$/),
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
  google_maps_url: z
    .string()
    .trim()
    .max(500)
    .refine(
      (value) => !value || /^https:\/\//i.test(value),
      "Use a secure https:// map link.",
    )
    .transform((value) => value || null),
  gstin: z
    .string()
    .trim()
    .toUpperCase()
    .max(15)
    .refine(
      (value) => !value || /^[0-9A-Z]{15}$/.test(value),
      "GSTIN must contain 15 letters and digits.",
    )
    .transform((value) => value || null),
  fssai_licence_no: z
    .string()
    .trim()
    .max(20)
    .refine(
      (value) => !value || /^\d{14}$/.test(value),
      "FSSAI licence must contain 14 digits.",
    )
    .transform((value) => value || null),
  fssai_valid_till: optionalDate,
  timezone: z.string().trim().min(3).max(80),
  service_mode: z.enum(["DELIVERY", "PICKUP", "BOTH"]),
  default_prep_minutes: z.number().int().min(1).max(240),
  rush_buffer_minutes: z.number().int().min(0).max(180),
  max_concurrent_orders: z.number().int().positive().max(100_000).nullable(),
});

export const branchHoursSchema = z
  .object({
    id: uuid.optional(),
    day_of_week: z.number().int().min(0).max(6),
    opens_at: time,
    closes_at: time,
    closes_next_day: z.boolean(),
    day_part: z.enum([
      "BREAKFAST",
      "LUNCH",
      "SNACKS",
      "DINNER",
      "LATE_NIGHT",
      "ALL_DAY",
    ]),
    is_closed: z.boolean(),
  })
  .superRefine((value, context) => {
    if (!value.closes_next_day && value.closes_at <= value.opens_at) {
      context.addIssue({
        code: "custom",
        path: ["closes_at"],
        message:
          "Closing time must be after opening time. For overnight hours, enable “Closes next day”.",
      });
    }
    if (value.closes_next_day && value.closes_at === value.opens_at) {
      context.addIssue({
        code: "custom",
        path: ["closes_at"],
        message: "Opening and closing times cannot be identical.",
      });
    }
  });

export const branchHolidaySchema = z
  .object({
    id: uuid.optional(),
    holiday_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    label: z.string().trim().min(2).max(120),
    is_closed: z.boolean(),
    opens_at: time.nullable(),
    closes_at: time.nullable(),
  })
  .superRefine((value, context) => {
    const date = new Date(`${value.holiday_on}T00:00:00.000Z`);
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(value.holiday_on) ||
      !Number.isFinite(date.getTime()) ||
      date.toISOString().slice(0, 10) !== value.holiday_on
    ) {
      context.addIssue({
        code: "custom",
        path: ["holiday_on"],
        message: "Enter a valid date.",
      });
    }
    if (value.is_closed) return;
    if (!value.opens_at || !value.closes_at) {
      context.addIssue({
        code: "custom",
        path: ["opens_at"],
        message: "Set both opening and closing times for an open exception.",
      });
    } else if (value.closes_at <= value.opens_at) {
      context.addIssue({
        code: "custom",
        path: ["closes_at"],
        message: "Closing time must be after opening time.",
      });
    }
  });

export const taxCategorySchema = z
  .object({
    id: uuid.optional(),
    code: z
      .string()
      .trim()
      .toUpperCase()
      .min(1)
      .max(30)
      .regex(/^[A-Z0-9_-]+$/),
    name: z.string().trim().min(2).max(120),
    description: optionalText(500),
    cgst_rate: z.number().finite().min(0).max(1),
    sgst_rate: z.number().finite().min(0).max(1),
    igst_rate: z.number().finite().min(0).max(1),
    cess_rate: z.number().finite().min(0).max(1),
    hsn_sac_code: optionalText(32),
    is_inclusive: z.boolean(),
  })
  .superRefine((value, context) => {
    if (value.cgst_rate + value.sgst_rate + value.igst_rate > 1) {
      context.addIssue({
        code: "custom",
        path: ["cgst_rate"],
        message: "The combined GST rate cannot exceed 100%.",
      });
    }
  })
  .transform((value) => ({
    ...value,
    rate: Number(
      (value.cgst_rate + value.sgst_rate + value.igst_rate).toFixed(4),
    ),
  }));

export const idSchema = uuid;
export const featureFlagRolloutSchema = z.object({
  key: z.string().trim().min(1).max(120),
  rollout_percentage: z.number().int().min(0).max(100),
});
export const featureFlagUpdateSchema = z
  .object({
    key: z.string().trim().min(1).max(120),
    rollout_percentage: z.number().int().min(0).max(100).optional(),
    is_enabled: z.boolean().optional(),
  })
  .refine(
    (value) =>
      value.rollout_percentage !== undefined || value.is_enabled !== undefined,
    { message: "Set an enabled state or rollout percentage." },
  );

export type BranchSettingsValues = z.infer<typeof branchSettingsSchema>;
export type BranchHoursValues = z.infer<typeof branchHoursSchema>;
export type BranchHolidayValues = z.infer<typeof branchHolidaySchema>;
export type TaxCategoryValues = z.infer<typeof taxCategorySchema>;
