"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Plus, Save, Trash2 } from "lucide-react";
import { toast } from "sonner";
import type { Database } from "@bitesbox/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardToolbar } from "@/components/ui/card";
import { Field, Input, Switch } from "@/components/ui/form-controls";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { errorMessage } from "@/lib/errors";

type Variant = {
  id: string;
  name: string;
  name_hi: string | null;
  option_group: string;
  option_group_hi: string | null;
  sku: string | null;
  price: number;
  compare_price: number | null;
  calories: number | null;
  serves_count: number | null;
  preparation_minutes: number | null;
  is_default: boolean;
  is_active: boolean;
  display_order: number;
  availability: Database["public"]["Enums"]["availability_state"];
};

type VariantDraft = Variant & { isNew?: boolean; isRemoved?: boolean };

type ModifierGroup = {
  id: string;
  name: string;
  name_hi: string | null;
  description: string | null;
  is_active: boolean;
  selection: Database["public"]["Enums"]["modifier_selection"];
  is_required: boolean;
  min_select: number;
  max_select: number | null;
  display_order: number;
  modifiers: {
    id: string;
    name: string;
    name_hi: string | null;
    price: number;
    food_type: Database["public"]["Enums"]["food_type"];
    is_active: boolean;
  }[];
};

type ProductGroupLink = {
  id: string;
  modifier_group_id: string;
  is_required: boolean | null;
  min_select: number | null;
  max_select: number | null;
  display_order: number;
};

type ModifierGroupDraft = ModifierGroup & {
  attached: boolean;
  link_id: string | null;
  required: boolean;
  min: number;
  max: number | null;
};

function currency(value: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(value);
}

