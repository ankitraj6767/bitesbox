"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { MapPinned, Pencil, Plus, Trash2 } from "lucide-react";
import type { Database } from "@bitesbox/shared-types";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardToolbar } from "@/components/ui/card";
import {
  Field,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
  Textarea,
} from "@/components/ui/form-controls";
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  ConfirmDialog,
} from "@/components/ui/overlays";
import { EmptyState, ErrorState, InlineNotice } from "@/components/ui/states";
import {
  Table,
  TableWrap,
  TBody,
  TD,
  TH,
  THead,
  TR,
} from "@/components/ui/table";
import { money } from "@/lib/utils";
import {
  deleteDeliveryZone,
  saveDeliveryZone,
  updateDeliveryZoneStatus,
} from "./delivery-zone-actions";
import {
  deliveryZoneFormSchema,
  type DeliveryZoneFormValues,
} from "./delivery-zone-schema";

type ZoneRow = Pick<
  Database["public"]["Tables"]["delivery_zones"]["Row"],
  | "id"
  | "branch_id"
  | "name"
  | "description"
  | "kind"
  | "min_distance_km"
  | "max_distance_km"
  | "polygon"
  | "delivery_fee"
  | "min_order_amount"
  | "free_delivery_threshold"
  | "per_km_surcharge"
  | "surcharge_after_km"
  | "peak_surcharge"
  | "peak_starts_at"
  | "peak_ends_at"
  | "dynamic_surcharge"
  | "base_eta_minutes"
  | "extra_eta_minutes"
  | "cod_enabled"
  | "max_cod_amount"
  | "is_serviceable"
  | "is_active"
  | "priority"
>;

type Draft = {
  name: string;
  description: string;
  kind: "RADIUS" | "POLYGON";
  min_distance_km: string;
  max_distance_km: string;
  polygon: string;
  delivery_fee: string;
  min_order_amount: string;
  free_delivery_threshold: string;
  per_km_surcharge: string;
  surcharge_after_km: string;
  peak_surcharge: string;
  peak_starts_at: string;
  peak_ends_at: string;
  dynamic_surcharge: string;
  base_eta_minutes: string;
  extra_eta_minutes: string;
  cod_enabled: boolean;
  max_cod_amount: string;
  is_serviceable: boolean;
  is_active: boolean;
  priority: string;
};

const DEFAULT_POLYGON = JSON.stringify(
  [
    [
      [85.51, 25.46],
      [85.54, 25.46],
      [85.53, 25.49],
    ],
  ],
  null,
  2,
);

function newDraft(priority: number): Draft {
  return {
    name: "",
    description: "",
    kind: "RADIUS",
    min_distance_km: "0",
    max_distance_km: "3",
    polygon: DEFAULT_POLYGON,
    delivery_fee: "20",
    min_order_amount: "99",
    free_delivery_threshold: "349",
    per_km_surcharge: "0",
    surcharge_after_km: "",
    peak_surcharge: "0",
    peak_starts_at: "",
    peak_ends_at: "",
    dynamic_surcharge: "0",
    base_eta_minutes: "30",
    extra_eta_minutes: "0",
    cod_enabled: true,
    max_cod_amount: "2000",
    is_serviceable: true,
    is_active: true,
    priority: String(priority),
  };
}

function draftForZone(zone: ZoneRow): Draft {
  return {
    name: zone.name,
    description: zone.description ?? "",
    kind: zone.kind,
    min_distance_km:
      zone.min_distance_km === null ? "" : String(zone.min_distance_km),
    max_distance_km:
      zone.max_distance_km === null ? "" : String(zone.max_distance_km),
    polygon: zone.polygon
      ? JSON.stringify(zone.polygon, null, 2)
      : DEFAULT_POLYGON,
    delivery_fee: String(zone.delivery_fee),
    min_order_amount: String(zone.min_order_amount),
    free_delivery_threshold:
      zone.free_delivery_threshold === null
        ? ""
        : String(zone.free_delivery_threshold),
    per_km_surcharge: String(zone.per_km_surcharge),
    surcharge_after_km:
      zone.surcharge_after_km === null ? "" : String(zone.surcharge_after_km),
    peak_surcharge: String(zone.peak_surcharge),
    peak_starts_at: zone.peak_starts_at?.slice(0, 5) ?? "",
    peak_ends_at: zone.peak_ends_at?.slice(0, 5) ?? "",
    dynamic_surcharge: String(zone.dynamic_surcharge),
    base_eta_minutes: String(zone.base_eta_minutes),
    extra_eta_minutes: String(zone.extra_eta_minutes),
    cod_enabled: zone.cod_enabled,
    max_cod_amount:
      zone.max_cod_amount === null ? "" : String(zone.max_cod_amount),
    is_serviceable: zone.is_serviceable,
    is_active: zone.is_active,
    priority: String(zone.priority),
  };
}

