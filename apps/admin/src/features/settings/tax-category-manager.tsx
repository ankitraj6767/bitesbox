"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Archive, Pencil, Plus, Star } from "lucide-react";
import type { Database } from "@bitesbox/shared-types";
import { Button } from "@/components/ui/button";
import { CardContent, CardToolbar } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Field, Input, Switch, Textarea } from "@/components/ui/form-controls";
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
import {
  archiveTaxCategory,
  saveTaxCategory,
  setDefaultTaxCategory,
} from "./settings-actions";

type TaxCategory = Pick<
  Database["public"]["Tables"]["tax_categories"]["Row"],
  | "id"
  | "code"
  | "name"
  | "description"
  | "rate"
  | "cgst_rate"
  | "sgst_rate"
  | "igst_rate"
  | "cess_rate"
  | "hsn_sac_code"
  | "is_inclusive"
  | "is_default"
  | "is_active"
>;
type Draft = {
  code: string;
  name: string;
  description: string;
  cgst: string;
  sgst: string;
  igst: string;
  cess: string;
  hsn_sac_code: string;
  is_inclusive: boolean;
};
const blank: Draft = {
  code: "",
  name: "",
  description: "",
  cgst: "2.5",
  sgst: "2.5",
  igst: "0",
  cess: "0",
  hsn_sac_code: "",
  is_inclusive: true,
};
const percentage = (value: number) =>
  (value * 100).toFixed(2).replace(/\.00$/, "");
function draftFor(tax: TaxCategory): Draft {
  return {
    code: tax.code,
    name: tax.name,
    description: tax.description ?? "",
    cgst: percentage(tax.cgst_rate),
    sgst: percentage(tax.sgst_rate),
    igst: percentage(tax.igst_rate),
    cess: percentage(tax.cess_rate),
    hsn_sac_code: tax.hsn_sac_code ?? "",
    is_inclusive: tax.is_inclusive,
  };
}
const rate = (value: string) => Number(value) / 100;

