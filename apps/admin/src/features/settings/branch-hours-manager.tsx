"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Pencil, Plus, Trash2 } from "lucide-react";
import type { Database } from "@bitesbox/shared-types";
import { Button } from "@/components/ui/button";
import { CardContent, CardToolbar } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Field,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
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
import { EmptyState, InlineNotice } from "@/components/ui/states";
import {
  TBody,
  TD,
  TH,
  THead,
  TR,
  Table,
  TableWrap,
} from "@/components/ui/table";
import { toast } from "sonner";
import { deleteBranchHours, saveBranchHours } from "./settings-actions";

type Hour = Pick<
  Database["public"]["Tables"]["branch_hours"]["Row"],
  | "id"
  | "day_of_week"
  | "opens_at"
  | "closes_at"
  | "day_part"
  | "is_closed"
  | "closes_next_day"
>;
type Draft = {
  day_of_week: string;
  opens_at: string;
  closes_at: string;
  day_part: string;
  is_closed: boolean;
  closes_next_day: boolean;
};
const DAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];
const PARTS = [
  ["BREAKFAST", "Breakfast"],
  ["LUNCH", "Lunch"],
  ["SNACKS", "Snacks"],
  ["DINNER", "Dinner"],
  ["LATE_NIGHT", "Late night"],
  ["ALL_DAY", "All day"],
] as const;

function blankDraft(): Draft {
  return {
    day_of_week: "0",
    opens_at: "08:00",
    closes_at: "23:00",
    day_part: "ALL_DAY",
    is_closed: false,
    closes_next_day: false,
  };
}
function draftFor(hour: Hour): Draft {
  return {
    day_of_week: String(hour.day_of_week),
    opens_at: hour.opens_at.slice(0, 5),
    closes_at: hour.closes_at.slice(0, 5),
    day_part: hour.day_part,
    is_closed: hour.is_closed,
    closes_next_day: hour.closes_next_day,
  };
}

