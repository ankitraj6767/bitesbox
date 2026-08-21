/**
 * POST /functions/v1/rider-signup
 *
 * Public application endpoint. It can create only a delivery-partner applicant:
 * the account starts PENDING, is OFFLINE, has no partner code and cannot receive
 * dispatch until an authorised manager completes document review and approval.
 *
 * The service key never leaves this function. The mobile app receives no
 * privileged credential; after this succeeds it signs in normally with the
 * email and password supplied during registration.
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { AppError, fromPostgrestError } from "../_shared/errors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";

const VEHICLE_TYPES = ["BICYCLE", "SCOOTER", "MOTORCYCLE", "CAR", "ON_FOOT"] as const;

serveFunction("rider-signup", async ({ req, requestId, origin }) => {
    const body = await readJson<Record<string, unknown>>(req);
    const fullName = v.string(body, "full_name", { min: 2, max: 120 });
    const email = v.string(body, "email", { min: 5, max: 254 }).toLowerCase();
    const password = v.string(body, "password", { min: 8, max: 72 });
    const rawPhone = v.string(body, "phone", { min: 10, max: 20 });
    const phone = normaliseIndianPhone(rawPhone);
    const vehicleType = v.enumValue(body, "vehicle_type", VEHICLE_TYPES);
    const vehicleNumber = v.optionalString(body, "vehicle_number", { max: 30 });
    const addressLine1 = v.optionalString(body, "address_line1", { max: 180 });
    const city = v.optionalString(body, "city", { max: 80 });
    const state = v.optionalString(body, "state", { max: 80 });
    const postalCode = v.optionalString(body, "postal_code", { max: 12 });
    const emergencyContactName = v.optionalString(body, "emergency_contact_name", { max: 120 });
    const emergencyContactPhone = optionalIndianPhone(body, "emergency_contact_phone");

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new AppError("VALIDATION_FAILED", "Enter a valid email address.");
    }

    const admin = serviceClient();
    const { data: branch, error: branchError } = await admin
        .from("branches")
        .select("id")
        .eq("is_active", true)
        .is("deleted_at", null)
        .order("is_default", { ascending: false })
        .order("display_order", { ascending: true })
        .limit(1)
        .maybeSingle();

    if (branchError) throw fromPostgrestError(branchError);
    if (!branch?.id) {
        throw new AppError("CONFIGURATION_ERROR", "No active delivery outlet is configured.");
    }

    const { data: created, error: authError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        phone,
        phone_confirm: true,
        user_metadata: {
            full_name: fullName,
            phone,
            signup_channel: "rider_app",
        },
    });

    if (authError || !created.user) {
        throw new AppError(
            "VALIDATION_FAILED",
            authError?.message?.toLowerCase().includes("already")
                ? "An account with these details already exists. Sign in or contact the outlet."
                : authError?.message ?? "The delivery-partner account could not be created.",
        );
    }

    const userId = created.user.id;

    try {
        // The Auth trigger starts every user as CUSTOMER. Move the new applicant
        // to the delivery shell, but keep the rider row PENDING so the app can
        // show the checklist while the admin reviews it.
        const { data: role, error: roleError } = await admin
            .from("roles")
            .select("id")
            .eq("code", "DELIVERY_PARTNER")
            .single();
        if (roleError || !role) {
            throw fromPostgrestError(roleError ?? { message: "Delivery role is not configured." });
        }

        const { data: partner, error: partnerError } = await admin
            .from("delivery_partners")
            .insert({
                user_id: userId,
                branch_id: branch.id,
                full_name: fullName,
                phone,
                email,
                vehicle_type: vehicleType,
                vehicle_number: vehicleNumber,
                address_line1: addressLine1,
                city,
                state,
                postal_code: postalCode,
                emergency_contact_name: emergencyContactName,
                emergency_contact_phone: emergencyContactPhone,
                onboarding_status: "PENDING",
                duty_state: "OFFLINE",
                is_salaried: false,
                created_by: userId,
            })
            .select("id")
            .single();
        if (partnerError || !partner) {
            throw fromPostgrestError(
                partnerError ?? { message: "The delivery-partner application could not be created." },
            );
        }

        const { error: demoteError } = await admin
            .from("user_roles")
            .update({ is_primary: false })
            .eq("user_id", userId)
            .eq("is_primary", true);
        if (demoteError) throw fromPostgrestError(demoteError);

        const { error: grantError } = await admin.from("user_roles").insert({
            user_id: userId,
            role_id: role.id,
            branch_id: branch.id,
            is_primary: true,
            assigned_by: userId,
        });
        if (grantError) throw fromPostgrestError(grantError);

        return jsonResponse(
            {
                application: "SUBMITTED",
                delivery_partner_id: partner.id,
                onboarding_status: "PENDING",
                message: "Application submitted. Sign in to upload your documents.",
            },
            { origin, requestId },
        );
    } catch (error) {
        // Do not leave an email/password account that has no rider record if a
        // downstream insert or role grant fails.
        await admin.auth.admin.deleteUser(userId);
        throw error;
    }
});

function normaliseIndianPhone(value: string): string {
    let digits = value.replace(/[^0-9]/g, "");
    if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(1);
    if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(2);
    if (digits.length !== 10 || !/^[6-9]/.test(digits)) {
        throw new AppError("VALIDATION_FAILED", "Enter a valid Indian mobile number.");
    }
    return `+91${digits}`;
}

function optionalIndianPhone(body: Record<string, unknown>, field: string): string | null {
    const raw = body[field];
    if (raw === undefined || raw === null || raw === "") return null;
    const value = v.string(body, field, { min: 10, max: 20 });
    return normaliseIndianPhone(value);
}