function numberOrNull(value: string) {
  if (!value.trim()) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function makeVariantDraft(variant: Variant): VariantDraft {
  return { ...variant };
}

export function ProductConfigurationEditor({
  productId,
  basePrice,
  variants: initialVariants,
  modifierGroups: initialGroups,
  productGroupLinks,
  canManage,
  canChangePrice,
}: {
  productId: string;
  basePrice: number;
  variants: Variant[];
  modifierGroups: ModifierGroup[];
  productGroupLinks: ProductGroupLink[];
  canManage: boolean;
  canChangePrice: boolean;
}) {
  const router = useRouter();
  const [variants, setVariants] = React.useState(() =>
    initialVariants.map(makeVariantDraft),
  );
  const [groups, setGroups] = React.useState<ModifierGroupDraft[]>(() => {
    const linksByGroup = new Map(
      productGroupLinks.map((link) => [link.modifier_group_id, link]),
    );
    return initialGroups.map((group) => {
      const link = linksByGroup.get(group.id);
      return {
        ...group,
        attached: Boolean(link),
        link_id: link?.id ?? null,
        display_order: link?.display_order ?? group.display_order,
        required: link?.is_required ?? group.is_required,
        min: link?.min_select ?? group.min_select,
        max: link?.max_select ?? group.max_select,
      };
    });
  });
  const [savingOptions, setSavingOptions] = React.useState(false);
  const [savingGroups, setSavingGroups] = React.useState(false);

  function updateVariant(id: string, patch: Partial<VariantDraft>) {
    setVariants((current) =>
      current.map((variant) =>
        variant.id === id ? { ...variant, ...patch } : variant,
      ),
    );
  }

  function addVariant() {
    const id = `draft-${crypto.randomUUID()}`;
    setVariants((current) => [
      ...current,
      {
        id,
        name: "",
        name_hi: "",
        option_group: current[0]?.option_group ?? "Size",
        option_group_hi: current[0]?.option_group_hi ?? "आकार",
        sku: null,
        price: basePrice,
        compare_price: null,
        calories: null,
        serves_count: 1,
        preparation_minutes: 15,
        is_default: current.every((variant) => variant.isRemoved),
        is_active: true,
        display_order: current.length + 1,
        availability: "AVAILABLE",
        isNew: true,
      },
    ]);
  }

  async function saveVariants() {
    if (!canManage) return;
    const activeVariants = variants.filter((variant) => !variant.isRemoved);
    const removedVariants = variants.filter(
      (variant) => variant.isRemoved && !variant.isNew,
    );

    if (
      activeVariants.some(
        (variant) => !variant.name.trim() || !variant.option_group.trim(),
      )
    ) {
      toast.error("Each option needs a name and an option group.");
      return;
    }
    if (activeVariants.some((variant) => variant.price < 0)) {
      toast.error("Option prices cannot be negative.");
      return;
    }
    if (
      activeVariants.some(
        (variant) =>
          variant.compare_price !== null &&
          variant.compare_price < variant.price,
      )
    ) {
      toast.error("Compare-at prices must be at least the option price.");
      return;
    }
    if (activeVariants.filter((variant) => variant.is_default).length > 1) {
      toast.error("Choose only one default option.");
      return;
    }
    if (
      activeVariants.some((variant) => variant.is_default && !variant.is_active)
    ) {
      toast.error("The default option must be active.");
      return;
    }
    if (
      activeVariants.length &&
      !activeVariants.some((variant) => variant.is_default)
    ) {
      toast.error("Choose a default option before saving.");
      return;
    }
    if (!canChangePrice && activeVariants.some((variant) => variant.isNew)) {
      toast.error("Price update access is required to add a priced option.");
      return;
    }

    const previousDefault = variants.find(
      (variant) => variant.is_default && !variant.isRemoved && !variant.isNew,
    )?.id;
    const nextDefault = activeVariants.find((variant) => variant.is_default);
    const supabase = createSupabaseBrowserClient();
    setSavingOptions(true);

    try {
      const { error: clearError } = await supabase
        .from("product_variants")
        .update({ is_default: false })
        .eq("product_id", productId)
        .is("deleted_at", null);
      if (clearError) throw clearError;

      for (const variant of removedVariants) {
        const { error } = await supabase
          .from("product_variants")
          .update({
            deleted_at: new Date().toISOString(),
            is_active: false,
            is_default: false,
          })
          .eq("id", variant.id);
        if (error) throw error;
      }

      const insertedIds = new Map<string, string>();
      for (const [index, variant] of activeVariants.entries()) {
        const sharedPayload = {
          product_id: productId,
          name: variant.name.trim(),
          name_hi: variant.name_hi?.trim() || null,
          option_group: variant.option_group.trim(),
          option_group_hi: variant.option_group_hi?.trim() || null,
          sku: variant.sku,
          calories: variant.calories,
          serves_count: variant.serves_count,
          preparation_minutes: variant.preparation_minutes,
          is_default: false,
          is_active: variant.is_active,
          display_order: index + 1,
        };
        if (variant.isNew) {
          const { data, error } = await supabase
            .from("product_variants")
            .insert({
              ...sharedPayload,
              price: variant.price,
              compare_price: variant.compare_price,
            })
            .select("id")
            .single();
          if (error) throw error;
          insertedIds.set(variant.id, data.id);
          setVariants((current) =>
            current.map((item) =>
              item.id === variant.id
                ? { ...item, id: data.id, isNew: false }
                : item,
            ),
          );
        } else {
          const { error } = await supabase
            .from("product_variants")
            .update({
              ...sharedPayload,
              ...(canChangePrice
                ? { price: variant.price, compare_price: variant.compare_price }
                : {}),
            })
            .eq("id", variant.id);
          if (error) throw error;
        }
      }

      if (nextDefault) {
        const defaultId = insertedIds.get(nextDefault.id) ?? nextDefault.id;
        const { error } = await supabase
          .from("product_variants")
          .update({ is_default: true })
          .eq("id", defaultId);
        if (error) throw error;
      }

      setVariants(
        activeVariants.map((variant, index) => ({
          ...variant,
          id: insertedIds.get(variant.id) ?? variant.id,
          isNew: false,
          isRemoved: false,
          display_order: index + 1,
        })),
      );
      toast.success("Dish options saved");
      router.refresh();
    } catch (error) {
      if (previousDefault) {
        const { error: restoreError } = await supabase
          .from("product_variants")
          .update({ is_default: true })
          .eq("id", previousDefault);
        if (restoreError)
          toast.error("Could not restore the previous default option.");
      }
      toast.error(errorMessage(error));
    } finally {
      setSavingOptions(false);
    }
  }

  function updateGroup(id: string, patch: Partial<ModifierGroupDraft>) {
    setGroups((current) =>
      current.map((group) =>
        group.id === id ? { ...group, ...patch } : group,
      ),
    );
  }

  async function saveGroups() {
    if (!canManage) return;
    for (const group of groups.filter((choice) => choice.attached)) {
      if (
        group.min < 0 ||
        (group.max !== null && group.max < Math.max(group.min, 1))
      ) {
        toast.error(`${group.name}: check the minimum and maximum selections.`);
        return;
      }
      if (group.required && group.min < 1) {
        toast.error(
          `${group.name}: a required group needs at least one selection.`,
        );
        return;
      }
      if (group.selection === "SINGLE" && group.min > 1) {
        toast.error(
          `${group.name} allows one choice, so its minimum can be at most one.`,
        );
        return;
      }
    }

    const supabase = createSupabaseBrowserClient();
    setSavingGroups(true);
    try {
      for (const group of groups) {
        if (group.attached) {
          const payload = {
            product_id: productId,
            modifier_group_id: group.id,
            is_required: group.required,
            min_select: group.min,
            max_select: group.selection === "SINGLE" ? 1 : group.max,
            display_order: group.display_order,
          };
          const { data, error } = await supabase
            .from("product_modifier_groups")
            .upsert(payload, { onConflict: "product_id,modifier_group_id" })
            .select("id")
            .single();
          if (error) throw error;
          setGroups((current) =>
            current.map((item) =>
              item.id === group.id ? { ...item, link_id: data.id } : item,
            ),
          );
        } else if (group.link_id) {
          const { error } = await supabase
            .from("product_modifier_groups")
            .delete()
            .eq("id", group.link_id);
          if (error) throw error;
          setGroups((current) =>
            current.map((item) =>
              item.id === group.id ? { ...item, link_id: null } : item,
            ),
          );
        }
      }

      toast.success("Dish add-on groups saved");
      router.refresh();
    } catch (error) {
      toast.error(errorMessage(error));
    } finally {
      setSavingGroups(false);
    }
  }

  const visibleVariants = variants.filter((variant) => !variant.isRemoved);

  return (
    <div className="mt-4 grid gap-4 lg:grid-cols-2">
      <Card>
        <CardToolbar
          title="Options"
          description="Sizes and portions customers can choose"
          action={
            canManage ? (
              <Button
                type="button"
                size="sm"
                variant="secondary"
                onClick={addVariant}
                disabled={!canChangePrice}
              >
                <Plus /> Add option
              </Button>
            ) : null
          }
        />
        <CardContent className="space-y-4">
          {!canChangePrice && canManage ? (
            <p className="text-[12px] text-ink-muted">
              Price update permission is needed to add a priced option.
            </p>
          ) : null}
          {visibleVariants.length === 0 ? (
            <div className="rounded-lg border border-dashed border-hairline bg-surface-muted/60 px-4 py-4">
              <p className="text-[13px] font-medium text-ink">
                Single-size dish
              </p>
              <p className="mt-1 text-[12px] text-ink-muted">
                Add serving sizes or portions when this dish is offered in more
                than one format.
              </p>
            </div>
          ) : null}
          {visibleVariants.map((variant, index) => (
            <div
              key={variant.id}
              className="rounded-lg border border-hairline bg-canvas p-4"
            >
              <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <Button
                    type="button"
                    size="sm"
                    variant={variant.is_default ? "subtle" : "ghost"}
                    disabled={!canManage}
                    aria-pressed={variant.is_default}
                    onClick={() =>
                      setVariants((current) =>
                        current.map((item) => ({
                          ...item,
                          is_default: item.id === variant.id,
                        })),
                      )
                    }
                  >
                    {variant.is_default ? "Default option" : "Set as default"}
                  </Button>
                  <Badge tone={variant.is_active ? "positive" : "neutral"}>
                    {variant.is_active ? "Active" : "Hidden"}
                  </Badge>
                </div>
                {canManage ? (
                  <Button
                    type="button"
                    variant="ghost"
                    size="iconSm"
                    aria-label={`Remove ${variant.name || `option ${index + 1}`}`}
                    onClick={() => {
                      if (variant.isNew)
                        setVariants((current) =>
                          current.filter((item) => item.id !== variant.id),
                        );
                      else updateVariant(variant.id, { isRemoved: true });
                    }}
                  >
                    <Trash2 />
                  </Button>
                ) : null}
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label="Option name">
                  <Input
                    value={variant.name}
                    disabled={!canManage}
                    onChange={(event) =>
                      updateVariant(variant.id, { name: event.target.value })
                    }
                  />
                </Field>
                <Field label="Option name (Hindi)">
                  <Input
                    lang="hi"
                    value={variant.name_hi ?? ""}
                    disabled={!canManage}
                    onChange={(event) =>
                      updateVariant(variant.id, { name_hi: event.target.value })
                    }
                  />
                </Field>
                <Field label="Option group">
                  <Input
                    value={variant.option_group}
                    disabled={!canManage}
                    onChange={(event) =>
                      updateVariant(variant.id, {
                        option_group: event.target.value,
                      })
                    }
                  />
                </Field>
                <Field label="Option group (Hindi)">
                  <Input
                    lang="hi"
                    value={variant.option_group_hi ?? ""}
                    disabled={!canManage}
                    onChange={(event) =>
                      updateVariant(variant.id, {
                        option_group_hi: event.target.value,
                      })
                    }
                  />
                </Field>
                <Field label="Price">
                  <Input
                    type="number"
                    min="0"
                    step="1"
                    value={variant.price}
                    disabled={!canManage || !canChangePrice}
                    onChange={(event) =>
                      updateVariant(variant.id, {
                        price: Number(event.target.value),
                      })
                    }
                  />
                </Field>
                <Field label="Compare-at price">
                  <Input
                    type="number"
                    min="0"
                    step="1"
                    value={variant.compare_price ?? ""}
                    disabled={!canManage || !canChangePrice}
                    onChange={(event) =>
                      updateVariant(variant.id, {
                        compare_price: numberOrNull(event.target.value),
                      })
                    }
                  />
                </Field>
                <Field label="Serves">
                  <Input
                    type="number"
                    min="1"
                    max="20"
                    step="1"
                    value={variant.serves_count ?? ""}
                    disabled={!canManage}
                    onChange={(event) =>
                      updateVariant(variant.id, {
                        serves_count: numberOrNull(event.target.value),
                      })
                    }
                  />
                </Field>
                <Field label="Preparation time (minutes)">
                  <Input
                    type="number"
                    min="1"
                    max="240"
                    step="1"
                    value={variant.preparation_minutes ?? ""}
                    disabled={!canManage}
                    onChange={(event) =>
                      updateVariant(variant.id, {
                        preparation_minutes: numberOrNull(event.target.value),
                      })
                    }
                  />
                </Field>
              </div>
              {canManage ? (
                <div className="mt-3 flex items-center justify-between gap-4 rounded-md bg-surface-muted px-3 py-2 text-[12px] text-ink">
                  <span>Visible to customers</span>
                  <Switch
                    checked={variant.is_active}
                    onCheckedChange={(checked) =>
                      updateVariant(variant.id, { is_active: checked })
                    }
                    aria-label={`Toggle ${variant.name || "option"} availability`}
                  />
                </div>
              ) : null}
            </div>
          ))}
          {canManage ? (
            <div className="flex items-center justify-between gap-3 border-t border-hairline pt-4">
              <p className="text-[12px] text-ink-muted">
                {visibleVariants.length
                  ? `${visibleVariants.length} option${visibleVariants.length === 1 ? "" : "s"} configured`
                  : "No size choice will be shown to customers."}
              </p>
              <Button
                type="button"
                onClick={() => void saveVariants()}
                loading={savingOptions}
              >
                <Save /> Save options
              </Button>
            </div>
          ) : null}
        </CardContent>
      </Card>

      <Card>
        <CardToolbar
          title="Add-on groups"
          description="Choose which customization groups are available for this dish"
        />
        <CardContent className="space-y-3">
          {groups.length === 0 ? (
            <p className="text-[13px] text-ink-muted">
              No add-on groups are available in the catalog.
            </p>
          ) : null}
          {groups.map((group) => (
            <div
              key={group.id}
              className="rounded-lg border border-hairline bg-canvas p-4"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <h3 className="text-[13px] font-semibold text-ink">
                      {group.name}
                    </h3>
                    <Badge tone="neutral">
                      {group.selection === "SINGLE"
                        ? "Choose one"
                        : "Choose many"}
                    </Badge>
                    {group.attached ? (
                      <Badge tone="positive">Attached</Badge>
                    ) : null}
                    {!group.is_active ? (
                      <Badge tone="caution">Inactive in catalog</Badge>
                    ) : null}
                  </div>
                  <p className="mt-1 text-[12px] text-ink-muted">
                    {group.description ??
                      group.name_hi ??
                      "Available customization choices"}
                  </p>
                </div>
                {canManage ? (
                  <div className="flex items-center gap-2 text-[12px] font-medium text-ink">
                    <span>{group.attached ? "On" : "Off"}</span>
                    <Switch
                      checked={group.attached}
                      onCheckedChange={(attached) =>
                        updateGroup(group.id, { attached })
                      }
                      aria-label={`${group.attached ? "Detach" : "Attach"} ${group.name}`}
                      disabled={!group.is_active && !group.attached}
                    />
                  </div>
                ) : null}
              </div>
              {group.modifiers.length ? (
                <ul
                  className="mt-3 flex flex-wrap gap-2"
                  aria-label={`${group.name} choices`}
                >
                  {group.modifiers
                    .filter((modifier) => modifier.is_active)
                    .map((modifier) => (
                      <li key={modifier.id}>
                        <Badge tone="neutral">
                          {modifier.name} · {currency(Number(modifier.price))}
                        </Badge>
                      </li>
                    ))}
                </ul>
              ) : null}
              {group.attached && canManage ? (
                <div className="mt-4 grid gap-3 border-t border-hairline pt-3 sm:grid-cols-3">
                  <div className="flex items-center justify-between gap-3 text-[12px] text-ink">
                    <span>Require a choice</span>
                    <Switch
                      checked={group.required}
                      onCheckedChange={(required) =>
                        updateGroup(group.id, {
                          required,
                          min: required ? Math.max(1, group.min) : 0,
                        })
                      }
                      aria-label={`Require a choice from ${group.name}`}
                    />
                  </div>
                  <Field label="Minimum choices">
                    <Input
                      type="number"
                      min="0"
                      step="1"
                      value={group.min}
                      onChange={(event) =>
                        updateGroup(group.id, {
                          min: numberOrNull(event.target.value) ?? 0,
                        })
                      }
                    />
                  </Field>
                  <Field label="Maximum choices">
                    <Input
                      type="number"
                      min="1"
                      step="1"
                      value={
                        group.selection === "SINGLE" ? 1 : (group.max ?? "")
                      }
                      placeholder="No limit"
                      disabled={group.selection === "SINGLE"}
                      onChange={(event) =>
                        updateGroup(group.id, {
                          max: numberOrNull(event.target.value),
                        })
                      }
                    />
                  </Field>
                </div>
              ) : null}
            </div>
          ))}
          {canManage ? (
            <div className="flex items-center justify-between gap-3 border-t border-hairline pt-4">
              <p className="text-[12px] text-ink-muted">
                {groups.filter((group) => group.attached).length} group
                {groups.filter((group) => group.attached).length === 1
                  ? ""
                  : "s"}{" "}
                attached
              </p>
              <Button
                type="button"
                onClick={() => void saveGroups()}
                loading={savingGroups}
              >
                <Save /> Save add-ons
              </Button>
            </div>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