export function TaxCategoryManager({
  categories,
  canEdit,
  loadError = false,
}: {
  categories: TaxCategory[];
  canEdit: boolean;
  loadError?: boolean;
}) {
  const router = useRouter();
  const [open, setOpen] = React.useState(false);
  const [editing, setEditing] = React.useState<TaxCategory | null>(null);
  const [archiveTarget, setArchiveTarget] = React.useState<TaxCategory | null>(
    null,
  );
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
  const edit = (category: TaxCategory) => {
    setEditing(category);
    setDraft(draftFor(category));
    setFormError(null);
    setOpen(true);
  };
  const save = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFormError(null);
    startSaving(async () => {
      const result = await saveTaxCategory({
        id: editing?.id,
        code: draft.code,
        name: draft.name,
        description: draft.description,
        cgst_rate: rate(draft.cgst),
        sgst_rate: rate(draft.sgst),
        igst_rate: rate(draft.igst),
        cess_rate: rate(draft.cess),
        hsn_sac_code: draft.hsn_sac_code,
        is_inclusive: draft.is_inclusive,
      });
      if (!result.ok) {
        setFormError(result.message);
        return;
      }
      setOpen(false);
      toast.success(editing ? "Tax category updated" : "Tax category added");
      router.refresh();
    });
  };
  const makeDefault = (category: TaxCategory) =>
    startSaving(async () => {
      const result = await setDefaultTaxCategory(category.id);
      if (!result.ok) {
        toast.error(result.message);
        return;
      }
      toast.success(`${category.name} is now the default tax category`);
      router.refresh();
    });
  const archive = () => {
    if (!archiveTarget) return;
    startSaving(async () => {
      const result = await archiveTaxCategory(archiveTarget.id);
      if (!result.ok) {
        toast.error(result.message);
        return;
      }
      setArchiveTarget(null);
      toast.success(
        "Tax category archived; existing orders and menu references are preserved",
      );
      router.refresh();
    });
  };

  return (
    <>
      <CardToolbar
        title="Tax categories"
        description="GST rates applied to menu items. Archived categories remain available to historical orders and invoices."
        action={
          canEdit ? (
            <Button size="sm" onClick={create}>
              <Plus aria-hidden /> Add category
            </Button>
          ) : null
        }
      />
      <CardContent className="p-0">
        {loadError ? (
          <InlineNotice tone="critical" className="m-4">
            Tax categories could not be loaded. Refresh the page and try again.
          </InlineNotice>
        ) : categories.length === 0 ? (
          <EmptyState
            title="No tax categories"
            description="Add a category before assigning tax to menu items."
            action={
              canEdit ? (
                <Button size="sm" onClick={create}>
                  <Plus aria-hidden /> Add category
                </Button>
              ) : undefined
            }
          />
        ) : (
          <TableWrap className="rounded-none border-0">
            <Table>
              <THead>
                <TR className="hover:bg-transparent">
                  <TH>Code</TH>
                  <TH>Name</TH>
                  <TH numeric>GST</TH>
                  <TH>HSN/SAC</TH>
                  <TH>Tax mode</TH>
                  <TH>State</TH>
                  {canEdit ? <TH>Actions</TH> : null}
                </TR>
              </THead>
              <TBody>
                {categories.map((category) => (
                  <TR key={category.id}>
                    <TD className="font-mono text-[12.5px] font-semibold">
                      {category.code}
                    </TD>
                    <TD className="text-[13px]">
                      {category.name}
                      {category.is_default ? (
                        <Badge tone="brand" className="ml-1.5">
                          Default
                        </Badge>
                      ) : null}
                    </TD>
                    <TD numeric className="tnum text-[13px] font-semibold">
                      {percentage(category.rate)}%
                    </TD>
                    <TD className="font-mono text-[12px] text-ink-muted">
                      {category.hsn_sac_code ?? "—"}
                    </TD>
                    <TD>
                      <Badge
                        tone={category.is_inclusive ? "positive" : "neutral"}
                      >
                        {category.is_inclusive ? "Inclusive" : "Added on top"}
                      </Badge>
                    </TD>
                    <TD>
                      <Badge tone={category.is_active ? "positive" : "neutral"}>
                        {category.is_active ? "Active" : "Inactive"}
                      </Badge>
                    </TD>
                    {canEdit ? (
                      <TD>
                        <div className="flex flex-wrap gap-1">
                          <Button
                            size="iconSm"
                            variant="ghost"
                            aria-label={`Edit ${category.name}`}
                            onClick={() => edit(category)}
                          >
                            <Pencil aria-hidden />
                          </Button>
                          {!category.is_default ? (
                            <Button
                              size="sm"
                              variant="secondary"
                              onClick={() => makeDefault(category)}
                              disabled={saving}
                            >
                              <Star aria-hidden /> Make default
                            </Button>
                          ) : null}
                          <Button
                            size="iconSm"
                            variant="ghost"
                            aria-label={`Archive ${category.name}`}
                            title={
                              category.is_default
                                ? "Choose another default category first."
                                : "Archive category"
                            }
                            disabled={category.is_default || saving}
                            onClick={() => setArchiveTarget(category)}
                          >
                            <Archive aria-hidden />
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
        <DialogContent size="lg">
          <DialogHeader>
            <DialogTitle>
              {editing ? "Edit tax category" : "Add tax category"}
            </DialogTitle>
            <DialogDescription>
              New tax values apply to future quotes. Existing orders retain
              their tax snapshots.
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={save}>
            <DialogBody className="space-y-4">
              {formError ? (
                <InlineNotice tone="critical">{formError}</InlineNotice>
              ) : null}
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label="Code" required>
                  <Input
                    value={draft.code}
                    onChange={(e) => set("code", e.target.value.toUpperCase())}
                    required
                    maxLength={30}
                  />
                </Field>
                <Field label="Name" required>
                  <Input
                    value={draft.name}
                    onChange={(e) => set("name", e.target.value)}
                    required
                    maxLength={120}
                  />
                </Field>
                <Field label="CGST (%)">
                  <Input
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    value={draft.cgst}
                    onChange={(e) => set("cgst", e.target.value)}
                  />
                </Field>
                <Field label="SGST (%)">
                  <Input
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    value={draft.sgst}
                    onChange={(e) => set("sgst", e.target.value)}
                  />
                </Field>
                <Field label="IGST (%)">
                  <Input
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    value={draft.igst}
                    onChange={(e) => set("igst", e.target.value)}
                  />
                </Field>
                <Field label="Cess (%)">
                  <Input
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    value={draft.cess}
                    onChange={(e) => set("cess", e.target.value)}
                  />
                </Field>
                <Field label="HSN/SAC">
                  <Input
                    value={draft.hsn_sac_code}
                    onChange={(e) => set("hsn_sac_code", e.target.value)}
                    maxLength={32}
                  />
                </Field>
              </div>
              <Field label="Description">
                <Textarea
                  value={draft.description}
                  onChange={(e) => set("description", e.target.value)}
                  maxLength={500}
                />
              </Field>
              <label className="flex items-center gap-2 text-sm">
                <Switch
                  checked={draft.is_inclusive}
                  onCheckedChange={(value) => set("is_inclusive", value)}
                />{" "}
                Prices include this tax
              </label>
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
                Save category
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={archiveTarget !== null}
        onOpenChange={(value) => !value && setArchiveTarget(null)}
        title={`Archive ${archiveTarget?.name ?? "tax category"}?`}
        description="The category is removed from future selection. Existing menu and order records keep their saved tax data."
        confirmLabel="Archive category"
        confirmText="ARCHIVE"
        destructive
        loading={saving}
        onConfirm={archive}
      />
    </>
  );
}