function optionalNumber(value: string): number | null {
  if (value.trim() === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : Number.NaN;
}

function payloadFromDraft(draft: Draft, id?: string): unknown {
  let parsedPolygon: unknown = null;
  if (draft.kind === "POLYGON") {
    try {
      parsedPolygon = JSON.parse(draft.polygon) as unknown;
    } catch {
      parsedPolygon = undefined;
    }
  }

  return {
    ...(id ? { id } : {}),
    name: draft.name,
    description: draft.description.trim() || null,
    kind: draft.kind,
    min_distance_km:
      draft.kind === "RADIUS" ? optionalNumber(draft.min_distance_km) : null,
    max_distance_km:
      draft.kind === "RADIUS" ? optionalNumber(draft.max_distance_km) : null,
    polygon: draft.kind === "POLYGON" ? parsedPolygon : null,
    delivery_fee: Number(draft.delivery_fee),
    min_order_amount: Number(draft.min_order_amount),
    free_delivery_threshold: optionalNumber(draft.free_delivery_threshold),
    per_km_surcharge: Number(draft.per_km_surcharge),
    surcharge_after_km: optionalNumber(draft.surcharge_after_km),
    peak_surcharge: Number(draft.peak_surcharge),
    peak_starts_at: draft.peak_starts_at || null,
    peak_ends_at: draft.peak_ends_at || null,
    dynamic_surcharge: Number(draft.dynamic_surcharge),
    base_eta_minutes: Number(draft.base_eta_minutes),
    extra_eta_minutes: Number(draft.extra_eta_minutes),
    cod_enabled: draft.cod_enabled,
    max_cod_amount: optionalNumber(draft.max_cod_amount),
    is_serviceable: draft.is_serviceable,
    is_active: draft.is_active,
    priority: Number(draft.priority),
  };
}

export function DeliveryZoneManager({
  zones,
  branchId,
  branchName,
  canManage,
  loadError,
}: {
  zones: ZoneRow[];
  branchId: string | null;
  branchName: string;
  canManage: boolean;
  loadError?: boolean;
}) {
  const router = useRouter();
  const [editorOpen, setEditorOpen] = React.useState(false);
  const [editingZone, setEditingZone] = React.useState<ZoneRow | null>(null);
  const [draft, setDraft] = React.useState<Draft>(() => newDraft(10));
  const [formError, setFormError] = React.useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = React.useState<ZoneRow | null>(null);
  const [pendingId, setPendingId] = React.useState<string | null>(null);
  const [saving, startSaving] = React.useTransition();

  const openNew = () => {
    const nextPriority =
      zones.reduce((highest, zone) => Math.max(highest, zone.priority), 0) + 10;
    setEditingZone(null);
    setDraft(newDraft(nextPriority));
    setFormError(null);
    setEditorOpen(true);
  };

  const openEdit = (zone: ZoneRow) => {
    setEditingZone(zone);
    setDraft(draftForZone(zone));
    setFormError(null);
    setEditorOpen(true);
  };

  const submit = () => {
    const parsed = deliveryZoneFormSchema.safeParse(
      payloadFromDraft(draft, editingZone?.id),
    );
    if (!parsed.success) {
      setFormError(
        parsed.error.issues[0]?.message ?? "Review the delivery zone details.",
      );
      return;
    }

    setFormError(null);
    startSaving(async () => {
      try {
        const result = await saveDeliveryZone(
          parsed.data satisfies DeliveryZoneFormValues,
        );
        if (!result.ok) {
          setFormError(result.message);
          return;
        }
        toast.success(
          editingZone ? "Delivery zone updated" : "Delivery zone created",
        );
        setEditorOpen(false);
        router.refresh();
      } catch {
        setFormError("The delivery zone could not be saved. Please try again.");
      }
    });
  };

  const changeStatus = (
    zone: ZoneRow,
    key: "is_active" | "is_serviceable",
    value: boolean,
  ) => {
    setPendingId(zone.id);
    startSaving(async () => {
      try {
        const result = await updateDeliveryZoneStatus({
          id: zone.id,
          [key]: value,
        });
        if (!result.ok) {
          toast.error(result.message);
          return;
        }
        toast.success(
          key === "is_active"
            ? value
              ? "Zone enabled"
              : "Zone paused"
            : "Serviceability updated",
        );
        router.refresh();
      } catch {
        toast.error("The zone status could not be changed. Please try again.");
      } finally {
        setPendingId(null);
      }
    });
  };

  const removeZone = () => {
    if (!deleteTarget) return;
    setPendingId(deleteTarget.id);
    startSaving(async () => {
      try {
        const result = await deleteDeliveryZone(deleteTarget.id);
        if (!result.ok) {
          toast.error(result.message);
          return;
        }
        toast.success("Delivery zone deleted from future serviceability");
        setDeleteTarget(null);
        router.refresh();
      } catch {
        toast.error(
          "The delivery zone could not be deleted. Please try again.",
        );
      } finally {
        setPendingId(null);
      }
    });
  };

  const setDraftValue = <K extends keyof Draft>(key: K, value: Draft[K]) =>
    setDraft((current) => ({ ...current, [key]: value }));

  return (
    <>
      <Card>
        <CardToolbar
          title="Delivery zones"
          description={`Fees and serviceability for ${branchName}. Changes apply to new delivery quotes immediately; confirmed orders keep their saved totals. Lower priority numbers win when zones overlap.`}
          action={
            canManage && branchId ? (
              <Button size="sm" onClick={openNew}>
                <Plus aria-hidden />
                Add zone
              </Button>
            ) : null
          }
        />
        <CardContent className="p-0">
          {loadError ? (
            <ErrorState
              title="Could not load delivery zones"
              message="Refresh the page and try again."
            />
          ) : zones.length === 0 ? (
            <EmptyState
              icon={MapPinned}
              title="No delivery zones for this outlet"
              description={
                canManage
                  ? "Add a radius or polygon zone to control serviceability and delivery pricing."
                  : "Ask a branch manager to configure delivery serviceability."
              }
              action={
                canManage && branchId ? (
                  <Button size="sm" onClick={openNew}>
                    <Plus aria-hidden /> Add zone
                  </Button>
                ) : undefined
              }
            />
          ) : (
            <TableWrap className="rounded-none border-0">
              <Table>
                <THead>
                  <TR className="hover:bg-transparent">
                    <TH>Zone</TH>
                    <TH>Distance</TH>
                    <TH numeric>Fee</TH>
                    <TH numeric>Min order</TH>
                    <TH numeric>Free above</TH>
                    <TH numeric>ETA</TH>
                    <TH>Cash on delivery</TH>
                    <TH>State</TH>
                    {canManage ? <TH className="w-28">Actions</TH> : null}
                  </TR>
                </THead>
                <TBody>
                  {zones.map((zone) => {
                    const state = !zone.is_active
                      ? "Paused"
                      : zone.is_serviceable
                        ? "Serviceable"
                        : "Not serviceable";
                    const stateTone = !zone.is_active
                      ? "neutral"
                      : zone.is_serviceable
                        ? "positive"
                        : "caution";
                    return (
                      <TR key={zone.id}>
                        <TD>
                          <span className="block text-[13px] font-medium text-ink">
                            {zone.name}
                          </span>
                          <span className="block max-w-56 truncate text-[11.5px] text-ink-muted">
                            {zone.description ??
                              (zone.kind === "RADIUS"
                                ? "Radius zone"
                                : "Polygon zone")}
                          </span>
                        </TD>
                        <TD className="text-[12.5px]">
                          {zone.kind === "RADIUS"
                            ? `${zone.min_distance_km}–${zone.max_distance_km} km`
                            : "Geofenced"}
                        </TD>
                        <TD numeric className="text-[13px] font-semibold">
                          {money(zone.delivery_fee)}
                          {Number(zone.peak_surcharge) > 0 ? (
                            <span className="block text-[11px] font-normal text-caution">
                              +{money(zone.peak_surcharge)} peak
                            </span>
                          ) : null}
                          {Number(zone.dynamic_surcharge) > 0 ? (
                            <span className="block text-[11px] font-normal text-caution">
                              +{money(zone.dynamic_surcharge)} live
                            </span>
                          ) : null}
                        </TD>
                        <TD numeric className="text-[12.5px]">
                          {money(zone.min_order_amount)}
                        </TD>
                        <TD numeric className="text-[12.5px]">
                          {zone.free_delivery_threshold === null
                            ? "—"
                            : money(zone.free_delivery_threshold)}
                        </TD>
                        <TD numeric className="text-[12.5px]">
                          {zone.base_eta_minutes + zone.extra_eta_minutes}m
                        </TD>
                        <TD>
                          {zone.cod_enabled ? (
                            <Badge tone="positive">
                              {zone.max_cod_amount === null
                                ? "No limit"
                                : `Up to ${money(zone.max_cod_amount)}`}
                            </Badge>
                          ) : (
                            <Badge tone="neutral">Not allowed</Badge>
                          )}
                        </TD>
                        <TD>
                          <div className="flex min-w-36 flex-col gap-2">
                            <div className="flex items-center gap-2">
                              <Badge
                                tone={stateTone}
                                dot={zone.is_active && zone.is_serviceable}
                              >
                                {state}
                              </Badge>
                            </div>
                            {canManage ? (
                              <div className="flex flex-wrap gap-x-3 gap-y-1.5 text-[11px] text-ink-muted">
                                <div className="inline-flex items-center gap-1.5">
                                  <Switch
                                    checked={zone.is_active}
                                    disabled={saving || pendingId === zone.id}
                                    onCheckedChange={(value) =>
                                      changeStatus(zone, "is_active", value)
                                    }
                                    aria-label={`Enable ${zone.name}`}
                                    className="scale-75 origin-left"
                                  />
                                  Live
                                </div>
                                <div className="inline-flex items-center gap-1.5">
                                  <Switch
                                    checked={zone.is_serviceable}
                                    disabled={
                                      saving ||
                                      pendingId === zone.id ||
                                      !zone.is_active
                                    }
                                    onCheckedChange={(value) =>
                                      changeStatus(
                                        zone,
                                        "is_serviceable",
                                        value,
                                      )
                                    }
                                    aria-label={`Make ${zone.name} serviceable`}
                                    className="scale-75 origin-left"
                                  />
                                  Accept orders
                                </div>
                              </div>
                            ) : null}
                          </div>
                        </TD>
                        {canManage ? (
                          <TD>
                            <div className="flex items-center gap-1">
                              <Button
                                variant="ghost"
                                size="iconSm"
                                disabled={saving}
                                onClick={() => openEdit(zone)}
                                aria-label={`Edit ${zone.name}`}
                              >
                                <Pencil aria-hidden />
                              </Button>
                              <Button
                                variant="ghost"
                                size="iconSm"
                                disabled={saving}
                                onClick={() => setDeleteTarget(zone)}
                                aria-label={`Delete ${zone.name}`}
                                className="text-critical hover:bg-critical-soft hover:text-critical"
                              >
                                <Trash2 aria-hidden />
                              </Button>
                            </div>
                          </TD>
                        ) : null}
                      </TR>
                    );
                  })}
                </TBody>
              </Table>
            </TableWrap>
          )}
        </CardContent>
      </Card>

      <Dialog open={editorOpen} onOpenChange={setEditorOpen}>
        <DialogContent size="xl">
          <DialogHeader>
            <DialogTitle>
              {editingZone ? "Edit delivery zone" : "Add delivery zone"}
            </DialogTitle>
            <DialogDescription>
              Updates affect future quotes for {branchName} as soon as they are
              saved. Existing orders retain their confirmed delivery terms.
            </DialogDescription>
          </DialogHeader>
          <DialogBody className="space-y-5">
            {formError ? (
              <InlineNotice tone="critical">{formError}</InlineNotice>
            ) : null}
            <section className="space-y-3">
              <h3 className="text-[13px] font-semibold text-ink">
                Zone and coverage
              </h3>
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label="Zone name" required htmlFor="zone-name">
                  <Input
                    id="zone-name"
                    maxLength={100}
                    value={draft.name}
                    onChange={(event) =>
                      setDraftValue("name", event.target.value)
                    }
                  />
                </Field>
                <Field label="Coverage type" htmlFor="zone-kind">
                  <Select
                    value={draft.kind}
                    onValueChange={(value) =>
                      setDraftValue("kind", value as "RADIUS" | "POLYGON")
                    }
                  >
                    <SelectTrigger id="zone-kind" aria-label="Coverage type">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="RADIUS">Distance radius</SelectItem>
                      <SelectItem value="POLYGON">Map polygon</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
                <Field
                  label="Description"
                  htmlFor="zone-description"
                  className="sm:col-span-2"
                >
                  <Textarea
                    id="zone-description"
                    maxLength={500}
                    rows={2}
                    value={draft.description}
                    onChange={(event) =>
                      setDraftValue("description", event.target.value)
                    }
                  />
                </Field>
                {draft.kind === "RADIUS" ? (
                  <>
                    <NumberField
                      id="zone-min-distance"
                      label="From distance (km)"
                      value={draft.min_distance_km}
                      onChange={(value) =>
                        setDraftValue("min_distance_km", value)
                      }
                      step="0.1"
                    />
                    <NumberField
                      id="zone-max-distance"
                      label="Through distance (km)"
                      value={draft.max_distance_km}
                      onChange={(value) =>
                        setDraftValue("max_distance_km", value)
                      }
                      step="0.1"
                    />
                  </>
                ) : (
                  <Field
                    label="Outer ring coordinates (JSON)"
                    htmlFor="zone-polygon"
                    hint="Use one ring: [[[longitude, latitude], ...]]. At least three points are required. Polygon holes are not supported."
                  >
                    <Textarea
                      id="zone-polygon"
                      rows={6}
                      spellCheck={false}
                      className="font-mono text-[12px]"
                      value={draft.polygon}
                      onChange={(event) =>
                        setDraftValue("polygon", event.target.value)
                      }
                    />
                  </Field>
                )}
                <NumberField
                  id="zone-priority"
                  label="Priority"
                  value={draft.priority}
                  onChange={(value) => setDraftValue("priority", value)}
                  step="1"
                  hint="Lower numbers win when coverage overlaps."
                />
              </div>
            </section>

            <section className="space-y-3 border-t border-hairline pt-4">
              <h3 className="text-[13px] font-semibold text-ink">
                Pricing and delivery
              </h3>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <NumberField
                  id="zone-fee"
                  label="Delivery fee (₹)"
                  value={draft.delivery_fee}
                  onChange={(value) => setDraftValue("delivery_fee", value)}
                  step="0.01"
                />
                <NumberField
                  id="zone-min-order"
                  label="Minimum order (₹)"
                  value={draft.min_order_amount}
                  onChange={(value) => setDraftValue("min_order_amount", value)}
                  step="0.01"
                />
                <NumberField
                  id="zone-free-threshold"
                  label="Free delivery above (₹)"
                  value={draft.free_delivery_threshold}
                  onChange={(value) =>
                    setDraftValue("free_delivery_threshold", value)
                  }
                  step="0.01"
                  hint="Leave blank to disable free delivery."
                />
                <NumberField
                  id="zone-per-km"
                  label="Per-km surcharge (₹)"
                  value={draft.per_km_surcharge}
                  onChange={(value) => setDraftValue("per_km_surcharge", value)}
                  step="0.01"
                />
                <NumberField
                  id="zone-after-km"
                  label="Surcharge starts after (km)"
                  value={draft.surcharge_after_km}
                  onChange={(value) =>
                    setDraftValue("surcharge_after_km", value)
                  }
                  step="0.1"
                />
                <NumberField
                  id="zone-dynamic-surcharge"
                  label="Live operations surcharge (₹)"
                  value={draft.dynamic_surcharge}
                  onChange={(value) =>
                    setDraftValue("dynamic_surcharge", value)
                  }
                  step="0.01"
                  hint="Added to new quotes immediately; set to zero to remove."
                />
                <NumberField
                  id="zone-peak-surcharge"
                  label="Peak surcharge (₹)"
                  value={draft.peak_surcharge}
                  onChange={(value) => setDraftValue("peak_surcharge", value)}
                  step="0.01"
                />
                <Field label="Peak starts" htmlFor="zone-peak-start">
                  <Input
                    id="zone-peak-start"
                    type="time"
                    value={draft.peak_starts_at}
                    onChange={(event) =>
                      setDraftValue("peak_starts_at", event.target.value)
                    }
                  />
                </Field>
                <Field label="Peak ends" htmlFor="zone-peak-end">
                  <Input
                    id="zone-peak-end"
                    type="time"
                    value={draft.peak_ends_at}
                    onChange={(event) =>
                      setDraftValue("peak_ends_at", event.target.value)
                    }
                  />
                </Field>
              </div>
            </section>

            <section className="space-y-3 border-t border-hairline pt-4">
              <h3 className="text-[13px] font-semibold text-ink">
                Timing, payment, and availability
              </h3>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <NumberField
                  id="zone-base-eta"
                  label="Base ETA (minutes)"
                  value={draft.base_eta_minutes}
                  onChange={(value) => setDraftValue("base_eta_minutes", value)}
                  step="1"
                />
                <NumberField
                  id="zone-extra-eta"
                  label="Additional ETA (minutes)"
                  value={draft.extra_eta_minutes}
                  onChange={(value) =>
                    setDraftValue("extra_eta_minutes", value)
                  }
                  step="1"
                />
                <NumberField
                  id="zone-max-cod"
                  label="Maximum COD order (₹)"
                  value={draft.max_cod_amount}
                  onChange={(value) => setDraftValue("max_cod_amount", value)}
                  step="0.01"
                  hint="Leave blank for no COD amount limit."
                />
                <SwitchField
                  label="Cash on delivery"
                  checked={draft.cod_enabled}
                  onChange={(value) => setDraftValue("cod_enabled", value)}
                />
                <SwitchField
                  label="Accept orders in this zone"
                  checked={draft.is_serviceable}
                  onChange={(value) => setDraftValue("is_serviceable", value)}
                />
                <SwitchField
                  label="Zone active"
                  checked={draft.is_active}
                  onChange={(value) => setDraftValue("is_active", value)}
                />
              </div>
            </section>
          </DialogBody>
          <DialogFooter>
            <Button
              variant="secondary"
              onClick={() => setEditorOpen(false)}
              disabled={saving}
            >
              Cancel
            </Button>
            <Button onClick={submit} loading={saving}>
              {editingZone ? "Save changes" : "Create zone"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={deleteTarget !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteTarget(null);
        }}
        title="Delete delivery zone?"
        description={
          deleteTarget
            ? `“${deleteTarget.name}” will stop matching new delivery quotes immediately. Historical orders keep their saved zone and totals. The zone is archived in the audit trail.`
            : undefined
        }
        confirmLabel="Delete zone"
        confirmText={deleteTarget?.name}
        destructive
        loading={saving && pendingId === deleteTarget?.id}
        onConfirm={removeZone}
      />
    </>
  );
}

function NumberField({
  id,
  label,
  value,
  onChange,
  step,
  hint,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  step: string;
  hint?: string;
}) {
  return (
    <Field label={label} htmlFor={id} hint={hint}>
      <Input
        id={id}
        type="number"
        inputMode="decimal"
        step={step}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
    </Field>
  );
}

function SwitchField({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-lg border border-hairline px-3 py-2.5">
      <span className="text-[12.5px] font-medium text-ink">{label}</span>
      <Switch checked={checked} onCheckedChange={onChange} aria-label={label} />
    </div>
  );
}
