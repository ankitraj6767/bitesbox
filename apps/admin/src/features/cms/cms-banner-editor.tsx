"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Save, Upload } from "lucide-react";
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
} from "@/components/ui/form-controls";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { errorMessage } from "@/lib/errors";
import { humanise } from "@/lib/utils";
import {
  BANNER_LINK_KINDS,
  type BannerLinkKind,
  type CmsBannerInitial,
  type CmsOption,
} from "./cms-types";

export function CmsBannerEditor({
  initial,
  sections,
  categories,
  products,
  coupons,
  collections,
}: {
  initial: CmsBannerInitial;
  sections: CmsOption[];
  categories: CmsOption[];
  products: CmsOption[];
  coupons: CmsOption[];
  collections: CmsOption[];
}) {
  const router = useRouter();
  const [form, setForm] = React.useState(() => normalise(initial));
  const [file, setFile] = React.useState<File | null>(null);
  const [saving, setSaving] = React.useState(false);

  const set = <K extends keyof ReturnType<typeof normalise>>(
    key: K,
    value: ReturnType<typeof normalise>[K],
  ) => setForm((current) => ({ ...current, [key]: value }));

  async function save(event: React.FormEvent) {
    event.preventDefault();
    if (!form.image_path.trim() && !file) {
      toast.error("Add a banner image or enter an existing storage path.");
      return;
    }
    if (!linkIsValid(form.link_kind, form)) {
      toast.error(
        `Choose the target for this ${humanise(form.link_kind).toLowerCase()} link.`,
      );
      return;
    }

    setSaving(true);
    try {
      const supabase = createSupabaseBrowserClient();
      let imagePath = form.image_path.trim();

      if (file) {
        const safeName = file.name.toLowerCase().replace(/[^a-z0-9._-]+/g, "-");
        imagePath = `cms/${crypto.randomUUID()}-${safeName}`;
        const { error } = await supabase.storage
          .from("banners")
          .upload(imagePath, file, {
            cacheControl: "3600",
            upsert: false,
            contentType: file.type || "image/jpeg",
          });
        if (error) throw error;
      }

      const payload = {
        section_id: form.section_id || null,
        title: form.title.trim() || null,
        subtitle: form.subtitle.trim() || null,
        badge_text: form.badge_text.trim() || null,
        image_path: imagePath,
        image_path_wide: form.image_path_wide.trim() || null,
        alt_text: form.alt_text.trim() || null,
        background_color: form.background_color.trim() || null,
        link_kind: form.link_kind,
        link_category_id:
          form.link_kind === "CATEGORY" ? form.link_category_id || null : null,
        link_product_id:
          form.link_kind === "PRODUCT" ? form.link_product_id || null : null,
        link_coupon_id:
          form.link_kind === "COUPON" ? form.link_coupon_id || null : null,
        link_collection_id:
          form.link_kind === "COLLECTION"
            ? form.link_collection_id || null
            : null,
        link_url:
          form.link_kind === "EXTERNAL_URL"
            ? form.link_url.trim() || null
            : null,
        link_route:
          form.link_kind === "IN_APP_ROUTE"
            ? form.link_route.trim() || null
            : null,
        display_order: Math.max(0, Number(form.display_order) || 0),
        is_active: form.is_active,
        starts_at: form.starts_at
          ? new Date(form.starts_at).toISOString()
          : null,
        ends_at: form.ends_at ? new Date(form.ends_at).toISOString() : null,
      };

      const result = form.id
        ? await supabase.from("cms_banners").update(payload).eq("id", form.id)
        : await supabase.from("cms_banners").insert(payload);
      if (result.error) throw result.error;

      toast.success(form.id ? "Banner updated" : "Banner created");
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
          title="Banner content"
          description="Artwork and copy used by the customer-facing carousel."
        />
        <CardContent className="grid gap-4 p-5 md:grid-cols-2">
          <Field label="Title">
            <Input
              value={form.title}
              onChange={(event) => set("title", event.target.value)}
              placeholder="Handi biryani, sealed and slow-cooked"
            />
          </Field>
          <Field label="Badge text">
            <Input
              value={form.badge_text}
              onChange={(event) => set("badge_text", event.target.value)}
              placeholder="SIGNATURE"
            />
          </Field>
          <Field label="Subtitle">
            <Input
              value={form.subtitle}
              onChange={(event) => set("subtitle", event.target.value)}
            />
          </Field>
          <Field
            label="Alt text"
            required
            hint="Describe the image for accessibility."
          >
            <Input
              value={form.alt_text}
              onChange={(event) => set("alt_text", event.target.value)}
              required
            />
          </Field>
          <Field
            label="Banner image"
            required
            hint="Upload a new image or enter an existing object path."
          >
            <Input
              type="file"
              accept="image/png,image/jpeg,image/webp,image/avif"
              onChange={(event) => setFile(event.target.files?.[0] ?? null)}
            />
            <div className="mt-1 flex items-center gap-2 text-[11.5px] text-ink-muted">
              <Upload className="size-3.5" />
              {file ? file.name : form.image_path || "No image selected"}
            </div>
          </Field>
          <Field label="Existing image path">
            <Input
              value={form.image_path}
              onChange={(event) => set("image_path", event.target.value)}
              placeholder="banners/hero-biryani.jpg"
            />
          </Field>
          <Field
            label="Wide image path"
            hint="Optional artwork for wider screens."
          >
            <Input
              value={form.image_path_wide}
              onChange={(event) => set("image_path_wide", event.target.value)}
            />
          </Field>
          <Field label="Background color">
            <Input
              value={form.background_color}
              onChange={(event) => set("background_color", event.target.value)}
              placeholder="#3B0A0D"
            />
          </Field>
        </CardContent>
      </Card>

      <Card>
        <CardToolbar
          title="Placement and link"
          description="Choose which section owns the banner and where it opens."
        />
        <CardContent className="grid gap-4 p-5 md:grid-cols-2">
          <Field label="Section">
            <Select
              value={form.section_id || "none"}
              onValueChange={(value) =>
                set("section_id", value === "none" ? "" : value)
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="No section" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">No section</SelectItem>
                {sections.map((item) => (
                  <SelectItem key={item.id} value={item.id}>
                    {item.label}
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
          <Field label="Link type" required>
            <Select
              value={form.link_kind}
              onValueChange={(value) =>
                set("link_kind", value as BannerLinkKind)
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {BANNER_LINK_KINDS.map((kind) => (
                  <SelectItem key={kind.value} value={kind.value}>
                    {kind.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          {form.link_kind === "CATEGORY" ? (
            <OptionField
              label="Category"
              value={form.link_category_id}
              options={categories}
              onChange={(value) => set("link_category_id", value)}
            />
          ) : null}
          {form.link_kind === "PRODUCT" ? (
            <OptionField
              label="Product"
              value={form.link_product_id}
              options={products}
              onChange={(value) => set("link_product_id", value)}
            />
          ) : null}
          {form.link_kind === "COUPON" ? (
            <OptionField
              label="Coupon"
              value={form.link_coupon_id}
              options={coupons}
              onChange={(value) => set("link_coupon_id", value)}
            />
          ) : null}
          {form.link_kind === "COLLECTION" ? (
            <OptionField
              label="Collection"
              value={form.link_collection_id}
              options={collections}
              onChange={(value) => set("link_collection_id", value)}
            />
          ) : null}
          {form.link_kind === "EXTERNAL_URL" ? (
            <Field label="External URL" required>
              <Input
                value={form.link_url}
                onChange={(event) => set("link_url", event.target.value)}
                type="url"
                required
              />
            </Field>
          ) : null}
          {form.link_kind === "IN_APP_ROUTE" ? (
            <Field
              label="In-app route"
              required
              hint="Example: bitesbox://offers"
            >
              <Input
                value={form.link_route}
                onChange={(event) => set("link_route", event.target.value)}
                required
              />
            </Field>
          ) : null}
          <label className="flex items-center gap-2 text-[13px] text-ink md:col-span-2">
            <input
              type="checkbox"
              checked={form.is_active}
              onChange={(event) => set("is_active", event.target.checked)}
            />
            Show this banner to customers
          </label>
        </CardContent>
      </Card>

      <Card>
        <CardToolbar
          title="Schedule"
          description="Leave blank to keep the banner eligible at all times."
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
          {form.id ? "Save changes" : "Create banner"}
        </Button>
      </div>
    </form>
  );
}

function OptionField({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: CmsOption[];
  onChange: (value: string) => void;
}) {
  return (
    <Field label={label} required>
      <Select
        value={value || "none"}
        onValueChange={(next) => onChange(next === "none" ? "" : next)}
      >
        <SelectTrigger>
          <SelectValue placeholder={`Choose ${label.toLowerCase()}`} />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="none">Choose {label.toLowerCase()}</SelectItem>
          {options.map((item) => (
            <SelectItem key={item.id} value={item.id}>
              {item.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </Field>
  );
}

function normalise(initial: CmsBannerInitial) {
  return {
    ...initial,
    section_id: initial.section_id ?? "",
    title: initial.title ?? "",
    subtitle: initial.subtitle ?? "",
    badge_text: initial.badge_text ?? "",
    image_path_wide: initial.image_path_wide ?? "",
    alt_text: initial.alt_text ?? "",
    background_color: initial.background_color ?? "",
    link_category_id: initial.link_category_id ?? "",
    link_product_id: initial.link_product_id ?? "",
    link_coupon_id: initial.link_coupon_id ?? "",
    link_collection_id: initial.link_collection_id ?? "",
    link_url: initial.link_url ?? "",
    link_route: initial.link_route ?? "",
    starts_at: toLocalInput(initial.starts_at),
    ends_at: toLocalInput(initial.ends_at),
  };
}

function linkIsValid(kind: BannerLinkKind, form: ReturnType<typeof normalise>) {
  return (
    kind === "NONE" ||
    (kind === "CATEGORY" && Boolean(form.link_category_id)) ||
    (kind === "PRODUCT" && Boolean(form.link_product_id)) ||
    (kind === "COUPON" && Boolean(form.link_coupon_id)) ||
    (kind === "COLLECTION" && Boolean(form.link_collection_id)) ||
    (kind === "EXTERNAL_URL" && Boolean(form.link_url.trim())) ||
    (kind === "IN_APP_ROUTE" && Boolean(form.link_route.trim()))
  );
}

function toLocalInput(value: string | null): string {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value.slice(0, 16);
  const pad = (number: number) => String(number).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
