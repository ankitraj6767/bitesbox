"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { activeBranchId, requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  branchHolidaySchema,
  branchHoursSchema,
  branchSettingsSchema,
  featureFlagRolloutSchema,
  idSchema,
  taxCategorySchema,
} from "./settings-schema";

export type SettingsActionResult =
  | { ok: true; id?: string }
  | { ok: false; message: string };

export async function saveBranchSettings(
  input: unknown,
): Promise<SettingsActionResult> {
  const values = branchSettingsSchema.safeParse(input);
  if (!values.success) return invalid(values.error.issues[0]?.message);
  if (!validTimezone(values.data.timezone))
    return invalid("Choose a valid timezone.");

  const context = await branchContext();
  if (!context.ok) return context;
  const { data, error } = await context.supabase
    .from("branches")
    .update({ ...values.data, updated_by: context.userId })
    .eq("id", context.branchId)
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();
  if (error) return failure(error.code, "Branch details could not be saved.");
  if (!data)
    return {
      ok: false,
      message: "This outlet is no longer available. Refresh and try again.",
    };
  revalidatePath("/settings");
  revalidatePath("/");
  return { ok: true, id: data.id };
}

export async function archiveCurrentBranch(): Promise<SettingsActionResult> {
  const context = await branchContext();
  if (!context.ok) return context;
  const { data, error } = await context.supabase.rpc("archive_branch", {
    p_branch_id: context.branchId,
  });
  if (error)
    return {
      ok: false,
      message: archiveBranchMessage(error.code, error.hint),
    };
  revalidatePath("/settings");
  revalidatePath("/");
  return { ok: true, id: data ?? context.branchId };
}

export async function saveBranchHours(
  input: unknown,
): Promise<SettingsActionResult> {
  const values = branchHoursSchema.safeParse(input);
  if (!values.success) return invalid(values.error.issues[0]?.message);
  const context = await branchContext();
  if (!context.ok) return context;
  const { id, ...fields } = values.data;
  const result = id
    ? await context.supabase
        .from("branch_hours")
        .update(fields)
        .eq("id", id)
        .eq("branch_id", context.branchId)
        .select("id")
        .maybeSingle()
    : await context.supabase
        .from("branch_hours")
        .insert({ ...fields, branch_id: context.branchId })
        .select("id")
        .single();
  if (result.error)
    return failure(result.error.code, "Trading hours could not be saved.");
  if (!result.data)
    return {
      ok: false,
      message:
        "This trading-hours slot is no longer available. Refresh and try again.",
    };
  revalidatePath("/settings");
  revalidatePath("/");
  return { ok: true, id: result.data.id };
}

export async function deleteBranchHours(
  id: string,
): Promise<SettingsActionResult> {
  if (!idSchema.safeParse(id).success)
    return invalid("The trading-hours slot is invalid.");
  const context = await branchContext();
  if (!context.ok) return context;
  const { data, error } = await context.supabase
    .from("branch_hours")
    .delete()
    .eq("id", id)
    .eq("branch_id", context.branchId)
    .select("id")
    .maybeSingle();
  if (error) return failure(error.code, "Trading hours could not be deleted.");
  if (!data)
    return {
      ok: false,
      message:
        "This trading-hours slot is no longer available. Refresh and try again.",
    };
  revalidatePath("/settings");
  revalidatePath("/");
  return { ok: true, id: data.id };
}

export async function saveBranchHoliday(
  input: unknown,
): Promise<SettingsActionResult> {
  const values = branchHolidaySchema.safeParse(input);
  if (!values.success) return invalid(values.error.issues[0]?.message);
  const context = await branchContext();
  if (!context.ok) return context;
  const { id, ...fields } = values.data;
  const normalized = {
    ...fields,
    opens_at: fields.is_closed ? null : fields.opens_at,
    closes_at: fields.is_closed ? null : fields.closes_at,
  };
  const result = id
    ? await context.supabase
        .from("branch_holidays")
        .update(normalized)
        .eq("id", id)
        .eq("branch_id", context.branchId)
        .select("id")
        .maybeSingle()
    : await context.supabase
        .from("branch_holidays")
        .insert({ ...normalized, branch_id: context.branchId })
        .select("id")
        .single();
  if (result.error)
    return failure(
      result.error.code,
      "The holiday exception could not be saved.",
    );
  if (!result.data)
    return {
      ok: false,
      message:
        "This holiday exception is no longer available. Refresh and try again.",
    };
  revalidatePath("/settings");
  revalidatePath("/");
  return { ok: true, id: result.data.id };
}

export async function deleteBranchHoliday(
  id: string,
): Promise<SettingsActionResult> {
  if (!idSchema.safeParse(id).success)
    return invalid("The holiday exception is invalid.");
  const context = await branchContext();
  if (!context.ok) return context;
  const { data, error } = await context.supabase
    .from("branch_holidays")
    .delete()
    .eq("id", id)
    .eq("branch_id", context.branchId)
    .select("id")
    .maybeSingle();
  if (error)
    return failure(error.code, "The holiday exception could not be deleted.");
  if (!data)
    return {
      ok: false,
      message:
        "This holiday exception is no longer available. Refresh and try again.",
    };
  revalidatePath("/settings");
  revalidatePath("/");
  return { ok: true, id: data.id };
}

