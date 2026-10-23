"use server";

import { revalidatePath } from "next/cache";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { activeBranchId, requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  deliveryZoneFormSchema,
  deliveryZoneIdSchema,
  deliveryZoneStatusSchema,
} from "./delivery-zone-schema";

export type DeliveryZoneActionResult =
  | { ok: true; id: string }
  | { ok: false; message: string };

export async function saveDeliveryZone(
  input: unknown,
): Promise<DeliveryZoneActionResult> {
  const session = await requirePermission(PERMISSIONS.BRANCH_MANAGE);
  const branchId = await activeBranchId(session);
  if (!branchId)
    return {
      ok: false,
      message: "Choose an outlet before managing its delivery zones.",
    };

  const parsed = deliveryZoneFormSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      message:
        parsed.error.issues[0]?.message ?? "Review the delivery zone details.",
    };
  }

  const { id, ...values } = parsed.data;
  const supabase = await createSupabaseServerClient();
  const mutation = id
    ? await supabase
        .from("delivery_zones")
        .update({ ...values, updated_by: session.user_id })
        .eq("id", id)
        .eq("branch_id", branchId)
        .is("deleted_at", null)
        .select("id")
        .maybeSingle()
    : await supabase
        .from("delivery_zones")
        .insert({
          ...values,
          branch_id: branchId,
          created_by: session.user_id,
          updated_by: session.user_id,
        })
        .select("id")
        .single();

  if (mutation.error)
    return { ok: false, message: messageForDatabaseError(mutation.error.code) };
  if (!mutation.data) {
    return {
      ok: false,
      message:
        "This zone is no longer available in the selected outlet. Refresh and try again.",
    };
  }

  revalidatePath("/settings");
  return { ok: true, id: mutation.data.id };
}

export async function updateDeliveryZoneStatus(
  input: unknown,
): Promise<DeliveryZoneActionResult> {
  const session = await requirePermission(PERMISSIONS.BRANCH_MANAGE);
  const branchId = await activeBranchId(session);
  if (!branchId)
    return {
      ok: false,
      message: "Choose an outlet before managing its delivery zones.",
    };

  const parsed = deliveryZoneStatusSchema.safeParse(input);
  if (!parsed.success)
    return { ok: false, message: "The requested zone status is invalid." };

  const { id, ...status } = parsed.data;
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("delivery_zones")
    .update({ ...status, updated_by: session.user_id })
    .eq("id", id)
    .eq("branch_id", branchId)
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();

  if (error) return { ok: false, message: messageForDatabaseError(error.code) };
  if (!data)
    return {
      ok: false,
      message:
        "This zone is no longer available in the selected outlet. Refresh and try again.",
    };

  revalidatePath("/settings");
  return { ok: true, id: data.id };
}

export async function deleteDeliveryZone(
  id: string,
): Promise<DeliveryZoneActionResult> {
  const session = await requirePermission(PERMISSIONS.BRANCH_MANAGE);
  const branchId = await activeBranchId(session);
  if (!branchId)
    return {
      ok: false,
      message: "Choose an outlet before managing its delivery zones.",
    };
  if (!deliveryZoneIdSchema.safeParse(id).success) {
    return { ok: false, message: "The requested zone is invalid." };
  }

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("delivery_zones")
    .update({
      is_active: false,
      deleted_at: new Date().toISOString(),
      updated_by: session.user_id,
    })
    .eq("id", id)
    .eq("branch_id", branchId)
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();

  if (error) return { ok: false, message: messageForDatabaseError(error.code) };
  if (!data)
    return {
      ok: false,
      message:
        "This zone is no longer available in the selected outlet. Refresh and try again.",
    };

  revalidatePath("/settings");
  return { ok: true, id: data.id };
}

function messageForDatabaseError(code: string | undefined): string {
  switch (code) {
    case "23505":
      return "A delivery zone with this name already exists for the selected outlet.";
    case "42501":
      return "You no longer have permission to change delivery zones for this outlet.";
    case "23514":
      return "Some delivery zone values are outside the allowed range. Review the form and try again.";
    default:
      return "The delivery zone could not be saved. Please try again.";
  }
}
