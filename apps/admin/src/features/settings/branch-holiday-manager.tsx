"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { CalendarPlus, Pencil, Plus, Trash2 } from "lucide-react";
import type { Database } from "@bitesbox/shared-types";
import { Button } from "@/components/ui/button";
import { CardContent, CardToolbar } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Field, Input, Switch } from "@/components/ui/form-controls";
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
import { deleteBranchHoliday, saveBranchHoliday } from "./settings-actions";

type Holiday = Pick<
  Database["public"]["Tables"]["branch_holidays"]["Row"],
  "id" | "holiday_on" | "label" | "is_closed" | "opens_at" | "closes_at"
>;
type Draft = {
  holiday_on: string;
  label: string;
  is_closed: boolean;
  opens_at: string;
  closes_at: string;
};
const blank: Draft = {
  holiday_on: "",
  label: "",
  is_closed: true,
  opens_at: "09:00",
  closes_at: "17:00",
};
function draftFor(value: Holiday): Draft {
  return {
    holiday_on: value.holiday_on,
    label: value.label,
    is_closed: value.is_closed,
    opens_at: value.opens_at?.slice(0, 5) ?? "09:00",
    closes_at: value.closes_at?.slice(0, 5) ?? "17:00",
  };
}

export function BranchHolidayManager({
  holidays,
  canManage,
  loadError = false,
}: {
  holidays: Holiday[];
  canManage: boolean;
  loadError?: boolean;
}) {
  const router = useRouter();
  const [open, setOpen] = React.useState(false);
  const [editing, setEditing] = React.useState<Holiday | null>(null);
  const [deleteTarget, setDeleteTarget] = React.useState<Holiday | null>(null);
  const [draft, setDraft] = React.useState<Draft>(blank);
  const [formError, setFormError] = React.useState<string | null>(null);
  const [saving, startSaving] = React.useTransition();
  const set = <K extends keyof Draft>(key: K, value: Draft[K]) =>
    setDraft((current) => ({ ...current, [key]: value }));

  const create = () => {
    setEditing(null);
    setDraft({ ...blank });
    setFormError(null);
    setOpen(true);
  };
  const edit = (holiday: Holiday) => {
    setEditing(holiday);
    setDraft(draftFor(holiday));
    setFormError(null);
    setOpen(true);
  };
  const save = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFormError(null);
    startSaving(async () => {
      const result = await saveBranchHoliday({
        ...draft,
        id: editing?.id,
        opens_at: draft.is_closed ? null : draft.opens_at,
        closes_at: draft.is_closed ? null : draft.closes_at,
      });
      if (!result.ok) {
        setFormError(result.message);
        return;
      }
      setOpen(false);
      toast.success(
        editing ? "Holiday exception updated" : "Holiday exception added",
      );
      router.refresh();
    });
  };
  const remove = () => {
    if (!deleteTarget) return;
    startSaving(async () => {
      const result = await deleteBranchHoliday(deleteTarget.id);
      if (!result.ok) {
        toast.error(result.message);
        return;
      }
      setDeleteTarget(null);
      toast.success("Holiday exception deleted");
      router.refresh();
    });
  };

  return (
    <>
      <CardToolbar
        title="Holiday exceptions"
        description="A dated exception overrides weekly trading hours. Use it to close for a holiday or set special opening hours."
        action={
          canManage ? (
            <Button size="sm" onClick={create}>
              <Plus aria-hidden /> Add exception
            </Button>
          ) : null
        }
      />
      <CardContent className="p-0">
        {loadError ? (
          <InlineNotice tone="critical" className="m-4">
            Holiday exceptions could not be loaded. Refresh the page and try
            again.
          </InlineNotice>
        ) : holidays.length === 0 ? (
          <EmptyState
            icon={CalendarPlus}
            title="No holiday exceptions"
            description="Weekly trading hours will apply on every date until an exception is added."
            action={
              canManage ? (
                <Button size="sm" onClick={create}>
                  <Plus aria-hidden /> Add exception
                </Button>
              ) : undefined
            }
          />
        ) : (
          <TableWrap className="rounded-none border-0">
            <Table>
              <THead>
                <TR className="hover:bg-transparent">
                  <TH>Date</TH>
                  <TH>Exception</TH>
                  <TH>Service</TH>
                  {canManage ? <TH className="w-28">Actions</TH> : null}
                </TR>
              </THead>
              <TBody>
                {holidays.map((holiday) => (
                  <TR key={holiday.id}>
                    <TD className="tnum text-[13px]">{holiday.holiday_on}</TD>
                    <TD className="text-[13px] font-medium">{holiday.label}</TD>
                    <TD>
                      <Badge tone={holiday.is_closed ? "caution" : "positive"}>
                        {holiday.is_closed
                          ? "Closed"
                          : `${holiday.opens_at?.slice(0, 5)}–${holiday.closes_at?.slice(0, 5)}`}
                      </Badge>
                    </TD>
                    {canManage ? (
                      <TD>
                        <div className="flex gap-1">
                          <Button
                            size="iconSm"
                            variant="ghost"
                            aria-label={`Edit ${holiday.label}`}
                            onClick={() => edit(holiday)}
                          >
                            <Pencil aria-hidden />
                          </Button>
                          <Button
                            size="iconSm"
                            variant="ghost"
                            aria-label={`Delete ${holiday.label}`}
                            onClick={() => setDeleteTarget(holiday)}
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
              {editing ? "Edit holiday exception" : "Add holiday exception"}
            </DialogTitle>
            <DialogDescription>
              The exception affects order availability only on this date.
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={save}>
            <DialogBody className="space-y-4">
              {formError ? (
                <InlineNotice tone="critical">{formError}</InlineNotice>
              ) : null}
              <Field label="Date" required>
                <Input
                  type="date"
                  value={draft.holiday_on}
                  onChange={(e) => set("holiday_on", e.target.value)}
                  required
                />
              </Field>
              <Field label="Label" required>
                <Input
                  value={draft.label}
                  onChange={(e) => set("label", e.target.value)}
                  required
                  maxLength={120}
                  placeholder="Diwali"
                />
              </Field>
              <label className="flex items-center gap-2 text-sm">
                <Switch
                  checked={draft.is_closed}
                  onCheckedChange={(value) => set("is_closed", value)}
                />{" "}
                Closed all day
              </label>
              {!draft.is_closed ? (
                <div className="grid gap-3 sm:grid-cols-2">
                  <Field label="Opens" required>
                    <Input
                      type="time"
                      value={draft.opens_at}
                      onChange={(e) => set("opens_at", e.target.value)}
                      required
                    />
                  </Field>
                  <Field label="Closes" required>
                    <Input
                      type="time"
                      value={draft.closes_at}
                      onChange={(e) => set("closes_at", e.target.value)}
                      required
                    />
                  </Field>
                </div>
              ) : null}
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
                Save exception
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={deleteTarget !== null}
        onOpenChange={(value) => !value && setDeleteTarget(null)}
        title="Delete this holiday exception?"
        description="The outlet will fall back to its weekly trading hours on this date."
        confirmLabel="Delete exception"
        confirmText="DELETE"
        destructive
        loading={saving}
        onConfirm={remove}
      />
    </>
  );
}
