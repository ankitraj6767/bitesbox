"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Save } from "lucide-react";
import { toast } from "sonner";
import { Card, CardContent, CardToolbar } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  Field,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Textarea,
} from "@/components/ui/form-controls";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { errorMessage } from "@/lib/errors";
import { humanise } from "@/lib/utils";
import {
  SECTION_KINDS,
  type CmsLayout,
  type CmsOption,
  type CmsSectionInitial,
} from "./cms-types";
import type { Json } from "@bitesbox/shared-types";

const layouts: CmsLayout[] = ["CAROUSEL", "GRID", "LIST", "BANNER", "STRIP"];

export function CmsSectionEditor({
  initial,
  categories,
  collections,
}: {
  initial: CmsSectionInitial;
  categories: CmsOption[];
  collections: CmsOption[];
}) {
  const router = useRouter();
  const [form, setForm] = React.useState(() => normalise(initial));
  const [saving, setSaving] = React.useState(false);

  const set = <K extends keyof ReturnType<typeof normalise>>(
    key: K,
    value: ReturnType<typeof normalise>[K],
  ) => setForm((current) => ({ ...current, [key]: value }));

  async function save(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);

    try {
      const rule = parseRule(form.rule);
      const payload = {
        kind: form.kind,
        section_key: form.section_key.trim().toLowerCase(),
        title: form.title.trim() || null,
        subtitle: form.subtitle.trim() || null,
        action_label: form.action_label.trim() || null,
        action_route: form.action_route.trim() || null,
        layout: form.layout,
        item_limit: Math.max(1, Math.min(50, Number(form.item_limit) || 1)),
        display_order: Math.max(0, Number(form.display_order) || 0),
        is_active: form.is_active,
        requires_auth: form.requires_auth,
        category_id: form.category_id || null,
        collection_id: form.collection_id || null,
        rule,
        background_color: form.background_color.trim() || null,
        text_color: form.text_color.trim() || null,
        image_path: form.image_path.trim() || null,
        rich_text: form.rich_text.trim() || null,
        starts_at: form.starts_at
          ? new Date(form.starts_at).toISOString()
          : null,
        ends_at: form.ends_at ? new Date(form.ends_at).toISOString() : null,
        valid_days_of_week: form.valid_days_of_week,
        valid_from_time: form.valid_from_time || null,
        valid_to_time: form.valid_to_time || null,
      };

      const supabase = createSupabaseBrowserClient();
      const result = form.id
        ? await supabase.from("cms_sections").update(payload).eq("id", form.id)
        : await supabase.from("cms_sections").insert(payload);
      if (result.error) throw result.error;

      toast.success(form.id ? "Home section updated" : "Home section created");
      router.push("/cms");
      router.refresh();
    } catch (error) {
      toast.error(errorMessage(error));
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={save} className="space-y-4">
      <Card>
        <CardToolbar
          title="Section identity"
          description="The block and stable key used by the customer home feed."
        />
        <CardContent className="grid gap-4 p-5 md:grid-cols-2">
          <Field label="Section type" required>
            <Select
              value={form.kind}
              onValueChange={(value) => set("kind", value as typeof form.kind)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SECTION_KINDS.map((kind) => (
                  <SelectItem key={kind.value} value={kind.value}>
                    {kind.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          <Field
            label="Stable key"
            required
            hint="Lowercase letters, numbers and hyphens only."
          >
            <Input
              value={form.section_key}
              onChange={(event) => set("section_key", event.target.value)}
              pattern="[a-z0-9]+(?:-[a-z0-9]+)*"
              required
            />
          </Field>
          <Field label="Title">
            <Input
              value={form.title}
              onChange={(event) => set("title", event.target.value)}
              placeholder="What are you craving?"
            />
          </Field>
          <Field label="Subtitle">
            <Input
              value={form.subtitle}
              onChange={(event) => set("subtitle", event.target.value)}
              placeholder="Browse by category"
            />
          </Field>
          <Field label="Action label">
            <Input
              value={form.action_label}
              onChange={(event) => set("action_label", event.target.value)}
              placeholder="See all"
            />
          </Field>
          <Field label="Action route" hint="Example: bitesbox://menu">
            <Input
              value={form.action_route}
              onChange={(event) => set("action_route", event.target.value)}
            />
          </Field>
          <Field label="Layout">
            <Select
              value={form.layout}
              onValueChange={(value) => set("layout", value as CmsLayout)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {layouts.map((layout) => (
                  <SelectItem key={layout} value={layout}>
                    {humanise(layout)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          <Field label="Display order">
            <Input
              type="number"
              min="0"
              step="1"
              value={String(form.display_order)}
              onChange={(event) =>
                set("display_order", Number(event.target.value))
              }
            />
          </Field>
          <Field label="Item limit" hint="Between 1 and 50.">
            <Input
              type="number"
              min="1"
              max="50"
              step="1"
              value={String(form.item_limit)}
              onChange={(event) =>
                set("item_limit", Number(event.target.value))
              }
            />
          </Field>
          <Field label="Category binding">
            <Select
              value={form.category_id || "none"}
              onValueChange={(value) =>
                set("category_id", value === "none" ? "" : value)
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="No category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">No category</SelectItem>
                {categories.map((item) => (
                  <SelectItem key={item.id} value={item.id}>
                    {item.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          <Field label="Collection binding">
            <Select
              value={form.collection_id || "none"}
              onValueChange={(value) =>
                set("collection_id", value === "none" ? "" : value)
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="No collection" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">No collection</SelectItem>
                {collections.map((item) => (
                  <SelectItem key={item.id} value={item.id}>
                    {item.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
        </CardContent>
      </Card>

      <Card>
        <CardToolbar
          title="Presentation and rules"
          description="Optional colors, rich text and JSON rules used by the feed resolver."
        />
        <CardContent className="grid gap-4 p-5 md:grid-cols-2">
          <Field
            label="Background color"
            hint="Six-digit hex, for example #FFF4E8."
          >
            <Input
              value={form.background_color}
              onChange={(event) => set("background_color", event.target.value)}
              placeholder="#FFF4E8"
            />
          </Field>
          <Field label="Text color" hint="Six-digit hex, for example #1A1614.">
            <Input
              value={form.text_color}
              onChange={(event) => set("text_color", event.target.value)}
              placeholder="#1A1614"
            />
          </Field>
          <Field
            label="Image path"
            hint="Object path in the public CMS/banner storage bucket."
          >
            <Input
              value={form.image_path}
              onChange={(event) => set("image_path", event.target.value)}
            />
          </Field>
          <Field label="Rule JSON" hint='Example: {"max_price":199}'>
            <Input
              value={form.rule}
              onChange={(event) => set("rule", event.target.value)}
              className="font-mono"
            />
          </Field>
          <Field label="Rich text" className="md:col-span-2">
            <Textarea
              value={form.rich_text}
              onChange={(event) => set("rich_text", event.target.value)}
              rows={5}
              placeholder="Optional customer-facing text."
            />
          </Field>
          <label className="flex items-center gap-2 text-[13px] text-ink">
            <input
              type="checkbox"
              checked={form.is_active}
              onChange={(event) => set("is_active", event.target.checked)}
            />
            Show on the customer home screen
          </label>
          <label className="flex items-center gap-2 text-[13px] text-ink">
            <input
              type="checkbox"
              checked={form.requires_auth}
              onChange={(event) => set("requires_auth", event.target.checked)}
            />
            Signed-in customers only
          </label>
        </CardContent>
      </Card>

      <Card>
        <CardToolbar
          title="Schedule"
          description="Leave the fields blank for an always-eligible section."
        />
        <CardContent className="grid gap-4 p-5 md:grid-cols-2">
          <Field label="Starts at">
            <Input
              type="datetime-local"
              value={toLocalInput(form.starts_at)}
              onChange={(event) => set("starts_at", event.target.value)}
            />
          </Field>
          <Field label="Ends at">
            <Input
              type="datetime-local"
              value={toLocalInput(form.ends_at)}
              onChange={(event) => set("ends_at", event.target.value)}
            />
          </Field>
          <Field label="Valid from">
            <Input
              type="time"
              value={form.valid_from_time}
              onChange={(event) => set("valid_from_time", event.target.value)}
            />
          </Field>
          <Field label="Valid to">
            <Input
              type="time"
              value={form.valid_to_time}
              onChange={(event) => set("valid_to_time", event.target.value)}
            />
          </Field>
          <div className="md:col-span-2">
            <p className="mb-2 text-[13px] font-medium text-ink">
              Days of week
            </p>
            <div className="flex flex-wrap gap-2">
              {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map(
                (day, index) => (
                  <label
                    key={day}
                    className="flex items-center gap-1.5 text-[13px] text-ink"
                  >
                    <input
                      type="checkbox"
                      checked={form.valid_days_of_week.includes(index)}
                      onChange={(event) =>
                        set(
                          "valid_days_of_week",
                          event.target.checked
                            ? [...form.valid_days_of_week, index].sort()
                            : form.valid_days_of_week.filter(
                                (value) => value !== index,
                              ),
                        )
                      }
                    />
                    {day}
                  </label>
                ),
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="flex justify-end gap-2">
        <Button
          type="button"
          variant="secondary"
          onClick={() => router.push("/cms")}
        >
          Cancel
        </Button>
        <Button type="submit" loading={saving}>
          <Save />
          {form.id ? "Save changes" : "Create section"}
        </Button>
      </div>
    </form>
  );
}

function normalise(initial: CmsSectionInitial) {
  return {
    ...initial,
    title: initial.title ?? "",
    subtitle: initial.subtitle ?? "",
    action_label: initial.action_label ?? "",
    action_route: initial.action_route ?? "",
    category_id: initial.category_id ?? "",
    collection_id: initial.collection_id ?? "",
    rule: JSON.stringify(initial.rule ?? {}),
    background_color: initial.background_color ?? "",
    text_color: initial.text_color ?? "",
    image_path: initial.image_path ?? "",
    rich_text: initial.rich_text ?? "",
    starts_at: toLocalInput(initial.starts_at),
    ends_at: toLocalInput(initial.ends_at),
    valid_from_time: initial.valid_from_time?.slice(0, 5) ?? "",
    valid_to_time: initial.valid_to_time?.slice(0, 5) ?? "",
    valid_days_of_week: initial.valid_days_of_week?.length
      ? initial.valid_days_of_week
      : [0, 1, 2, 3, 4, 5, 6],
  };
}

function parseRule(value: string): Json {
  if (!value.trim()) return {};
  const parsed: unknown = JSON.parse(value);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
    throw new Error("Rule JSON must be an object.");
  return parsed as Json;
}

function toLocalInput(value: string | null): string {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value.slice(0, 16);
  const pad = (number: number) => String(number).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