export async function saveTaxCategory(
  input: unknown,
): Promise<SettingsActionResult> {
  const values = taxCategorySchema.safeParse(input);
  if (!values.success) return invalid(values.error.issues[0]?.message);
  await requirePermission(PERMISSIONS.SETTINGS_UPDATE);
  const supabase = await createSupabaseServerClient();
  const { id, ...fields } = values.data;
  const result = id
    ? await supabase
        .from("tax_categories")
        .update(fields)
        .eq("id", id)
        .is("deleted_at", null)
        .select("id")
        .maybeSingle()
    : await supabase
        .from("tax_categories")
        .insert(fields)
        .select("id")
        .single();
  if (result.error)
    return failure(result.error.code, "The tax category could not be saved.");
  if (!result.data)
    return {
      ok: false,
      message:
        "This tax category is no longer available. Refresh and try again.",
    };
  revalidatePath("/settings");
  revalidatePath("/menu");
  return { ok: true, id: result.data.id };
}

export async function setDefaultTaxCategory(
  id: string,
): Promise<SettingsActionResult> {
  if (!idSchema.safeParse(id).success)
    return invalid("The tax category is invalid.");
  await requirePermission(PERMISSIONS.SETTINGS_UPDATE);
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("set_default_tax_category", {
    p_category_id: id,
  });
  if (error)
    return {
      ok: false,
      message: taxCategoryRpcMessage(error.code, error.hint),
    };
  revalidatePath("/settings");
  revalidatePath("/menu");
  return { ok: true, id: data ?? id };
}

export async function archiveTaxCategory(
  id: string,
): Promise<SettingsActionResult> {
  if (!idSchema.safeParse(id).success)
    return invalid("The tax category is invalid.");
  await requirePermission(PERMISSIONS.SETTINGS_UPDATE);
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("archive_tax_category", {
    p_category_id: id,
  });
  if (error)
    return {
      ok: false,
      message: taxCategoryRpcMessage(error.code, error.hint),
    };
  revalidatePath("/settings");
  revalidatePath("/menu");
  return { ok: true, id: data ?? id };
}

export async function updateFeatureFlag(
  input: unknown,
): Promise<SettingsActionResult> {
  const values = featureFlagRolloutSchema
    .extend({ is_enabled: z.boolean().optional() })
    .safeParse(input);
  if (!values.success) return invalid(values.error.issues[0]?.message);
  const session = await requirePermission(PERMISSIONS.FEATURE_FLAG_UPDATE);
  const supabase = await createSupabaseServerClient();
  const { key, ...fields } = values.data;
  const { data, error } = await supabase
    .from("feature_flags")
    .update({ ...fields, updated_by: session.user_id })
    .eq("key", key)
    .select("key")
    .maybeSingle();
  if (error)
    return failure(error.code, "The feature flag could not be updated.");
  if (!data)
    return {
      ok: false,
      message:
        "This feature flag is no longer available. Refresh and try again.",
    };
  revalidatePath("/settings");
  revalidatePath("/");
  return { ok: true };
}

async function branchContext(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
      branchId: string;
      userId: string;
    }
  | { ok: false; message: string }
> {
  const session = await requirePermission(PERMISSIONS.BRANCH_MANAGE);
  const branchId = await activeBranchId(session);
  if (!branchId)
    return {
      ok: false,
      message: "Choose an outlet before changing its settings.",
    };
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("has_permission", {
    p_permission: PERMISSIONS.BRANCH_MANAGE,
    p_branch_id: branchId,
  });
  if (error)
    return {
      ok: false,
      message: "Could not verify access to this outlet. Refresh and try again.",
    };
  if (!data)
    return {
      ok: false,
      message:
        "Your account does not have Manage branch access for this outlet.",
    };
  const userId = session.user_id;
  if (!userId)
    return {
      ok: false,
      message: "Sign in again before changing outlet settings.",
    };
  return { ok: true, supabase, branchId, userId };
}

function validTimezone(value: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value });
    return true;
  } catch {
    return false;
  }
}

function invalid(message?: string): SettingsActionResult {
  return {
    ok: false,
    message: message ?? "Review the settings and try again.",
  };
}

function failure(code: string, fallback: string): SettingsActionResult {
  if (code === "42501" || code === "PGRST301")
    return {
      ok: false,
      message: "You do not have permission to make this change.",
    };
  if (code === "23505")
    return {
      ok: false,
      message: "A setting with the same name or time already exists.",
    };
  if (code === "23514" || code === "22P02")
    return {
      ok: false,
      message: "Some values are not valid. Review the form and try again.",
    };
  return { ok: false, message: fallback };
}

function archiveBranchMessage(
  code: string,
  databaseHint: string | null,
): string {
  if (databaseHint?.includes("DEFAULT_BRANCH_REASSIGNMENT_PERMISSION_REQUIRED"))
    return "Manage branch access on a replacement outlet is required before archiving the default outlet.";
  if (code === "42501")
    return "Your account does not have permission to archive this outlet or select its replacement.";
  if (databaseHint?.includes("LAST_ACTIVE_BRANCH"))
    return "The last active outlet cannot be archived.";
  if (databaseHint?.includes("BRANCH_HAS_ACTIVE_ORDERS"))
    return "Finish or cancel this outlet’s active orders before archiving it.";
  if (databaseHint?.includes("BRANCH_NOT_FOUND"))
    return "This outlet is no longer available. Refresh and try again.";
  return "The outlet could not be archived. Refresh the page and try again.";
}

function taxCategoryRpcMessage(
  code: string,
  databaseHint: string | null,
): string {
  if (code === "42501")
    return "You do not have permission to manage tax categories.";
  if (databaseHint?.includes("DEFAULT_TAX_CATEGORY_CANNOT_BE_ARCHIVED"))
    return "Choose another default tax category before archiving this one.";
  if (databaseHint?.includes("TAX_CATEGORY_NOT_AVAILABLE"))
    return "This tax category is no longer available. Refresh and try again.";
  return "The tax category could not be changed. Refresh and try again.";
}
