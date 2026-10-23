"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Archive, Pencil } from "lucide-react";
import type { Database } from "@bitesbox/shared-types";
import { Button } from "@/components/ui/button";
import { CardContent, CardToolbar } from "@/components/ui/card";
import {
  Field,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/form-controls";
import {
  ConfirmDialog,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/overlays";
import { InlineNotice } from "@/components/ui/states";
import { toast } from "sonner";
import { archiveCurrentBranch, saveBranchSettings } from "./settings-actions";

type Branch = Pick<
  Database["public"]["Tables"]["branches"]["Row"],
  | "id"
  | "code"
  | "name"
  | "legal_name"
  | "phone"
  | "alternate_phone"
  | "whatsapp_phone"
  | "email"
  | "address_line1"
  | "address_line2"
  | "landmark"
  | "city"
  | "state"
  | "postal_code"
  | "latitude"
  | "longitude"
  | "google_maps_url"
  | "gstin"
  | "fssai_licence_no"
  | "fssai_valid_till"
  | "timezone"
  | "service_mode"
  | "default_prep_minutes"
  | "rush_buffer_minutes"
  | "max_concurrent_orders"
  | "is_active"
  | "is_default"
>;

type Draft = Record<keyof BranchDraft, string>;
type BranchDraft = {
  name: string;
  legal_name: string;
  phone: string;
  alternate_phone: string;
  whatsapp_phone: string;
  email: string;
  address_line1: string;
  address_line2: string;
  landmark: string;
  city: string;
  state: string;
  postal_code: string;
  latitude: string;
  longitude: string;
  google_maps_url: string;
  gstin: string;
  fssai_licence_no: string;
  fssai_valid_till: string;
  timezone: string;
  service_mode: string;
  default_prep_minutes: string;
  rush_buffer_minutes: string;
  max_concurrent_orders: string;
};

function toDraft(branch: Branch): Draft {
  return {
    name: branch.name,
    legal_name: branch.legal_name ?? "",
    phone: branch.phone,
    alternate_phone: branch.alternate_phone ?? "",
    whatsapp_phone: branch.whatsapp_phone ?? "",
    email: branch.email ?? "",
    address_line1: branch.address_line1,
    address_line2: branch.address_line2 ?? "",
    landmark: branch.landmark ?? "",
    city: branch.city,
    state: branch.state,
    postal_code: branch.postal_code,
    latitude: String(branch.latitude),
    longitude: String(branch.longitude),
    google_maps_url: branch.google_maps_url ?? "",
    gstin: branch.gstin ?? "",
    fssai_licence_no: branch.fssai_licence_no ?? "",
    fssai_valid_till: branch.fssai_valid_till ?? "",
    timezone: branch.timezone,
    service_mode: branch.service_mode,
    default_prep_minutes: String(branch.default_prep_minutes),
    rush_buffer_minutes: String(branch.rush_buffer_minutes),
    max_concurrent_orders:
      branch.max_concurrent_orders == null
        ? ""
        : String(branch.max_concurrent_orders),
  };
}

export function BranchSettingsManager({
  branch,
  canManage,
  canArchive,
  archiveCheckFailed,
}: {
  branch: Branch;
  canManage: boolean;
  canArchive: boolean;
  archiveCheckFailed: boolean;
}) {
  const router = useRouter();
  const [open, setOpen] = React.useState(false);
  const [archiveOpen, setArchiveOpen] = React.useState(false);
  const [draft, setDraft] = React.useState<Draft>(() => toDraft(branch));
  const [error, setError] = React.useState<string | null>(null);
  const [saving, startSaving] = React.useTransition();

  React.useEffect(() => setDraft(toDraft(branch)), [branch]);

  const set = (key: keyof Draft, value: string) =>
    setDraft((current) => ({ ...current, [key]: value }));
  const save = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    startSaving(async () => {
      const result = await saveBranchSettings({
        ...draft,
        latitude: Number(draft.latitude),
        longitude: Number(draft.longitude),
        default_prep_minutes: Number(draft.default_prep_minutes),
        rush_buffer_minutes: Number(draft.rush_buffer_minutes),
        max_concurrent_orders: draft.max_concurrent_orders.trim()
          ? Number(draft.max_concurrent_orders)
          : null,
      });
      if (!result.ok) {
        setError(result.message);
        return;
      }
      setOpen(false);
      toast.success("Outlet details saved");
      router.refresh();
    });
  };

  const archive = () => {
    startSaving(async () => {
      const result = await archiveCurrentBranch();
      if (!result.ok) {
        toast.error(result.message);
        return;
      }
      setArchiveOpen(false);
      toast.success("Outlet archived. Historical orders remain available.");
      router.refresh();
    });
  };

  return (
    <>
      <CardToolbar
        title={branch.name}
        description={`${branch.code} · ${branch.timezone}`}
        action={
          canManage ? (
            <>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  setError(null);
                  setDraft(toDraft(branch));
                  setOpen(true);
                }}
              >
                <Pencil aria-hidden /> Edit outlet
              </Button>
              <Button
                variant="outlineDestructive"
                size="sm"
                disabled={!branch.is_active || !canArchive}
                title={
                  archiveCheckFailed
                    ? "Could not verify another active outlet. Refresh and try again."
                    : !canArchive
                      ? "The last active outlet cannot be archived."
                      : undefined
                }
                onClick={() => setArchiveOpen(true)}
              >
                <Archive aria-hidden /> Archive
              </Button>
            </>
          ) : null
        }
      />
      {canManage && !canArchive ? (
        <CardContent className="pt-0">
          <InlineNotice tone={archiveCheckFailed ? "critical" : "info"}>
            {archiveCheckFailed
              ? "We could not confirm that another active outlet is available. Refresh the page before archiving this outlet."
              : "The last active outlet cannot be archived. This protects customer ordering and keeps the app connected to an active outlet."}
          </InlineNotice>
        </CardContent>
      ) : null}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent size="xl">
          <DialogHeader>
            <DialogTitle>Edit outlet details</DialogTitle>
            <DialogDescription>
              Changes apply to future quotes and customer app config. Existing
              orders keep their saved address, tax and delivery terms.
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={save}>
            <DialogBody className="space-y-5">
              {error ? (
                <InlineNotice tone="critical">{error}</InlineNotice>
              ) : null}
              <section className="space-y-3">
                <h3 className="text-sm font-semibold text-ink">
                  Outlet and contact
                </h3>
                <div className="grid gap-3 sm:grid-cols-2">
                  <Field label="Outlet name" required>
                    <Input
                      value={draft.name}
                      onChange={(e) => set("name", e.target.value)}
                      required
                      maxLength={120}
                    />
                  </Field>
                  <Field label="Legal name">
                    <Input
                      value={draft.legal_name}
                      onChange={(e) => set("legal_name", e.target.value)}
                      maxLength={180}
                    />
                  </Field>
                  <Field label="Phone" required>
                    <Input
                      value={draft.phone}
                      onChange={(e) => set("phone", e.target.value)}
                      placeholder="+919876543210"
                      required
                    />
                  </Field>
                  <Field label="Alternate phone">
                    <Input
                      value={draft.alternate_phone}
                      onChange={(e) => set("alternate_phone", e.target.value)}
                      placeholder="+919876543210"
                    />
                  </Field>
                  <Field label="WhatsApp">
                    <Input
                      value={draft.whatsapp_phone}
                      onChange={(e) => set("whatsapp_phone", e.target.value)}
                      placeholder="+919876543210"
                    />
                  </Field>
                  <Field label="Email">
                    <Input
                      type="email"
                      value={draft.email}
                      onChange={(e) => set("email", e.target.value)}
                    />
                  </Field>
                </div>
              </section>
              <section className="space-y-3">
                <h3 className="text-sm font-semibold text-ink">
                  Address and map pin
                </h3>
                <div className="grid gap-3 sm:grid-cols-2">
                  <Field label="Address line 1" required>
                    <Input
                      value={draft.address_line1}
                      onChange={(e) => set("address_line1", e.target.value)}
                      required
                    />
                  </Field>
                  <Field label="Address line 2">
                    <Input
                      value={draft.address_line2}
                      onChange={(e) => set("address_line2", e.target.value)}
                    />
                  </Field>
                  <Field label="Landmark">
                    <Input
                      value={draft.landmark}
                      onChange={(e) => set("landmark", e.target.value)}
                    />
                  </Field>
                  <Field label="City" required>
                    <Input
                      value={draft.city}
                      onChange={(e) => set("city", e.target.value)}
                      required
                    />
                  </Field>
                  <Field label="State" required>
                    <Input
                      value={draft.state}
                      onChange={(e) => set("state", e.target.value)}
                      required
                    />
                  </Field>
                  <Field label="Postal code" required>
                    <Input
                      value={draft.postal_code}
                      onChange={(e) => set("postal_code", e.target.value)}
                      required
                    />
                  </Field>
                  <Field
                    label="Latitude"
                    hint="Used for distance quotes and delivery zones."
                  >
                    <Input
                      type="number"
                      step="0.0000001"
                      min="-90"
                      max="90"
                      value={draft.latitude}
                      onChange={(e) => set("latitude", e.target.value)}
                      required
                    />
                  </Field>
                  <Field label="Longitude">
                    <Input
                      type="number"
                      step="0.0000001"
                      min="-180"
                      max="180"
                      value={draft.longitude}
                      onChange={(e) => set("longitude", e.target.value)}
                      required
                    />
                  </Field>
                  <Field label="Google Maps link" className="sm:col-span-2">
                    <Input
                      type="url"
                      value={draft.google_maps_url}
                      onChange={(e) => set("google_maps_url", e.target.value)}
                      placeholder="https://maps.google.com/..."
                    />
                  </Field>
                </div>
              </section>
              <section className="space-y-3">
                <h3 className="text-sm font-semibold text-ink">
                  Compliance and service
                </h3>
                <div className="grid gap-3 sm:grid-cols-2">
                  <Field label="GSTIN">
                    <Input
                      value={draft.gstin}
                      onChange={(e) =>
                        set("gstin", e.target.value.toUpperCase())
                      }
                      maxLength={15}
                    />
                  </Field>
                  <Field label="FSSAI licence">
                    <Input
                      value={draft.fssai_licence_no}
                      onChange={(e) => set("fssai_licence_no", e.target.value)}
                      maxLength={14}
                    />
                  </Field>
                  <Field label="FSSAI valid till">
                    <Input
                      type="date"
                      value={draft.fssai_valid_till}
                      onChange={(e) => set("fssai_valid_till", e.target.value)}
                    />
                  </Field>
                  <Field label="Timezone">
                    <Input
                      value={draft.timezone}
                      onChange={(e) => set("timezone", e.target.value)}
                      required
                      placeholder="Asia/Kolkata"
                    />
                  </Field>
                  <Field label="Service mode">
                    <Select
                      value={draft.service_mode}
                      onValueChange={(value) => set("service_mode", value)}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="BOTH">
                          Delivery and pickup
                        </SelectItem>
                        <SelectItem value="DELIVERY">Delivery only</SelectItem>
                        <SelectItem value="PICKUP">Pickup only</SelectItem>
                      </SelectContent>
                    </Select>
                  </Field>
                  <Field label="Default prep time (minutes)">
                    <Input
                      type="number"
                      min="1"
                      max="240"
                      value={draft.default_prep_minutes}
                      onChange={(e) =>
                        set("default_prep_minutes", e.target.value)
                      }
                    />
                  </Field>
                  <Field label="Rush buffer (minutes)">
                    <Input
                      type="number"
                      min="0"
                      max="180"
                      value={draft.rush_buffer_minutes}
                      onChange={(e) =>
                        set("rush_buffer_minutes", e.target.value)
                      }
                    />
                  </Field>
                  <Field
                    label="Max concurrent orders"
                    hint="Leave empty for unlimited."
                  >
                    <Input
                      type="number"
                      min="1"
                      max="100000"
                      value={draft.max_concurrent_orders}
                      onChange={(e) =>
                        set("max_concurrent_orders", e.target.value)
                      }
                    />
                  </Field>
                </div>
              </section>
            </DialogBody>
            <DialogFooter>
              <Button
                type="button"
                variant="secondary"
                onClick={() => setOpen(false)}
                disabled={saving}
              >
                Cancel
              </Button>
              <Button type="submit" loading={saving}>
                Save outlet
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={archiveOpen}
        onOpenChange={setArchiveOpen}
        title={`Archive ${branch.name}?`}
        description="This outlet stops serving new orders and disappears from active outlet selection. Historical orders, invoices and audit records are retained."
        confirmLabel="Archive outlet"
        confirmText="ARCHIVE"
        destructive
        loading={saving}
        onConfirm={archive}
      />
    </>
  );
}
