import { z } from "zod";

const coordinate = z.tuple([
  z.number().finite().min(-180).max(180),
  z.number().finite().min(-90).max(90),
]);

/** The serviceability function evaluates the outer ring only, so holes are intentionally unsupported. */
const polygon = z.array(z.array(coordinate).min(3)).nullable();

const amount = z.number().finite().min(0).max(999_999_999.99);
const time = z
  .string()
  .regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/)
  .nullable();

export const deliveryZoneFormSchema = z
  .object({
    id: z.string().uuid().optional(),
    name: z.string().trim().min(2).max(100),
    description: z.string().trim().max(500).nullable(),
    kind: z.enum(["RADIUS", "POLYGON"]),
    min_distance_km: z.number().finite().min(0).max(9_999.99).nullable(),
    max_distance_km: z.number().finite().min(0).max(9_999.99).nullable(),
    polygon,
    delivery_fee: amount,
    min_order_amount: amount,
    free_delivery_threshold: amount.nullable(),
    per_km_surcharge: amount,
    surcharge_after_km: z.number().finite().min(0).max(9_999.99).nullable(),
    peak_surcharge: amount,
    peak_starts_at: time,
    peak_ends_at: time,
    dynamic_surcharge: amount,
    base_eta_minutes: z.number().int().min(5).max(240),
    extra_eta_minutes: z.number().int().min(0).max(240),
    cod_enabled: z.boolean(),
    max_cod_amount: amount.nullable(),
    is_serviceable: z.boolean(),
    is_active: z.boolean(),
    priority: z.number().int().min(-1_000_000).max(1_000_000),
  })
  .superRefine((zone, context) => {
    if (zone.kind === "RADIUS") {
      if (zone.min_distance_km === null || zone.max_distance_km === null) {
        context.addIssue({
          code: "custom",
          path: ["min_distance_km"],
          message: "Enter both distance limits.",
        });
      } else if (zone.max_distance_km <= zone.min_distance_km) {
        context.addIssue({
          code: "custom",
          path: ["max_distance_km"],
          message:
            "The outer distance must be greater than the inner distance.",
        });
      }
      if (zone.polygon !== null) {
        context.addIssue({
          code: "custom",
          path: ["polygon"],
          message: "Radius zones do not use a polygon.",
        });
      }
    } else {
      if (!zone.polygon || zone.polygon.length !== 1) {
        context.addIssue({
          code: "custom",
          path: ["polygon"],
          message:
            "Add one polygon ring with at least three longitude/latitude points.",
        });
      }
      if (zone.min_distance_km !== null || zone.max_distance_km !== null) {
        context.addIssue({
          code: "custom",
          path: ["min_distance_km"],
          message: "Polygon zones do not use radius limits.",
        });
      }
    }

    if (zone.per_km_surcharge > 0 && zone.surcharge_after_km === null) {
      context.addIssue({
        code: "custom",
        path: ["surcharge_after_km"],
        message:
          "Set the distance after which the per-kilometre surcharge starts.",
      });
    }

    if (
      zone.peak_surcharge > 0 &&
      (!zone.peak_starts_at || !zone.peak_ends_at)
    ) {
      context.addIssue({
        code: "custom",
        path: ["peak_starts_at"],
        message: "Set both times for the peak surcharge window.",
      });
    }
  });

export type DeliveryZoneFormValues = z.infer<typeof deliveryZoneFormSchema>;

export const deliveryZoneStatusSchema = z
  .object({
    id: z.string().uuid(),
    is_active: z.boolean().optional(),
    is_serviceable: z.boolean().optional(),
  })
  .refine(
    (value) =>
      value.is_active !== undefined || value.is_serviceable !== undefined,
  );

export const deliveryZoneIdSchema = z.string().uuid();