export function BranchHoursManager({
  hours,
  canManage,
  loadError = false,
}: {
  hours: Hour[];
  canManage: boolean;
  loadError?: boolean;
}) {
  const router = useRouter();
  const [open, setOpen] = React.useState(false);
  const [editing, setEditing] = React.useState<Hour | null>(null);
  const [deleteTarget, setDeleteTarget] = React.useState<Hour | null>(null);
  const [draft, setDraft] = React.useState<Draft>(blankDraft);
  const [formError, setFormError] = React.useState<string | null>(null);
  const [saving, startSaving] = React.useTransition();
  const set = <K extends keyof Draft>(key: K, value: Draft[K]) =>
    setDraft((current) => ({ ...current, [key]: value }));

  const openCreate = () => {
    setEditing(null);
    setDraft(blankDraft());
    setFormError(null);
    setOpen(true);
  };
  const openEdit = (hour: Hour) => {
    setEditing(hour);
    setDraft(draftFor(hour));
    setFormError(null);
    setOpen(true);
  };
  const save = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFormError(null);
    startSaving(async () => {
      const result = await saveBranchHours({
        ...draft,
        id: editing?.id,
        day_of_week: Number(draft.day_of_week),
      });
      if (!result.ok) {
        setFormError(result.message);
        return;
      }
      setOpen(false);
      toast.success(
        editing ? "Trading hours updated" : "Trading-hours slot added",
      );
      router.refresh();
    });
  };
  const remove = () => {
    if (!deleteTarget) return;
    startSaving(async () => {
      const result = await deleteBranchHours(deleteTarget.id);
      if (!result.ok) {
        toast.error(result.message);
        return;
      }
      setDeleteTarget(null);
      toast.success("Trading-hours slot deleted");
      router.refresh();
    });
  };

  return (
    <>
      <CardToolbar
        title="Trading hours"
        description="When the kitchen accepts orders. Holiday exceptions override these weekly hours. Changes apply to future order availability."
        action={
          canManage ? (
            <Button size="sm" onClick={openCreate}>
              <Plus aria-hidden /> Add hours
            </Button>
          ) : null
        }
      />
      <CardContent className="p-0">
        {loadError ? (
          <InlineNotice tone="critical" className="m-4">
            Trading hours could not be loaded. Refresh the page and try again.
          </InlineNotice>
        ) : hours.length === 0 ? (
          <EmptyState
            title="No trading hours configured"
            description="Customers will see the outlet as closed until a weekly service window is added."
            action={
              canManage ? (
                <Button size="sm" onClick={openCreate}>
                  <Plus aria-hidden /> Add hours
                </Button>
              ) : undefined
            }
          />
        ) : (
          <TableWrap className="rounded-none border-0">
            <Table>
              <THead>
                <TR className="hover:bg-transparent">
                  <TH>Day</TH>
                  <TH>Service</TH>
                  <TH>Opens</TH>
                  <TH>Closes</TH>
                  {canManage ? <TH className="w-28">Actions</TH> : null}
                </TR>
              </THead>
              <TBody>
                {hours.map((hour) => (
                  <TR key={hour.id}>
                    <TD className="text-[13px] font-medium">
                      {DAYS[hour.day_of_week]}
                    </TD>
                    <TD>
                      <Badge tone="neutral">
                        {hour.day_part.replace("_", " ").toLowerCase()}
                      </Badge>
                      {hour.is_closed ? (
                        <Badge tone="caution" className="ml-1.5">
                          Closed
                        </Badge>
                      ) : null}
                    </TD>
                    <TD className="tnum text-[12.5px]">
                      {hour.is_closed ? "—" : hour.opens_at.slice(0, 5)}
                    </TD>
                    <TD className="tnum text-[12.5px]">
                      {hour.is_closed
                        ? "—"
                        : `${hour.closes_at.slice(0, 5)}${hour.closes_next_day ? " (next day)" : ""}`}
                    </TD>
                    {canManage ? (
                      <TD>
                        <div className="flex gap-1">
                          <Button
                            size="iconSm"
                            variant="ghost"
                            aria-label={`Edit ${DAYS[hour.day_of_week]} hours`}
                            onClick={() => openEdit(hour)}
                          >
                            <Pencil aria-hidden />
                          </Button>
                          <Button
                            size="iconSm"
                            variant="ghost"
                            aria-label={`Delete ${DAYS[hour.day_of_week]} hours`}
                            onClick={() => setDeleteTarget(hour)}
                          >
                            <Trash2 aria-hidden />
                          </Button>
                        </div>
                      </TD>
                    ) : null}
                  </TR>
                ))}
              </TBody>
            </Table>
          </TableWrap>
        )}
      </CardContent>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent size="md">
          <DialogHeader>
            <DialogTitle>
              {editing ? "Edit trading hours" : "Add trading hours"}
            </DialogTitle>
            <DialogDescription>
              These weekly hours drive live ordering and scheduled-order
              availability.
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={save}>
            <DialogBody className="space-y-4">
              {formError ? (
                <InlineNotice tone="critical">{formError}</InlineNotice>
              ) : null}
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label="Day">
                  <Select
                    value={draft.day_of_week}
                    onValueChange={(value) => set("day_of_week", value)}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {DAYS.map((day, index) => (
                        <SelectItem key={day} value={String(index)}>
                          {day}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label="Service period">
                  <Select
                    value={draft.day_part}
                    onValueChange={(value) => set("day_part", value)}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {PARTS.map(([value, label]) => (
                        <SelectItem key={value} value={value}>
                          {label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label="Opens">
                  <Input
                    type="time"
                    value={draft.opens_at}
                    disabled={draft.is_closed}
                    onChange={(e) => set("opens_at", e.target.value)}
                    required
                  />
                </Field>
                <Field label="Closes">
                  <Input
                    type="time"
                    value={draft.closes_at}
                    disabled={draft.is_closed}
                    onChange={(e) => set("closes_at", e.target.value)}
                    required
                  />
                </Field>
              </div>
              <div className="flex flex-wrap gap-6 border-t border-hairline pt-4">
                <label className="flex items-center gap-2 text-sm">
                  <Switch
                    checked={draft.closes_next_day}
                    disabled={draft.is_closed}
                    onCheckedChange={(value) => set("closes_next_day", value)}
                  />{" "}
                  Closes next day
                </label>
                <label className="flex items-center gap-2 text-sm">
                  <Switch
                    checked={draft.is_closed}
                    onCheckedChange={(value) => set("is_closed", value)}
                  />{" "}
                  Closed this service period
                </label>
              </div>
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
                Save hours
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={deleteTarget !== null}
        onOpenChange={(value) => !value && setDeleteTarget(null)}
        title="Delete this weekly service period?"
        description="This removes the selected weekly window from future ordering. You can add it again at any time."
        confirmLabel="Delete hours"
        confirmText="DELETE"
        destructive
        loading={saving}
        onConfirm={remove}
      />
    </>
  );
}
